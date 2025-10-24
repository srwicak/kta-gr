# config/routes.rb
Rails.application.routes.draw do
  root "pages#home"

  resources :registrations, only: [:new, :create]
  resource :session, only: [:new, :create, :destroy]
  resources :members, only: [:show] do
    get :kta, on: :member
    get :letter, on: :member
  end

  namespace :api do
    get :nik_info, to: "nik#show"
    get "wilayah/children", to: "wilayah#children"
  end
end
