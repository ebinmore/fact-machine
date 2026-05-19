require "stringio"
require_relative "predicate_store"

class PredicateProgram
  class ParseError < StandardError; end
  class RuntimeError < StandardError; end

  def initialize(store = PredicateStore.new, output: $stdout)
    @store = store
    @output = output
  end

  # Execute commands from a file line-by-line.
  #
  def run_file(path)
    File.readlines(path, chomp: true).each_with_index do |line, index|
      run_line(line, line_number: index + 1)

    rescue ParseError, PredicateStore::ArityMismatchError => error
      raise RuntimeError,
        "Line #{index + 1}: #{error.message}\n  #{line}"
    end
  end

  # Execute a single INPUT or QUERY line.
  #
  def run_line(line, line_number: nil)
    line = line.strip

    # Ignore blank lines and comments.
    #
    return if line.empty? || line.start_with?("#")

    command, predicate, arguments = parse_line(line)

    case command
    when "INPUT"
      @store.add(predicate, *arguments)

    when "QUERY"
      result = @store.query(predicate, *arguments)
      print_query_result(predicate, arguments, result)

    else
      raise ParseError,
        "Unknown command #{command.inspect}"
    end
  end

  private

  # Parse lines like:
  #
  # INPUT loves (garfield, lasagna)
  # QUERY loves (garfield, FavoriteFood)
  #
  def parse_line(line)
    match = line.match(
      /\A(INPUT|QUERY)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\((.*)\)\z/
    )

    unless match
      raise ParseError, "Could not parse command"
    end

    command = match[1]
    predicate = match[2].to_sym
    raw_arguments = match[3].strip

    arguments =
      if raw_arguments.empty?
        []
      else
        raw_arguments
          .split(",", -1)
          .map { |argument| parse_argument(argument.strip) }
      end
    [command, predicate, arguments]
  end

  # Parse a single argument.
  #
  # "_"                  => wildcard
  # "Person"             => variable placeholder
  # "garfield"           => concrete entity
  #
  def parse_argument(argument)
    if argument.empty?
      raise ParseError, "Empty argument"
    end

    case argument
    when "_"
      PredicateStore::ANY

      # Variable placeholders
      when /\A[A-Z][a-zA-Z0-9_]*\z/
        argument.to_sym

      # Integer literals become strings
      when /\A\d+\z/
        argument.to_s

      # Concrete entity names
      when /\A[a-z_][a-zA-Z0-9_]*\z/
        argument

    else
      raise ParseError,
        "Invalid argument #{argument.inspect}"
    end
  end

  # Print the user-visible result for a query.
  #
  # Output format depends on the number of variables:
  #
  # QUERY likes (sam, sam)
  # => true
  #
  # QUERY likes (X, sam)
  # => alex
  #
  # QUERY likes (X, Y)
  # => {X: alex, Y: sam}
  #
  def print_query_result(_predicate, arguments, result)
    case result
    when true, false
      # Concrete queries return boolean.
      #
      @output.puts result

    else
      # No matches found.
      #
      if result.empty?
        @output.puts false
        return
      end

      # Count distinct variables used in query.
      #
      variables =
        arguments
          .select { |argument| variable?(argument) }
          .uniq

      rendered_rows =
        if variables.length <= 1
          # Single-variable queries only print values.
          #
          # QUERY likes (X, sam)
          # => alex
          #
          result.map do |row|
            projected_values(arguments, row).join(", ")
          end

        else
          # Multi-variable queries print named bindings.
          #
          # QUERY likes (X, Y)
          # => {X: alex, Y: sam}
          #
          result.map do |row|
            "{#{projected_bindings(arguments, row).join(", ")}}"
          end
        end

      @output.puts rendered_rows.join(", ")
    end
  end

  # Extract only bound variable values from a row.
  #
  # QUERY likes (X, sam)
  #
  # with:
  #
  # ["alex", "sam"]
  #
  # becomes:
  #
  # ["alex"]
  #
  def projected_values(arguments, row)
    arguments.zip(row).filter_map do |argument, value|
      value if variable?(argument)
    end.uniq
  end

  # Extract named variable bindings from a row.
  #
  # QUERY likes (X, Y)
  #
  # with:
  #
  # ["alex", "sam"]
  #
  # becomes:
  #
  # ["X: alex", "Y: sam"]
  #
  def projected_bindings(arguments, row)
    seen_variables = {}

    arguments.zip(row).filter_map do |argument, value|
      next unless variable?(argument)

      # Repeated variables should only
      # appear once in output.
      #
      next if seen_variables[argument]

      seen_variables[argument] = true

      "#{argument}: #{value}"
    end
  end

  # Variables are symbols except for the wildcard.
  #
  # :X
  # :Person
  # :FavoriteFood
  #
  def variable?(value)
    value.is_a?(Symbol) && value != PredicateStore::ANY
  end
end

# CLI usage:
#
# ruby predicate_program.rb example.txt [expected_output.txt]
#
if __FILE__ == $PROGRAM_NAME
  input_path = ARGV[0]
  expected_output_path = ARGV[1]

  unless input_path
    warn "Usage: ruby predicate_program.rb input.txt [expected_output.txt]"
    exit 1
  end

  begin
    if expected_output_path
      actual_output = StringIO.new

      PredicateProgram.new(output: actual_output).run_file(input_path)

      actual = actual_output.string
      expected = File.read(expected_output_path)

      # Always print normal program output first.
      print actual

      if actual == expected
        puts "PASS"
        exit 0
      else
        puts "FAIL"

        warn
        warn "Expected:"
        warn expected
        warn
        warn "Actual:"
        warn actual

        exit 1
      end
    else
      PredicateProgram.new.run_file(input_path)
    end
  rescue PredicateProgram::RuntimeError => error
    warn error.message
    exit 1
  end
end