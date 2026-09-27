# Comments that signed-in users leave on a book.
# Routes: POST /books/:book_id/comments, DELETE /books/:book_id/comments/:id
class CommentsController < ApplicationController
  before_action :set_book

  def create
    @comment = @book.comments.build(comment_params.merge(user: Current.user))

    respond_to do |format|
      if @comment.save
        format.turbo_stream # renders create.turbo_stream.erb
        format.html { redirect_to book_path(@book, anchor: "comments"), notice: "Comment posted." }
      else
        format.turbo_stream { render :form_with_errors, status: :unprocessable_content }
        format.html { redirect_to book_path(@book, anchor: "comments"), alert: @comment.errors.full_messages.to_sentence }
      end
    end
  end

  def destroy
    @comment = @book.comments.find(params.expect(:id))

    unless @comment.deletable_by?(Current.user)
      return redirect_to book_path(@book), alert: "You can only delete your own comments."
    end

    @comment.destroy!

    respond_to do |format|
      format.turbo_stream # renders destroy.turbo_stream.erb
      format.html { redirect_to book_path(@book, anchor: "comments"), notice: "Comment deleted.", status: :see_other }
    end
  end

  private
    def set_book
      @book = Book.find(params.expect(:book_id))
    end

    def comment_params
      params.expect(comment: [ :body, :parent_id ])
    end
end
