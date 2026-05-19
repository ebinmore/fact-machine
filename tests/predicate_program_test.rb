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
      garfield, lucy
    OUTPUT
  end

  def test_ignores_blank_lines_and_comments
    @program.run_line("")
    @program.run_line("   ")
    @program.run_line("# comment")
    @program.run_line("INPUT is_a_cat (lucy)")
    @program.run_line("QUERY is_a_cat (X)")

    assert_equal <<~OUTPUT, @output.string
      lucy
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
      garfield, lucy
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

  def test_concrete_query_prints_boolean
    @program.run_line("INPUT is_a_cat (lucy)")
    @program.run_line("QUERY is_a_cat (lucy)")

    assert_equal <<~OUTPUT, @output.string
      true
    OUTPUT
  end

  def test_query_with_no_matches_prints_false
    @program.run_line("QUERY is_a_cat (X)")

    assert_equal <<~OUTPUT, @output.string
      false
    OUTPUT
  end

  def test_single_variable_query_prints_values_only
    @program.run_line("INPUT are_friends (alex, sam)")
    @program.run_line("INPUT are_friends (frog, toad)")
    @program.run_line("QUERY are_friends (X, sam)")

    assert_equal <<~OUTPUT, @output.string
      alex
    OUTPUT
  end

  def test_single_repeated_variable_query_prints_value_once
    @program.run_line("INPUT likes (alex, sam)")
    @program.run_line("INPUT likes (sam, sam)")
    @program.run_line("QUERY likes (X, X)")

    assert_equal <<~OUTPUT, @output.string
      sam
    OUTPUT
  end

  def test_multi_variable_query_prints_named_bindings
    @program.run_line("INPUT likes (alex, sam)")
    @program.run_line("INPUT likes (sam, frodo)")
    @program.run_line("QUERY likes (X, Y)")

    assert_equal <<~OUTPUT, @output.string
      {X: alex, Y: sam}, {X: sam, Y: frodo}
    OUTPUT
  end

  def test_multi_variable_query_with_repeated_variable_prints_each_binding_once
    @program.run_line("INPUT triplet (alice, bob, alice)")
    @program.run_line("QUERY triplet (X, Y, X)")

    assert_equal <<~OUTPUT, @output.string
      {X: alice, Y: bob}
    OUTPUT
  end
end