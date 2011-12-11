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
    rescue StandardError => e
      pp e
      retry
    end

    puts "Searching for #{@block}-#{@lot}"
    page.form.field_with(id: "ctl00_ctl00_rootMasterContent_LocalContentPlaceHolder_txtBlock").value = @block
    page.form.field_with(id: "ctl00_ctl00_rootMasterContent_LocalContentPlaceHolder_txtLot").value = @lot
    button = page.form.button_with("ctl00$ctl00$rootMasterContent$LocalContentPlaceHolder$btnSearch")
    page = page.form.submit(button)

    (1..4).collect do |num|
      page.at("//span[@id='ctl00_ctl00_rootMasterContent_LocalContentPlaceHolder_DataGrid1_ctl02_lblOwner#{num}']").text.strip
    end
  end
end

# this is what I ran from irb to collect the files
def test_func
  cwd = File.dirname(__FILE__)
  date = Date.today
  tmpdir = "#{cwd}/../tmp"

  props = CSV.read("#{tmpdir}/sorted_properties.csv")

  props.each do |prop|
    block, lot = prop[1].split(/\s+/)[2,3]

    scraper = PropertyOwnerScraper.new(block,lot)
    owner_details = scraper.scrape
    pp owner_details
    props += owner_details
  end

  CSV.open("#{tmpdir}/properties_with_owners.csv", "w") do |csv|
    props.each { |p| csv << p }
  end
end

