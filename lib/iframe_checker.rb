require 'net/http'
require 'uri'

module RandomInputs
  module IframeChecker
    TIMEOUT = 8
    USER_AGENT = 'Mozilla/5.0 (randominputs)'
    MAX_REDIRECTS = 5

    # Returns true if the URL refuses to render in an iframe,
    # false if it appears safe to embed, or nil on network error.
    def self.blocked?(url)
      response = head(URI.parse(url))
      return nil unless response

      if (xfo = response['x-frame-options']) && xfo.match?(/\b(deny|sameorigin)\b/i)
        return true
      end

      if (csp = response['content-security-policy']) && csp =~ /frame-ancestors\s+([^;]+)/i
        directive = Regexp.last_match(1)
        return true unless directive.match?(/(\A|\s)\*(\s|\z)/)
      end

      false
    rescue StandardError
      nil
    end

    def self.head(uri, limit = MAX_REDIRECTS)
      return nil if limit.zero?

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.open_timeout = TIMEOUT
      http.read_timeout = TIMEOUT

      request = Net::HTTP::Head.new(uri.request_uri, 'User-Agent' => USER_AGENT)
      response = http.request(request)

      case response
      when Net::HTTPRedirection
        location = response['location']
        return nil if location.nil? || location.empty?

        next_uri = URI.parse(location)
        next_uri = uri + next_uri unless next_uri.absolute?
        head(next_uri, limit - 1)
      else
        response
      end
    end
  end
end
