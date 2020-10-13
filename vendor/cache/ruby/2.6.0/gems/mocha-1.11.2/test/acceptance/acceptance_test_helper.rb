require File.expand_path('../../test_helper', __FILE__)
require 'test_runner'
require 'mocha/configuration'
require 'mocha/mockery'
require 'introspection'

if Mocha::Detection::MiniTest.testcase && (ENV['MOCHA_RUN_INTEGRATION_TESTS'] != 'test-unit')
  require 'mocha/minitest'
else
  require 'mocha/test_unit'
end

module AcceptanceTest
  class FakeLogger
    attr_reader :warnings

    def initialize
      @warnings = []
    end

    def warn(message)
      @warnings << message
    end
  end

  attr_reader :logger

  include TestRunner

  def setup_acceptance_test
    Mocha::Configuration.reset_configuration
    @logger = FakeLogger.new
    mockery = Mocha::Mockery.instance
    mockery.logger = @logger
  end

  def teardown_acceptance_test
    Mocha::Configuration.reset_configuration
  end

  include Introspection::Assertions
end
