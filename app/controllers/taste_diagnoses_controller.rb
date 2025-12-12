class TasteDiagnosesController < ApplicationController
  before_action :authenticate_user!

  TASTE_QUESTIONS = [
    {
      key: :chocolate,
      title: "チョコレートを買うとき、どちらを選ぶ事が多いですか？",
      options: [
        { label: "甘めのミルクチョコレート", value: "milk_chocolate" },
        { label: "ビターなダークチョコレート", value: "dark_chocolate"  },
        { label: "チョコはあまり食べない",   value: "not_chocolate" }
      ]
    },
    {
      key: :cake,
      title: "次の中で、コーヒーと合わせて食べたいと思うケーキはどれですか？",
      options: [
        { label: "フルーツタルト", value: "fruit_tart" },
        { label: "モンブラン", value: "mont_blanc"  },
        { label: "ガトーショコラ", value: "gateau_chocolat"  }
      ]
    },
    {
      key: :dressing,
      title: "サラダにドレッシングをかけるなら、次のうちどれが最も多いですか？",
      options: [
        { label: "フレンチドレッシング", value: "french_dressing" },
        { label: "和風しょうゆドレッシング",     value: "japanese_dressing"      },
        { label: "ごまドレッシング", value: "sesame_dressing"          }
      ]
    },
    {
      key: :amount,
      title: "コーヒーを飲むとき、以下のどちらの飲み方の方が好みですか？",
      options: [
        { label: "あっさりめの濃さ を たっぷりめの量 で飲みたい", value: "much" },
        { label: "どっしりめの濃さ を 控えめの量 で飲みたい",     value: "little"      },
        { label: "わからない", value: "amount_neither"          }
      ]
    },
    {
      key: :dislike,
      title: "以下のうち、食べるのをイメージしてより「苦手だ」と感じるのはどちらですか？",
      options: [
        { label: "酸っぱいレモン", value: "too_sour" },
        { label: "カカオ95%以上のとても苦いチョコレート",     value: "too_bitter"      },
        { label: "わからない、もしくは どちらも苦手ではない", value: "both_like"          }
      ]
    }
  ].freeze

  def new
    @questions = TASTE_QUESTIONS
  end

  def create
    @questions = TASTE_QUESTIONS

    # 回答の取得＋未回答チェックをまとめたメソッド
    answers = build_answers_from_params
    if answers.nil?
      flash.now[:alert] = "全ての質問に回答してください。"
      return render :new, status: :unprocessable_entity
    end
    # ---- スコア計算 ----
    scores = calculate_scores(answers)

    bitterness_score = scores[:bitterness]
    acidity_score    = scores[:acidity]
    sweetness_score  = scores[:sweetness]
    body_score       = scores[:body]

    # ---- 焙煎度・タイプの判定 ----
    preferred_roast, taste_type, description =
      judge_roast_and_description(bitterness_score, acidity_score, body_score)

    # ---- TasteProfile 保存 ----
    taste_profile = current_user.taste_profile || current_user.build_taste_profile

    taste_profile.assign_attributes(
      taste_type:        taste_type,
      description:       description,
      bitterness_score:  bitterness_score,
      acidity_score:     acidity_score,
      sweetness_score:   sweetness_score,
      body_score:        body_score,
      preferred_roast:   preferred_roast,
      diagnosed_at:      Time.current
    )

    if taste_profile.save
      redirect_to taste_profile_path, notice: "味覚診断が完了しました。"
    else
      flash.now[:alert] = "診断の保存に失敗しました。もう一度お試しください。"
      render :new, status: :unprocessable_entity
    end
  end

  private

  # ==========================
  # 回答取得＋未回答チェック
  # ==========================
  def build_answers_from_params
    raw_answers = params[:answers]

    # 1問も選ばれていない場合
    return nil if raw_answers.blank?

    # strong parameters で許可するキーを限定
    permitted = raw_answers.permit(
      :chocolate,
      :cake,
      :dressing,
      :amount,
      :dislike
    )

    # Hash にしてキーをシンボル化
    answers = permitted.to_h.symbolize_keys

    # 必須キー（質問側の key）と比較して、足りているかチェック
    required_keys = TASTE_QUESTIONS.map { |q| q[:key] }
    missing_keys  = required_keys - answers.keys

    return nil if missing_keys.any?

    answers
  end

  # ============
  # スコア計算
  # ============
  def calculate_scores(answers)
    # 0〜10 の中央値スタート
    scores = {
      bitterness: 5,
      acidity:    5,
      sweetness:  5, # MVP未使用だが保存はOK
      body:       5
    }

    # チョコ（小〜中幅）
    case answers[:chocolate]
    when "milk_chocolate"
      scores[:bitterness] -= 2  # 苦味を下げる（浅〜中煎り寄り）
    when "dark_chocolate"
      scores[:bitterness] += 2  # 苦味↑（中深〜深寄り）
      scores[:body]       += 2  # コク↑
    end

    # ケーキ（fruit_tart / gateau は“大幅”）
    case answers[:cake]
    when "fruit_tart"
      scores[:acidity] += 4     # 酸味を大幅加点（浅煎り寄り）
    when "mont_blanc"
      scores[:bitterness] += 2  # 苦味↑（中〜中深寄り）
      scores[:body]       += 2  # コク↑
    when "gateau_chocolat"
      scores[:bitterness] += 4  # 苦味を大幅加点（深煎り寄り）
      scores[:body]       += 2  # コク↑
    end

    # ドレッシング（french は“大幅”＋コク減点）
    case answers[:dressing]
    when "french_dressing"
      scores[:acidity] += 4     # 酸味を大幅加点（浅煎り寄り）
      scores[:body]    -= 2     # コク↓
    when "japanese_dressing"
      scores[:acidity] += 2     # 酸味↑（中煎り寄り）
      scores[:body]    += 2     # コク↑
    when "sesame_dressing"
      scores[:bitterness] += 2  # 苦味↑（中深〜深寄り）
      scores[:body]       += 2  # コク↑
    end

    # 量・濃さ（little はコク“大幅”）
    case answers[:amount]
    when "much"
      scores[:acidity] += 2     # 酸味↑（浅〜中寄り）
      scores[:body]    -= 2     # コク↓
    when "little"
      scores[:bitterness] += 2  # 苦味↑
      scores[:body]       += 4  # コクを大幅加点（中深〜深寄り）
    end

    # 苦手（中幅の相互トレード）
    case answers[:dislike]
    when "too_sour"
      scores[:bitterness] += 2  # 苦味↑（中深〜深寄り）
      scores[:acidity]    -= 2  # 酸味↓
    when "too_bitter"
      scores[:acidity]    += 2  # 酸味↑（浅〜中寄り）
      scores[:bitterness] -= 2  # 苦味↓
    end

    scores.transform_values! { |v| v.clamp(0, 10) }
    scores
  end

  # ==========================
  # 焙煎度・タイプ判定ロジック
  # ==========================
  def judge_roast_and_description(bitterness, acidity, body)
    preferred_roast = :medium
    taste_type      = :medium_like
    description     = ""

    # 浅煎り：酸味高め＆苦味控えめ
    if acidity >= 8 && bitterness <= 3
      preferred_roast = :light
      taste_type      = :light_like
      description = "フルーツのような酸味や爽やかさを楽しめる、浅煎りタイプです。明るく軽やかな味わいのコーヒーがお好きな傾向があります。"

    # 深煎り：苦味・コクがかなり高く、酸味は低め
    elsif bitterness >= 8 && body >= 8 && acidity <= 3
      preferred_roast = :dark
      taste_type      = :dark_like
      description = "ビターな味わいとどっしりしたコクが際立つ、深煎りタイプです。濃厚で余韻の長いコーヒーを好む傾向があります。"

    # 中深煎り：苦味・コクが高めで酸味は控えめ
    elsif bitterness >= 7 && body >= 6 && acidity <= 4
      preferred_roast = :medium_dark
      taste_type      = :medium_dark_like
      description = "香ばしさとしっかりしたコクを楽しめる、中深煎りタイプです。カフェオレやスイーツと合わせても負けない力強さが特徴です。"

    # 中煎り：全体が中庸〜やや寄り（“バランス”帯）
    elsif acidity >= 7 || bitterness.between?(4, 6) && body.between?(4, 6) && acidity.between?(4, 6)
      preferred_roast = :medium
      taste_type      = :medium_like
      description = "酸味・苦味・コクのバランスが取れた、中煎りタイプです。毎日飲んでも飲み疲れしにくい、ほどよいコーヒーがお好きな傾向があります。"

    # どこにも強く当てはまらない場合：近いものへ寄せる（MVPでは簡略化）
    else
      # 迷ったら、苦味/コクが強い方を優先して中深〜深に寄せる
      if bitterness >= 7 || body >= 7
        preferred_roast = :medium_dark
        taste_type      = :medium_dark_like
        description = "香ばしさとコクを楽しめる、中深煎り寄りのタイプです。好みに合わせて深煎りも相性が良い可能性があります。"
      else
        preferred_roast = :medium
        taste_type      = :medium_like
        description = "全体のバランスが良いタイプです。気分やシーンに合わせて幅広いコーヒーを楽しめます。"
      end
    end

  [ preferred_roast, taste_type, description ]
end
end
