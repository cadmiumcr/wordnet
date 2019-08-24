module Cadmium
  module Wordnet

    # :nodoc:
    MORPHOLOGICAL_SUBSTITUTIONS = {
      "noun" => [["s", ""], ["ses", "s"], ["ves", "f"], ["xes", "x"],
                 ["zes", "z"], ["ches", "ch"], ["shes", "sh"],
                 ["men", "man"], ["ies", "y"]],
      "verb" => [["s", ""], ["ies", "y"], ["es", "e"], ["es", ""],
                 ["ed", "e"], ["ed", ""], ["ing", "e"], ["ing", ""]],
      "adj" => [["er", ""], ["est", ""], ["er", "e"], ["est", "e"]],
      "adv" => [] of Array(String),
    }

    # Represents a synset (or group of synonymous words) in Wordnet. Synsets are related to each other by various (and numerous!)
    # relationships, including Hypernym (x is a hypernym of y <=> x is a parent of y) and Hyponym (x is a child of y)
    class Synset
      @@exception_map = {} of Lemma::POS => Hash(String, Array(String))
      @pointers : Array(Wordnet::Pointer)

      # Wordnet data diretctory
      class_property data_dir : String = File.expand_path("../../../data/wordnet/", __DIR__)

      # Get the offset, in bytes, at which this synset's information is stored in Wordnet's internal DB.
      # You almost certainly don't care about this.
      getter synset_offset : String

      # A two digit decimal integer representing the name of the lexicographer file containing the synset for the sense.
      # Probably only of interest if you're using a wordnet database marked up with custom attributes, and you
      # want to ensure that you're using your own additions.
      getter lex_filenum : Int32

      # Get the list of words (and their frequencies within the Wordnet graph) contained
      # in this Synset.
      getter word_counts : Hash(String, Int32)

      # Get the part of speech type of this synset. One of 'n' (noun), 'v' (verb), 'a' (adjective), or 'r' (adverb)
      getter synset_type : String

      # Get the offset, in bytes, at which this synset's POS information is stored in Wordnet's internal DB.
      # You almost certainly don't care about this.
      getter pos_offset : Int32

      # Get a shorthand representation of the part of speech this synset represents, e.g. "v" for verbs.
      getter pos : String

      # Get a string representation of this synset's gloss. "Gloss" is a human-readable
      # description of this concept, often with example usage, e.g:
      #
      # ```text
      # move upward; "The fog lifted"; "The smoke arose from the forest fire"; "The mist uprose from the meadows"
      # ```
      #
      # for the second sense of the verb "fall"
      getter gloss : String

      # Create a new synset by reading from the data file specified by *pos*, at *offset* bytes into the file. This is how
      # the Wordnet database is organized. You shouldn't be creating Synsets directly; instead, use Lemma#synsets.
      def initialize(pos : Lemma::POS, offset : Int32)
        pos = pos.to_s.downcase
        data_line = DB.open(File.join("dict", "data.#{pos}}")) do |f|
          f.seek(offset)
          f.read_line.strip
        end

        info_line, @gloss = data_line.split(" | ", 2)
        line = info_line.split(" ")

        @pos = pos
        @pos_offset = offset
        @synset_offset = line.shift
        @lex_filenum = line.shift.to_i
        @synset_type = line.shift

        @word_counts = {} of String => Int32
        word_count = line.shift.to_i
        word_count.times do
          @word_counts[line.shift] = line.shift.to_i? || 0
        end

        pointer_count = line.shift.to_i
        @pointers = Array(Wordnet::Pointer).new(pointer_count) do
          Wordnet::Pointer.new(
            symbol: line.shift,
            offset: line.shift.to_i,
            pos: line.shift,
            source: line.shift
          )
        end
      end

      # Similar to the method `Lemma#find`, but returns a list of Synsets instead of a Lemma
      def self.find(word : String, pos : Lemma::POS)
        word = word.downcase
        lemmas = self.morphy(word, pos).map { |form| Wordnet::Lemma.find(form, pos) }
        lemmas.map { |lemma| lemma.synsets }.flatten
      end

      # Similar to the method `Lemma#find_all`, but returns Synsets instead of Lemmas
      def self.find_all(word)
        Lemma::POS.values.map { |pos| self.find(word, pos) }.flatten
      end

      def self.load_exception_map
        Lemma::POS.values.each do |pos|
          @@exception_map[pos] = {} of String => Array(String)
          File.open(File.join(@@data_dir, "exceptions", "#{pos.to_s.downcase}.exc"), "r").each_line do |line|
            line = line.split
            @@exception_map[pos][line[0]] = line[1..-1]
          end
        end
      end

      def self._apply_rules(forms, pos : Lemma::POS)
        substitutions = MORPHOLOGICAL_SUBSTITUTIONS[pos.to_s.downcase]
        res = [] of String
        forms.each do |form|
          substitutions.each do |a|
            if form.ends_with? a[0]
              res.push form[0...-a[0].size] + a[1]
            end
          end
        end
        res
      end

      def self._filter_forms(forms, pos : Lemma::POS)
        forms.reject { |form| Lemma.find(form, pos).nil? }.uniq
      end

      # Get the root of a *form* by *pos*
      def self.morphy(form, pos : Lemma::POS)
        if @@exception_map.empty?
          self.load_exception_map
        end

        exceptions = @@exception_map[pos]

        # 0. Check the exception lists
        if exceptions.has_key? form
          return self._filter_forms([form] + exceptions[form], pos)
        end

        # 1. Apply rules once to the input to get y1, y2, y3, etc.
        forms = self._apply_rules([form], pos)

        # 2. Return all that are in the database (and check the original too)
        results = self._filter_forms([form] + forms, pos)
        if !results.empty?
          return results
        end

        # 3. If there are no matches, keep applying rules until we find a match
        while forms.size > 0
          forms = self._apply_rules(forms, pos)
          results = self._filter_forms(forms, pos)
          if !results.empty?
            return results
          end
        end

        # Return an empty list if we can't find anything
        [] of String
      end

      # Get all roots of a *form* regardless of part of speech
      def self.morphy(form)
        Lemma::POS.values.map { |pos| self.morphy(form, pos) }.flatten.uniq
      end

      # How many words does this Synset include?
      def word_count
        @word_counts.size
      end

      # Get a list of words included in this Synset
      def words
        @word_counts.keys
      end

      # Get an array of Synsets with the relation `pointer_symbol` relative to this
      # Synset. Mostly, this is an internal method used by convience methods (e.g. `Synset#antonym`), but
      # it can take any valid valid *pointer_symbol* defined in pointers.cr.
      #
      # Example (get the gloss of an antonym for 'fall'):
      # ```
      # lemma = Cadmium::Wordnet.lookup("fall", :verb)
      # puts lemma.synsets[1].relation("!")[0].gloss unless lemma.nil?
      # ```
      #
      # NOTE: Valid pointer symbols are contained in the constants `NOUN_POINTERS`,
      # `VERB_POINTERS`, `ADJECTIVE_POINTERS`, and `ADVERB_POINTERS`
      def relation(pointer_symbol)
        @pointers.select { |pointer| pointer.symbol == pointer_symbol }
          .map { |pointer| Synset.new(@synset_type, pointer.offset) }
      end

      # Get the Synsets of this sense's antonym
      def antonyms
        relation(ANTONYM)
      end

      # Get the parent synset (higher-level category, i.e. fruit -> reproductive_structure).
      def hypernym
        relation(HYPERNYM)[0]
      end

      # Get the parent synset (higher-level category, i.e. fruit -> reproductive_structure)
      # as an array.
      def hypernyms
        relation(HYPERNYM)
      end

      # Get the child synset(s) (i.e., lower-level categories, i.e. fruit -> edible_fruit)
      def hyponyms
        relation(HYPONYM)
      end

      # Get the synonyms (hypernyms and hyponyms) for this Synset
      def synonyms
        hypernyms + hyponyms
      end

      # Get the entire hypernym tree (from this synset all the way up to *entity*) as an array.
      def expanded_first_hypernyms
        parent = hypernym
        list = [] of Int32
        return list unless parent

        while parent
          break if list.include? parent.pos_offset
          list.push parent.pos_offset
          parent = parent.hypernym
        end

        list.flatten!
        list.map! { |offset| Synset.new(@pos, offset) }
      end

      # Get the entire hypernym tree (from this synset all the way up to *entity*) as an array.
      def expanded_hypernyms
        parents = hypernyms
        list = [] of Int32
        return list unless parents

        while parents.size > 0
          parent = parents.pop
          next if list.include? parent.pos_offset
          list.push parent.pos_offset
          parents.push *parent.hypernyms
        end

        list.flatten!
        list.map! { |offset| Synset.new(@pos, offset) }
      end

      def expanded_hypernyms_depth
        parents = hypernyms.map { |hypernym| [hypernym, 1] }
        list = [] of Int32
        out = [] of Synset
        return list unless parents

        max_depth = 1
        while parents.size > 0
          parent, depth = parents.pop
          next if list.include? parent.pos_offset
          list.push parent.pos_offset
          out.push [Synset.new(@pos, parent.pos_offset), depth]
          parents.push *(parent.hypernyms.map { |hypernym| [hypernym, depth + 1] })
          max_depth = [max_depth, depth].max
        end
        [out, max_depth]
      end

      # Returns a compact, human-readable form of this synset, e.g.
      #
      #    (v) fall (descend in free fall under the influence of gravity; "The branch fell from the tree"; "The unfortunate hiker fell into a crevasse")
      #
      # for the second meaning of the verb "fall."
      def to_s(io)
        io << "(#{@synset_type}) #{words.map { |x| x.tr("_", " ") }.join(", ")} (#{@gloss})"
      end
    end
  end
end
