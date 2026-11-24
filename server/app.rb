# frozen_string_literal: true

require "json"
require "roda"
require_relative "address_cap"
require_relative "entries"

module Guestbook
  class Server
    SITE_URL = "https://siena.codes"
    MAX_BYTES = 2048
    JSON_TYPE = %r{\Aapplication/json\b}i
    LOOPBACK = %w[127.0.0.1 ::1].freeze
    ABOUT = "The siena.codes guestbook. It takes entries and never shows them.\n"

    class App < Roda
      plugin :default_headers, "cache-control" => "no-store"
      plugin :head
      plugin :halt
      plugin :all_verbs
      plugin :json

      route do |r|
        deps = opts[:deps]

        r.root do
          r.get { text(200, ABOUT) }
          not_allowed("GET, HEAD")
        end

        r.is("entries") do
          cors
          r.post { sign(deps) }
          not_allowed("POST, OPTIONS")
        end
      end

      private

      def sign(deps)
        refuse(403, "Entries come from the guestbook page.") unless env["HTTP_ORIGIN"] == deps[:site_url]
        refuse(415, "Send JSON.") unless request.content_type.to_s.match?(JSON_TYPE)
        fields = parsed_body
        no_content if fields.is_a?(Hash) && !fields.fetch("website", "").to_s.empty?
        entry = Entries.clean(fields)
        refuse(400, "An entry is a name up to 40 characters and a message up to 280.") unless entry
        save(deps, entry)
        no_content
      end

      def save(deps, entry)
        ip = client_ip
        refuse(429, "Too many entries from here today. Try again tomorrow.") unless deps[:addresses].reserve(ip)
        saved = begin
          deps[:entries].add(entry)
        rescue StandardError
          deps[:addresses].release(ip)
          raise
        end
        return if saved

        deps[:addresses].release(ip)
        refuse(429, "The guestbook is full for today. Try again tomorrow.")
      end

      def parsed_body
        body = env["rack.input"]&.read(MAX_BYTES + 1).to_s
        refuse(413, "That request is too big.") if body.bytesize > MAX_BYTES
        body.force_encoding(Encoding::UTF_8)
        refuse(400, "That body isn't JSON.") unless body.valid_encoding?
        JSON.parse(body)
      rescue JSON::ParserError
        refuse(400, "That body isn't JSON.")
      end

      def client_ip
        remote = env["REMOTE_ADDR"].to_s
        forwarded = env["HTTP_X_FORWARDED_FOR"].to_s.split(",").last.to_s.strip
        LOOPBACK.include?(remote) && !forwarded.empty? ? forwarded : remote
      end

      def cors
        response["access-control-allow-origin"] = opts[:deps][:site_url]
        response["vary"] = "origin"
        return unless request.options?

        response["access-control-allow-methods"] = "POST"
        response["access-control-allow-headers"] = "content-type"
        response["access-control-max-age"] = "600"
        no_content
      end

      def refuse(status, message)
        request.halt(status, { "error" => message })
      end

      def no_content
        response.status = 204
        request.halt
      end

      def not_allowed(methods)
        response["allow"] = methods
        text(405, "Method not allowed")
      end

      def text(status, message)
        response.status = status
        response["content-type"] = "text/plain; charset=utf-8"
        message
      end
    end

    def self.db_path(env = ENV)
      return env["GUESTBOOK_DB"] unless env["GUESTBOOK_DB"].to_s.empty?
      return File.join(env["STATE_DIRECTORY"].split(":").first, "guestbook.sqlite3") unless env["STATE_DIRECTORY"].to_s.empty?
      raise "Set GUESTBOOK_DB or StateDirectory=, or every entry is lost on restart" if env["RACK_ENV"] == "production"

      ":memory:"
    end

    def initialize(site_url: ENV.fetch("SITE_URL", SITE_URL), clock: -> { Time.now.utc },
                   entries: Entries.new(path: Server.db_path, clock: clock),
                   addresses: AddressCap.new(clock: clock))
      deps = { site_url: site_url.chomp("/"), entries: entries, addresses: addresses }.freeze
      @app = Class.new(App) { opts[:deps] = deps }.freeze.app
    end

    def call(env)
      @app.call(env)
    end
  end
end
