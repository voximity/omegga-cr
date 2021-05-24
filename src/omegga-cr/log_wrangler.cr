module Omegga::Log
  GENERIC_LINE_REGEX = /^(\[(?<date>\d{4}\.\d\d.\d\d-\d\d.\d\d.\d\d:\d{3})\]\[\s*(?<counter>\d+)\])?(?<generator>\w+): (?<data>.+)$/

  class WatcherTimeoutError < Exception
    def initialize
      super("The watcher timed out.")
    end
  end

  class Matcher
    getter pattern : Regex
    getter callback : Regex::MatchData ->

    def initialize(@pattern, &block : Regex::MatchData ->)
      @callback = block
    end
  end

  class Watcher
    getter pattern : Regex
    getter timeout : Time::Span
    getter channel : Channel(Regex::MatchData)

    def initialize(@pattern, *, @timeout = 50.milliseconds)
      @channel = Channel(Regex::MatchData).new
    end

    # Wait to receive a response from the passed `Wrangler`.
    # Returns a `Regex::MatchData`.
    # Raises if the timeout is reached.
    def receive(wrangler : Wrangler) : Regex::MatchData
      # watcher is not bundled, try to receive once, otherwise raise
      if @timeout == Time::Span.zero
        # there is no timeout, wait forever
        match = channel.receive
        wrangler.wranglers.delete(self)
        return match
      end

      select
      when match = channel.receive
        wrangler.wranglers.delete(self) # delete this watcher
        return match
      when timeout @timeout
        wrangler.wranglers.delete(self) # delete this watcher
        raise WatcherTimeoutError.new
      end
    end
  end

  class WatcherBundled < Watcher
    getter debounce : Bool
    getter after_match_delay : Time::Span?
    getter last : (Regex::MatchData -> Bool)?

    def initialize(pattern, *, timeout = 50.milliseconds, @debounce = false, @after_match_delay = nil, @last = nil)
      raise ArgumentError.new("Timeout must be non-zero when watcher is on bundle mode") if @timeout == Time::Span.zero
      super(pattern, timeout: timeout)
    end

    # Wait to receive a response from the passed `Wrangler`, aggregating matches during the timeout into an array.
    # Returns an `Array(Regex::MatchData)`.
    def receive_bundled(wrangler : Wrangler) : Array(Regex::MatchData)
      # watcher is bundled, receive constantly until the timeout expires
      matches = [] of Regex::MatchData
      start_time = Time.monotonic
      second_timeout = @after_match_delay || @timeout
      while true
        select
        when match = channel.receive
          matches << match
          break if !@last.nil? && @last.call(match) # break out of the loop if @last is specified and it returns true
        when timeout(matches.size == 0 ? @timeout : (@debounce ? second_timeout : second_timeout - (Time.monotonic - start_time)))
          break # break out of the while loop
        end
      end
      return matches
    end
  end

  class Wrangler
    getter matchers = [] of Matcher
    getter watchers = [] of Watcher

    def initialize
    end

    # Adds a new `Matcher`. Alternatively, use `Wrangler#matchers << ...`.
    def add_matcher(matcher : Matcher)
      @matchers << matcher
    end

    # Adds a new `Matcher`. Alternatively, use `Wrangler#matchers << ...`.
    def add_watcher(watcher : Watcher) : -> Regex::MatchData | Array(Regex::MatchData)
      @watchers << watcher
    end

    def handle_line(line : String)
      log_match = line.match GENERIC_LINE_REGEX

      # handle matchers first
      # matchers could remove themselves from @matchers, so we iterate backwards
      (@matchers.size - 1).downto(0) do |i|
        matcher = @matchers[i]

        match = line.match matcher.pattern
        matcher.callback.call(match) unless match.nil?
      end

      # now, handle watchers
      (@watchers.size - 1).downto(0) do |i|
        watcher = @watchers[i]

        match = line.match watcher.pattern
        # unlike matchers, watchers take care of self-removal in their receive function, so we can just send the match to the channel
        watcher.channel.send(match) unless match.nil?
      end
    end
  end
end
