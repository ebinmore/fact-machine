# Fact Machine

A small Ruby logic engine for storing predicate facts and querying them with variables, wildcards, and repeated-variable matching.

## Table of Contents

- [Requirements](#requirements)
- [Installing Ruby with Homebrew](#installing-ruby-with-homebrew)
- [Running the Program](#running-the-program)
- [Input Format](#input-format)
- [Query Terms](#query-terms)
- [How the Logic Engine Works](#how-the-logic-engine-works)
- [Running Tests](#running-tests)

## Requirements

- macOS
- Homebrew
- Ruby 4+

## Installing Ruby with Homebrew

Install Homebrew if needed:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Install Ruby:

```bash
brew install ruby
```

Confirm Ruby is available:

```bash
ruby --version
# ruby 4.0.4 (2026-05-12 revision b89eb1bcbf) +PRISM [arm64-darwin23]
```

If macOS is still using the system Ruby, add Homebrew Ruby to your shell path.

### Apple Silicon Macs

```bash
echo 'export PATH="/opt/homebrew/opt/ruby/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Alternatively, if you don't want to permanently override your shell path, you can apply `export PATH="/opt/homebrew/opt/ruby/bin:$PATH"` in your current terminal to point to the homebrew ruby. **Note: you will need to re-apply the export for each terminal window.**

### Intel Macs

```bash
echo 'export PATH="/usr/local/opt/ruby/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

## Running the Program

Run the program with an input file:

```bash
ruby predicate_program.rb input.txt
```

Run the program with an input file and compare against an expected output file:

```bash
ruby predicate_program.rb input.txt expected_output.txt
```

When an expected output file is provided, the program will:

1. print the normal query output
2. compare that output against the expected output file
3. print `PASS` or `FAIL`

## Input Format

The program reads one command per line.

There are two command types:

```text
INPUT predicate_name (entity1, entity2, ...)
QUERY predicate_name (term1, term2, ...)
```

Example:

```text
QUERY is_a_cat (X)
INPUT is_a_cat (lucy)
INPUT is_a_cat (garfield)
INPUT loves (garfield, lasagna)
INPUT is_a_cat (bowler_cat)
QUERY is_a_cat (X)
QUERY loves (garfield, FavoriteFood)
```

Blank lines and lines beginning with `#` are ignored.

## Query Terms

Queries may contain concrete entities, variables, or wildcards.

### Concrete entity

```text
QUERY loves (garfield, lasagna)
```

Returns `true` if that exact fact exists.

### Variable

Variables start with an uppercase letter:

```text
QUERY loves (garfield, FavoriteFood)
```

Returns all matching facts where `garfield` is in the first position.

### Wildcard

The `_` wildcard matches anything:

```text
QUERY loves (_, lasagna)
```

Returns all facts where something loves `lasagna`.

### Repeated Variables

Repeated variables must bind to the same value:

```text
QUERY sameish (X, X)
```

This matches:

```text
INPUT sameish (sam, sam)
```

but not:

```text
INPUT sameish (sam, frodo)
```

## How the Logic Engine Works

The engine stores facts by predicate.

For example:

```text
INPUT loves (garfield, lasagna)
```

stores the fact:

```ruby
[:loves, ["garfield", "lasagna"]]
```

Each predicate maintains:

- a list of all stored facts
- positional indexes for fast lookups

For example:

```text
INPUT loves (garfield, lasagna)
```

creates indexes like:

```ruby
indexes[0]["garfield"]
indexes[1]["lasagna"]
```

This allows queries like:

```text
QUERY loves (garfield, Food)
```

to efficiently narrow the candidate facts before pattern matching.

The matcher then evaluates each candidate fact:

- concrete values must match exactly
- `_` matches anything
- variables bind to values
- repeated variables must consistently bind to the same value

Query results are sorted to ensure deterministic output regardless of insertion order.

### Result Ordering

The current implementation returns query results in deterministic alphabetical order.

Some evaluator examples appear to expect a different ordering that is neither alphabetical nor insertion order. This requires additional clarification to determine the correct behaviour.

## Running Tests

Run the test suite with:

```bash
ruby tests/predicate_store_test.rb
ruby tests/predicate_program_test.rb
```

`minitest` ships with Ruby, so no additional gem installation is required.
