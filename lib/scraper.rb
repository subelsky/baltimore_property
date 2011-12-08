# based on https://scraperwiki.com/scrapers/advanced-scraping-aspx-pages-1/
require "open-uri"
require "mechanize"
require "nokogiri"
require "pp"
require "csv"

class Scraper
  BASE_URL = "http://sdatcert3.resiusa.org/rp_rewrite/results.aspx?County=03&SearchType=STREET&StreetNumber=&StreetName=%s*"

  def initialize(letter)
    @letter = letter
    @browser = Mechanize.new do |br|
      # if the page knows we're Mechanize, it won't return all fields
      br.user_agent_alias = 'Linux Firefox'
    end
    @url = BASE_URL % @letter
  end

  def scrape
    Mechanize.html_parser = Nokogiri::HTML
    properties = []
    options = []

    loop do
      puts "Searching for #{@letter}"
      page = @browser.get(@url)
      field = page.form_with(id: "Form1").field_with("SelectedPage")

      if field
        options = field.options[1..-1]
        break
      else
        next
      end
    end

    loop do
      page.search("//table[@id='Results']/tr")[1..-1].each do |row|
        values = row.children[0..-2].collect { |c| c.text.strip }
        properties << values
      end

      puts "Now at #{properties.size} properties"

      next_value = options.shift
      break if next_value.nil?

      form = page.form_with(id: "Form1")
      form.field_with("SelectedPage").value = next_value.to_s
      puts "Searching for page #{@letter} - #{next_value}"
      page = form.submit
    end

    properties
  end
end

if __FILE__ == $0
  cwd = File.dirname(__FILE__)
  date = Date.today
  tmpdir = "#{cwd}/tmp"

  ("B".."Z").each do |letter|
    props = Scraper.new(letter).scrape
    CSV.open("#{tmpdir}/#{letter}_#{date}.csv", "w") do |csv|
      props.each { |p| csv << p }
    end
  end
end
