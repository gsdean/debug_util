require "debug_util/version"

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

  def self.csv(o, name = nil)
    CSV.open(name || 'debug.csv', 'wb') do |csv|
      o.each do |row|
        csv << (row.is_a?(Array) ? row : [row])
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
end
