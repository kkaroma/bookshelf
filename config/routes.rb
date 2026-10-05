Rails.application.routes.draw do
  resource :session
  resource :registration, only: %i[ new create ]
  resources :passwords, param: :token
  resources :books do
    # The owner's review of a book: /books/:book_id/review/edit
    resource :review, only: %i[ edit update ], module: :books
    resource :rating, only: %i[ update destroy ], module: :books
    # POST lists the book for exchange, DELETE takes it off the list.
    resource :exchange_listing, only: %i[ create destroy ], module: :books
    resources :comments, only: %i[ create destroy ]
    # Ask to swap for this book: /books/:book_id/exchange_requests/new
    resources :exchange_requests, only: %i[ new create ]
  end

  # My exchange requests (received and sent), and answering them.
  resources :exchange_requests, only: :index do
    member do
      patch :accept   # owner says yes
      patch :decline  # owner says no
      patch :cancel   # requester withdraws
    end
  end

  # "Find cover online" in the book form: /cover_search?title=...&author=...&isbn=...
  resource :cover_search, only: :show

  # Admin-only pages live under /admin (controllers in app/controllers/admin/).
  namespace :admin do
    resource :reports, only: :show # /admin/reports
  end

  # The exchange shelf: every book available for exchange.
  resources :exchanges, only: :index

  # Account settings: /settings/profile/edit, /settings/password/edit,
  # /settings/notifications/edit and /settings/account (delete account).
  namespace :settings do
    resource :profile, only: %i[ edit update ]
    resource :password, only: %i[ edit update ]
    resource :notifications, only: %i[ edit update ]
    resource :account, only: %i[ show destroy ]
  end
  get "settings", to: redirect("/settings/profile/edit"), as: :settings

  # Members and their profiles: /users, /users/:id, /users/:id/followers, /users/:id/following
  resources :users, only: %i[ index show ] do
    member do
      get :followers
      get :following
    end
    # POST follows this user, DELETE unfollows them.
    resource :follow, only: %i[ create destroy ], module: :users
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#show"
end
