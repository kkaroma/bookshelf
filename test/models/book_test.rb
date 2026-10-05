require "test_helper"

class BookTest < ActiveSupport::TestCase
  test "is valid with a title and author" do
    assert books(:hobbit).valid?
  end

  test "requires an owner" do
    book = Book.new(title: "T", author: "A")
    assert_not book.valid?
    assert_includes book.errors[:user], "must exist"
  end

  test "owned_by? is true only for the book's owner" do
    assert books(:hobbit).owned_by?(users(:one))
    assert_not books(:hobbit).owned_by?(users(:two))
    assert_not books(:hobbit).owned_by?(nil)
  end

  test "editable_by? allows the owner and admins only" do
    book = books(:hobbit)
    assert book.editable_by?(users(:one))
    assert book.editable_by?(users(:admin))
    assert_not book.editable_by?(users(:two))
    assert_not book.editable_by?(nil)
  end

  test "rateable_by? allows anyone signed in except the owner" do
    book = books(:hobbit)
    assert book.rateable_by?(users(:two))
    assert book.rateable_by?(users(:admin))
    assert_not book.rateable_by?(users(:one))
    assert_not book.rateable_by?(nil)
  end

  test "new books are not offered for exchange" do
    assert_not Book.new.available_for_exchange?
  end

  test "for_exchange lists only books offered for exchange" do
    assert_includes Book.for_exchange, books(:dune)
    assert_not_includes Book.for_exchange, books(:hobbit)
  end

  # --- ISBN ---

  test "ISBN is optional" do
    assert Book.new(user: users(:one), title: "T", author: "A", isbn: "").valid?
  end

  test "ISBN dashes and spaces are removed" do
    assert_equal "9780547928227", Book.new(isbn: "978-0-547 92822-7").isbn
    assert_equal "080442957X", Book.new(isbn: "0-8044-2957-x").isbn
  end

  test "valid ISBN-10 and ISBN-13 are accepted" do
    assert Book.valid_isbn?("9780547928227")
    assert Book.valid_isbn?("0306406152")
    assert Book.valid_isbn?("080442957X")
  end

  test "ISBNs with a typo are rejected" do
    assert_not Book.valid_isbn?("9780547928228") # last digit wrong
    assert_not Book.valid_isbn?("12345")

    book = Book.new(user: users(:one), title: "T", author: "A", isbn: "978-0-547-92822-8")
    assert_not book.valid?
    assert_includes book.errors[:isbn], "isn't a valid ISBN (check for typos)"
  end

  # --- Cover image ---

  def new_book(**attributes)
    Book.new({ user: users(:one), title: "Piranesi", author: "Susanna Clarke" }.merge(attributes))
  end

  def upload(name, content_type)
    Rack::Test::UploadedFile.new(file_fixture(name), content_type)
  end

  test "a JPEG or PNG cover can be uploaded" do
    book = new_book(cover: upload("cover.jpg", "image/jpeg"))
    book.save!
    assert book.cover_ready?

    assert new_book(cover: upload("cover.png", "image/png")).valid?
  end

  test "books without a cover are fine" do
    book = new_book
    assert book.valid?
    assert_not book.cover_ready?
  end

  test "a cover must be an image" do
    book = new_book(cover: upload("not_an_image.txt", "text/plain"))
    assert_not book.valid?
    assert_includes book.errors[:cover], "must be a JPEG, PNG or WebP image"
  end

  test "a cover must be under 5 MB" do
    book = new_book
    book.cover.attach(io: StringIO.new("x" * (5.megabytes + 1)), filename: "huge.jpg", content_type: "image/jpeg")
    assert_not book.valid?
    assert_includes book.errors[:cover], "must be smaller than 5 MB"
  end

  test "picking a cover online downloads and attaches it" do
    fake_open_library "covers.openlibrary.org/b/id/42-L.jpg" => open_library_image

    book = new_book(open_library_cover_id: 42)
    book.save!

    assert book.cover_ready?
    assert_equal "cover-42.jpg", book.cover.filename.to_s
  end

  test "if the online cover can't be downloaded, the book isn't saved and says why" do
    fake_open_library "covers.openlibrary.org" => ->(_uri) { raise SocketError }

    book = new_book(open_library_cover_id: 42)
    assert_not book.save
    assert_match "couldn't be downloaded", book.errors[:cover].first
  end

  test "an uploaded file wins over an online pick" do
    # BLOCKED fetcher would raise if a download were attempted
    book = new_book(cover: upload("cover.png", "image/png"), open_library_cover_id: 42)
    book.save!
    assert_equal "cover.png", book.cover.filename.to_s
  end

  test "the online cover is only downloaded once, even if validation runs again" do
    downloads = 0
    fake_open_library "covers.openlibrary.org" => ->(_uri) { downloads += 1; open_library_image }

    book = new_book(open_library_cover_id: 42)
    book.valid?
    book.valid?
    book.save!
    assert_equal 1, downloads
  end

  test "remove_cover deletes the current cover" do
    book = new_book(cover: upload("cover.jpg", "image/jpeg"))
    book.save!

    book.update!(remove_cover: true)
    assert_not book.reload.cover.attached?
  end

  # --- Search ---

  test "search finds books by title, ignoring case and partial words" do
    assert_equal [ books(:hobbit) ], Book.search("hobbit").to_a
    assert_equal [ books(:hobbit) ], Book.search("HOBB").to_a
  end

  test "search looks at the subtitle and the author" do
    assert_equal [ books(:hobbit) ], Book.search("there and back").to_a
    assert_equal [ books(:dune) ], Book.search("herbert").to_a
  end

  test "every word must match somewhere in the book" do
    assert_equal [ books(:hobbit) ], Book.search("tolkien hobbit").to_a
    assert_empty Book.search("tolkien dune")
  end

  test "search finds a book by ISBN, with or without dashes" do
    books(:hobbit).update!(isbn: "9780547928227")
    assert_equal [ books(:hobbit) ], Book.search("978-0-547-92822-7").to_a
    assert_equal [ books(:hobbit) ], Book.search("92822").to_a
  end

  test "search treats % and _ as ordinary characters" do
    assert_empty Book.search("%")
    assert_empty Book.search("_")
  end

  test "an empty search returns every book" do
    assert_equal Book.count, Book.search("   ").count
  end

  test "deleting a user deletes their books" do
    assert_difference("Book.count", -1) { users(:one).destroy }
  end

  test "requires a title" do
    book = Book.new(author: "Someone")
    assert_not book.valid?
    assert_includes book.errors[:title], "can't be blank"
  end

  test "requires an author" do
    book = Book.new(title: "Something")
    assert_not book.valid?
    assert_includes book.errors[:author], "can't be blank"
  end

  test "subtitle and review are optional" do
    assert Book.new(user: users(:one), title: "T", author: "A", subtitle: nil, review: nil).valid?
  end

  test "a review of only spaces is saved as no review" do
    book = books(:hobbit)
    book.update!(review: "   ")
    assert_nil book.review
  end

  test "subtitle can be at most 200 characters" do
    assert Book.new(user: users(:one), title: "T", author: "A", subtitle: "x" * 200).valid?
    assert_not Book.new(user: users(:one), title: "T", author: "A", subtitle: "x" * 201).valid?
  end

  test "published year is optional" do
    assert Book.new(user: users(:one), title: "T", author: "A", published_year: nil).valid?
  end

  test "published year cannot be in the future" do
    book = Book.new(user: users(:one), title: "T", author: "A", published_year: Date.current.year + 1)
    assert_not book.valid?
  end

  test "published year must be a whole number" do
    book = Book.new(user: users(:one), title: "T", author: "A", published_year: 1999.5)
    assert_not book.valid?
  end
end
