#!/usr/bin/env ruby
# Pulls current top stories from each script in sources/. For every candidate
# URL, checks the learned blocked_hosts cache; if the host is unknown, does a
# HEAD request to see if the page refuses iframe embedding. URLs that pass
# go into inputs.json for the static frontend; hosts that block get added to
# the cache so we never check them again.

require 'bundler/setup'
require 'json'
require 'uri'
require 'set'

require_relative 'lib/database'
require_relative 'lib/source'
require_relative 'lib/iframe_checker'

module Fetch
  ROOT = File.expand_path(__dir__)
  DB_PATH = File.join(ROOT, 'inputs.db')
  JSON_PATH = File.join(ROOT, 'inputs.json')
  SOURCES_DIR = File.join(ROOT, 'sources')

  def self.run(db_path: DB_PATH, json_path: JSON_PATH,
               sources_dir: SOURCES_DIR, sources: nil,
               iframe_checker: RandomInputs::IframeChecker,
               logger: $stdout)
    db = RandomInputs::Database.new(db_path)
    sources ||= discover_sources(sources_dir)

    logger.puts "Sources: #{sources.map(&:first).join(', ')}"
    candidates = collect_candidates(sources, logger)
    pool = build_pool(db, candidates, iframe_checker, logger)
    write_json(pool, json_path, logger)
  ensure
    db&.close
  end

  def self.discover_sources(dir)
    Dir["#{dir}/*.rb"].sort.each { |path| require path }
    Sources.constants.sort.map { |name| [name.to_s.downcase, Sources.const_get(name)] }
  end

  def self.collect_candidates(sources, logger)
    sources.flat_map do |name, mod|
      logger.print "  fetching #{name}... "
      items = mod.fetch
      logger.puts "#{items.size} items"
      items.map { |item| item.merge(source: name) }
    rescue StandardError => e
      logger.puts "FAILED (#{e.class}: #{e.message})"
      []
    end
  end

  def self.build_pool(db, candidates, iframe_checker, logger)
    pool = []
    seen = Set.new
    newly_blocked = 0

    candidates.each do |item|
      next unless seen.add?(item[:url])

      host = host_of(item[:url])
      next unless host
      next if db.host_blocked?(host)

      case iframe_checker.blocked?(item[:url])
      when true
        logger.puts "  blocked: #{host}"
        db.block_host!(host)
        newly_blocked += 1
      when false
        pool << { source: item[:source], url: item[:url], title: item[:title] }
      end
    end

    logger.puts "Pool: #{pool.size} URLs (#{newly_blocked} new blocked hosts)"
    pool
  end

  def self.write_json(pool, path, logger)
    File.write(path, JSON.pretty_generate(pool))
    logger.puts "Wrote #{File.basename(path)}"
  end

  def self.host_of(url)
    URI.parse(url).host&.downcase
  rescue URI::InvalidURIError
    nil
  end
end

Fetch.run if $PROGRAM_NAME == __FILE__
