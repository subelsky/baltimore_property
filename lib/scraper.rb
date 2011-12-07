#!/usr/bin/ruby

# based on https://scraperwiki.com/scrapers/advanced-scraping-aspx-pages-1/

require "open-uri"
require "mechanize"
require "nokogiri"
require "pp"

Mechanize.html_parser = Nokogiri::HTML
BASE_URL = "http://sdatcert3.resiusa.org/rp_rewrite/results.aspx?County=03&SearchType=STREET&StreetNumber=&StreetName=%s*"

browser = Mechanize.new do |br|
  # if the page knows we're Mechanize, it won't return all fields
  br.user_agent_alias = 'Linux Firefox'
end

class LetterScraper
  def initialize(letter)
    @letter = letter
  end

  def scrape
    page = browser.get(BASE_URL % @letter)
    options = page.form_with(id: "Form1").field_with("SelectedPage").options[1..-1]
    properties = []

    loop do
      page.search("//table[@id='Results']/tr")[1..-1].each do |row|
        values = row.children[0..-2].collect { |c| c.text.strip }
        pp values
        properties << values
      end

      puts "Now at #{properties.size} properties"

      next_value = options.shift
      break if next_value.nil?

      form = page.form_with(id: "Form1")
      form.field_with("SelectedPage").value = next_value.to_s
      puts "Searching for page #{next_value}"
      page = form.submit
    end

    props
  end
end
