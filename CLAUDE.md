# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A personal app for managing the owner's own book collection (multiple users). Stack: Ruby 3.4.4, Rails 8.1.4, SQLite, Hotwire.

Built so far: `Book` CRUD (root is `books#index`) and authentication from the Rails 8 generator (`User`, `Session`, `Current`, `concerns/authentication.rb`) plus a custom `RegistrationsController` for sign-up. Books belong to a user (`Book#owned_by?`). Users have a `role` enum (`member`/`admin`); `Book#editable_by?` allows the owner or an admin. `BooksController#require_owner` enforces it for edit/update/destroy and the `can_edit?` helper hides those controls in views. `db/seeds.rb` creates the admin account (`ADMIN_EMAIL`/`ADMIN_PASSWORD`, with development defaults; production requires `ADMIN_PASSWORD`). Every controller requires login unless it calls `allow_unauthenticated_access`. A book's `review` column is the owner's own write-up after reading it. It can be edited in the full book form or inline on the book page via `Books::ReviewsController` (`/books/:book_id/review/edit`, rendered inside a Turbo Frame from `books/_review.html.erb`); other users respond with `Comment`s (nested under books; `CommentsController` answers Turbo Stream requests with `create`/`destroy`/`form_with_errors` `.turbo_stream.erb` templates, with an HTML redirect fallback). Comments can be deleted by their author or an admin (`Comment#deletable_by?`). Replies are comments with a `parent_id`; threads are one level deep (`Comment#join_parent_thread` re-parents a reply-to-a-reply onto the top-level comment), and deleting a comment deletes its replies. The reply form in each thread is shown/hidden by the Stimulus `reply_controller.js`. Remaining planned features, in order: ratings → exchange listing → follows.

Styling is hand-written CSS in `app/assets/stylesheets/application.css` (no Tailwind/build step), with design tokens as CSS variables in `:root` and a dark-mode override. Reuse its classes (`.btn`, `.card`, `.form`/`.field`/`.input`, `.page-header`, `.book-cover`) and the `shared/_form_errors` partial for new pages.

System tests run headless Chrome with the password manager and leak detection disabled (`test/application_system_test_case.rb`); without that, Chrome's hidden breach warning after signing in with a test password swallows later clicks and makes tests flaky. In system tests, `sign_in_as` (in `test/application_system_test_case.rb`) signs in through the real form. The integration-test `sign_in_as` in `test/test_helpers/session_test_helper.rb` sets the session cookie directly.

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
```

`bin/ci` also runs `RAILS_ENV=test bin/rails db:seed:replant`, so `db/seeds.rb` must stay runnable against the test DB, and Brakeman runs with `--exit-on-warn` (any warning fails CI).

## Architecture

- **Stack**: Rails "omakase" defaults — Hotwire (Turbo + Stimulus), importmap for JS (no Node/bundler; pin packages with `bin/importmap pin`), Propshaft for assets, Minitest for tests.
- **Stimulus controllers** in `app/javascript/controllers/` are auto-registered via `index.js` using importmap's `pin_all_from`; naming follows `foo_controller.js` → `data-controller="foo"`.
- **Database**: SQLite everywhere, files under `storage/`. Production uses four separate SQLite databases — `primary`, plus `cache`, `queue`, `cable` for Solid Cache / Solid Queue / Solid Cable. Their schemas live in `db/cache_schema.rb`, `db/queue_schema.rb`, `db/cable_schema.rb` with migrations in `db/{cache,queue,cable}_migrate`. In development/test only the primary DB is configured.
- **Background jobs**: Solid Queue (DB-backed, no Redis). In production it runs inside Puma (`SOLID_QUEUE_IN_PUMA=true`); `bin/jobs` runs it standalone. Recurring jobs go in `config/recurring.yml`.
- **Deployment**: Kamal (`config/deploy.yml`, `.kamal/secrets`) building the root `Dockerfile`, served via Thruster in front of Puma. `storage/` is mounted as a persistent volume (`my_app_storage`), which is where the production SQLite DBs and Active Storage files live. Deploy config still has placeholder server IP/registry. Kamal aliases: `bin/kamal console`, `shell`, `logs`, `dbc`.
- **Secrets**: encrypted credentials in `config/credentials.yml.enc`; `RAILS_MASTER_KEY` is required in production.
- **Health check**: `GET /up` (`rails/health#show`).
