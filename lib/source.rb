require 'net/http'
require 'json'
require 'rss'
require 'uri'

module RandomInputs
  module Source
    USER_AGENT = 'Mozilla/5.0 (randominputs)'
    TIMEOUT = 10

    def self.http_get(url)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.open_timeout = TIMEOUT
      http.read_timeout = TIMEOUT
      response = http.get(uri.request_uri, 'User-Agent' => USER_AGENT)
      response.body
    end

    def self.get_json(url)
      JSON.parse(http_get(url))
    end
  end

  # Convenience for RSS / Atom feeds. Usage in a sources/foo.rb file:
  #
  #   module Sources
  #     module Foo
  #       FEED = RandomInputs::RSSSource.new('https://example.com/feed.xml')
  #       def self.fetch = FEED.fetch
  #     end
  #   end
  class RSSSource
    def initialize(feed_url, limit: 30)
      @feed_url = feed_url
      @limit = limit
    end

    def fetch
      body = Source.http_get(@feed_url)
      feed = RSS::Parser.parse(body, false)
      feed.items.first(@limit).map do |item|
        { url: link_of(item), title: title_of(item) }
      end.reject { |entry| entry[:url].nil? || entry[:url].empty? }
    end

    private

    def link_of(item)
      link = item.link
      return nil unless link
      link.respond_to?(:href) ? link.href : link.to_s
    end

    def title_of(item)
      title = item.title
      return nil unless title
      title.respond_to?(:content) ? title.content : title.to_s
    end
  end
end
