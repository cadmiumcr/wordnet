require "./wordnet/pointer"
require "./wordnet/db"
require "./wordnet/lemma"
require "./wordnet/pointers"
require "./wordnet/synset"

module Cadmium
  # API to grant full access to the Stanford Wordnet project allowing
  # you to find words, definitions (gloss), hypernyms, hyponyms,
  # antonyms, etc.
  module Wordnet
    # Find a lemma for a given word and pos. Valid parts of speech are:
    # :adj, :adv, :noun, :verb. Additionally, you can use the shorthand
    def self.lookup(word : String, pos : Lemma::POS)
      Lemma.find(word, pos)
    end

    # Find all lemmas for this word across all known parts of speech
    def self.lookup(word : String)
      Lemma.find_all(word)
    end

    # Find a random lemma with the given part of speech and min/max size.
    def self.random(pos : Lemma::POS? = nil, min : Int32? = nil, max : Int32? = nil, random : Random = Random.new)
      Lemma.random(pos, min, max, random)
    end

    # Create a `Synset` by *offset* and *pos*
    def self.get(offset : Int32, pos : Lemma::POS)
      Synset.new(pos, offset)
    end

    # Get the root of a *form*
    def self.morphy(form : String)
      Synset.morphy(form)
    end

    # Get the root of a *form* with a specific *pos*
    def self.morphy(form : String, pos : Lemma::POS)
      Synset.morphy(form, pos)
    end

    # Get a random synset, optionally with a specific *pos*
    def self.random(pos : Lemma::POS? = nil, random : Random = Random.new)
    end
  end
end
