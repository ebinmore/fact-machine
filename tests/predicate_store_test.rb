require "minitest/autorun"
require_relative "../predicate_store"

class PredicateStoreTest < Minitest::Test
  def setup
    @store = PredicateStore.new
  end

  def test_single_entity_query_returns_all_matches
    @store.add(:is_a_cat, "lucy")
    @store.add(:is_a_cat, "garfield")

    assert_equal [
      ["garfield"],
      ["lucy"]
    ], @store.query(:is_a_cat, :X)
  end

  def test_single_entity_concrete_query_returns_true
    @store.add(:is_a_cat, "lucy")

    assert_equal true, @store.query(:is_a_cat, "lucy")
  end

  def test_single_entity_concrete_query_returns_false
    @store.add(:is_a_cat, "lucy")

    assert_equal false, @store.query(:is_a_cat, "alf")
  end

  def test_unknown_predicate_returns_empty_array
    assert_equal [], @store.query(:is_a_dog, :X)
  end

  def test_two_entity_query_with_first_position_concrete
    @store.add(:loves, "garfield", "lasagna")
    @store.add(:loves, "lucy", "milk")

    assert_equal [
      ["garfield", "lasagna"]
    ], @store.query(:loves, "garfield", :FavoriteFood)
  end

  def test_two_entity_query_with_second_position_concrete
    @store.add(:loves, "garfield", "lasagna")
    @store.add(:loves, "odie", "lasagna")
    @store.add(:loves, "lucy", "milk")

    assert_equal [
      ["garfield", "lasagna"],
      ["odie", "lasagna"]
    ], @store.query(:loves, :Who, "lasagna")
  end

  def test_two_entity_concrete_query_returns_true
    @store.add(:loves, "garfield", "lasagna")

    assert_equal true, @store.query(:loves, "garfield", "lasagna")
  end

  def test_two_entity_concrete_query_returns_false
    @store.add(:loves, "garfield", "lasagna")

    assert_equal false, @store.query(:loves, "garfield", "pizza")
  end

  def test_any_wildcard_matches_anything
    @store.add(:loves, "garfield", "lasagna")
    @store.add(:loves, "lucy", "milk")

    assert_equal [
      ["garfield", "lasagna"]
    ], @store.query(:loves, "garfield", PredicateStore::ANY)
  end

  def test_repeated_variable_requires_same_value
    @store.add(:sameish, "sam", "sam")
    @store.add(:sameish, "sam", "frodo")
    @store.add(:sameish, "lucy", "lucy")

    assert_equal [
      ["lucy", "lucy"],
      ["sam", "sam"]
    ], @store.query(:sameish, :X, :X)
  end

  def test_different_variables_do_not_require_same_value
    @store.add(:sameish, "sam", "sam")
    @store.add(:sameish, "sam", "frodo")

    assert_equal [
      ["sam", "frodo"],
      ["sam", "sam"]
    ], @store.query(:sameish, :X, :Y)
  end

  def test_three_entity_predicate_with_middle_concrete
    @store.add(:triplet, "alice", "bob", "carol")
    @store.add(:triplet, "dave", "bob", "erin")
    @store.add(:triplet, "alice", "frank", "carol")

    assert_equal [
      ["alice", "bob", "carol"],
      ["dave", "bob", "erin"]
    ], @store.query(:triplet, :X, "bob", :Y)
  end

  def test_three_entity_repeated_variable
    @store.add(:triplet, "alice", "bob", "alice")
    @store.add(:triplet, "alice", "bob", "carol")
    @store.add(:triplet, "dave", "erin", "dave")

    assert_equal [
      ["alice", "bob", "alice"],
      ["dave", "erin", "dave"]
    ], @store.query(:triplet, :X, :Y, :X)
  end

  def test_query_results_are_independent_of_input_order
    @store.add(:is_a_cat, "lucy")
    @store.add(:is_a_cat, "garfield")
    @store.add(:is_a_cat, "bowler_cat")

    assert_equal [
      ["bowler_cat"],
      ["garfield"],
      ["lucy"]
    ], @store.query(:is_a_cat, :X)
  end

  def test_query_with_wrong_arity_does_not_match
    @store.add(:loves, "garfield", "lasagna")

    assert_equal [], @store.query(:loves, :X)
    assert_equal [], @store.query(:loves, :X, :Y, :Z)
  end
end