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
    base = @user.coffee_logs.where.not(roast_level: :unknown)
    logs = apply_scope(base)

    logs_count = logs.count
    return { available: false, logs_count: 0, scope: @scope } if logs_count.zero?

    # 焙煎度：好み加重（overall_rating を重み）
    roast_weighted = logs.group(:roast_level).sum(:overall_rating)
    roast_counts   = logs.group(:roast_level).count
    total_weight   = roast_weighted.values.sum.to_f

    roast_pie = roast_weighted.transform_keys { |k| roast_label(k) }

    # 味：酸味・苦味（0..2）を加重平均 → 0..10（×5）
    sum_w = logs.sum(:overall_rating).to_f
    taste_bar = {
      "酸味" => weighted_avg(logs, "acidity", sum_w),
      "苦味" => weighted_avg(logs, "bitterness", sum_w)
    }.transform_values { |v| (v * 5).round(1) }

    # Top3ランキング（%と件数）
    ranking =
      roast_weighted
        .sort_by { |_, w| -w }
        .first(3)
        .map do |k, w|
          {
            label: roast_label(k),
            percent: total_weight.zero? ? 0 : (w / total_weight * 100).round,
            count: roast_counts[k] || 0,
            weight: w
          }
        end

    top_label = ranking.first&.dig(:label)

    {
      available: true,
      scope: @scope,
      logs_count: logs_count,
      roast_pie: roast_pie,
      taste_bar: taste_bar,
      ranking: ranking,
      summary_roast: top_label,
      reason: scope_reason
    }
  end

  private

  def apply_scope(base)
    case @scope
    when :liked
      base.where("overall_rating >= ?", 4)
    else
      base
    end
  end

  def scope_reason
    case @scope
    when :liked
      "★4以上の記録だけで集計しています。"
    else
      "全記録を、好み度（★）で重み付けして集計しています。"
    end
  end

  def roast_label(key)
    enum_key = key.is_a?(Integer) ? CoffeeLog.roast_levels.key(key) : key.to_s
    ROAST_LABELS.fetch(enum_key, enum_key)
  end

  def weighted_avg(logs, column_sql, sum_w)
    return 0 if sum_w.zero?
    logs.sum("#{column_sql} * overall_rating").to_f / sum_w
  end
end