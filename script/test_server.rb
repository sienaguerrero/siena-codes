#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "rack/lint"
require "rack/mock_request"
require "sqlite3"
require "stringio"
require "tmpdir"
require_relative "../server/app"
require_relative "guestbook"

Encoding.default_external = Encoding::UTF_8

SITE = "https://site.test"
JSON_HEADERS = { "CONTENT_TYPE" => "application/json", "HTTP_ORIGIN" => SITE }.freeze

failures = []
check = ->(ok, message) { failures << message unless ok }

now = Time.utc(2026, 11, 23, 12)
clock = -> { now }
server = lambda do |path: ":memory:", per_day: 200, max_rows: 5000, per_address: 3|
  Guestbook::Server.new(site_url: SITE, clock: clock,
                        entries: Guestbook::Entries.new(path: path, clock: clock, per_day: per_day, max_rows: max_rows),
                        addresses: Guestbook::AddressCap.new(clock: clock, limit: per_address))
end
call = lambda do |app, method, path, body = nil, headers = {}|
  opts = { method: method, input: body.is_a?(String) || body.nil? ? body.to_s : JSON.generate(body), "REMOTE_ADDR" => "203.0.113.9" }
  status, response_headers, response_body = Rack::Lint.new(app).call(Rack::MockRequest.env_for(path, opts.merge(headers)))
  text = +""
  response_body.each { |part| text << part }
  response_body.close if response_body.respond_to?(:close)
  [status, response_headers, text]
end
rows = ->(path) { SQLite3::Database.new(path).execute("SELECT name, from_place, text, created_at FROM entries ORDER BY id") }
good = { "name" => "Kyle", "from" => "Beverly Hills", "text" => "Hi from the hills" }

Dir.mktmpdir do |dir|
  db = File.join(dir, "guestbook.sqlite3")
  app = server.call(path: db)

  status, headers, = call.call(app, "POST", "/entries", good, JSON_HEADERS)
  check.call(status == 204, "a good entry answered #{status}, expected 204")
  check.call(headers["access-control-allow-origin"] == SITE, "POST /entries allows origin #{headers['access-control-allow-origin'].inspect}")
  check.call(headers["cache-control"] == "no-store", "POST /entries can be cached")
  check.call(rows.call(db) == [["Kyle", "Beverly Hills", "Hi from the hills", now.to_i]], "the entry was stored as #{rows.call(db).inspect}")

  call.call(app, "POST", "/entries", { "name" => "No place", "text" => "from is optional" }, JSON_HEADERS)
  check.call(rows.call(db).last&.first(3) == ["No place", "", "from is optional"], "an entry without a from was not stored")

  hostile = "Robert'); DROP TABLE entries;--"
  call.call(app, "POST", "/entries", { "name" => hostile, "text" => "\e[31mred\u0000text\r\nline two" }, JSON_HEADERS)
  check.call(rows.call(db).last&.first(3) == [hostile, "", "[31mred text line two"],
             "SQL in a name or control characters in a message were stored as #{rows.call(db).last.inspect}")
  check.call(rows.call(db).length == 3, "the entries table has #{rows.call(db).length} rows after a hostile name, expected 3")
end

app = server.call(per_address: 100)
entries_before = lambda do |probe|
  store = Guestbook::Entries.new(path: ":memory:", clock: clock)
  probe_app = Guestbook::Server.new(site_url: SITE, clock: clock, entries: store, addresses: Guestbook::AddressCap.new(clock: clock, limit: 100))
  status, _, body = probe.call(probe_app)
  [status, body, store.size]
end

{
  "an empty name" => good.merge("name" => "   "),
  "an empty message" => good.merge("text" => ""),
  "a missing message" => { "name" => "Kyle" },
  "a 41 character name" => good.merge("name" => "k" * 41),
  "a 41 character from" => good.merge("from" => "k" * 41),
  "a 281 character message" => good.merge("text" => "k" * 281),
  "a number for a name" => good.merge("name" => 7),
  "a list for a message" => good.merge("text" => ["hi"]),
  "a JSON list" => [good],
  "a JSON string" => "hello"
}.each do |label, body|
  status, _, size = entries_before.call(->(a) { call.call(a, "POST", "/entries", JSON.generate(body), JSON_HEADERS) })
  check.call(status == 400 && size.zero?, "#{label} answered #{status} and stored #{size}, expected 400 and nothing stored")
end

status, _, size = entries_before.call(->(a) { call.call(a, "POST", "/entries", good.merge("name" => "k" * 40, "text" => "é" * 280), JSON_HEADERS) })
check.call(status == 204 && size == 1, "an entry at the length limits answered #{status}")

