class RecommendedRoast
  MIN_LIKED = 3 # ★4以上がこれ以上あれば「好き」を優先
  MIN_ALL   = 5 # 全記録がこれ以上あれば「よく飲む」を採用

  def initialize(preference_liked:, preference_all:, taste_profile:)
    @liked = preference_liked
    @all   = preference_all
    @taste_profile = taste_profile
  end

  def call
    # 1) ★4以上が十分あるなら最優先
    if @liked[:available] && @liked[:logs_count].to_i >= MIN_LIKED
      return build(
        label: @liked[:summary_roast],
        reason: "★4以上の評価が最も多い",
        n: @liked[:logs_count],
        message: "最近の「好き」から見ると、この焙煎度が合いやすいです。"
      )
    end

    # 2) 全記録が十分あるなら次点
    if @all[:available] && @all[:logs_count].to_i >= MIN_ALL
      return build(
        label: @all[:summary_roast],
        reason: "全記録ベース",
        n: @all[:logs_count],
        message: "記録全体の傾向から見ると、この焙煎度が選びやすいです。"
      )
    end

    # 3) 記録が少ないなら診断（仮説）に戻す
    if @taste_profile.present?
      label = PreferenceSummary::ROAST_LABELS.fetch(@taste_profile.preferred_roast.to_s, "不明")
      return build(
        label: label,
        reason: "味覚診断ベース（記録が少ないため）",
        n: 0,
        message: "まずは診断結果の焙煎度を軸に選んで、記録を増やしてみましょう。"
      )
    end

    { available: false }
  end

  private

  def build(label:, reason:, n:, message:)
    {
      available: true,
      label: label,
      reason: reason,
      n: n,
      message: message
    }
  end
end
