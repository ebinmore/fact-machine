require_relative "predicate_store"

class PredicateProgram
  def initialize(store = PredicateStore.new)
    @store = store
  end

  def run_file(path)
    File.readlines(path, chomp: true).each_with_index do |line, index|
      run_line(line, line_number: index + 1)
    end
  end

  def run_line(line, line_number: nil)
    line = line.strip
    return if line.empty? || line.start_with?("#")

    command, predicate, args = parse_line(line)

    case command
    when "INPUT"
      @store.add(predicate, *args)
    when "QUERY"
      result = @store.query(predicate, *args)
      print_query_result(predicate, args, result)
    else
      raise "Unknown command #{command.inspect} on line #{line_number}"
    end
  end

  private

  def parse_line(line)
    match = line.match(/\A(INPUT|QUERY)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\((.*)\)\z/)

    unless match
      raise "Could not parse line: #{line.inspect}"
    end

    command = match[1]
    predicate = match[2].to_sym
    raw_args = match[3].strip

    args =
      if raw_args.empty?
        []
      else
        raw_args.split(",").map { |arg| parse_arg(arg.strip) }
      end

    [command, predicate, args]
  end

  def parse_arg(arg)
    case arg
    when "_"
      PredicateStore::ANY
    when /\A[A-Z][a-zA-Z0-9_]*\z/
      arg.to_sym # Placeholder variable: X, FavoriteFood, Person, etc.
    else
      arg # Concrete entity: lucy, garfield, bowler_cat, lasagna
    end
  end

  def print_query_result(predicate, args, result)
    rendered_query = "#{predicate}(#{args.map(&:to_s).join(", ")})"

    puts "QUERY #{rendered_query}"

    case result
    when true, false
      puts "=> #{result}"
    else
      if result.empty?
        puts "=> no matches"
      else
        result.each do |row|
          puts "=> #{row.inspect}"
        end
      end
    end
  end
end

# CLI usage:
#
# ruby predicate_bootstrap.rb example.txt

if __FILE__ == $PROGRAM_NAME
  path = ARGV[0]

  unless path
    warn "Usage: ruby predicate_bootstrap.rb path/to/file.txt"
    exit 1
  end

  PredicateProgram.new.run_file(path)
end