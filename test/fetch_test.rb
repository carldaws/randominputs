require 'bundler/setup'
require 'minitest/autorun'
require 'stringio'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'uri'

require_relative '../fetch'

class StubIframeChecker
  def initialize(verdicts)
    @verdicts = verdicts
    @calls = 0
  end

  attr_reader :calls

  def blocked?(url)
    @calls += 1
    @verdicts.fetch(URI.parse(url).host)
  end
end

class FetchTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @db_path = File.join(@tmpdir, 'test.db')
    @json_path = File.join(@tmpdir, 'test.json')
    @sources = [['testsrc', FakeSource]]
    @checker = StubIframeChecker.new(
      'good-blog.example' => false,
      'news.example' => true,
      'another-blog.example' => false
    )
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_pipeline_filters_blocked_hosts_and_caches_blocked_decisions
    run_fetch
    urls_in_output = JSON.parse(File.read(@json_path)).map { |i| i['url'] }
    assert_includes urls_in_output, 'https://good-blog.example/post'
    assert_includes urls_in_output, 'https://another-blog.example/x'
    refute_includes urls_in_output, 'https://news.example/article'
    assert_equal 3, @checker.calls, 'first run should check each candidate exactly once'

    # Second run with the same candidates: only the URL whose host got
    # cached as blocked is skipped; the others get re-checked because we
    # no longer remember individual URLs.
    @checker = StubIframeChecker.new(
      'good-blog.example' => false,
      'another-blog.example' => false
    )
    run_fetch
    assert_equal 2, @checker.calls,
      'second run should skip cached-blocked host and re-check the rest'
  end

  private

  def run_fetch
    Fetch.run(db_path: @db_path, json_path: @json_path,
              sources: @sources,
              iframe_checker: @checker, logger: StringIO.new)
  end

  module FakeSource
    def self.fetch
      [
        { url: 'https://good-blog.example/post', title: 'A good post' },
        { url: 'https://news.example/article', title: 'A news article' },
        { url: 'https://another-blog.example/x', title: 'Another good post' }
      ]
    end
  end
end
