#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "shellwords"

module Guestbook
  class Reader
    REPO = "sienaguerrero/siena-codes"
    APP_DIR = "/srv/guestbook"
    DB = "/var/lib/guestbook/guestbook.sqlite3"
    USAGE = <<~TEXT
      Usage: ruby script/guestbook.rb <command>

        list              every sent entry, oldest first
        delete <id>...    delete entries by the number list shows

      Set ADMIN_SUDO_USER to your own droplet login with sudo. The script logs in
      as it and runs as deploy with sudo -n. Without it, the script logs in as
      deploy, which only works where a deploy key is loaded.
    TEXT

    LIST_PROGRAM = <<~'RUBY'
      require "json"
      require "sqlite3"

      db = SQLite3::Database.new(ENV.fetch("GUESTBOOK_DB"), readonly: true)
      db.busy_timeout = 5000
      puts JSON.generate(db.execute("SELECT id, name, from_place, text, created_at FROM entries ORDER BY id"))
    RUBY

    DELETE_PROGRAM = <<~'RUBY'
      require "json"
      require "sqlite3"

      ids = ENV.fetch("IDS").split(",").map { |id| Integer(id) }
      db = SQLite3::Database.new(ENV.fetch("GUESTBOOK_DB"))
      db.busy_timeout = 5000
      before = db.get_first_value("SELECT COUNT(*) FROM entries")
      ids.each { |id| db.execute("DELETE FROM entries WHERE id = ?", [id]) }
      left = db.get_first_value("SELECT COUNT(*) FROM entries")
      puts JSON.generate("deleted" => before - left, "left" => left)
    RUBY

    Failed = Class.new(StandardError)

    def initialize(run: method(:run), out: $stdout, env: ENV)
      @run = run
      @out = out
      @env = env
    end

    def call(args)
      case args
      in ["list"] then list
      in ["delete", *ids] if ids.any? && ids.all? { |id| id.match?(/\A[1-9]\d*\z/) } then delete(ids)
      else
        @out.puts USAGE
        1
      end
    rescue Failed => e
      @out.puts e.message
      1
    end

    private

    def list
      entries = JSON.parse(remote(LIST_PROGRAM))
      @out.puts "No entries yet." if entries.empty?
      entries.each do |id, name, from, text, created_at|
        place = from.empty? ? "" : " from #{from}"
        @out.puts "##{id}  #{Time.at(created_at).utc.strftime('%F')}  #{name}#{place}", "    #{text}", ""
      end
      0
    end

    def delete(ids)
      answer = JSON.parse(remote(DELETE_PROGRAM, "IDS" => ids.join(",")))
      @out.puts "Deleted #{answer['deleted']} of #{ids.length}. #{answer['left']} left."
      0
    end

    def remote(program, extra = {})
      vars = { "GUESTBOOK_DB" => DB, "BUNDLE_DEPLOYMENT" => "true", "BUNDLE_PATH" => "#{APP_DIR}/bundle" }.merge(extra)
      ruby = %(export PATH="$HOME/.rbenv/shims:$PATH" && cd #{APP_DIR}/server && ) +
             "#{vars.map { |key, value| "#{key}=#{Shellwords.escape(value)}" }.join(' ')} bundle exec ruby -"
      user = @env["ADMIN_SUDO_USER"].to_s
      command = user.empty? ? ruby : "sudo -n -u deploy -H sh -c #{Shellwords.escape(ruby)}"
      @run.call(["ssh", "#{user.empty? ? 'deploy' : user}@#{host}", command], stdin: program)
    end

    def host
      @host ||= @run.call(%W[gh variable get DEPLOY_HOST -R #{REPO}]).strip.tap do |found|
        raise Failed, "The DEPLOY_HOST repository variable is empty." if found.empty?
      end
    end

    def run(command, stdin: nil)
      out, err, status = Open3.capture3(*command, stdin_data: stdin.to_s)
      raise Failed, "#{command.first} failed: #{err.strip.empty? ? out.strip : err.strip}" unless status.success?

      out
    end
  end
end

exit Guestbook::Reader.new.call(ARGV) if $PROGRAM_NAME == __FILE__
