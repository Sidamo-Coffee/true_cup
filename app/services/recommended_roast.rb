class RecommendedRoast
  MIN_LIKED = 3 # ★4以上がこれ以上あれば「好き」を優先
  MIN_ALL   = 5 # 全記録がこれ以上あれば「よく飲む」を採用

  # 実データを根拠にしていて、裏付けがこれ以上あれば「安定」とみなす。
  # 旧・信頼度が low を抜ける境界（全記録10件）を引き継いでいる。
  STABLE_MIN = 10

  # おすすめとして提示するのに必要な平均評価。★3（普通）を下回るものは推薦しない。
  # 低評価しかつけていない焙煎度を「おすすめ」として出さないため（#117）。
  MIN_AVERAGE_RATING = 3.0

  def initialize(preference_liked:, preference_all:, taste_profile:)
    @liked = preference_liked
    @all   = preference_all
    @taste_profile = taste_profile
  end

  def call
    # 焙煎度が不明な記録は根拠にできないため、閾値の判定には roast_logs_count を使う。
    # logs_count（不明を含む全件）で判定すると、不明な記録だけで閾値を満たしてしまう。

    # 選ぶのは「件数が最も多い焙煎度」ではなく「評価が最も高い焙煎度」。
    # よく飲んでいることと好きであることは別で、惰性で頼んでいる一杯が
    # 最頻値になると好みと逆の推薦になるため（#117）。

    # 1) ★4以上が十分あるなら最優先
    if @liked[:roast_available] && @liked[:roast_logs_count].to_i >= MIN_LIKED
      return build(
        roast_key: @liked[:top_rated_roast_key],
        label: @liked[:top_rated_roast],
        reason: I18n.t("services.recommended_roast.reason.liked"),
        n: @liked[:roast_logs_count],
        message: I18n.t("services.recommended_roast.message.liked"),
        from_logs: true
      )
    end

    # 2) 全記録が十分あり、かつ低評価ばかりでないなら次点。
    #    平均が★3を下回る焙煎度しかない場合は実データを根拠にせず診断へ落とす。
    if @all[:roast_available] && @all[:roast_logs_count].to_i >= MIN_ALL &&
       @all[:top_rated_average].to_f >= MIN_AVERAGE_RATING
      return build(
        roast_key: @all[:top_rated_roast_key],
        label: @all[:top_rated_roast],
        reason: I18n.t("services.recommended_roast.reason.all"),
        n: @all[:roast_logs_count],
        message: I18n.t("services.recommended_roast.message.all"),
        from_logs: true
      )
    end

    # 3) 記録が少ないか、低評価ばかりで根拠にできないなら診断（仮説）に戻す
    if @taste_profile.present?
      # 記録は十分あるのに低評価で弾かれた場合、「記録するほど近づきます」では
      # なぜ実データが使われないのか伝わらないため文言を分ける
      rejected_for_low_rating =
        @all[:roast_available] && @all[:roast_logs_count].to_i >= MIN_ALL
      key = @taste_profile.preferred_roast.to_s
      label = PreferenceSummary::ROAST_LABELS.fetch(@taste_profile.preferred_roast.to_s, "不明")
      return build(
        roast_key: key,
        label: label,
        reason: I18n.t("services.recommended_roast.reason.diagnosis"),
        n: 0,
        message: I18n.t("services.recommended_roast.message.diagnosis"),
        from_logs: false,
        low_rated: rejected_for_low_rating
      )
    end

    { available: false, confidence: nil, notice: nil, progress: nil }
  end

  private

  def build(roast_key:, label:, reason:, n:, message:, from_logs:, low_rated: false)
    level = confidence_level(from_logs, n.to_i)
    notice_key = (level == :hypothesis && low_rated) ? :low_rated : level

    {
      available: true,
      roast_key: roast_key,
      label: label,
      reason: reason,
      n: n,
      message: message,
      confidence: level,
      notice: I18n.t("services.recommended_roast.notice.#{notice_key}", count: n.to_i),
      progress: progress_for(level, low_rated)
    }
  end

  # 次の段階までの進み具合。
  #
  # 分子には「焙煎度を記録した全記録数」を使う。おすすめの根拠は★4以上と全記録で
  # 切り替わるため、根拠になった件数を分子にすると意味が変わって値が後退する。
  # 「記録するほど進む」を見せる機能なので、単調に増える量でなければならない。
  #
  # 記録を増やせば段階が進む状況でのみ返す。件数以外が理由で止まっている場合に
  # 「あとN件」と言うと、記録しても進まないという誤った期待を持たせるため。
  def progress_for(level, low_rated)
    return nil if low_rated                # 低評価が理由。件数では進まない
    return nil unless roast_recorded?      # 焙煎度が未記録。件数では進まない

    recorded = @all[:roast_logs_count].to_i
    target   = (level == :hypothesis) ? MIN_ALL : STABLE_MIN

    build_progress(stage: level, current: recorded, target: target)
  end

  # 焙煎度を記録した分が積み上がっているか。
  # 記録はあるのに焙煎度が全て不明なら、件数を増やしても実データには切り替わらない。
  # 記録が1件も無い場合は、これから積み上がるため進捗を出してよい。
  def roast_recorded?
    @all[:logs_count].to_i.zero? || @all[:roast_logs_count].to_i.positive?
  end

  def build_progress(stage:, current:, target:)
    capped = current.clamp(0, target)

    {
      stage: stage,
      current: capped,
      target: target,
      remaining: target - capped,
      percent: (capped.to_f / target * 100).round
    }
  end

  def confidence_level(from_logs, n)
    return :hypothesis unless from_logs

    n >= STABLE_MIN ? :stable : :likely
  end
end
