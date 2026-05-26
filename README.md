# random inputs

A browser homepage that opens a random article from the current top of Hacker News, lobste.rs, and Pinboard. Hit the shuffle for another.

The point is exposure to the open web — independent blogs, niche projects, considered writing — the kind of thing that doesn't surface on an algorithmic timeline. Set it as your homepage and you'll read a bit of it without having to actively go looking.

## How it works

`fetch.rb` pulls the current top stories from each script in `sources/`, HEAD-checks every URL to see whether it refuses iframe embedding, and writes the survivors to `inputs.json`. The static frontend (`index.html`) reads that JSON, picks a URL at random, and shows it full-screen with a bottom bar — title in the middle, shuffle button on the right.

Hosts that block embedding get cached in SQLite (`blocked_hosts`) so we don't waste a request on them next time. A GitHub Action runs the script on a cron and commits the regenerated `inputs.json` back to the repo.

## Run it locally

```sh
bundle install
ruby fetch.rb            # regenerate inputs.json
python3 -m http.server   # serve index.html on :8000
```

Requires Ruby (see `mise.toml`).

## Add a source

Drop a `.rb` file in `sources/` that defines a module with a `fetch` method returning `[{url:, title:}]`. For an RSS or Atom feed, the whole file can be:

```ruby
module Sources
  module YourSite
    FEED = RandomInputs::RSSSource.new('https://example.com/feed.xml')
    def self.fetch = FEED.fetch
  end
end
```

The next time `fetch.rb` runs, your source is picked up automatically.
