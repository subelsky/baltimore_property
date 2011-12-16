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

    begin
      page = page.form.submit(button)
    rescue Exception => e
      pp e
      retry
    end

    (1..4).collect do |num|
      node = page.at("//span[@id='ctl00_ctl00_rootMasterContent_LocalContentPlaceHolder_DataGrid1_ctl02_lblOwner#{num}']")
      next "" if node.nil?
      node.text.strip
    end
  end
end

# this is what I ran from irb to collect the data
def test_property_owner_scraper
  cwd = File.dirname(__FILE__)
  date = Date.today
  tmpdir = "#{cwd}/../tmp"

  non_occupied = props.select { |p| p[3] == "N" }

  puts "Scraping nonoccupant owners for #{non_occupied.size} properties"

  non_occupied.each_slice(non_occupied.size / 10) do |slice|
    Thread.new do
      out_dir = "#{tmpdir}/owners3/#{Thread.current.object_id}"
      `mkdir -p #{out_dir}`

      slice.each do |property_details|
        block, lot = Array(property_details[1].split(/\s+/))[2,3]

        unless block && lot
          puts "unable to read #{property_details.inspect}"
          next
        end

        File.open("#{out_dir}/#{block}-#{lot}.tsv", "w") do |f|
          scraper = PropertyOwnerScraper.new(block,lot)
          owner_details = scraper.scrape
          f.puts((property_details + owner_details).join("\t"))
        end
      end
      puts "#{Thread.current.object_id} complete"
    end
  end

  (Thread.list - [Thread.current]).each(&:join)
end
