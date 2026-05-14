class PredicateStore
  ANY = :_

  def initialize
    @data = Hash.new { |h, k| h[k] = [] }
  end

  def add(predicate, *entities)
    @data[predicate] << entities
  end

  # Examples:
  #
  # query(:likes, :_, "Sam")
  # => [["Alex", "Sam"], ["Jordan", "Sam"]]
  #
  # query(:likes, :x, :x)
  # => [["Sam", "Sam"], ["Lucy", "Lucy"]]
  #
  # query(:likes, :x, :y)
  # => all likes pairs
  #
  # query(:is_cat)
  # => [["Lucy"], ["Garfield"]]
  #
  # query(:is_cat, "Lucy")
  # => true
  #
  def query(predicate, *pattern)
    facts = @data[predicate]

    # No query args means "return everything"
    return facts if pattern.empty?

    matches = facts.select do |fact|
      match_pattern?(pattern, fact)
    end

    # If fully concrete query (no placeholders),
    # return boolean instead of rows
    if concrete_query?(pattern)
      matches.any?
    else
      matches
    end
  end

  private

  def concrete_query?(pattern)
    pattern.none? do |p|
      placeholder?(p)
    end
  end

  def placeholder?(value)
    value == ANY || variable?(value)
  end

  # variables are symbols except :_
  # :x, :y, :person, etc.
  def variable?(value)
    value.is_a?(Symbol) && value != ANY
  end

  def match_pattern?(pattern, fact)
    return false unless pattern.length == fact.length

    bindings = {}

    pattern.zip(fact).all? do |token, value|
      case
      when token == ANY
        true

      when variable?(token)
        if bindings.key?(token)
          bindings[token] == value
        else
          bindings[token] = value
          true
        end

      else
        token == value
      end
    end
  end
end

# -----------------------------------
# Example usage
# -----------------------------------

# store = PredicateStore.new

# store.add(:is_cat, "Lucy")
# store.add(:is_cat, "Garfield")

# store.add(:likes, "Alex", "Sam")
# store.add(:likes, "Jordan", "Sam")
# store.add(:likes, "Sam", "Sam")
# store.add(:likes, "Lucy", "Lucy")

# p store.query(:is_cat)
# # => [["Lucy"], ["Garfield"]]

# p store.query(:is_cat, "Lucy")
# # => true

# p store.query(:is_cat, "Alf")
# # => false

# p store.query(:likes, :_, "Sam")
# # => [["Alex", "Sam"], ["Jordan", "Sam"], ["Sam", "Sam"]]

# p store.query(:likes, :x, :x)
# # => [["Sam", "Sam"], ["Lucy", "Lucy"]]

# p store.query(:likes, :x, :y)
# # => all rows

# p store.query(:likes, "Alex", "Sam")
# # => true