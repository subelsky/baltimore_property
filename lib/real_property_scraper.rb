# based on https://scraperwiki.com/scrapers/advanced-scraping-aspx-pages-1/
require "open-uri"
require "mechanize"
require "nokogiri"
require "pp"
require "csv"

# scrapes MD SDAT real property database; use this to get every property in
# Baltimore, vacant or not
class RealPropertyScraper
  BASE_URL = "http://sdatcert3.resiusa.org/rp_rewrite/results.aspx?County=03&SearchType=STREET&StreetNumber=&StreetName=%s*"

  def initialize(combo)
    @combo = combo
    @browser = Mechanize.new do |br|
      # if the page knows we're Mechanize, it won't return all fields
      br.user_agent_alias = 'Linux Firefox'
    end
    @url = BASE_URL % @combo
  end

  def scrape
    Mechanize.html_parser = Nokogiri::HTML
    properties = []
    page = nil

    options = loop do
      puts "Searching for #{@combo}"

      begin
        page = @browser.get(@url)
      rescue StandardError => e
        pp e
        retry
      end

      case page.body
      when /There are no records that match/
        return []
      when /Page 1 of 1/
        break []
      when /Owner Information/
        yield @url
        return []
      else
        if field = page.form_with(id: "Form1").field_with("SelectedPage")
          break field.options[1..-1]
        else
          # means we got a server error, need to try again
          sleep(5)
          next
        end
      end
    end

    loop do
      rows = page.search("//table[@id='Results']/tr")[1..-1]
      break if rows.nil?

      rows.each do |row|
        values = row.children[0..-2].collect { |c| c.text.strip }
        properties << values
      end

      puts "Now at #{properties.size} properties"

      next_value = options.shift
      break if next_value.nil?

      form = page.form_with(id: "Form1")
      form.field_with("SelectedPage").value = next_value.to_s
      puts "Searching for page #{@combo} - #{next_value}"
      page = form.submit
    end

    properties
  end
end

# columns output are owner name, account num, street address, owner occupied or not, map # and parcel #
# an N in the owner occupied column means it's not occupied

# this is what I ran from irb to collect the files
# SDAT only returns up to 40 pages of 90 records at a time,
# so when scraping letters you need to start at AAA and end at ZZZ or otherwise
# you won't see some records. I also scraped 1* to 9* to get numbered streets

def test_real_prop_scraper(start_combo,end_combo)
  cwd = File.dirname(__FILE__)
  date = Date.today
  tmpdir = "#{cwd}/../tmp"

  single_property_file = File.open("#{tmpdir}/single_properties.txt","a") do |single_props_file|
    (start_combo..end_combo).each do |combo|
      props = RealPropertyScraper.new(combo).scrape { |single_url| single_props_file.puts(single_url) }
      next if props.empty?
      CSV.open("#{tmpdir}/#{combo}_#{date}.csv", "w") do |csv|
        props.each { |p| csv << p }
      end
    end
  end
end
