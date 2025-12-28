require "cgi"

class TasteDiagnosisLogic
  Result = Struct.new(
    :preferred_roast,
    :taste_type,
    :description,
    :scores,
    keyword_init: true
  )

  QUESTIONS = [
    { key: :chocolate, options: %w[milk_chocolate dark_chocolate not_chocolate] },
    { key: :cake,      options: %w[fruit_tart mont_blanc gateau_chocolat] },
    { key: :dressing,  options: %w[french_dressing japanese_dressing sesame_dressing] },
    { key: :amount,    options: %w[much little amount_neither] },
    { key: :dislike,   options: %w[too_sour too_bitter both_like] }
  ].freeze

  ROAST_KEYS = %w[light medium medium_dark dark].freeze

  def self.questions
    QUESTIONS
  end

  # params[:answers] を受け取り、必須未回答なら nil
  def self.extract_answers(raw_answers)
    return nil if raw_answers.blank?

    permitted = raw_answers.permit(*QUESTIONS.map { |q| q[:key] })
    answers = permitted.to_h.symbolize_keys

    required_keys = QUESTIONS.map { |q| q[:key] }
    missing_keys = required_keys - answers.keys
    return nil if missing_keys.any?

    answers
  end

  def self.diagnose(answers)
    scores = calculate_scores(answers)

    bitterness = scores[:bitterness]
    acidity    = scores[:acidity]
    body       = scores[:body]

    preferred_roast, taste_type = judge_roast_and_type(bitterness, acidity, body)
    description = I18n.t("diagnosis_results.description.#{preferred_roast}")

    Result.new(
      preferred_roast: preferred_roast.to_s, # "light" etc
      taste_type: taste_type.to_s,           # "light_like" etc
      description: description,
      scores: scores
    )
  end

  def self.valid_roast_key?(key)
    ROAST_KEYS.include?(key.to_s)
  end

  def self.description_for(roast_key)
    I18n.t("diagnosis_results.description.#{roast_key}")
  end

  def self.build_x_share_url(text:, url:)
    "https://twitter.com/intent/tweet?text=#{CGI.escape(text)}&url=#{CGI.escape(url)}"
  end

  # ============
  # スコア計算
  # ============
  def self.calculate_scores(answers)
    scores = {
      bitterness: 5,
      acidity:    5,
      sweetness:  5, # MVP未使用でも保存OK
      body:       5
    }

    case answers[:chocolate]
    when "milk_chocolate"
      scores[:bitterness] -= 2
    when "dark_chocolate"
      scores[:bitterness] += 2
      scores[:body]       += 2
    end

    case answers[:cake]
    when "fruit_tart"
      scores[:acidity] += 4
    when "mont_blanc"
      scores[:bitterness] += 2
      scores[:body]       += 2
    when "gateau_chocolat"
      scores[:bitterness] += 4
      scores[:body]       += 2
    end

    case answers[:dressing]
    when "french_dressing"
      scores[:acidity] += 4
      scores[:body]    -= 2
    when "japanese_dressing"
      scores[:acidity] += 2
      scores[:body]    += 2
    when "sesame_dressing"
      scores[:bitterness] += 2
      scores[:body]       += 2
    end

    case answers[:amount]
    when "much"
      scores[:acidity] += 2
      scores[:body]    -= 2
    when "little"
      scores[:bitterness] += 2
      scores[:body]       += 4
    end

    case answers[:dislike]
    when "too_sour"
      scores[:bitterness] += 2
      scores[:acidity]    -= 2
    when "too_bitter"
      scores[:acidity]    += 2
      scores[:bitterness] -= 2
    end

    scores.transform_values { |v| v.clamp(0, 10) }
  end

  # ==========================
  # 焙煎度・タイプ判定
  # ==========================
  def self.judge_roast_and_type(bitterness, acidity, body)
    preferred_roast = :medium
    taste_type      = :medium_like

    if acidity >= 7 && bitterness <= 4
      preferred_roast = :light
      taste_type      = :light_like

    elsif bitterness >= 8 && body >= 7 && acidity <= 3
      preferred_roast = :dark
      taste_type      = :dark_like

    elsif bitterness >= 7 && body >= 6 && acidity <= 4
      preferred_roast = :medium_dark
      taste_type      = :medium_dark_like

    elsif bitterness.between?(6, 10) && body.between?(6, 10) && acidity.between?(6, 10)
      preferred_roast = :medium
      taste_type      = :medium_like

    else
      if bitterness >= 7 && body >= 6
        preferred_roast = :medium_dark
        taste_type      = :medium_dark_like
      else
        preferred_roast = :medium
        taste_type      = :medium_like
      end
    end

    [preferred_roast, taste_type]
  end

  private_class_method :calculate_scores, :judge_roast_and_type
end
