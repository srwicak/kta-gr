# config/routes.rb
Rails.application.routes.draw do
  root "pages#home"

  resources :registrations, only: [:new, :create] do
    member do
      get :success
    end
  end
  resource :session, only: [:new, :create, :destroy]
  resources :members, only: [:show] do
    get :kta, on: :member
<<<<<<< HEAD
    get :letter, on: :member
=======
    get :sk, on: :member
>>>>>>> 57e1852 (Feature: SK)
  end

  namespace :api do
    get :nik_info, to: "nik#show"
    get "wilayah/children", to: "wilayah#children"
  end
end
