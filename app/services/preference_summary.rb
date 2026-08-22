class PreferenceSummary
  ROAST_LABELS = {
    "unknown" => "不明",
    "light" => "浅煎り",
    "medium" => "中煎り",
    "medium_dark" => "中深煎り",
    "dark" => "深煎り"
  }.freeze

  # 平均評価で焙煎度を比べる際に必要な最低件数。
  # 1件だけの焙煎度が偶然の高評価で居座るのを防ぐ（#117）。
  MIN_LOGS_PER_ROAST = 2

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

    # 同数の焙煎度に別々の順位を振ると、並び順だけで優劣がついたように見える。
    # 件数が同じなら同順位にする（#144）。
    sorted_roasts = sorted_roast_counts(roast_counts)

    ranking = build_ranking(sorted_roasts, total)

    summary_keys   = []
    summary_labels = []
    rated_keys     = []
    rated_labels   = []
    rated_avg      = 0.0

    if roast_logs_count.positive?
      # 件数が最多の焙煎度。同数のときは一つに絞らず全て返す。
      # 2件と2件なのに片方を「最も」と呼ぶのは事実と違うため（#144）。
      top_keys       = top_roast_keys(sorted_roasts)
      summary_keys   = top_keys.map { |k| CoffeeLog.roast_levels.key(k) || k.to_s }
      summary_labels = top_keys.map { |k| roast_label(k) }

      # 「よく飲んでいる」焙煎度（上の summary_*）とは別に、
      # 「評価が高い」焙煎度を出す。おすすめはこちらを根拠にする（#117）。
      #
      # 平均が同点のときも一つに絞らない。件数→最終記録日で崩そうとしても、
      # 同じ日に記録すれば決着せず、実質 enum の定義順で決まっていた（#146）。
      rating_avgs = logs_with_roast.group(:roast_level).average(:overall_rating)
      rated_top   = top_rated_roast_keys(rating_avgs, roast_counts)
      rated_keys   = rated_top.map { |k| CoffeeLog.roast_levels.key(k) || k.to_s }
      rated_labels = rated_top.map { |k| roast_label(k) }
      # 閾値判定に使うため丸めない。丸めると 2.995 が 3.0 として通ってしまう
      rated_avg    = rating_avgs[rated_top.first].to_f
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

      # 同数でない場合の1件。同数のときは見出しが summary_roast_labels を使う
      summary_roast: summary_labels.first,

      # 同数の焙煎度。tied が true のとき、見出しは「同じくらい」と表現する
      summary_roast_labels: summary_labels,
      summary_roast_keys: summary_keys,
      summary_tied: summary_keys.size > 1,

      # 評価が最も高い焙煎度。件数最多の summary_* とは異なりうる。
      # 同点ならすべて返し、おすすめ側が併記するか判断する（#146）
      top_rated_roast_keys: rated_keys,
      top_rated_roast_labels: rated_labels,
      top_rated_tied: rated_keys.size > 1,
      top_rated_average: rated_avg,
      reason: summary_reason(roast_logs_count, summary_keys.size > 1),
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
      summary_roast: nil,
      summary_roast_keys: [],
      summary_roast_labels: [],
      top_rated_roast_keys: [],
      top_rated_roast_labels: [],
      top_rated_tied: false,
      summary_tied: false,
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

  # 見出しの根拠。同数のときは「最も飲まれている焙煎度です」と言わない。
  # 見出しが一つに絞らなかったのに、直下で絞ったことにすると矛盾して読めるため（#144）。
  def summary_reason(roast_logs_count, tied)
    return tied_reason(roast_logs_count) if tied

    case @scope
    when :liked
      "★4以上の評価をした記録のうち、焙煎度を記録した#{roast_logs_count}件の中で最も飲まれている焙煎度です。"
    else
      "焙煎度を記録した#{roast_logs_count}件の中で、最も飲まれている焙煎度です。"
    end
  end

  def tied_reason(roast_logs_count)
    case @scope
    when :liked
      "★4以上の評価をした記録のうち、焙煎度を記録した#{roast_logs_count}件をもとにした集計です。"
    else
      "焙煎度を記録した#{roast_logs_count}件をもとにした集計です。"
    end
  end

  def roast_label(key)
    enum_key = key.is_a?(Integer) ? CoffeeLog.roast_levels.key(key) : key.to_s
    ROAST_LABELS.fetch(enum_key, enum_key)
  end

  # 件数が最多の焙煎度。同数ならすべて返す（並び順は sorted_roasts に従う）。
  def top_roast_keys(sorted_roasts)
    max = sorted_roasts.first.last
    sorted_roasts.take_while { |_, c| c == max }.map(&:first)
  end

  # Top3。ただし3位と同数のものは切り落とさない。
  # 同順位にした以上、「同じ #1 なのに1つだけ載らない」のは説明がつかないため（#144）。
  def build_ranking(sorted_roasts, total)
    counts = sorted_roasts.map(&:last)

    sorted_roasts.filter_map do |k, c|
      rank = counts.index(c) + 1
      next if rank > 3

      {
        rank: rank,
        label: roast_label(k),
        percent: total.zero? ? 0 : (c / total * 100).round,
        count: c
      }
    end
  end

  # 件数の多い順。同数なら焙煎度の定義順。
  #
  # 第2キーが無いと、同数のときの表示順（見出しの左右・Top3 の切り出し）が
  # 実行のたびに変わりうる。GROUP BY は順序を保証せず、Ruby の sort_by も
  # 同値では入力順のままのため。
  def sorted_roast_counts(roast_counts)
    roast_counts.sort_by { |k, c| [ -c, roast_order(k) ] }
  end

  def roast_order(key)
    key.is_a?(Integer) ? key : CoffeeLog.roast_levels.fetch(key.to_s, 99)
  end

  # 平均評価が最も高い焙煎度。同点ならすべて返す。
  # 記録が1件だけの焙煎度は、2件以上ある焙煎度があるうちは比較対象にしない。
  #
  # 同点は件数で崩す。件数まで並んだら、そこで打ち切って両方返す。
  # 以前は最終記録日で崩していたが、同じ日に記録すると決着せず、
  # 最後は enum の定義順という説明できない基準になっていた（#146）。
  def top_rated_roast_keys(rating_avgs, roast_counts)
    return [] if rating_avgs.blank?

    keys = rating_avgs.keys.select { |k| roast_counts[k].to_i >= MIN_LOGS_PER_ROAST }
    keys = rating_avgs.keys if keys.empty?

    best = keys.map { |k| rating_avgs[k].to_f }.max
    candidates = keys.select { |k| rating_avgs[k].to_f == best }
    return candidates if candidates.size == 1

    max_count = candidates.map { |k| roast_counts[k].to_i }.max
    candidates.select { |k| roast_counts[k].to_i == max_count }
              .sort_by { |k| roast_order(k) }
  end
end
