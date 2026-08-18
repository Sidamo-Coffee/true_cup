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

  def comparable?
    @taste_profile.present? &&
      @liked[:available] &&
      @liked[:logs_count].to_i >= MIN_LOGS
  end

  def build_axes
    AXES.map do |key, conf|
      diagnosed = @taste_profile.public_send(conf[:score]).to_f
      actual    = @liked[:taste_bar][conf[:bar]].to_f
      diff      = (actual - diagnosed).round(1)

      {
        key: key,
        diagnosed: diagnosed,
        actual: actual,
        diff: diff.abs,
        direction: diff.positive? ? :higher : :lower,
        large: diff.abs >= LARGE_GAP
      }
    end
  end

  # 実際の好みは、おすすめが示すものと同じ値を使う。
  # ここで別の選び方をすると、同じ画面内で違う焙煎度を提示することになる。
  def build_roast
    return nil unless @liked[:roast_available]

    diagnosed_key = @taste_profile.preferred_roast.to_s
    actual_key    = @liked[:top_rated_roast_key].to_s

    {
      diagnosed_key: diagnosed_key,
      diagnosed_label: PreferenceSummary::ROAST_LABELS.fetch(diagnosed_key, diagnosed_key),
      actual_key: actual_key,
      actual_label: @liked[:top_rated_roast],
      match: diagnosed_key == actual_key
    }
  end

  def verdict(roast, axes)
    return :diverged if roast && !roast[:match]
    return :diverged if axes.any? { |a| a[:large] }

    :aligned
  end
end
