Rails.application.routes.draw do
  # One main address: when CANONICAL_HOST is set (e.g. "bookshelf.co.tz"), any
  # other address (www., the old .fly.dev one) redirects there permanently,
  # keeping the page and its query string. /up is left alone because Fly's
  # health check calls it by the machine's internal address.
  constraints ->(request) {
    canonical = ENV["CANONICAL_HOST"].presence
    canonical && request.host != canonical && request.path != "/up"
  } do
    match "(*path)", via: :all, to: redirect(status: 301) { |_params, request|
      "https://#{ENV["CANONICAL_HOST"]}#{request.fullpath}"
    }
  end

  resource :session
  resource :registration, only: %i[ new create ]
  # The link in the confirmation email (GET /email_confirmation?token=...),
  # and "send it again" (POST /email_confirmation).
  resource :email_confirmation, only: %i[ show create ]
  resources :passwords, param: :token
  resources :books do
    # The owner's review of a book: /books/:book_id/review/edit
    resource :review, only: %i[ edit update ], module: :books
    resource :rating, only: %i[ update destroy ], module: :books
    resource :reading_status, only: :update, module: :books
    # Lending: POST /books/:book_id/loans, PATCH /books/:book_id/loans/:id/return
    resources :loans, only: :create, module: :books do
      patch :return, on: :member
    end
    # POST lists the book for exchange, DELETE takes it off the list.
    resource :exchange_listing, only: %i[ create destroy ], module: :books
    resources :comments, only: %i[ create destroy ]
    # Ask to swap for this book: /books/:book_id/exchange_requests/new
    resources :exchange_requests, only: %i[ new create ]
  end

  # My exchange requests (received and sent), and answering them.
  resources :exchange_requests, only: %i[ index show ] do
    member do
      patch :accept   # owner says yes
      patch :decline  # owner says no
      patch :cancel   # requester withdraws
      patch :complete # either person: "we swapped" - the books change owners
    end
    # The conversation about a request: POST /exchange_requests/:id/messages
    resources :messages, only: :create, module: :exchange_requests
  end

  # "Find cover online" in the book form: /cover_search?title=...&author=...&isbn=...
  resource :cover_search, only: :show
  # Book details for an ISBN, as JSON for the book form: /isbn_lookup.json?isbn=...
  resource :isbn_lookup, only: :show
  # Import a Goodreads library export: /goodreads_import/new
  resource :goodreads_import, only: %i[ new create ]

  # Admin-only pages live under /admin (controllers in app/controllers/admin/).
  namespace :admin do
    resource :reports, only: :show # /admin/reports (and /admin/reports.csv)
    # Manage members: /admin/users
    resources :users, only: :index do
      member do
        patch :promote   # make admin
        patch :demote    # back to member
        patch :suspend
        patch :reinstate
        patch :confirm_email
      end
    end
    # Reported books and comments: /admin/flags
    resources :flags, only: :index do
      collection do
        patch :dismiss # PATCH /admin/flags/dismiss?book_id=1 (or comment_id=)
        delete :remove # deletes the reported book or comment
      end
    end
  end

  # Report a book or comment: /flags/new?book_id=1 or /flags/new?comment_id=3
  resources :flags, only: %i[ new create ]

  # The exchange shelf: every book available for exchange.
  resources :exchanges, only: :index

  # My wishlist: /wishlist (books I'd like; I'm told when one is offered for exchange).
  resources :wishlist_items, only: %i[ index create destroy ], path: "wishlist"

  # The notification bell: /notifications, and /notifications/:id opens one.
  resources :notifications, only: %i[ index show ] do
    patch :mark_all_read, on: :collection
  end

  # This year's reading goal (on the Home page): PATCH to set it, DELETE to remove it.
  resource :reading_goal, only: %i[ update destroy ]

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
