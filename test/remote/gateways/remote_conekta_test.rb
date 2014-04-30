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
      description: 'Blue clip',
      address1: "Rio Missisipi #123",
      address2: "Paris",
      city: "Guerrero",
      country: "Mexico",
      zip: "5555",
      name: "Mario Reyes",
      phone: "12345678",
      carrier: "Estafeta"
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

  def test_unsuccessful_refund
    assert response = @gateway.refund(@amount, "1", @options)
    assert_failure response
    assert_equal "The resource was not found.", response.message
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

  def test_successful_store
    assert response = @gateway.store("tok_test_visa_4242", {name: "John Doe", email: "email@example.com"})
    assert_success response
    assert response = @gateway.store("tok_test_visa_1881", {id: response.params["id"]})
    assert_equal "customer", response.params["object"]
    assert_equal "John Doe", response.params["name"]
    assert_equal "4242", response.params["cards"][0]["last4"]
    assert_equal "1881", response.params["cards"][1]["last4"]
    assert_equal "email@example.com", response.params["email"]
  end

  def test_successful_unstore
    creation = @gateway.store("tok_test_visa_4242", {name: "John Doe", email: "email@example.com"})
    assert response = @gateway.unstore(creation.params['id'])
    assert_success response
    assert_equal true, response.params["deleted"]
  end

  def test_unsuccessful_capture
    assert response = @gateway.capture(@amount, "1", @options)
    assert_failure response
    assert_equal "The resource was not found.", response.message
  end

  def test_invalid_key
    gateway = ConektaGateway.new(key: 'invalid_token')
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Unrecognized access key.", response.message
  end
end	
