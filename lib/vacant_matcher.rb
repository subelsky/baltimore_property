class VacantMatcher
  def initialize(path)
    @vacants_by_block_lot = {}
    @vacants_by_address = {}

    CSV.read(path).each do |row|
      block, lot = Array(row[0].match(/(.+)\s*(\d{3}\D{,1}$)/))[1,2]
      @vacants_by_block_lot[[block,lot]] = true
      @vacants_by_address[row[1]] = true
    end
  end

  def vacant?(address,block,lot)
    !!(@vacants_by_block_lot[[block,lot]] || @vacants_by_address[address])
  end
end

def run_matcher(properties_path,vacant_buildings_path,vacant_lots_path)
  cwd = File.dirname(__FILE__)
  tmpdir = "#{cwd}/../tmp"
  vacant_lot_matcher = VacantMatcher.new(vacant_lots_path)
  vacant_bldg_matcher = VacantMatcher.new(vacant_buildings_path)

  File.open("#{tmpdir}/vacant_nonocc_properties.tsv","w") do |out|
    properties = IO.readlines(properties_path)

    # use header row from the original file in the vacants file
    out.puts "#{properties.shift.strip}\tIs Vacant Building?\tIs Vacant Lot?"

    properties.each do |row|
      address, block, lot = row.split(/\t/).values_at(0,3,4)

      is_vacant_lot = vacant_lot_matcher.vacant?(address,block,lot)
      is_vacant_bldg = vacant_bldg_matcher.vacant?(address,block,lot)

      if is_vacant_lot || is_vacant_bldg
        out.puts "#{row.strip}\t#{is_vacant_bldg}\t#{is_vacant_lot}"
      end
    end
    nil
  end
end
