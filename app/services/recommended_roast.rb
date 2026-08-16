class RecommendedRoast
  MIN_LIKED = 3 # ★4以上がこれ以上あれば「好き」を優先
  MIN_ALL   = 5 # 全記録がこれ以上あれば「よく飲む」を採用

  # 実データを根拠にしていて、裏付けがこれ以上あれば「安定」とみなす。
  # 旧・信頼度が low を抜ける境界（全記録10件）を引き継いでいる。
  STABLE_MIN = 10

  def initialize(preference_liked:, preference_all:, taste_profile:)
    @liked = preference_liked
    @all   = preference_all
    @taste_profile = taste_profile
  end

  def call
    # 焙煎度が不明な記録は根拠にできないため、閾値の判定には roast_logs_count を使う。
    # logs_count（不明を含む全件）で判定すると、不明な記録だけで閾値を満たしてしまう。

    # 1) ★4以上が十分あるなら最優先
    if @liked[:roast_available] && @liked[:roast_logs_count].to_i >= MIN_LIKED
      return build(
        roast_key: @liked[:summary_roast_key],
        label: @liked[:summary_roast],
        reason: "★4以上が最も多い",
        n: @liked[:roast_logs_count],
        message: "最近の「好き」から見ると、この焙煎度が合いやすいです。",
        from_logs: true
      )
    end

    # 2) 全記録が十分あるなら次点
    if @all[:roast_available] && @all[:roast_logs_count].to_i >= MIN_ALL
      return build(
        roast_key: @all[:summary_roast_key],
        label: @all[:summary_roast],
        reason: "全記録ベース",
        n: @all[:roast_logs_count],
        message: "記録全体の傾向から見ると、この焙煎度が選びやすいです。",
        from_logs: true
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
        message: "まずは診断結果の焙煎度を軸に選んで、記録を増やしてみましょう。",
        from_logs: false
      )
    end

    { available: false, confidence: nil, notice: nil }
  end

  private

  def build(roast_key:, label:, reason:, n:, message:, from_logs:)
    level = confidence_level(from_logs, n.to_i)

    {
      available: true,
      roast_key: roast_key,
      label: label,
      reason: reason,
      n: n,
      message: message,
      confidence: level,
      notice: I18n.t("services.recommended_roast.notice.#{level}", count: n.to_i)
    }
  end

  # 確からしさは「何を根拠にしたか」と「その裏付け件数」だけで決まる。
  # おすすめと同じ数字を見て決めるため、両者が食い違うことがない（#118）。
  def confidence_level(from_logs, n)
    return :hypothesis unless from_logs

    n >= STABLE_MIN ? :stable : :likely
  end
end
