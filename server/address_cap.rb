# frozen_string_literal: true

require "digest"
require "securerandom"

module Guestbook
  class AddressCap
    PER_DAY = 3

    def initialize(clock:, limit: PER_DAY)
      @clock = clock
      @limit = limit
      @mutex = Mutex.new
    end

    def reserve(ip)
      @mutex.synchronize do
        counts = today
        key = digest(ip)
        next false if counts.fetch(key, 0) >= @limit

        counts[key] = counts.fetch(key, 0) + 1
        true
      end
    end

    def release(ip)
      @mutex.synchronize do
        counts = today
        key = digest(ip)
        counts[key] -= 1 if counts.fetch(key, 0).positive?
      end
    end

    private

    def today
      day = @clock.call.utc.strftime("%F")
      if day != @day
        @day = day
        @salt = SecureRandom.bytes(32)
        @counts = {}
      end
      @counts
    end

    def digest(ip) = Digest::SHA256.hexdigest(@salt + ip.to_s)
  end
end
