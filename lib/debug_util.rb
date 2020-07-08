require "debug_util/version"
require 'csv'
require 'objspace'

module DebugUtil
  def self.rescue
    if defined?(Pry)
      Pry.rescue { yield }
    else
      yield
    end
  end

  def self.show_sql
    ActiveRecord::Base.logger = Logger.new(STDOUT)
  end

  def self.json(o, name = nil)
    File.open(name || 'debug.json', 'w') do |f|
      f.write(o.to_json)
    end
  end

  def self.csv(o, name = 'debug.csv', file_opts = 'wb')
    CSV.open(name, file_opts) do |csv|
      o.each do |row|
        row = block_given? ? yield(row) : row
        csv << (row.is_a?(Array) ? row : [row])
        csv.flush
      end
    end
  end

  def self.measure(gc = false)
    GC.start
    GC.disable unless gc
    ActiveRecord::Base.logger.level = 1
    begin
      measure = Benchmark.measure{ yield }
    ensure
      ActiveRecord::Base.logger.level = 0
      GC.enable unless gc
    end


    measure
  end

  def self.profile(name = nil, iterations =1, options = { :min_percent => 1 })
    return 'No profiler' unless defined?(RubyProf)
    path = name.blank? ? 'tmp' : "tmp/#{name}"
    Dir.mkdir(path) unless Dir.exists?(path)
    options[:path] = path
    RubyProf.start
    ActiveRecord::Base.logger.level = 1
    begin
      iterations.times{ yield }
    ensure
      ActiveRecord::Base.logger.level = 0
      result = RubyProf.stop
    end

    multi_printer = RubyProf::MultiPrinter.new(result)
    multi_printer.print(options)

    dot_printer = RubyProf::DotPrinter.new(result)
    profile_dot = "#{path}/profile.dot"
    File.open(profile_dot, 'w') do |file|
      dot_printer.print(file, options)
    end
    `dot -Tpng #{profile_dot} > #{path}/profile.png 2> /dev/null`
    result
  end

  UNIT_PREFIXES = {
      0 => 'B',
      3 => 'kB',
      6 => 'MB',
      9 => 'GB',
      12 => 'TB',
      15 => 'PB',
      18 => 'EB',
      21 => 'ZB',
      24 => 'YB'
  }.freeze

  def self.scale_bytes(bytes)
    return "0 B" if bytes.zero?

    scale = Math.log10(bytes.abs).div(3) * 3
    scale = 24 if scale > 24
    "%.2f#{UNIT_PREFIXES[scale]}" % (bytes / 10.0**scale)
  end

  class Snapshot
    attr_reader :instances, :bytes, :total

    def initialize
      @bytes = Hash.new { 0 }
      @instances = Hash.new { 0 }

      ObjectSpace.each_object do |o|
        instances[o.class] += 1
        bytes[o.class] += ObjectSpace.memsize_of(o)
      end

      @total = ObjectSpace.memsize_of_all
    end
  end

  def self.heap
    Snapshot.new
  end

  def self.sample_heap(frequency: 30)
    Thread.start do
      previous = heap
      loop do
        current = heap

        system("clear")

        puts "100%, *, #{scale_bytes(current.total)}, #{scale_bytes(current.total - previous.total)}"
        current.bytes.sort{|(k1,v1), (k2, v2)| v2 <=> v1}.take(50).each do |k, bytes|
          instances = current.instances[k].to_i
          delta_bytes = bytes - previous.bytes[k].to_i
          delta_instances = instances - previous.instances[k].to_i
          percent = (bytes / current.total.to_f * 100).round(2)
          puts "#{percent}%, #{k}, #{scale_bytes(bytes)} #{instances} (#{scale_bytes(delta_bytes)} #{delta_instances})"
        end

        previous = current
        sleep(frequency)
      end
    end
  end
end
