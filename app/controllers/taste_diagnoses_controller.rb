class TasteDiagnosesController < ApplicationController
  before_action :authenticate_user!

  TASTE_QUESTIONS = [
    {
      key: :chocolate,
      title: "チョコレートを買うとき、どちらを選ぶ事が多いですか？",
      options: [
        { label: "甘めのミルクチョコレート", value: "milk_chocolate" },
        { label: "ビターなダークチョコレート", value: "dark_chocolate"  },
        { label: "チョコはあまり食べない",   value: "not_chocolate" },
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
        { label: "和風しょうゆドレッシング",     value: "japanse_dressing"      },
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

  # この段階ではロジックは未実装でOK
  def create
    # TODO: 診断ロジック・TasteProfile保存は次のIssueで実装
    redirect_to new_taste_diagnosis_path, notice: "診断ロジックは現在準備中です。"
  end
end
