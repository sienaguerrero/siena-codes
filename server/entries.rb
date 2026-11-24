# frozen_string_literal: true

require "sqlite3"

module Guestbook
  class Entries
    LIMITS = { "name" => 40, "from" => 40, "text" => 280 }.freeze
    REQUIRED = %w[name text].freeze
    PER_DAY = 200
    MAX_ROWS = 5000
    DAY = 24 * 60 * 60
    SCHEMA = <<~SQL
      CREATE TABLE IF NOT EXISTS entries (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        from_place TEXT NOT NULL,
        text TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    SQL

    def self.clean(fields)
      return unless fields.is_a?(Hash)

      entry = LIMITS.to_h do |key, limit|
        value = fields.fetch(key, "")
        return nil unless value.is_a?(String) && value.valid_encoding?

        value = value.gsub(/\p{Cc}+/, " ").strip
        return nil if value.length > limit

        [key, value]
      end
      entry if REQUIRED.none? { |key| entry[key].empty? }
    end

    def initialize(path:, clock:, per_day: PER_DAY, max_rows: MAX_ROWS)
      @db = SQLite3::Database.new(path)
      @db.execute(SCHEMA)
      @clock = clock
      @per_day = per_day
      @max_rows = max_rows
      @mutex = Mutex.new
    end

    def add(entry)
      @mutex.synchronize do
        now = @clock.call.to_i
        next false if count >= @max_rows
        next false if @db.get_first_value("SELECT COUNT(*) FROM entries WHERE created_at > ?", [now - DAY]) >= @per_day

        @db.execute("INSERT INTO entries (name, from_place, text, created_at) VALUES (?, ?, ?, ?)",
                    [entry["name"], entry["from"], entry["text"], now])
        true
      end
    end

    def size = @mutex.synchronize { count }

    private

    def count = @db.get_first_value("SELECT COUNT(*) FROM entries")
  end
end
