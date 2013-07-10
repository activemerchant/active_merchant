require 'test_helper'

class BluePayTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = BluePayGateway.new(fixtures(:blue_pay))
    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @options = {
      :order_id => generate_unique_id,
      :billing_address => address,
      :description => 'Store purchase'
    }

    @recurring_options = {
      :rebill_amount => 100,
      :rebill_start_date => Date.today,
      :rebill_expression => '1 DAY',
      :rebill_cycles => '4',
      :billing_address => address.merge(:first_name => 'Jim', :last_name => 'Smith'),
      :duplicate_override => 1
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_successful_purchase_with_check
    assert response = @gateway.purchase(@amount, check, @options)
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_expired_credit_card
    @credit_card.year = 2004
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_equal 'The credit card has expired', response.message
  end

  def test_forced_test_mode_purchase
    gateway = BluePayGateway.new(fixtures(:blue_pay).update(:test => true))
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal(true, response.test)
    assert response.authorization
  end

  def test_successful_authorization
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_authorization_and_capture
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization

    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
    assert_equal 'This transaction has been approved', capture.message
  end

  def test_authorization_and_void
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization

    assert void = @gateway.void(authorization.authorization)
    assert_success void
    assert_equal 'This transaction has been approved', void.message
  end

  def test_bad_login
    gateway = BluePayGateway.new(
      :login => 'X',
      :password => 'Y'
    )

    assert response = gateway.purchase(@amount, @credit_card)

    assert_equal Response, response.class
    assert_equal ["avs_result_code",
                  "card_code",
                  "response_code",
                  "response_reason_code",
                  "response_reason_text",
                  "transaction_id"], response.params.keys.sort
    assert_match(/The merchant login ID or password is invalid/, response.message)
    assert_failure response
  end

  def test_using_test_request
    gateway = BluePayGateway.new(
      :login => 'X',
      :password => 'Y'
    )

    assert response = gateway.purchase(@amount, @credit_card)

    assert_equal Response, response.class
    assert_equal ["avs_result_code",
                  "card_code",
                  "response_code",
                  "response_reason_code",
                  "response_reason_text",
                  "transaction_id"], response.params.keys.sort
    assert_match(/The merchant login ID or password is invalid/, response.message)
    assert_failure response
  end

  def test_successful_recurring
    assert response = @gateway.recurring(@amount, @credit_card, @recurring_options)
    assert_success response
    assert response.test?

    rebill_id = response.params['REBID']

    assert response = @gateway.update_recurring(:rebill_id => rebill_id, :rebill_amount => @amount * 2)
    assert_success response

    assert response = @gateway.status_recurring(rebill_id)
    assert_success response

    assert response = @gateway.cancel_recurring(rebill_id)
    assert_success response
  end

  def test_recurring_should_fail_expired_credit_card
    @credit_card.year = 2004
    assert response = @gateway.recurring(@amount, @credit_card, @recurring_options)
    assert_failure response
    assert response.test?
    assert_equal 'The credit card has expired', response.message
  end

  def test_successful_purchase_with_solution_id
    ActiveMerchant::Billing::BluePayGateway.application_id = 'A1000000'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  ensure
    ActiveMerchant::Billing::BluePayGateway.application_id = nil
  end
end
