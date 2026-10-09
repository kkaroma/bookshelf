# Preview at http://localhost:3000/rails/mailers/error_mailer
class ErrorMailerPreview < ActionMailer::Preview
  def alert
    ErrorMailer.alert(
      to: [ "admin@example.com" ], error_class: "NoMethodError",
      message: "undefined method 'title' for nil", source: "application.action_dispatch",
      backtrace: [ "app/views/books/show.html.erb:3", "app/controllers/books_controller.rb:12:in 'show'" ],
      url: "https://bookshelf.co.tz/books/42", user_id: User.first&.id
    )
  end
end
