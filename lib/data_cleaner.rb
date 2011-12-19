require "open-uri"
require "mechanize"
require "nokogiri"
require "pp"
require "csv"

module DataCleaner
  extend self

  def clean(row)
    #"10 S WOLFE STREET,",02 03 1735  036,10 WOLFE S ST,N,0002,0000,"10 S WOLFE STREET, LLC",1325 EUTAW PLACE,"BALTIMORE, MD.         21217",""

    sdat_owner = row[0]
    account = row[1]
    block, lot = account.split[2..3]
    street_addr = row[2]
    map = row[4]
    parcel = row[5]
    owner_names = [row[6]]

    # any columns after this that start with numbers then a space are assumed to
    # be the street address

    owner_lines = row[7..9]

    owner_street_addr = loop do
      line = owner_lines.shift
      break "" if line.nil?

      if line =~ /^\d+ /
        break line
      else
        owner_names << line
      end
    end

    owner_addr2, owner_addr3 = owner_lines

    result = [street_addr,map,parcel,block,lot,owner_names.sort.join(" & "),owner_street_addr,owner_addr2,owner_addr3,sdat_owner,account]
    result.each { |r| r.to_s.gsub!(/\s+/,' ') }
    result
  end
end

class VacantLooker
  def initialize(paths)
    @paths = Array(paths)
    @vacants_by_block_lot = {}
    @vacants_by_address = {}

    @paths.each do |path|
      CSV.read(path).each do |row|
        block, lot = Array(row[0].match(/(.+)\s*(\d{3}\D{,1}$)/))[1,2]
        @vacants_by_block_lot[[block,lot]] = true
        @vacants_by_address[row[1]] = true
      end
    end
  end

  def vacant?(address,block,lot)
    !!(@vacants_by_block_lot[[block,lot]] || @vacants_by_address[address])
  end
end

def run_cleaner(path,vacant_paths = ["./tmp/Vacant_Lots.csv","./tmp/Vacant_Buildings.csv"])
  cwd = File.dirname(__FILE__)
  date = Date.today
  tmpdir = "#{cwd}/../tmp"
  vacant_looker = VacantLooker.new(vacant_paths)

  CSV.open("#{tmpdir}/cleaned_#{File.basename(path)}","w") do |out|
    out << ["Street Address","Map","Parcel","Block","Lot","City Owner Names","City Owner Street Address","City Owner Address 2","City Owner Address 3","SDAT Owner Name","SDAT Account","In Vacant Database?"]
    CSV.read(path).each do |row|
      begin
        cleaned = DataCleaner.clean(row)
      rescue Exception => e
        pp e
        pp row
        next
      end

      out << cleaned + [vacant_looker.vacant?(cleaned[0],cleaned[3],cleaned[4]) ? "1" : "0"]
    end
  end
  nil
end
