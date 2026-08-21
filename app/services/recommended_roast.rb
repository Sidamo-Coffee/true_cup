class RecommendedRoast
  MIN_LIKED = 3 # ★4以上がこれ以上あれば「好き」を優先
  MIN_ALL   = 5 # 全記録がこれ以上あれば「よく飲む」を採用

  # 実データを根拠にしていて、裏付けがこれ以上あれば「安定」とみなす。
  # 旧・信頼度が low を抜ける境界（全記録10件）を引き継いでいる。
  STABLE_MIN = 10

  # おすすめとして提示するのに必要な平均評価。★3（普通）を下回るものは推薦しない。
  # 低評価しかつけていない焙煎度を「おすすめ」として出さないため（#117）。
  MIN_AVERAGE_RATING = 3.0

  # 同点のまま併記できる上限。4段階しかないため、3つ並んだ時点で
  # 「どれでもよい」と言っているのと変わらず、おすすめとして意味をなさない（#146）。
  MAX_TIED = 2

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

    # 平均評価が同点なら焙煎度を絞らない。ただし3つ以上並んだら根拠にしない（#146）。
    liked_keys = decidable_keys(@liked)
    all_keys   = decidable_keys(@all)

    # 1) ★4以上が十分あるなら最優先
    if @liked[:roast_available] && @liked[:roast_logs_count].to_i >= MIN_LIKED && liked_keys.present?
      return build(
        roast_keys: liked_keys,
        labels: @liked[:top_rated_roast_labels],
        scope_key: "liked",
        n: @liked[:roast_logs_count],
        from_logs: true
      )
    end

    # 2) 全記録が十分あり、かつ低評価ばかりでないなら次点。
    #    平均が★3を下回る焙煎度しかない場合は実データを根拠にせず診断へ落とす。
    if @all[:roast_available] && @all[:roast_logs_count].to_i >= MIN_ALL &&
       @all[:top_rated_average].to_f >= MIN_AVERAGE_RATING && all_keys.present?
      return build(
        roast_keys: all_keys,
        labels: @all[:top_rated_roast_labels],
        scope_key: "all",
        n: @all[:roast_logs_count],
        from_logs: true
      )
    end

    # 3) 記録が少ないか、根拠にできないなら診断（仮説）に戻す
    if @taste_profile.present?
      key = @taste_profile.preferred_roast.to_s
      label = PreferenceSummary::ROAST_LABELS.fetch(key, "不明")
      return build(
        roast_keys: [ key ],
        labels: [ label ],
        scope_key: "diagnosis",
        n: 0,
        from_logs: false,
        stalled: stalled_reason
      )
    end

    { available: false, confidence: nil, notice: nil, progress: nil }
  end

  private

  # 実データを根拠にできるか。3つ以上が同点なら、どれを勧めても同じで意味がない。
  def decidable_keys(preference)
    keys = preference[:top_rated_roast_keys].to_a
    keys.size <= MAX_TIED ? keys : []
  end

  # 記録は十分あるのに実データを使えなかった理由。
  # 「記録するほど近づきます」では、なぜ使われないのか伝わらないため文言を分ける。
  # 件数を増やしても解消するとは限らないので、進捗も出さない。
  #
  # 低評価を先に見る。全部★2で3つ並んだ状態は「同点で絞れない」より
  # 「まだ好みに合うものが無い」の方が実態に近く、次の一手も変わるため。
  def stalled_reason
    return nil unless @all[:roast_available] && @all[:roast_logs_count].to_i >= MIN_ALL

    return :low_rated if @all[:top_rated_average].to_f < MIN_AVERAGE_RATING

    :undecided if decidable_keys(@all).empty?
  end

  def build(roast_keys:, labels:, scope_key:, n:, from_logs:, stalled: nil)
    level = confidence_level(from_logs, n.to_i)
    tied  = roast_keys.size > 1
    suffix = tied ? "#{scope_key}_tied" : scope_key
    # 同点のまま「安定しています」と言うと、絞り込めたように読める
    notice_key =
      if level == :hypothesis && stalled
        stalled
      else
        tied ? "#{level}_tied" : level
      end

    {
      available: true,
      roast_keys: roast_keys,
      labels: labels,
      tied: tied,
      reason: I18n.t("services.recommended_roast.reason.#{suffix}"),
      n: n,
      message: I18n.t("services.recommended_roast.message.#{suffix}"),
      confidence: level,
      notice: I18n.t("services.recommended_roast.notice.#{notice_key}", count: n.to_i),
      progress: progress_for(level, stalled.present?)
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
  def progress_for(level, stalled)
    return nil if stalled                  # 低評価・同点が理由。件数では進まない
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
