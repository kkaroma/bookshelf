class BooksController < ApplicationController
  before_action :set_book, only: %i[ show edit update destroy ]
  before_action :require_owner, only: %i[ edit update destroy ]
  helper_method :can_edit?

  # GET /books or /books.json
  # /books?q=hobbit searches; without q it lists every book.
  def index
    @query = params[:q].to_s.squish
    books = Book.with_attached_cover.includes(:user).order(:title)
    books = books.search(@query) if @query.present?
    @pagination = Pagination.new(books, page: params[:page], per_page: 24)
    @books = @pagination.records
  end

  # GET /books/1 or /books/1.json
  def show
    @my_rating = @book.ratings.find_by(user: Current.user)
    @my_pending_request = @book.exchange_requests.pending.find_by(requester: Current.user)
    @pending_requests_count = @book.exchange_requests.pending.count if @book.owned_by?(Current.user)
    @comments = @book.comments.top_level.includes(:user, replies: :user).order(:created_at)
  end

  # GET /books/new
  def new
    @book = Current.user.books.build
  end

  # GET /books/1/edit
  def edit
  end

  # POST /books or /books.json
  def create
    @book = Current.user.books.build(book_params)

    respond_to do |format|
      if @book.save
        format.html { redirect_to @book, notice: "Book was successfully created." }
        format.json { render :show, status: :created, location: @book }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @book.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /books/1 or /books/1.json
  def update
    respond_to do |format|
      if @book.update(book_params)
        format.html { redirect_to @book, notice: "Book was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @book }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @book.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /books/1 or /books/1.json
  def destroy
    @book.destroy!

    respond_to do |format|
      format.html { redirect_to books_path, notice: "Book was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_book
      @book = Book.find(params.expect(:id))
    end

    # The owner of a book, or an admin, may change it.
    def can_edit?(book)
      book.editable_by?(Current.user)
    end

    def require_owner
      unless can_edit?(@book)
        redirect_to @book, alert: "Only the person who added this book can change it."
      end
    end

    # Only allow a list of trusted parameters through.
    def book_params
      params.expect(book: [ :title, :subtitle, :author, :isbn, :description, :published_year, :review, :available_for_exchange,
                            :cover, :remove_cover, :open_library_cover_id ])
    end
end
