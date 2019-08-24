# Cadmium::Wordnet

>> WordNet® is a large lexical database of English. Nouns, verbs, adjectives and adverbs are grouped into sets of cognitive synonyms (synsets), each expressing a distinct concept. Synsets are interlinked by means of conceptual-semantic and lexical relations. - [https://wordnet.princeton.edu/](https://wordnet.princeton.edu/)

This WordNet implimentation is based almost completely on [doches](https://github.com/doches) ruby library [rwordnet](https://github.com/doches/rwordnet) with some extras thrown in and, of course, backed by the speed and type safety of Crystal. This is experimental and the API may change, but WordNet brings the power of the English (and hopefully other languages in the future) dictionary to your programs.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     cadmium_wordnet:
       github: cadmiumcr/wordnet
   ```

2. Run `shards install`

## Usage

Using it is easy with Cadmium's API.

```crystal
require "cadmium_wordnet"

# Lookup a single word with a specific part of speech
lemma = Cadmium.wordnet.lookup("horse", :n)
puts lemma.word.capitalize + " - " + lemma.pos
lemma.synsets.each_with_index do |synset, i|
  puts "#{i + 1}. #{synset.gloss}"
end

# Lookup a single word accross all parts of speech
lemmas = Cadmium.wordnet.lookup("horse")
lemmas = lemmas.map { |l| {word: l.word, pos: l.pos, synsets: l.synsets} }
lemmas.each do |l|
  word = l[:word].capitalize
  pos = l[:pos]
  l[:synsets].each do |s|
    puts "#{word} (#{pos}) - #{s.gloss}"
  end
end


# Lookup a definition by offset and part of speech
synset = Cadmium.wordnet.get(4424418, :n)
puts "---------------------------------------------"
puts synset.synset_offset
puts synset.pos
puts synset.gloss
puts synset.word_counts
```

## Contributing

1. Fork it (<https://github.com/cadmiumcr/wordnet/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Chris Watson](https://github.com/cadmiumcr) - creator and maintainer
