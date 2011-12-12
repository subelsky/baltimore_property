# based on https://scraperwiki.com/scrapers/advanced-scraping-aspx-pages-1/
require "open-uri"
require "mechanize"
require "nokogiri"
require "pp"
require "csv"

class PropertyOwnerScraper
  def initialize(block,lot)
    @block = block
    @lot = lot
  end

  def scrape
    @browser = Mechanize.new do |br|
      # if the page knows we're Mechanize, it won't return all fields
      br.user_agent_alias = 'Linux Firefox'
    end

    begin
      page = @browser.get("http://cityservices.baltimorecity.gov/realproperty/default.aspx")
    rescue Exception => e
      pp e
      retry
    end

    page.form.field_with(id: "ctl00_ctl00_rootMasterContent_LocalContentPlaceHolder_txtBlock").value = @block
    page.form.field_with(id: "ctl00_ctl00_rootMasterContent_LocalContentPlaceHolder_txtLot").value = @lot
    button = page.form.button_with("ctl00$ctl00$rootMasterContent$LocalContentPlaceHolder$btnSearch")
    page = page.form.submit(button)

    (1..4).collect do |num|
      page.at("//span[@id='ctl00_ctl00_rootMasterContent_LocalContentPlaceHolder_DataGrid1_ctl02_lblOwner#{num}']").text.strip
    end
  end
end

# this is what I ran from irb to collect the data
def test_property_owner_scraper
  cwd = File.dirname(__FILE__)
  date = Date.today
  tmpdir = "#{cwd}/../tmp"

  non_occupied = CSV.read("#{tmpdir}/nonoccupied.csv")
  #non_occupied = props.select { |p| p[3] == "N" }

  already_scraped = CSV.read("./tmp/nonocc_props_with_owners.csv").inject({}) { |total,r| total.merge!(r[1] => true); total }
  need_scraping = non_occupied.reject { |r| already_scraped.include?(r[1]) }

  puts "Scraping nonoccupant owners for #{need_scraping.size} properties"

  need_scraping.each_slice(need_scraping.size / 10) do |slice|
    Thread.new do
      count = 1

      CSV.open("#{tmpdir}/properties_with_owners_#{Thread.current.object_id}.csv", "w") do |csv|
        slice.each do |property_details|
          block, lot = property_details[1].split(/\s+/)[2,3]
          scraper = PropertyOwnerScraper.new(block,lot)
          owner_details = scraper.scrape
          puts "#{Thread.current.object_id}-#{count}"
          csv << property_details + owner_details
          count += 1
        end
      end
    end
  end

  (Thread.list - [Thread.current]).each(&:join)
end
