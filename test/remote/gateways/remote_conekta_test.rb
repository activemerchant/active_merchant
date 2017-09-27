require 'test_helper'

class RemoteConektaTest < Test::Unit::TestCase
  def setup
    @gateway = ConektaGateway.new(fixtures(:conekta))

    @amount = 300

    @credit_card = ActiveMerchant::Billing::CreditCard.new(
      number:             "4242424242424242",
      verification_value: "183",
      month:              "01",
      year:               "2018",
      first_name:         "Mario F.",
      last_name:          "Moreno Reyes"
    )

    @declined_card = ActiveMerchant::Billing::CreditCard.new(
      number:             "4000000000000002",
      verification_value: "183",
      month:              "01",
      year:               "2018",
      first_name:         "Mario F.",
      last_name:          "Moreno Reyes"
    )

    @options = {
      :device_fingerprint => "41l9l92hjco6cuekf0c7dq68v4",
      description: 'Blue clip',
      billing_address: {
        address1: "Rio Missisipi #123",
        address2: "Paris",
        city: "Guerrero",
        country: "Mexico",
        zip: "5555",
        name: "Mario Reyes",
        phone: "12345678",
      },
      carrier: "Estafeta",
      email: "bob@something.com",
      line_items: [{
      name: "Box of Cohiba S1s",
      description: "Imported From Mex.",
      unit_price: 20000,
      quantity: 1,
      sku: "7500244909",
      type: "food"
     }]
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal nil, response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    @options[:order_id] = response.params["id"]
    assert_success response
    assert_equal nil, response.message

    assert response = @gateway.refund(@amount, response.authorization, @options)
    assert_success response
    assert_equal nil, response.message
  end

  def test_successful_void
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal nil, response.message

    identifier = response.params["id"]

    assert response = @gateway.void(identifier)
    assert_success response
    assert_equal nil, response.message
  end

  def test_unsuccessful_void
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal nil, response.message

    identifier = response.params["id"]

    assert response = @gateway.void(identifier)
    assert_failure response
    assert_equal "El cargo no existe o no es apto para esta operación.", response.message
  end

  def test_unsuccessful_refund
    assert response = @gateway.refund(@amount, "1", @options)
    assert_failure response
    assert_equal "El recurso no ha sido encontrado.", response.message
  end

  def test_successful_authorize
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal nil, response.message
  end

  def test_unsuccessful_authorize
    assert response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_successful_capture
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal nil, response.message

    assert response = @gateway.capture(@amount, response.authorization, @options)
    assert_success response
    assert_equal nil, response.message
  end

  def test_unsuccessful_capture
    assert response = @gateway.capture(@amount, "1", @options)
    assert_failure response
    assert_equal "El recurso no ha sido encontrado.", response.message
  end

  def test_successful_purchase_passing_more_details
    more_options = {
      customer: "TheCustomerName",
      shipping_address: {
        address1: "33 Main Street",
        address2: "Apartment 3",
        city: "Wanaque",
        state: "NJ",
        country: "USA",
        zip: "01085",
      },
      line_items: [
        {
          name: "Box of Cohiba S1s",
          description: "Imported From Mex.",
          unit_price: 20000,
          quantity: 1,
          sku: "cohb_s1",
          type: "other_human_consumption"
        },
        {
          name: "Basic Toothpicks",
          description: "Wooden",
          unit_price: 100,
          quantity: 250,
          sku: "tooth_r3",
          type: "Extra pointy"
        }
      ]
    }
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(more_options))
    assert_success response
    assert_equal "Wanaque", response.params['details']['shipment']['address']['city']
    assert_equal "Wooden", response.params['details']['line_items'][-1]['description']
    assert_equal "TheCustomerName", response.params['details']['name']
    assert_equal "Guerrero", response.params['details']['billing_address']['city']
  end

  def test_failed_purchase_with_no_details
    assert response = @gateway.purchase(@amount, @credit_card, {})
    assert_failure response
    assert_equal "Falta el correo del comprador.", response.message
  end

  def test_invalid_key
    gateway = ConektaGateway.new(key: 'invalid_token')
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Acceso no autorizado.", response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
  end
end
