require File.expand_path('../acceptance_test_helper', __FILE__)

class Bug18914Test < Mocha::TestCase
  include AcceptanceTest

  def setup
    setup_acceptance_test
  end

  def teardown
    teardown_acceptance_test
  end

  class AlwaysEql
    def my_method
      true
    end

    def ==(_other)
      true
    end

    def eql?(_other)
      true
    end
  end

  def test_should_not_allow_stubbing_of_non_mock_instance_disrupted_by_legitimate_overriding_of_eql_method
    always_eql1 = AlwaysEql.new
    always_eql1.stubs(:my_method).returns(false)

    always_eql2 = AlwaysEql.new
    always_eql2.stubs(:my_method).returns(false)

    assert_equal false, always_eql2.my_method
  end
end
