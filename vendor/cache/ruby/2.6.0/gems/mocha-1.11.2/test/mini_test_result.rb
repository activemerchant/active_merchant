require 'stringio'
require 'minitest/unit'

class MiniTestResult
  minitest_version = Gem::Version.new(::MiniTest::Unit::VERSION)
  if Gem::Requirement.new('<= 4.6.1').satisfied_by?(minitest_version)
    FAILURE_PATTERN = /(Failure)\:\n([^\(]+)\(([^\)]+)\) \[([^\]]+)\]\:\n(.*)\n/m
    ERROR_PATTERN   = /(Error)\:\n([^\(]+)\(([^\)]+)\)\:\n(.+?)\n/m
    PATTERN_INDICES = { :method => 2, :testcase => 3 }.freeze
  else
    FAILURE_PATTERN = /(Failure)\:\n.([^#]+)\#([^ ]+) \[([^\]]+)\]\:\n(.*)\n/m
    ERROR_PATTERN   = /(Error)\:\n.([^#]+)\#([^ ]+)\:\n(.+?)\n/m
    PATTERN_INDICES = { :method => 3, :testcase => 2 }.freeze
  end

  def self.parse_failure(raw)
    matches = FAILURE_PATTERN.match(raw)
    return nil unless matches
    Failure.new(matches[PATTERN_INDICES[:method]], matches[PATTERN_INDICES[:testcase]], [matches[4]], matches[5])
  end

  def self.parse_error(raw)
    matches = ERROR_PATTERN.match(raw)
    return nil unless matches
    backtrace = raw.gsub(ERROR_PATTERN, '').split("\n").map(&:strip)
    Error.new(matches[PATTERN_INDICES[:method]], matches[PATTERN_INDICES[:testcase]], matches[4], backtrace)
  end

  class Failure
    attr_reader :method, :test_case, :location, :message
    def initialize(method, test_case, location, message)
      @method = method
      @test_case = test_case
      @location = location
      @message = message
    end
  end

  class Error
    class Exception
      attr_reader :message, :backtrace
      def initialize(message, location)
        @message = message
        @backtrace = location
      end
    end

    attr_reader :method, :test_case, :exception
    def initialize(method, test_case, message, backtrace)
      @method = method
      @test_case = test_case
      @exception = Exception.new(message, backtrace)
    end
  end

  def initialize(runner, tests)
    @runner = runner
    @tests = tests
  end

  def failure_count
    @runner.failures
  end

  def assertion_count
    @tests.inject(0) { |total, test| total + test._assertions }
  end

  def error_count
    @runner.errors
  end

  def passed?
    @tests.all?(&:passed?)
  end

  def failures
    @runner.report.map { |puked| MiniTestResult.parse_failure(puked) }.compact
  end

  def errors
    @runner.report.map { |puked| MiniTestResult.parse_error(puked) }.compact
  end

  def failure_messages
    failures.map(&:message)
  end

  def failure_message_lines
    failure_messages.map { |message| message.split("\n") }.flatten
  end

  def error_messages
    errors.map { |e| e.exception.message }
  end
end