status, _, size = entries_before.call(->(a) { call.call(a, "POST", "/entries", "{not json", JSON_HEADERS) })
check.call(status == 400 && size.zero?, "a broken body answered #{status}, expected 400")

status, _, size = entries_before.call(->(a) { call.call(a, "POST", "/entries", "{\"name\":\"\xFF\",\"text\":\"x\"}".b, JSON_HEADERS) })
check.call(status == 400 && size.zero?, "a body that isn't UTF-8 answered #{status}, expected 400")

status, _, size = entries_before.call(->(a) { call.call(a, "POST", "/entries", JSON.generate(good.merge("pad" => "x" * 2048)), JSON_HEADERS) })
check.call(status == 413 && size.zero?, "a body over the cap answered #{status}, expected 413")

status, _, size = entries_before.call(->(a) { call.call(a, "POST", "/entries", good, JSON_HEADERS.merge("CONTENT_TYPE" => "text/plain")) })
check.call(status == 415 && size.zero?, "a text/plain entry answered #{status}, expected 415")

[nil, "https://evil.test", "#{SITE}.evil.test", "null"].each do |origin|
  headers = { "CONTENT_TYPE" => "application/json" }
  headers["HTTP_ORIGIN"] = origin if origin
  status, _, size = entries_before.call(->(a) { call.call(a, "POST", "/entries", good, headers) })
  check.call(status == 403 && size.zero?, "an entry from origin #{origin.inspect} answered #{status}, expected 403")
end

status, _, size = entries_before.call(->(a) { call.call(a, "POST", "/entries", good.merge("website" => "https://spam.test"), JSON_HEADERS) })
check.call(status == 204 && size.zero?, "a filled honeypot answered #{status} and stored #{size}, expected 204 and nothing stored")

status, headers, body = call.call(app, "OPTIONS", "/entries", nil, "HTTP_ORIGIN" => SITE, "HTTP_ACCESS_CONTROL_REQUEST_METHOD" => "POST")
check.call(status == 204 && body.empty?, "the preflight answered #{status}")
check.call(headers["access-control-allow-origin"] == SITE && headers["access-control-allow-methods"] == "POST" &&
           headers["access-control-allow-headers"] == "content-type", "the preflight headers are #{headers.inspect}")

%w[GET PUT DELETE PATCH].each do |method|
  status, headers, body = call.call(app, method, "/entries", nil, "HTTP_ORIGIN" => SITE)
  check.call(status == 405 && headers["allow"] == "POST, OPTIONS", "#{method} /entries answered #{status}, expected 405")
  check.call(!body.include?("Kyle"), "#{method} /entries served an entry")
end

status, _, body = call.call(app, "GET", "/")
check.call(status == 200 && body.include?("guestbook"), "GET / answered #{status}")
["/entries/", "/entries/1", "/entries.json", "/admin"].each do |path|
  status, = call.call(app, "GET", path)
  check.call(status == 404, "GET #{path} answered #{status}, expected 404")
end

capped = server.call(per_address: 2)
from = ->(ip, forwarded = nil) { JSON_HEADERS.merge("REMOTE_ADDR" => ip, **(forwarded ? { "HTTP_X_FORWARDED_FOR" => forwarded } : {})) }
statuses = Array.new(3) { call.call(capped, "POST", "/entries", good, from.call("203.0.113.1")).first }
check.call(statuses == [204, 204, 429], "three entries from one address answered #{statuses.join(', ')}, expected 204, 204, 429")
status, = call.call(capped, "POST", "/entries", good, from.call("203.0.113.2"))
check.call(status == 204, "a second address was capped by the first, answered #{status}")
statuses = Array.new(3) { call.call(capped, "POST", "/entries", good, from.call("127.0.0.1", "198.51.100.1, 198.51.100.7")).first }
check.call(statuses == [204, 204, 429], "three entries through the proxy from one address answered #{statuses.join(', ')}")
status, = call.call(capped, "POST", "/entries", good, from.call("127.0.0.1", "198.51.100.1, 198.51.100.8"))
check.call(status == 204, "a second address behind the proxy was capped, answered #{status}")
status, = call.call(capped, "POST", "/entries", good, from.call("203.0.113.3", "198.51.100.7"))
check.call(status == 204, "a forwarded header from a direct caller picked the address, answered #{status}")
3.times { call.call(capped, "POST", "/entries", good.merge("text" => ""), from.call("203.0.113.4")) }
status, = call.call(capped, "POST", "/entries", good, from.call("203.0.113.4"))
check.call(status == 204, "refused entries used up an address's day, answered #{status}")

now = Time.utc(2026, 11, 24, 0, 0, 1)
status, = call.call(capped, "POST", "/entries", good, from.call("203.0.113.1"))
check.call(status == 204, "an address was still capped the next day, answered #{status}")
now = Time.utc(2026, 11, 23, 12)

