xml.instruct!
xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
  xml.url { xml.loc root_url }

  @members.each do |member|
    xml.url do
      xml.loc user_url(member)
      xml.lastmod member.updated_at.to_date.iso8601
    end
  end

  @books.each do |book|
    xml.url do
      xml.loc book_url(book)
      xml.lastmod book.updated_at.to_date.iso8601
    end
  end
end
