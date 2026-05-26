module Sources
  module HN
    LIMIT = 30
    TOP_STORIES = 'https://hacker-news.firebaseio.com/v0/topstories.json'
    ITEM = 'https://hacker-news.firebaseio.com/v0/item/%d.json'

    def self.fetch
      ids = RandomInputs::Source.get_json(TOP_STORIES).first(LIMIT)
      ids.map { |id| RandomInputs::Source.get_json(ITEM % id) }
         .reject { |item| item.nil? || item['url'].to_s.empty? }
         .map { |item| { url: item['url'], title: item['title'] } }
    end
  end
end