daily = server.call(per_day: 2, per_address: 1)
statuses = (1..3).map { |n| call.call(daily, "POST", "/entries", good, from.call("203.0.113.#{n}")).first }
check.call(statuses == [204, 204, 429], "a third entry in a day of 2 answered #{statuses.join(', ')}")
status, _, body = call.call(daily, "POST", "/entries", good, from.call("203.0.113.3"))
check.call(status == 429 && body.include?("full for today"), "the address that met a full day was charged for it: #{status} #{body}")
now += 24 * 60 * 60
status, = call.call(daily, "POST", "/entries", good, from.call("203.0.113.9"))
check.call(status == 204, "the day's cap did not lift after 24 hours, answered #{status}")
now = Time.utc(2026, 11, 23, 12)

Dir.mktmpdir do |dir|
  db = File.join(dir, "guestbook.sqlite3")
  first = server.call(path: db, per_day: 1)
  call.call(first, "POST", "/entries", good, JSON_HEADERS)
  status, = call.call(server.call(path: db, per_day: 1), "POST", "/entries", good, JSON_HEADERS)
  check.call(status == 429, "a restart reset the day's cap, answered #{status}")
end

full = server.call(max_rows: 1, per_address: 5)
call.call(full, "POST", "/entries", good, JSON_HEADERS)
now += 3 * 24 * 60 * 60
status, = call.call(full, "POST", "/entries", good, JSON_HEADERS)
check.call(status == 429, "an entry past the row cap answered #{status}, expected 429")
now = Time.utc(2026, 11, 23, 12)

check.call(Guestbook::Server.db_path({ "GUESTBOOK_DB" => "/x/y.sqlite3" }) == "/x/y.sqlite3", "GUESTBOOK_DB does not set the database path")
check.call(Guestbook::Server.db_path({ "STATE_DIRECTORY" => "/var/lib/guestbook" }) == "/var/lib/guestbook/guestbook.sqlite3", "StateDirectory does not set the database path")
check.call(Guestbook::Server.db_path({}) == ":memory:", "a dev server does not keep entries in memory")
lost = begin
  Guestbook::Server.db_path({ "RACK_ENV" => "production" })
  false
rescue RuntimeError
  true
end
check.call(lost, "a production server with nowhere to keep entries started anyway")

Dir.mktmpdir do |dir|
  db = File.join(dir, "guestbook.sqlite3")
  app = server.call(path: db, per_address: 5)
  call.call(app, "POST", "/entries", good, JSON_HEADERS)
  call.call(app, "POST", "/entries", { "name" => "Kim", "text" => "second" }, JSON_HEADERS)

  sent = []
  on_this_machine = lambda do |command, stdin: nil|
    sent << command
    next "203.0.113.50\n" if command.first == "gh"

    script = command.last.start_with?("sudo") ? Shellwords.split(command.last).last : command.last
    vars = script.scan(/\b(GUESTBOOK_DB|IDS)=(\S+)/).to_h.merge("GUESTBOOK_DB" => db)
    out, status = Open3.capture2(vars, "ruby", "-", stdin_data: stdin)
    raise Guestbook::Reader::Failed, "ruby failed" unless status.success?

    out
  end
  read = lambda do |args, env = { "ADMIN_SUDO_USER" => "siena" }|
    out = StringIO.new
    [Guestbook::Reader.new(run: on_this_machine, out: out, env: env).call(args), out.string]
  end

  status, printed = read.call(%w[list])
  check.call(status.zero? && printed == "#1  2026-11-23  Kyle from Beverly Hills\n    Hi from the hills\n\n#2  2026-11-23  Kim\n    second\n\n",
             "list printed #{printed.inspect}")
  login, command = sent.last.last(2)
  check.call(login == "siena@203.0.113.50" && command.start_with?("sudo -n -u deploy -H sh -c "), "list logged in as #{login} and ran #{command}")

  read.call(%w[list], {})
  login, command = sent.last.last(2)
  check.call(login == "deploy@203.0.113.50" && !command.include?("sudo"), "list without a sudo login ran #{login} #{command}")

  status, printed = read.call(%w[delete 1 7])
  check.call(status.zero? && printed == "Deleted 1 of 2. 1 left.\n" && rows.call(db).map(&:first) == ["Kim"], "delete printed #{printed.inspect}")

  [%w[delete], %w[delete 1;rm], ["delete", "1 OR 1=1"], %w[delete 0], %w[drop], []].each do |args|
    before = sent.length
    status, printed = read.call(args)
    check.call(status == 1 && printed.start_with?("Usage:") && sent.length == before, "#{args.inspect} did not stop at the usage text")
  end
end

if failures.empty?
  puts "ok"
else
  puts failures
  exit 1
end
