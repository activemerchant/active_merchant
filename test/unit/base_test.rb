require 'test_helper'

class BaseTest < Test::Unit::TestCase
  def setup
    ActiveMerchant::Billing::Base.mode = :test
  end

  def teardown
    ActiveMerchant::Billing::Base.mode = :test
  end

  def test_should_return_a_new_gateway_specified_by_symbol_name
    assert_equal BogusGateway,         Base.gateway(:bogus)
    assert_equal MonerisGateway,       Base.gateway(:moneris)
    assert_equal MonerisUsGateway,     Base.gateway(:moneris_us)
    assert_equal AuthorizeNetGateway,  Base.gateway(:authorize_net)
    assert_equal UsaEpayGateway,       Base.gateway(:usa_epay)
    assert_equal LinkpointGateway,     Base.gateway(:linkpoint)
  end

  def test_should_raise_when_nil_gateway_is_passed
    e = assert_raise ArgumentError do
      Base.gateway(nil)
    end
    assert_equal 'A gateway provider must be specified', e.message
  end

  def test_should_raise_when_empty_gateway_is_passed
    e = assert_raise ArgumentError do
      Base.gateway('')
    end
    assert_equal 'A gateway provider must be specified', e.message
  end

  def test_should_raise_when_invalid_gateway_symbol_is_passed
    e = assert_raise ArgumentError do
      Base.gateway(:hotdog)
    end
    assert_equal 'The specified gateway is not valid (hotdog)', e.message
  end

  def test_should_raise_when_invalid_gateway_string_is_passed
    e = assert_raise ArgumentError do
      Base.gateway('hotdog')
    end
    assert_equal 'The specified gateway is not valid (hotdog)', e.message
  end

  def test_should_set_modes
    Base.mode = :test
    assert_equal :test, Base.mode

    Base.mode = :production
    assert_equal :production, Base.mode

    assert_deprecation_warning(Base::GATEWAY_MODE_DEPRECATION_MESSAGE) { Base.gateway_mode = :development }
    assert_deprecation_warning(Base::GATEWAY_MODE_DEPRECATION_MESSAGE) { assert_equal :development, Base.gateway_mode }
    assert_equal :development, Base.mode
  end

  def test_should_identify_if_test_mode
    Base.mode = :test
    assert Base.test?

    Base.mode = :production
    assert_false Base.test?
  end
end
