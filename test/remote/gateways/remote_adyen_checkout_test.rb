require 'test_helper'
require 'pry'

class RemoteAdyenTest < Test::Unit::TestCase
  def setup
    @gateway = AdyenCheckoutGateway.new(fixtures(:adyen_checkout))

    @options = {
      reference: '345123',
      email: 'john.smith@test.com',
      ip: '77.110.174.153',
      shopper_reference: 'John Smith',
      billing_address: address(country: 'US', state: 'CA'),
      order_id: '123',
      stored_credential: { reason_type: 'unscheduled' },
      return_url: 'https://example.com/',
      currency: 'EUR'
    }

    @credit_card = credit_card('4111111145551142',
      month: 3,
      year: 2030,
      first_name: 'John',
      last_name: 'Smith',
      verification_value: '737',
      brand: 'visa')

    @ideal_payment_method = {
      issuer: '1161',
      type: 'ideal'
    }

    @klarna_payment_method = {
      type: 'klarna'
    }

    @sofort_payment_method = {
      type: 'directEbanking'
    }

    @sepa_payment_method = {
      "type": 'sepadirectdebit',
      "sepa.ownerName": 'Test name',
      "sepa.ibanNumber": 'DE87123456781234567890'
    }

    @polish_payment_method = {
      type: 'onlineBanking_PL',
      issuer: '181'
    }

    @trustly_payment_method = {
      type: 'trustly'
    }

    @amount = 100
  end

  def test_successful_authorize_with_ideal
    response = @gateway.authorize(@amount, @ideal_payment_method, @options)
    assert_success response
    assert_equal 'RedirectShopper', response.message
    assert_equal 'ideal', response.params.dig('action', 'paymentMethodType')
  end

  def test_successful_authorize_with_sofort
    response = @gateway.authorize(@amount, @sofort_payment_method, @options)
    assert_success response
    assert_equal 'RedirectShopper', response.message
    assert_equal 'directEbanking', response.params.dig('action', 'paymentMethodType')
  end

  def test_successful_authorize_with_sepa
    response = @gateway.authorize(@amount, @sepa_payment_method, @options)
    assert_success response
    assert_equal 'Received', response.message
  end

  def test_successful_authorize_with_trustly
    response = @gateway.authorize(@amount, @trustly_payment_method, @options.merge(currency: 'SEK'))
    assert_success response
    assert_equal 'RedirectShopper', response.message
    assert_equal 'trustly', response.params.dig('action', 'paymentMethodType')
  end

  def test_successful_authorize_with_polish_banking
    response = @gateway.authorize(1000, @polish_payment_method, @options.merge(currency: 'PLN'))
    assert_success response
    assert_equal 'RedirectShopper', response.message
    assert_equal 'onlineBanking_PL', response.params.dig('action', 'paymentMethodType')
  end

  # Does not work with "Invalid open invoice request."
  # def test_successful_authorize_with_klarna
  #   @options.merge!({
  #     "line_items": [
  #       {
  #         "quantity":"1",
  #         "taxPercentage":"2100",
  #         "description":"Shoes",
  #         "id":"Item #1",
  #         "amountIncludingTax":"400",
  #         "productUrl": "URL_TO_PURCHASED_ITEM",
  #         "imageUrl": "URL_TO_PICTURE_OF_PURCHASED_ITEM"
  #      },
  #      {
  #         "quantity":"2",
  #         "taxPercentage":"2100",
  #         "description":"Socks",
  #         "id":"Item #2",
  #         "amountIncludingTax":"300",
  #         "productUrl": "URL_TO_PURCHASED_ITEM",
  #         "imageUrl": "URL_TO_PICTURE_OF_PURCHASED_ITEM"
  #      }
  #     ]
  #   })
  #   response = @gateway.authorize(@amount, @klarna_payment_method, @options)
  #   assert_success response
  #   assert_equal 'RedirectShopper', response.message
  #   assert_equal 'klarna', response.params.dig('action', 'paymentMethodType')
  # end
end
