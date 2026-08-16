class PreferenceSummary
  ROAST_LABELS = {
    "unknown" => "不明",
    "light" => "浅煎り",
    "medium" => "中煎り",
    "medium_dark" => "中深煎り",
    "dark" => "深煎り"
  }.freeze

  def initialize(user, scope: :all)
    @user  = user
    @scope = scope.to_sym
  end

  def call
    # 焙煎度が不明な記録も、記録件数・味の傾向・信頼度には算入する。
    # 焙煎度そのものの集計だけは、不明を除いた logs_with_roast から行う。
    logs = apply_scope(@user.coffee_logs)

    logs_count = logs.count
    return unavailable if logs_count.zero?

    logs_with_roast = logs.where.not(roast_level: :unknown)
    roast_logs_count = logs_with_roast.count
    unknown_roast_count = logs_count - roast_logs_count

    # 確からしさは RecommendedRoast が「おすすめの根拠」から導く（#118）。
    # ここで独立に算出すると、おすすめの表示と食い違うため持たせない。

    # 焙煎度：件数ベース（分かりやすさ優先）。不明は「好みの焙煎度」ではないため集計対象外。
    roast_counts = logs_with_roast.group(:roast_level).count
    total = roast_logs_count.to_f

    roast_pie = roast_counts.transform_keys { |k| roast_label(k) }

    ranking =
      roast_counts
        .sort_by { |_, c| -c }
        .first(3)
        .map do |k, c|
          {
            label: roast_label(k),
            percent: total.zero? ? 0 : (c / total * 100).round,
            count: c
          }
        end

    if roast_logs_count.positive?
      top_key = pick_top_roast_key(roast_counts, logs_with_roast)
      summary_label = roast_label(top_key)
      summary_key   = CoffeeLog.roast_levels.key(top_key) || top_key.to_s
    end

    # 味：件数ベースの平均（★で重み付けしない）。焙煎度が不明でも味は記録されている。
    acidity_avg    = logs.average(:acidity).to_f
    bitterness_avg = logs.average(:bitterness).to_f

    taste_bar = {
      "酸味" => (acidity_avg * 5).round(1),
      "苦味" => (bitterness_avg * 5).round(1)
    }

    {
      available: true,
      scope: @scope,
      logs_count: logs_count,

      # 焙煎度の集計は不明を除いた件数ベース。0件なら焙煎度の傾向は出せない。
      roast_available: roast_logs_count.positive?,
      roast_logs_count: roast_logs_count,
      unknown_roast_count: unknown_roast_count,

      roast_pie: roast_pie,
      taste_bar: taste_bar,
      ranking: ranking,

      summary_roast: summary_label,
      summary_roast_key: summary_key,
      reason: summary_reason(roast_logs_count),
      charts_reason: scope_reason
    }
  end

  private

  def unavailable
    {
      available: false,
      logs_count: 0,
      roast_available: false,
      roast_logs_count: 0,
      unknown_roast_count: 0,
      scope: @scope
    }
  end

  def apply_scope(base)
    case @scope
    when :liked
      base.where("overall_rating >= ?", 4)
    else
      base
    end
  end

  # 焙煎度の集計は「不明」を除いた分が対象。全記録と件数が食い違うため、
  # 「全記録」ではなく「焙煎度を記録した分」であることを明示する。
  def scope_reason
    case @scope
    when :liked
      "★4以上の評価をした記録のうち、焙煎度を記録した分を件数で集計しています。"
    else
      "焙煎度を記録した分を、件数で集計しています。"
    end
  end

  def summary_reason(roast_logs_count)
    case @scope
    when :liked
      "★4以上の評価をした記録のうち、焙煎度を記録した#{roast_logs_count}件の中で最も飲まれている焙煎度です。"
    else
      "焙煎度を記録した#{roast_logs_count}件の中で、最も飲まれている焙煎度です。"
    end
  end

  def roast_label(key)
    enum_key = key.is_a?(Integer) ? CoffeeLog.roast_levels.key(key) : key.to_s
    ROAST_LABELS.fetch(enum_key, enum_key)
  end

  # 件数が同数のときは、直近で飲んだ焙煎度を優先（決め打ちでOKなMVP向け）
  def pick_top_roast_key(roast_counts, logs)
    max = roast_counts.values.max
    candidates = roast_counts.select { |_, c| c == max }.keys
    return candidates.first if candidates.size == 1

    candidates.max_by do |k|
      logs.where(roast_level: k).maximum(:drank_on) || Date.new(1970, 1, 1)
    end
  end
end
