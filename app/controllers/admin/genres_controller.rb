# /admin/genres - the list of genres members choose from: add, rename,
# reorder, retire (hide from new choices) and delete unused ones.
class Admin::GenresController < Admin::BaseController
  before_action :set_genre, except: %i[ index create ]

  def index
    @genres = Genre.ordered
    @book_counts = Book.where.not(genre: nil).group(:genre).count
    @new_genre = Genre.new
  end

  def create
    @new_genre = Genre.new(genre_params)
    if @new_genre.save
      redirect_to admin_genres_path, notice: "Added “#{@new_genre.name}”."
    else
      redirect_to admin_genres_path, alert: @new_genre.errors.full_messages.to_sentence
    end
  end

  # Renaming also renames it on every book that has it.
  def update
    old_name = @genre.name
    if @genre.update(genre_params)
      count = @genre.books.count
      redirect_to admin_genres_path, notice: "Renamed “#{old_name}” to “#{@genre.name}”#{" on #{view_context.pluralize(count, "book")}" if count.positive?}."
    else
      redirect_to admin_genres_path, alert: @genre.errors.full_messages.to_sentence
    end
  end

  def move
    @genre.move!(params[:direction])
    redirect_to admin_genres_path(anchor: helpers.dom_id(@genre))
  end

  def retire
    @genre.retire!
    redirect_to admin_genres_path, notice: "“#{@genre.name}” is retired: it's no longer offered for books, but books that have it keep it."
  end

  def restore
    @genre.restore!
    redirect_to admin_genres_path, notice: "“#{@genre.name}” can be chosen again."
  end

  def destroy
    if @genre.destroy
      redirect_to admin_genres_path, notice: "Deleted “#{@genre.name}”.", status: :see_other
    else
      redirect_to admin_genres_path, alert: @genre.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private
    def set_genre
      @genre = Genre.find(params.expect(:id))
    end

    def genre_params
      params.expect(genre: [ :name ])
    end
end
