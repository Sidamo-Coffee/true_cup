Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: "users/registrations"
  }
  get "static_pages/top"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  root "static_pages#top"
  resource :taste_diagnosis, only: %i[new create]
  resource :taste_profile, only: %i[show]
  get  "trial_diagnosis", to: "trial_diagnoses#new"
  post "trial_diagnosis", to: "trial_diagnoses#create"
  get "trial_results/:type", to: "trial_results#show", as: :trial_result,
       constraints: { type: /light|medium|medium_dark|dark/ }
  resources :coffee_logs
  resource :preferences, only: %i[show]
  get "/terms",   to: "static_pages#terms"
  get "/privacy", to: "static_pages#privacy"
  get "mypage", to: "mypage#show", as: :mypage
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Defines the root path route ("/")
  # root "posts#index"
end
