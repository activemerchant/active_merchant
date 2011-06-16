require 'test_helper'

class QbmsTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway_options = fixtures(:qbms)

    @gateway = QbmsGateway.new(@gateway_options)
    @amount  = 100
    @card    = credit_card('4111111111111111')

    @options = {
      :billing_address => address,
    }
  end

  def test_successful_authorization
    assert response = @gateway.authorize(@amount, @card, @options)
    assert_instance_of Response, response
    assert_success response
    assert response.authorization
  end

  def test_successful_capture
    assert response = @gateway.authorize(@amount, @card, @options)
    assert_instance_of Response, response
    assert_success response
    assert response.authorization

    assert response = @gateway.capture(@amount, response.authorization, @options)
    assert_instance_of Response, response
    assert_success response
    assert response.authorization
  end

  def test_successful_void
    assert response = @gateway.authorize(@amount, @card, @options)
    assert_instance_of Response, response
    assert_success response
    assert response.authorization

    assert response = @gateway.void(response.authorization, @options)
    assert_instance_of Response, response
    assert_success response
    assert response.authorization
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @card, @options)
    assert_instance_of Response, response
    assert_success response
    assert response.authorization
  end

  def test_successful_credit
    assert response = @gateway.purchase(@amount, @card, @options)
    assert_instance_of Response, response
    assert_success response
    assert response.authorization

    assert response = @gateway.credit(@amount, response.authorization, @options)
    assert_instance_of Response, response
    assert_success response
    assert response.authorization
  end

  def test_invalid_ticket
    gateway = QbmsGateway.new(@gateway_options.merge(:ticket => "test123"))

    assert response = gateway.authorize(@amount, @card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert_equal "Application agent not found test123", response.message
  end

  def test_invalid_card_number
    assert response = @gateway.authorize(@amount, error_card('10301_ccinvalid'), @options)
    assert_instance_of Response, response
    assert_failure response
    assert_equal "This credit card number is invalid.", response.message
  end

  def test_decline
    assert response = @gateway.authorize(@amount, error_card('10401_decline'), @options)
    assert_instance_of Response, response
    assert_failure response
    assert_equal "The request to process this transaction has been declined.", response.message
  end

  private

  def error_card(config_id)
    credit_card('4111111111111111', :first_name => "configid=#{config_id}", :last_name => "")
  end
end
