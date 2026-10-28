# Admin → Member journey: of the people who joined in a period, how many went
# on to do each of the main things on Bookshelf - showing where newcomers stop.
class MemberJourney
  include ReportCsv

  Step = Data.define(:key, :label, :count)

  attr_reader :period

  def initialize(period: ReportPeriod.new(nil))
    @period = period
  end

  # Everyone who signed up in the period.
  def joined = User.where(created_at: period.range)

  # Each step counts members who have done that thing (whether or not they did
  # the steps before it), so a member can skip the checklist and still swap.
  def steps
    @steps ||= [
      Step.new(:joined,    "Signed up",                 joined.count),
      Step.new(:confirmed, "Confirmed their email",     joined.where.not(email_confirmed_at: nil).count),
      Step.new(:book,      "Added a book",              joined.where(books_count: 1..).count),
      Step.new(:checklist, "Finished “Getting started”", finished_checklist.count),
      Step.new(:swap,      "Completed a swap",          swapped.count)
    ]
  end

  def joined_count = steps.first.count

  def percent(step)
    joined_count.zero? ? 0 : (100.0 * step.count / joined_count).round
  end

  # Confirmed members who haven't added a book yet, newest first - the people
  # a friendly nudge might help.
  def no_books_yet(limit: 10)
    joined.where.not(email_confirmed_at: nil).where(books_count: 0).order(created_at: :desc).limit(limit)
  end

  def no_books_yet_count = joined.where.not(email_confirmed_at: nil).where(books_count: 0).count
  def unconfirmed_count = joined.where(email_confirmed_at: nil).count

  private
    # The same five steps as the Home page's GettingStarted checklist.
    def finished_checklist
      joined.where(books_count: 1..).where(following_count: 1..)
            .where(has_book(<<~SQL.squish))
              EXISTS (SELECT 1 FROM active_storage_attachments a
                      WHERE a.record_type = 'Book' AND a.record_id = books.id AND a.name = 'cover')
            SQL
            .where(has_book("books.review IS NOT NULL"))
            .where(has_book("books.available_for_exchange"))
    end

    def swapped
      joined.where(<<~SQL.squish, completed: ExchangeRequest.statuses[:completed])
        EXISTS (SELECT 1 FROM exchange_requests r WHERE r.status = :completed
                AND (r.requester_id = users.id OR r.owner_id = users.id))
      SQL
    end

    # SQL: "this member has a book that …"
    def has_book(condition)
      "EXISTS (SELECT 1 FROM books WHERE books.user_id = users.id AND books.given_away_at IS NULL AND #{condition})"
    end

    def csv_rows
      rows = [ [ "Report", "Members who joined", period.label ] ]
      steps.each { |step| rows << [ "Journey", step.label, step.count ] }
      steps.each { |step| rows << [ "Journey (% of those who joined)", step.label, percent(step) ] }
      rows << [ "Stuck", "Haven't confirmed their email", unconfirmed_count ]
      rows << [ "Stuck", "Confirmed but no books yet", no_books_yet_count ]
      rows
    end
end
