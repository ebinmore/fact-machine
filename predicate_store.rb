class PredicateStore
  class ArityMismatchError < StandardError; end

  # Wildcard placeholder:
  #
  # query(:likes, "garfield", :_)
  #
  # matches anything in the second position.
  #
  ANY = :_

  def initialize
    # Main storage structure:
    #
    # {
    #   loves: {
    #     facts: [
    #       ["garfield", "lasagna"]
    #     ],
    #
    #     indexes: {
    #       0 => {
    #         "garfield" => [
    #           ["garfield", "lasagna"]
    #         ]
    #       },
    #
    #       1 => {
    #         "lasagna" => [
    #           ["garfield", "lasagna"]
    #         ]
    #       }
    #     }
    #   }
    # }
    #
    @data = Hash.new do |data_by_predicate, predicate|
      data_by_predicate[predicate] = {
        # Full stored facts for this predicate
        facts: [],

        # Inverted indexes by argument position.
        #
        # Example:
        #
        # indexes[0]["garfield"]
        #
        # returns all facts where the first
        # entity is "garfield".
        #
        indexes: Hash.new do |indexes_by_position, argument_position|
          indexes_by_position[argument_position] =
            Hash.new do |facts_by_entity, entity_value|
              facts_by_entity[entity_value] = []
            end
        end
      }
    end
  end

  def add(predicate, *entities)
    predicate_data = @data[predicate]

    validate_fact_arity!(predicate, predicate_data, entities)
    
    # Store the full fact
    predicate_data[:facts] << entities

    # Add the fact to each positional index.
    #
    # Example:
    #
    # add(:loves, "garfield", "lasagna")
    #
    # creates:
    #
    # indexes[0]["garfield"]
    # indexes[1]["lasagna"]
    #
    entities.each_with_index do |entity, argument_position|
      predicate_data[:indexes][argument_position][entity] << entities
    end
  end

  def query(predicate, *query_terms)
    predicate_data = @data[predicate]

    # Unknown predicate
    return [] unless predicate_data

    # ensure query arity matches stored facts
    validate_arity!(predicate, predicate_data, query_terms)

    # Use indexes to reduce search space.
    #
    # query(:loves, "garfield", :Food)
    #
    # can use the first-position index
    # instead of scanning every fact.
    #
    candidate_facts = best_candidates(predicate_data, query_terms)

    matching_facts = candidate_facts.select do |stored_fact|
      match_pattern?(query_terms, stored_fact)
    end

    # Fully concrete queries return boolean:
    #
    # query(:loves, "garfield", "lasagna")
    # => true
    #
    # Variable queries return matching facts:
    #
    # query(:loves, "garfield", :Food)
    # => [["garfield", "lasagna"]]
    #
    concrete_query?(query_terms) ? matching_facts.any? : matching_facts.sort
  end

  private

  def validate_arity!(predicate, predicate_data, query_terms)
    return if predicate_data[:facts].empty?

    expected_arity = predicate_data[:facts].first.length
    actual_arity = query_terms.length

    return if expected_arity == actual_arity

    raise ArityMismatchError,
      "#{predicate} expects #{expected_arity} entities, got #{actual_arity}"
  end

  def validate_fact_arity!(predicate, predicate_data, entities)
    return if predicate_data[:facts].empty?

    expected_arity = predicate_data[:facts].first.length
    actual_arity = entities.length

    return if expected_arity == actual_arity

    raise ArityMismatchError,
      "#{predicate} expects #{expected_arity} entities, got #{actual_arity}"
  end

  def best_candidates(predicate_data, query_terms)
    candidate_fact_sets = []

    query_terms.each_with_index do |query_term, argument_position|
      # Variables and wildcards cannot
      # use positional indexes.
      #
      next if placeholder?(query_term)

      # Use positional index to narrow
      # the candidate set.
      #
      # query(:loves, "garfield", :Food)
      #
      # uses:
      #
      # indexes[0]["garfield"]
      #
      candidate_fact_sets << predicate_data[:indexes]
        .dig(argument_position, query_term)
        .to_a
    end

    # No concrete values means we must
    # scan all facts for this predicate.
    #
    # query(:loves, :X, :Y)
    #
    return predicate_data[:facts] if candidate_fact_sets.empty?

    # Use the smallest candidate set
    # for best performance.
    #
    candidate_fact_sets.min_by(&:size)
  end

  def concrete_query?(query_terms)
    query_terms.none? { |query_term| placeholder?(query_term) }
  end

  def placeholder?(value)
    value == ANY || variable?(value)
  end

  # Symbols are treated as variables:
  #
  # :X
  # :Person
  # :FavoriteFood
  #
  def variable?(value)
    value.is_a?(Symbol) && value != ANY
  end

  def match_pattern?(query_terms, stored_fact)
    # Predicates must have the same arity.
    #
    # query(:likes, :X)
    #
    # should not match:
    #
    # ["garfield", "lasagna"]
    #
    return false unless query_terms.length == stored_fact.length

    # Tracks variable bindings during matching.
    #
    # query(:triplet, :X, :Y, :X)
    #
    # might produce:
    #
    # {
    #   X: "alice",
    #   Y: "bob"
    # }
    #
    variable_bindings = {}

    # zip pairs query terms with stored values
    # by position.
    #
    # query_terms = [:X, :Y, :X]
    # stored_fact = ["alice", "bob", "alice"]
    #
    # becomes:
    #
    # [
    #   [:X, "alice"],
    #   [:Y, "bob"],
    #   [:X, "alice"]
    # ]
    #
    query_terms.zip(stored_fact).all? do |query_term, stored_entity|
      if query_term == ANY
        # Wildcard matches anything
        true

      elsif variable?(query_term)
        if variable_bindings.key?(query_term)
          # Variable already bound:
          # value must match previous binding
          variable_bindings[query_term] == stored_entity
        else
          # First appearance of variable:
          # bind it to current entity
          variable_bindings[query_term] = stored_entity
          true
        end

      else
        # Concrete value comparison
        query_term == stored_entity
      end
    end
  end
end