require 'test_helper'
require "support/mercury_helper"

class RemoteMercuryTest < Test::Unit::TestCase
  include MercuryHelper

  def setup
    @gateway = MercuryGateway.new(fixtures(:mercury))

    @amount = 100

    @credit_card = credit_card("4003000123456781", :brand => "visa", :month => "12", :year => "15")

    @options = {
      :order_id => "1",
      :description => "ActiveMerchant"
    }
    @options_with_billing = @options.merge(
      :merchant => '999',
      :billing_address => {
        :address1 => '4 Corporate Square',
        :zip => '30329'
      }
    )
    @full_options = @options_with_billing.merge(
      :ip => '123.123.123.123',
      :merchant => "Open Dining",
      :customer => "Tim",
      :tax => "5"
    )

    close_batch
  end

  def test_successful_authorize_and_capture
    response = @gateway.authorize(100, @credit_card, @options)
    assert_success response
    assert_equal '1.00', response.params['authorize']

    capture = @gateway.capture(nil, response.authorization)
    assert_success capture
    assert_equal '1.00', capture.params['authorize']
  end

  def test_failed_authorize
    response = @gateway.authorize(1100, @credit_card, @options)
    assert_failure response
    assert_equal "DECLINE", response.message
  end

  def test_reversal
    response = @gateway.authorize(100, @credit_card, @options)
    assert_success response

    void = @gateway.void(response.authorization, @options.merge(:try_reversal => true))
    assert_success void
  end

  def test_purchase_and_void
    response = @gateway.purchase(102, @credit_card, @options)
    assert_success response

    void = @gateway.void(response.authorization)
    assert_success void
  end

  def test_successful_purchase
    response = @gateway.purchase(50, @credit_card, @options)

    assert_success response
    assert_equal "0.50", response.params["purchase"]
  end

  def test_store
    response = @gateway.store(@credit_card, @options)

    assert_success response
    assert response.params.has_key?("record_no")
    assert response.params['record_no'] != ''
  end

  def test_credit
    response = @gateway.credit(50, @credit_card, @options)

    assert_success response
    assert_equal "0.50", response.params["purchase"], response.inspect
  end

  def test_failed_purchase
    response = @gateway.purchase(1100, @credit_card, @options)
    assert_failure response
    assert_equal "DECLINE", response.message
  end

  def test_avs_and_cvv_results
    response = @gateway.authorize(333, @credit_card, @options_with_billing)

    assert_success response
    assert_equal(
      {
        "code" => "Y",
        "postal_match" => "Y",
        "street_match" => "Y",
        "message" => "Street address and 5-digit postal code match."
      },
      response.avs_result
    )
    assert_equal({"code"=>"M", "message"=>"Match"}, response.cvv_result)
  end

  def test_partial_capture
    visa_partial_card = credit_card("4005550000000480")

    response = @gateway.authorize(2354, visa_partial_card, @options)

    assert_success response

    capture = @gateway.capture(2000, response.authorization)
    assert_success capture

    reverse = @gateway.refund(2000, capture.authorization)
    assert_success reverse
  end

  def test_authorize_with_bad_expiration_date
    @credit_card.month = 13
    @credit_card.year = 2001
    response = @gateway.authorize(575, @credit_card, @options_with_billing)
    assert_failure response
    assert_equal "INVLD EXP DATE", response.message
  end

  def test_mastercard_authorize_and_capture_with_refund
    mc = credit_card("5499990123456781", :brand => "master")

    response = @gateway.authorize(200, mc, @options)
    assert_success response
    assert_equal '2.00', response.params['authorize']

    capture = @gateway.capture(200, response.authorization)
    assert_success capture
    assert_equal '2.00', capture.params['authorize']

    refund = @gateway.refund(200, capture.authorization)
    assert_success refund
    assert_equal '2.00', refund.params['purchase']
    assert_equal 'Return', refund.params['tran_code']
  end

  def test_amex_authorize_and_capture_with_refund
    amex = credit_card("373953244361001", :brand => "american_express", :verification_value => "1234")

    response = @gateway.authorize(201, amex, @options)
    assert_success response
    assert_equal '2.01', response.params['authorize']

    capture = @gateway.capture(201, response.authorization)
    assert_success capture
    assert_equal '2.01', capture.params['authorize']

    response = @gateway.refund(201, capture.authorization, @options)
    assert_success response
    assert_equal '2.01', response.params['purchase']
  end

  def test_discover_authorize_and_capture
    discover = credit_card("6011000997235373", :brand => "discover")

    response = @gateway.authorize(225, discover, @options_with_billing)
    assert_success response
    assert_equal '2.25', response.params['authorize']

    capture = @gateway.capture(225, response.authorization)
    assert_success capture
    assert_equal '2.25', capture.params['authorize']
  end

  def test_refund_after_batch_close
    purchase = @gateway.purchase(50, @credit_card, @options)
    assert_success purchase

    close_batch

    refund = @gateway.refund(50, purchase.authorization)
    assert_success refund
  end

  def test_authorize_and_capture_without_tokenization
    gateway = MercuryGateway.new(fixtures(:mercury_no_tokenization))
    close_batch(gateway)

    response = gateway.authorize(100, @credit_card, @options)
    assert_success response
    assert_equal '1.00', response.params['authorize']

    capture = gateway.capture(nil, response.authorization, :credit_card => @credit_card)
    assert_success capture
    assert_equal '1.00', capture.params['authorize']
  end
end
