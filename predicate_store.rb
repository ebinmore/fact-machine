class PredicateStore
  # Matches any value in a query:
  #
  # query(:likes, "garfield", :_)
  #
  ANY = :_

  def initialize
    # Structure:
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
    @data = Hash.new do |h, predicate|
      h[predicate] = {
        facts: [],

        # Inverted indexes by argument position.
        #
        # indexes[0]["garfield"]
        # => all facts where first argument == "garfield"
        #
        indexes: Hash.new do |position_hash, position|
          position_hash[position] = Hash.new do |entity_hash, entity|
            entity_hash[entity] = []
          end
        end
      }
    end
  end

  def add(predicate, *entities)
    bucket = @data[predicate]

    # Store full fact
    bucket[:facts] << entities

    # Add fact to each positional index
    #
    # Example:
    #
    # add(:loves, "garfield", "lasagna")
    #
    # Creates:
    #
    # indexes[0]["garfield"]
    # indexes[1]["lasagna"]
    #
    entities.each_with_index do |entity, position|
      bucket[:indexes][position][entity] << entities
    end
  end

  def query(predicate, *pattern)
    bucket = @data[predicate]

    # Unknown predicate
    return [] unless bucket

    # Use indexes to reduce search space
    #
    # Example:
    #
    # query(:loves, "garfield", :Food)
    #
    # only scans rows matching:
    #
    # first entity == "garfield"
    #
    candidates = best_candidates(bucket, pattern)

    matches = candidates.select do |fact|
      match_pattern?(pattern, fact)
    end

    # Fully concrete queries return boolean
    #
    # query(:loves, "garfield", "lasagna")
    # => true
    #
    # Variable queries return matching rows
    #
    # query(:loves, "garfield", :Food)
    # => [["garfield", "lasagna"]]
    #
    concrete_query?(pattern) ? matches.any? : matches.sort
  end

  private

  def best_candidates(bucket, pattern)
    candidate_sets = []

    pattern.each_with_index do |token, position|
      # Variables and wildcards cannot use indexes
      next if placeholder?(token)

      # Use positional index to narrow search
      #
      # Example:
      #
      # query(:loves, "garfield", :Food)
      #
      # uses:
      #
      # indexes[0]["garfield"]
      #
      candidate_sets << bucket[:indexes].dig(position, token).to_a
    end

    # No concrete values means we must scan everything
    #
    # query(:loves, :X, :Y)
    #
    return bucket[:facts] if candidate_sets.empty?

    # Use smallest candidate set for efficiency
    candidate_sets.min_by(&:size)
  end

  def concrete_query?(pattern)
    pattern.none? { |token| placeholder?(token) }
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

  def match_pattern?(pattern, fact)
    # Arity mismatch
    #
    # query(:likes, :X)
    #
    # should not match:
    #
    # ["garfield", "lasagna"]
    #
    return false unless pattern.length == fact.length

    # Tracks variable bindings during matching
    #
    # query(:triplet, :X, :Y, :X)
    #
    # after matching:
    #
    # :X => "alice"
    # :Y => "bob"
    #
    bindings = {}

    # Pair query tokens with fact values
    #
    # pattern = [:X, :Y, :X]
    # fact    = ["alice", "bob", "alice"]
    #
    # becomes:
    #
    # [
    #   [:X, "alice"],
    #   [:Y, "bob"],
    #   [:X, "alice"]
    # ]
    #
    pattern.zip(fact).all? do |token, value|
      if token == ANY
        # Wildcard always matches
        true

      elsif variable?(token)
        if bindings.key?(token)
          # Variable already bound:
          #
          # :X must consistently refer
          # to the same value everywhere
          #
          bindings[token] == value
        else
          # First time variable seen:
          #
          # bind variable to current value
          #
          bindings[token] = value
          true
        end

      else
        # Concrete value comparison
        #
        # "garfield" == "garfield"
        #
        token == value
      end
    end
  end
end