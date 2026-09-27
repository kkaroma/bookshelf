# The "Getting started" checklist on a new member's Home page.
# Each step ticks itself off based on what the member has actually done.
class GettingStarted
  Step = Data.define(:key, :label, :hint, :done)

  def initialize(user)
    @user = user
  end

  def steps
    @steps ||= [
      Step.new(:add_book,  "Add your first book",       "Start your shelf with a book you own.",                   @user.books_count > 0),
      Step.new(:add_cover, "Give a book a cover",       "Upload a photo or find the cover online.",                books.joins(:cover_attachment).exists?),
      Step.new(:review,    "Write a review",            "Finished a book? Say what you thought.",                  books.where.not(review: nil).exists?),
      Step.new(:follow,    "Follow a member",           "Keep up with what other readers add.",                    @user.following_count > 0),
      Step.new(:exchange,  "Offer a book for exchange", "Put a book on the Exchange shelf so others can ask for it.", books.for_exchange.exists?)
    ]
  end

  def done_count
    steps.count(&:done)
  end

  def complete?
    done_count == steps.size
  end

  # Where to go to do a step (e.g. the first book that still has no cover).
  def book_for(key)
    case key
    when :add_cover then books.where.missing(:cover_attachment).order(:created_at).first
    when :review    then books.where(review: nil).order(:created_at).first
    when :exchange  then books.where(available_for_exchange: false).order(:created_at).first
    end
  end

  private
    def books
      @user.books
    end
end
