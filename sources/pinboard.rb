module Sources
  module Pinboard
    FEED = RandomInputs::RSSSource.new('https://feeds.pinboard.in/rss/popular/', limit: 30)

    def self.fetch
      FEED.fetch
    end
  end
end
