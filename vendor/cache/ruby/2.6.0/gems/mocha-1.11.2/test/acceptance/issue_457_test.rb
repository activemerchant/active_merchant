require File.expand_path('../acceptance_test_helper', __FILE__)

class Issue457Test < Mocha::TestCase
  include AcceptanceTest

  def setup
    setup_acceptance_test
  end

  def teardown
    teardown_acceptance_test
  end

  def test_only_inspect_objects_when_necessary
    test_result = run_as_test do
      klass = Class.new do
        def message
          raise 'Not inspectable in this state!'
        end

        def inspect
          message
        end
      end
      instance = klass.new
      instance.stubs(:message).returns('message')
      assert_equal 'message', instance.inspect
    end
    assert_passed(test_result)
  end
end
