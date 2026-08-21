# 診断（仮説）と実際の記録（実測）のズレを算出する。
#
# 診断は「好みの強さ」を測っているため、比較相手は「飲んだもの」ではなく
# 「高く評価したもの」＝★4以上の記録でなければ意味が揃わない。
# 全記録を使うと、惰性で飲んだ一杯まで好みとして数えてしまう（#120）。
class DiagnosisGap
  # 比較に必要な★4以上の記録数。おすすめが実データへ切り替わる閾値に合わせる
  MIN_LOGS = RecommendedRoast::MIN_LIKED

  # このスコア差（0..10）以上あれば「ズレている」とみなす
  LARGE_GAP = 3.0

  # 比較できるのは苦味と酸味のみ。
  # コクは記録側で収集しておらず、甘みは診断側が固定値5のため比較にならない。
  AXES = {
    bitterness: { score: :bitterness_score, bar: "苦味" },
    acidity:    { score: :acidity_score,    bar: "酸味" }
  }.freeze

  def initialize(taste_profile:, preference_liked:)
    @taste_profile = taste_profile
    @liked = preference_liked
  end

  def call
    return unavailable unless comparable?

    axes  = build_axes
    roast = build_roast

    {
      available: true,
      logs_count: @liked[:logs_count],
      roast: roast,
      axes: axes,
      verdict: verdict(roast, axes)
    }
  end

  private

  def unavailable
    { available: false, roast: nil, axes: [], verdict: nil }
  end

  # 味の比較は焙煎度が不明でも成り立つため logs_count で判定する。
  def comparable?
    @taste_profile.present? &&
      @liked[:available] &&
      @liked[:logs_count].to_i >= MIN_LOGS
  end

  # 焙煎度の比較だけは、おすすめと同じ roast_logs_count で判定する。
  # logs_count（不明を含む）で判定すると、焙煎度既知が1件でも
  # 「実際は深煎り」と断言してしまい、おすすめの表示と食い違う（#120 レビュー指摘）。
  #
  # 同点が MAX_TIED を超える場合は、おすすめ側も実データを根拠にしない。
  # ここだけ「実際は◯◯」と言うと、同じ画面で食い違う（#146）。
  def roast_comparable?
    @liked[:roast_available] &&
      @liked[:roast_logs_count].to_i >= MIN_LOGS &&
      rated_keys.size.between?(1, RecommendedRoast::MAX_TIED)
  end

  def rated_keys
    @liked[:top_rated_roast_keys].to_a
  end

  def build_axes
    AXES.map do |key, conf|
      diagnosed = @taste_profile.public_send(conf[:score]).to_f
      # キーが変わったら静かに 0.0 になり「大きなズレ」と誤表示するため fetch で落とす
      actual    = @liked[:taste_bar].fetch(conf[:bar]).to_f
      diff      = (actual - diagnosed).round(1)

      {
        key: key,
        diagnosed: diagnosed,
        actual: actual,
        diff: diff.abs,
        direction: direction_of(diff),
        large: diff.abs >= LARGE_GAP
      }
    end
  end

  def direction_of(diff)
    return :same if diff.zero?

    diff.positive? ? :higher : :lower
  end

  # 実際の好みは、おすすめが示すものと同じ値を使う。
  # ここで別の選び方をすると、同じ画面内で違う焙煎度を提示することになる。
  def build_roast
    return nil unless roast_comparable?

    diagnosed_key = @taste_profile.preferred_roast.to_s

    # 同点で2つ並ぶことがある。診断結果がそのどちらかなら「診断どおり」とみなす。
    # 片方だけと突き合わせて「ズレている」と言うと、おすすめの併記と食い違う（#146）。
    {
      diagnosed_key: diagnosed_key,
      diagnosed_label: PreferenceSummary::ROAST_LABELS.fetch(diagnosed_key, diagnosed_key),
      actual_keys: rated_keys,
      actual_label: @liked[:top_rated_roast_labels].to_a.join("・"),
      match: rated_keys.include?(diagnosed_key)
    }
  end

  def verdict(roast, axes)
    return :diverged if roast && !roast[:match]
    return :diverged if axes.any? { |a| a[:large] }

    :aligned
  end
end
