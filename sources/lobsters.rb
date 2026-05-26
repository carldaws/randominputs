module Sources
  module Lobsters
    LIMIT = 25
    HOTTEST = 'https://lobste.rs/hottest.json'

    def self.fetch
      RandomInputs::Source.get_json(HOTTEST)
        .first(LIMIT)
        .reject { |item| item['url'].to_s.empty? }
        .map { |item| { url: item['url'], title: item['title'] } }
    end
  end
end
