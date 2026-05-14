# tests/predicate_program_test.rb

require "minitest/autorun"
require "stringio"
require "tempfile"

require_relative "../predicate_program"

class PredicateProgramTest < Minitest::Test
  def setup
    @output = StringIO.new
    @program = PredicateProgram.new(output: @output)
  end

  def test_runs_query_lines_and_prints_results
    @program.run_line("INPUT is_a_cat (lucy)")
    @program.run_line("INPUT is_a_cat (garfield)")
    @program.run_line("QUERY is_a_cat (X)")

    assert_equal <<~OUTPUT, @output.string
      QUERY is_a_cat(X)
      => ["garfield"]
      => ["lucy"]
    OUTPUT
  end

  def test_ignores_blank_lines_and_comments
    @program.run_line("")
    @program.run_line("   ")
    @program.run_line("# comment")
    @program.run_line("INPUT is_a_cat (lucy)")
    @program.run_line("QUERY is_a_cat (X)")

    assert_equal <<~OUTPUT, @output.string
      QUERY is_a_cat(X)
      => ["lucy"]
    OUTPUT
  end

  def test_runs_file
    file = Tempfile.new("predicate-input")

    file.write <<~INPUT
      INPUT is_a_cat (lucy)
      INPUT is_a_cat (garfield)
      QUERY is_a_cat (X)
    INPUT

    file.close

    @program.run_file(file.path)

    assert_equal <<~OUTPUT, @output.string
      QUERY is_a_cat(X)
      => ["garfield"]
      => ["lucy"]
    OUTPUT
  ensure
    file&.unlink
  end

  def test_parse_error_includes_line_number_and_original_line
    file = Tempfile.new("bad-predicate-input")

    file.write <<~INPUT
      INPUT is_a_cat (lucy)
      NONSENSE is_a_cat (X)
    INPUT

    file.close

    error = assert_raises(PredicateProgram::RuntimeError) do
      @program.run_file(file.path)
    end

    assert_equal <<~ERROR.chomp, error.message
      Line 2: Could not parse command
        NONSENSE is_a_cat (X)
    ERROR
  ensure
    file&.unlink
  end

  def test_empty_argument_raises_parse_error
    error = assert_raises(PredicateProgram::ParseError) do
      @program.run_line("INPUT loves (garfield,)")
    end

    assert_equal "Empty argument", error.message
  end

  def test_invalid_argument_raises_parse_error
    error = assert_raises(PredicateProgram::ParseError) do
      @program.run_line("INPUT loves (garfield, lasagna!)")
    end

    assert_equal 'Invalid argument "lasagna!"', error.message
  end

  def test_arity_error_from_store_is_wrapped_when_running_file
    file = Tempfile.new("bad-arity-input")

    file.write <<~INPUT
      INPUT loves (garfield, lasagna)
      INPUT loves (odie)
    INPUT

    file.close

    error = assert_raises(PredicateProgram::RuntimeError) do
      @program.run_file(file.path)
    end

    assert_equal <<~ERROR.chomp, error.message
      Line 2: loves expects 2 entities, got 1
        INPUT loves (odie)
    ERROR
  ensure
    file&.unlink
  end
end