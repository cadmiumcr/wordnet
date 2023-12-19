module Cadmium
  module Wordnet
    class Lemma
      SPACE = " "

      enum POS
        Verb
        Noun
        Adj
        Adv

        def self.parse(str : String)
          case str.downcase
          when "verb", "v"
            Verb
          when "noun", "n"
            Noun
          when "adj", "a"
            Adj
          when "adv", "r"
            Adv
          else
            raise "Unknown POS '#{str}'"
          end
        end
      end

      # The word this lemma represents
      getter word : String

      # The part of speech (noun, verb, adjective) of this lemma.
      getter pos : POS

      # The number of times the sense is tagged in various semantic concordance texts.
      # A tagsense_count of 0 indicates that the sense has not been semantically tagged.
      getter tagsense_count : Int32

      # The offset, in bytes, at which the synsets contained in this lemma are stored
      # in Wordnet's internal database.
      getter synset_offsets : Array(Int32)

      # A unique integer id that references this lemma. Used internally within Wordnet's database.
      getter id : Int32

      # An array of valid pointer symbols for this lemma. The list of all valid
      # pointer symbols is defined in pointers.cr.
      getter pointer_symbols : Array(String)

      @@cache = {} of POS => Hash(String, Tuple(String, Int32))

      # Create a lemma from a line in an lexicon file. You should not be creating Lemmas by hand; instead,
      # use the Wordnet::Lemma.find and Wordnet::Lemma.find_all methods to find the Lemma for a word.
      def initialize(lexicon_line : String, id : Int32)
        @id = id
        line = lexicon_line.split(" ")

        @word = line.shift
        @pos = POS.parse(line.shift)
        synset_count = line.shift.to_i
        pend = line.shift.to_i
        @pointer_symbols = line[0, pend]
        line.delete_at(0, pend)
        line.shift # Throw away redundant sense_cnt
        @tagsense_count = line.shift.to_i
        @synset_offsets = line[0, synset_count].map(&.to_i)
        line.delete_at(0, synset_count)
      end

      # Return a list of synsets for this Lemma. Each synset represents a different sense, or meaning, of the word.
      def synsets
        @synset_offsets.reduce([] of Synset) { |acc, i| acc << Synset.new(@pos, i) }
      end

      # Returns a compact string representation of this lemma, e.g. "fall, v" for
      # the verb form of the word "fall".
      def to_s(io)
        io << @word << ", " << @pos
      end

      # Find all lemmas for this word across all known parts of speech
      def self.find_all(word : String)
        [POS::Noun, POS::Verb, POS::Adj, POS::Adv].map do |pos|
          find(word, pos) || [] of Lemma
        end
      end

      # Find a lemma for a given word and pos. Valid parts of speech are:
      # "adj", "adv", "noun", "verb". Additionally, you can use the shorthand
      # forms of each of these ("a", "r", "n", "v")/
      def self.find(word : String, pos : POS)
        cache = build_cache(pos)
        if cache.has_key?(word)
          found = cache[word]
          Lemma.new(*found)
        end
      end

      # Find a random lemma
      def self.random(pos : POS? = nil, min : Int32? = nil, max : Int32? = nil, random : Random = Random.new)
        min ||= 0
        max ||= 1000000

        if pos
          cache = build_cache(pos)
          items = cache.select { |w| w.size >= min && w.size <= max }
          lemma = items.sample(random)[1] if items.size > 0
        else
          lemma = [POS::Noun, POS::Verb, POS::Adj, POS::Adv].map do |pos|
            cache = build_cache(pos)
            items = cache.select { |w| w.size >= min && w.size <= max }
            items.sample(random)[1] if items.size > 0
          end.compact.sample(random)
        end

        if lemma
          Lemma.new(lemma[0], lemma[1])
        end
      end

      private def self.build_cache
        [POS::Noun, POS::Verb, POS::Adj, POS::Adv].each do |pos|
          build_cache(pos)
        end
      end

      private def self.build_cache(pos : POS)
        return @@cache[pos] if @@cache.has_key?(pos)
        pos_cache = {} of String => Tuple(String, Int32)
        DB.open(File.join("dict", "index.#{pos.to_s.downcase}")).each_line.each_with_index do |line, index|
          word = line[0, line.index(SPACE) || -1]
          pos_cache[word] = {line, index + 1}
        end
        @@cache[pos] = pos_cache
        pos_cache
      end
    end
  end
end
