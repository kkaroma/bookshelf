# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Bookshelf: a multi-user app for cataloguing the books you own, reviewing, rating and discussing them, following other readers, and swapping books. Stack: Ruby 3.4.4, Rails 8.1.4, PostgreSQL, Hotwire (Turbo + Stimulus), importmap (no Node), Propshaft, Minitest. Live at https://bookshelf.co.tz (the Fly app is also reachable at kkaroma-bookshelf.fly.dev, which redirects).

## Working with the owner

- The owner is learning Rails. Explain changes in simple terms: what each new file or change does and why, naming the Rails convention involved (e.g. "generators create a migration, model, and test together").
- Every new feature ships with Minitest tests (model tests for validations/logic, controller or integration tests for requests, system tests for key UI flows). Run them and report the result.

## Commands

```bash
bin/setup                  # install gems, prepare DB, start server (--skip-server to skip)
bin/dev                    # run the dev server (plain `rails server`, no Procfile/foreman)
bin/ci                     # full local CI pipeline defined in config/ci.rb

bin/rails test                                   # all unit/integration tests (excludes system tests)
bin/rails test test/models/user_test.rb          # single file
bin/rails test test/models/user_test.rb:42       # single test by line number
bin/rails test:system                            # Capybara + Selenium system tests
bin/rails db:test:prepare test                   # what GitHub Actions runs

bin/rubocop                # lint (rubocop-rails-omakase style); -a to autocorrect
bin/brakeman --no-pager    # security static analysis
bin/bundler-audit          # gem vulnerability audit
bin/importmap audit        # JS dependency audit

fly deploy --ha=false                                        # deploy (builds remotely; keep a single machine)
fly logs --app kkaroma-bookshelf                             # production logs
fly ssh console --app kkaroma-bookshelf -C "/rails/bin/rails runner '…'"   # run Ruby in production
fly secrets list --app kkaroma-bookshelf                     # secret names (values are never shown)
```

`bin/ci` also runs `RAILS_ENV=test bin/rails db:seed:replant`, so `db/seeds.rb` must stay runnable against the test DB, and Brakeman runs with `--exit-on-warn` (any warning fails CI). Pushing to GitHub runs CI but does not deploy.

## Domain and features

