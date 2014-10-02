require 'test_helper'

class RemoteCheckoutTest < Test::Unit::TestCase
  def setup
    @gateway = ActiveMerchant::Billing::CheckoutGateway.new(fixtures(:checkout))
    @credit_card = credit_card(
      "4543474002249996",
      month: "06",
      year: "2017",
      verification_value: "956"
    )
    @declined_card  = credit_card(
      '4543474002249996',
      month: '06',
      year: '2018',
      verification_value: '958'
    )
    @options = {
      order_id: generate_unique_id
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(100, @credit_card, @options)
    assert_success response
    assert_equal 'Successful', response.message
  end

  def test_successful_purchase_with_extra_options
    response = @gateway.purchase(100, @credit_card, @options.merge(
      currency: "EUR",
      email: "bob@example.com",
      order_id: generate_unique_id,
      customer: generate_unique_id,
      ip: "127.0.0.1"
    ))
    assert_success response
    assert_equal 'Successful', response.message
  end

  def test_successful_purchase_without_billing_address
    response = @gateway.purchase(100, @credit_card, @options)
    assert_success response
    assert_equal 'Successful', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(100, @declined_card, @options)
    assert_failure response
    assert_equal 'Not Successful', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(100, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(100, auth.authorization, @options)
    assert_success capture
    assert_equal 'Successful', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(100, @declined_card, @options)
    assert_failure response
    assert_equal 'Not Successful', response.message
  end
end
