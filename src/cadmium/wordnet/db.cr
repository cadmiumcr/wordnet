module Cadmium
  module Wordnet
    # Represents the Wordnet database, and provides some basic interaction.
    class DB
      @raw_wordnet = {} of String => String

      # To use your own Wordnet installation (rather than the one bundled with Cadmium:
      # Returns the path to the Wordnet installation currently in use. Defaults to the bundled version of Wordnet.
      class_property data_dir : String = File.expand_path("../../../data/wordnet/", __DIR__)

      # Open a wordnet database. You shouldn't have to call this directly; it's
      # handled by the autocaching implemented in lemma.cr.
      #
      # `path` should be a string containing the absolute path to the root of a
      # Wordnet installation.
      def self.open(path, &block)
        File.open(File.join(@@data_dir, path), "r") do |f|
          yield f
        end
      end

      def self.open(path)
        File.open(File.join(@@data_dir, path), "r")
      end
    end
  end
end