- **Auth & roles**: Rails 8 authentication generator (`User`, `Session`, `Current`, `concerns/authentication.rb`) plus a custom `RegistrationsController` for sign-up. Every controller requires login unless it calls `allow_unauthenticated_access`. `User#role` enum is `member`/`admin`. `db/seeds.rb` creates the admin (`ADMIN_EMAIL`/`ADMIN_PASSWORD`; development defaults, production requires `ADMIN_PASSWORD`).
- **Front page**: `HomeController#show` is root and public. Visitors get `home/landing` (recent covers, titles and authors only — no owners, reviews or links to book pages). Members get `home/dashboard`: the `GettingStarted` checklist (5 self-ticking steps, hidden when complete), a pending-request notice, and rows for followed members' books, the Exchange shelf and their own books.
- **Books & permissions**: `/books` CRUD; books belong to a user. `Book#owned_by?` (owner only — "My review", "Added by you", the review link) vs `Book#editable_by?` (owner or admin — edit/delete/exchange listing). `BooksController#require_owner` enforces it; the `can_edit?` helper hides controls in views. Permission rules live as predicates on models (`editable_by?`, `rateable_by?`, `requestable_by?`, `Comment#deletable_by?`) and are reused by controllers and views.
- **Review vs comments**: a book's `review` column is the owner's own write-up, editable in the book form or inline via `Books::ReviewsController` (`/books/:book_id/review/edit`, rendered into the Turbo Frame in `books/_review.html.erb`). Other users respond with `Comment`s. Replies are comments with `parent_id`, one level deep (`Comment#join_parent_thread` re-parents a reply-to-a-reply); deleting a comment deletes its replies. Author or admin can delete.
- **Ratings**: 1–5 via `Books::RatingsController` (singular `resource :rating`, `find_or_initialize_by`); one per user per book (validation + unique index); owners can't rate their own books; admins have no special rating powers. `books.ratings_count`/`average_rating` are cached columns refreshed by `Rating` callbacks (`Book#refresh_rating_stats!`). Averages display rounded to the nearest half star (`star_rating` helper).
- **Exchange**: `available_for_exchange` flag (`Book.for_exchange`), toggled in the form or via `Books::ExchangeListingsController` (POST/DELETE `/books/:book_id/exchange_listing`); `ExchangesController#index` is the Exchange shelf. `ExchangeRequest` (requester → listed `book`, optional `offered_book`, message) has a `status` enum pending/accepted/declined/cancelled with at most one pending request per requester per book (validation + partial unique index `WHERE status = 0`). `accept!`/`decline!`/`cancel!` raise `ExchangeRequest::AlreadyAnswered` unless pending; accepting unlists both books, and `Book`'s `after_update` callback declines remaining pending requests whenever a book leaves the shelf. Ownership is not transferred — the swap happens offline and both parties see each other's email.
- **Follows & profiles**: `Follow` (`follower_id` → `followed_id`, both users; unique pair, no self-follow). `User` has `active_follows`/`passive_follows` and `following`/`followers` through them, plus `follow`/`unfollow`/`following?` (memoized ID set). `users.books_count`/`followers_count`/`following_count` are counter caches. `UsersController` serves Members, profiles and followers/following; `users/_follow_box` is a Turbo Frame and `Users::FollowsController` redirects back.
- **Covers & ISBN**: optional `isbn` (normalized to digits/X, check-digit validated by `Book.valid_isbn?`). Active Storage `cover` with `:thumb`/`:card`/`:large` variants (libvips), JPEG/PNG/WebP ≤ 5 MB. Covers can be uploaded or picked online: `CoverSearchesController` renders Open Library results into a Turbo Frame, the `cover_picker` Stimulus controller stores the chosen ID in the virtual `open_library_cover_id` attribute, and a `Book` validation downloads it via `OpenLibrary` (`app/models/open_library.rb`: https only, openlibrary.org/archive.org hosts only, JPEG only, ≤ 5 MB, timeouts). Views use `book.cover_ready?` and fall back to the generated coloured cover.
- **Search**: `Book.search(query)` matches every word (max 5) against title, subtitle or author with `ILIKE` (input escaped with `sanitize_sql_like`), or against the ISBN's digits. `/books?q=…` and profiles (`/users/:id?q=…`, that user's books only) use it through the shared layout partial `books/_search.html.erb` (`render layout: "books/search", locals: {…} do` — the block is the page's own "no books yet" message); the form submits into the `books_results` Turbo Frame (`target: "_top"`), and the `search` Stimulus controller auto-submits 300ms after typing stops and updates the address bar with `history.replaceState`. Don't use `data-turbo-action="advance"` there: its promoted visit races with clicks right after results load (a stuck progress bar) and adds a history entry per pause.
- **Settings**: `app/controllers/settings/` (namespace `settings`, all inheriting `Settings::BaseController`, which loads a separate copy of the user as `@user` so failed form changes don't leak into the header): profile (name/email — changing email requires the current password), password (current password required; signs out other sessions), notifications, and delete account (password required; the last admin can't delete themselves, `User#last_admin?`). Pages share `settings/_layout` via `render layout:`.
- **Email**: `NotificationsMailer` sends exchange-request received/answered, new comment/reply, and new follower emails from model `after_*_commit` callbacks (`ExchangeRequest`, `Comment#people_to_notify`, `Follow`) with `deliver_later`, each gated by the recipient's `notify_exchange_requests`/`notify_comments`/`notify_followers` column. HTML emails use inline styles (`layouts/mailer`, `shared/_email_button`); previews live in `test/mailers/previews` (http://localhost:3000/rails/mailers). Production sends over SMTP only when the `SMTP_ADDRESS` secret is set (plus `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `MAIL_FROM`); otherwise deliveries are switched off.
- **Pagination**: the small `Pagination` PORO (`app/models/pagination.rb`; counts with `unscope(:order)` because PostgreSQL won't COUNT an ordered query) plus `shared/_pagination`, whose links keep the other query params (e.g. `q`). Used by Books (24), Exchange shelf (24), profile books (24) and Members (30).
- **Admin**: admin-only pages live in `app/controllers/admin/` and inherit `Admin::BaseController`, which renders `public/404.html` (status 404) for non-admins. `/admin/reports` is read-only and gets every number from the `AdminReport` PORO; its weekly charts are plain HTML/CSS (`admin/reports/_weekly_chart`, `--chart` colour tokens validated for light/dark, value on hover/focus, `<details>` table view).
- **Hotwire patterns**: Turbo Frames for in-place swaps (review, rating box, follow box, cover search results); Turbo Streams for comments (`CommentsController` + `create`/`destroy`/`form_with_errors` `.turbo_stream.erb`, with HTML redirect fallback); Stimulus controllers in `app/javascript/controllers/` (`reply`, `cover_picker`, `search`) auto-register by filename.

## UI

Hand-written CSS in `app/assets/stylesheets/application.css` (no Tailwind/build step): design tokens as CSS variables in `:root` with a dark-mode override. Reuse its classes (`.btn`, `.card`, `.form`/`.field`/`.input`, `.page-header`, `.book-cover`) and the `shared/_form_errors` partial for new pages. The header is tight on width: it shows only the member's name (`.nav-user-name`), hides it below 1000px, and moves page links to their own row below 800px — check an admin header at 1280px when adding nav links.

## Infrastructure

- **Database**: PostgreSQL everywhere (`bookshelf_development` / `bookshelf_test` on the local Homebrew server; production reads `DATABASE_URL`). Production uses ONE database for everything: Solid Cache, Solid Queue and Solid Cable tables come from ordinary migrations (`create_solid_*_tables`) and their config has no `connects_to`/`database:` — don't reintroduce separate cache/queue/cable databases, since a `url:` overrides any `database:` name.
- **Background jobs**: Solid Queue, run inside Puma in production (`SOLID_QUEUE_IN_PUMA=true`); `bin/jobs` runs it standalone; recurring jobs go in `config/recurring.yml`.
- **Domain**: `bookshelf.co.tz` (registrar KiliHost, DNS on `ns1/ns2.mysitehosted.com`): A/AAAA to the app's Fly IPs, `www` CNAME to the apex, and `_acme-challenge` CNAMEs to `*.flydns.net` for Fly's Let's Encrypt certificates (`fly certs list`). `CANONICAL_HOST` (in `fly.toml`) makes `config/routes.rb` 301-redirect every other host to it, except `/up`, which Fly health-checks by internal address; `APP_HOST` sets mailer link hosts.
- **Deployment**: Fly.io app `kkaroma-bookshelf` in `fra`, configured in `fly.toml`: one machine that auto-stops when idle and auto-starts on the next request (cold start ~10s). The database is Neon Postgres (Frankfurt, free tier, direct/non-pooled URL); letting the app sleep is what keeps Neon inside its free compute hours. Covers use the `tigris` Active Storage service (private bucket `kkaroma-bookshelf-covers`). Secrets: `DATABASE_URL`, `RAILS_MASTER_KEY`, `ADMIN_PASSWORD`, and the `AWS_*`/`BUCKET_NAME` set by `fly storage create`. `bin/docker-entrypoint` runs `db:prepare` on every boot (which also seeds an empty database). The generated Kamal files (`config/deploy.yml`, `.kamal/`) are unused. Email sending in production needs the SMTP secrets above.

## Gotchas

- **Fixtures skip callbacks and counter caches**: set `ratings_count`/`average_rating` in `books.yml` and `books_count`/`followers_count`/`following_count` in `users.yml` by hand to match the other fixtures.
- **Tests never hit the network**: `test/test_helpers/open_library_test_helper.rb` blocks `OpenLibrary.fetcher` by default (use `fake_open_library`), and system-test Chrome maps openlibrary.org to localhost.
- **System tests** (`test/application_system_test_case.rb`) run headless Chrome with the password manager and leak detection disabled — without it, Chrome's hidden breach warning after signing in with a test password swallows later clicks. Its `sign_in_as` uses the real form and asserts on `.nav-user-name`; the integration-test `sign_in_as` (`test/test_helpers/session_test_helper.rb`) sets the session cookie directly. `Capybara.enable_aria_label` is on (star buttons are found by aria-label).
- **PostgreSQL**: don't ORDER BY expressions over SELECT aliases (wrap in a subquery via `from(...)`, as in `AdminReport#most_active_members`). `gssencmode: disable` in `database.yml` is required on macOS — libpq's Kerberos negotiation over TCP segfaults forked parallel test workers. CI starts a `postgres` service and sets `DATABASE_URL` for the test jobs.
- **Forms & Turbo cache**: `form_with` silently drops attributes such as `role:` unless they go inside `html: { … }`. The layout sets `turbo-cache-control: no-preview` app-wide: Turbo's cached preview of a previously visited page showed stale values (old search text, old follower counts) and clicks on it were lost when the fresh page arrived — a real source of flaky system tests. Back/Forward restoration still uses the cache.
- **Fly**: Thruster listens on `HTTP_PORT=8080` because the container runs as a non-root user and can't bind port 80; `/up` is excluded from the SSL redirect so Fly's internal health check works. Changing the `ADMIN_PASSWORD` secret does not change an existing admin's password (seeds only create).
