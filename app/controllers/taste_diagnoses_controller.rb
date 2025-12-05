class TasteDiagnosesController < ApplicationController
  before_action :authenticate_user!

  TASTE_QUESTIONS = [
    {
      key: :cake,
      title: "好きなケーキは？",
      options: [
        { label: "レアチーズケーキ", value: "rare_cheese" },
        { label: "モンブラン",       value: "mont_blanc"  },
        { label: "ガトーショコラ",   value: "gateau_chocolat" }
      ]
    },
    {
      key: :drink,
      title: "普段よく飲む飲み物は？",
      options: [
        { label: "ブラックコーヒー", value: "black_coffee" },
        { label: "カフェラテ",       value: "cafe_latte"    },
        { label: "オレンジジュース", value: "orange_juice"  }
      ]
    },
    {
      key: :snack,
      title: "休憩中に食べたいお菓子は？",
      options: [
        { label: "ビターチョコレート", value: "bitter_chocolate" },
        { label: "レモン系のお菓子",     value: "lemon_snack"      },
        { label: "クッキー・ビスケット", value: "cookie"          }
      ]
    }
  ].freeze

  def new
    @questions = TASTE_QUESTIONS
  end

  # この段階ではロジックは未実装でOK
  def create
    # TODO: 診断ロジック・TasteProfile保存は次のIssueで実装
    redirect_to new_taste_diagnosis_path, notice: "診断ロジックは現在準備中です。"
  end
end
