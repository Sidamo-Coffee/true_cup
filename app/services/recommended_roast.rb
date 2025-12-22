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
        roast_key: @liked[:summary_roast_key],
        label: @liked[:summary_roast],
        reason: "★4以上が最も多い",
        n: @liked[:logs_count],
        message: "最近の「好き」から見ると、この焙煎度が合いやすいです。"
      )
    end

    # 2) 全記録が十分あるなら次点
    if @all[:available] && @all[:logs_count].to_i >= MIN_ALL
      return build(
        roast_key: @all[:summary_roast_key],
        label: @all[:summary_roast],
        reason: "全記録ベース",
        n: @all[:logs_count],
        message: "記録全体の傾向から見ると、この焙煎度が選びやすいです。"
      )
    end

    # 3) 記録が少ないなら診断（仮説）に戻す
    if @taste_profile.present?
      key = @taste_profile.preferred_roast.to_s
      label = PreferenceSummary::ROAST_LABELS.fetch(@taste_profile.preferred_roast.to_s, "不明")
      return build(
        roast_key: key,
        label: label,
        reason: "味覚診断ベース",
        n: 0,
        message: "まずは診断結果の焙煎度を軸に選んで、記録を増やしてみましょう。"
      )
    end

    { available: false }
  end

  private

  def build(roast_key:, label:, reason:, n:, message:)
    {
      available: true,
      roast_key: roast_key,
      label: label,
      reason: reason,
      n: n,
      message: message
    }
  end
end
