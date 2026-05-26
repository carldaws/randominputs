require 'sqlite3'
require 'time'

module RandomInputs
  class Database
    SCHEMA = <<~SQL
      DROP TABLE IF EXISTS urls;

      CREATE TABLE IF NOT EXISTS blocked_hosts (
        host TEXT PRIMARY KEY,
        blocked_at TEXT NOT NULL
      );
    SQL

    def initialize(path)
      @db = SQLite3::Database.new(path)
      @db.results_as_hash = true
      @db.execute_batch(SCHEMA)
    end

    def host_blocked?(host)
      !@db.get_first_value('SELECT 1 FROM blocked_hosts WHERE host = ?', host).nil?
    end

    def block_host!(host)
      @db.execute(
        'INSERT OR IGNORE INTO blocked_hosts (host, blocked_at) VALUES (?, ?)',
        [host, Time.now.utc.iso8601]
      )
    end

    def close
      @db.close
    end
  end
end
