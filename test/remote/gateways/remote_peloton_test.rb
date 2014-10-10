require 'test_helper'

class RemotePelotonTest < Test::Unit::TestCase
  def setup
    @gateway = PelotonGateway.new(fixtures(:peloton))

    Base.gateway_mode = :test

    @amount = 100
    @credit_card = credit_card('4030000010001234')
    @declined_card = credit_card('4003050500040005')

    @options = {
        :canadian_address_verification => false,
        :type => 'P',
        :order_number => rand(2000..3000),
        :language_code => 'EN',

        :billing_name => "John",
        :billing_address1 => "772 1 Ave",
        :billing_address2 => "",
        :billing_city => "Calgary",
        :billing_province_state => "AB",
        :billing_country => "CA",
        :billing_postal_zip_code => "T2N 0A3",
        :billing_email_address => "john@example.com",
        :billing_phone_number => "5872284918",

        :shipping_name => "John",
        :shipping_address1 => "772 1 Ave",
        :shipping_address2 => "",
        :shipping_city => "Calgary",
        :shipping_province_state => "AB",
        :shipping_country => "Canada",
        :shipping_postal_zip_code => "T2N 0A3",
        :shipping_email_address => "john@example.com",
        :shipping_phone_number => "5872284918",
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'The transaction was declined by your financial institution. Please contact your financial institution for further information.', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    @options[:transaction_ref_code] = auth.authorization
    assert capture = @gateway.capture(@amount, @options)
    assert_success capture
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    @options[:transaction_ref_code] = auth.authorization
    assert capture = @gateway.capture(@amount-1, @options)
    assert_success capture
  end

  def test_failed_capture
    @options[:transaction_ref_code] = 'wrong code'
    response = @gateway.capture(@amount, @options)
    assert_failure response
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    @options[:transaction_ref_code] = purchase.authorization
    assert refund = @gateway.refund(@amount, @options)
    assert_success refund
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    @options[:transaction_ref_code] = purchase.authorization
    assert refund = @gateway.refund(@amount-1, @options)
    assert_success refund
  end

  def test_failed_refund
    @options[:transaction_ref_code] = 'wrong code'
    response = @gateway.refund(@amount, @options)
    assert_failure response
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    @options[:transaction_ref_code] = auth.authorization
    assert void = @gateway.void(@options)
    assert_success void
  end

  def test_failed_void
    @options[:transaction_ref_code] = 'wrong code'
    response = @gateway.void(@options)
    assert_failure response
  end

  def test_invalid_login
    gateway = PelotonGateway.new(
      client_id: '222',
      password: 'empty'
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end
end
