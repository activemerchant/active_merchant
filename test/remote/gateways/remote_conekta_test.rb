require 'test_helper'

class RemoteConektaTest < Test::Unit::TestCase


  def setup
    @gateway = ConektaGateway.new(fixtures(:conekta))

    @amount = 300

    @credit_card = ActiveMerchant::Billing::CreditCard.new(
      :number             => "4111111111111111",
      :verification_value => "183",
      :month              => "01",
      :year               => "2018",
      :first_name         => "Mario F.",
      :last_name          => "Moreno Reyes"
    )

    @declined_card = ActiveMerchant::Billing::CreditCard.new(
      :number             => "4000000000000002",
      :verification_value => "183",
      :month              => "01",
      :year               => "2018",
      :first_name         => "Mario F.",
      :last_name          => "Moreno Reyes"
    )

    @options = {
      :description => 'Blue clip',
      :success_url => "https://www.example.com/success",
      :failure_url => "https://www.example.com/failure",
      :address1 => "Rio Missisipi #123",
      :address2 => "Paris",
      :address3 => nil,
      :city => "Guerrero",
      :country => "Mexico",
      :zip => "5555",
      :name => "Mario Reyes",
      :phone => "12345678",
      :carrier => "Estafeta"
    }
  end

  def test_successful_offline_purchase
    assert response = @gateway.offline_purchase(2000, "bank", "banorte", @options)
    assert_success response
    assert_equal nil, response.message
  end

  def test_unsuccessful_offline_purchase
    assert response = @gateway.offline_purchase(1000, "bank", "banorte", @options)
    assert_failure response
    assert_equal "The minimum purchase is 15 MXN pesos for bank transfer payments", response.message
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal nil, response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "The card was declined", response.message
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    @options[:order_id] = response.params["id"]
    assert_success response
    assert_equal nil, response.message

    assert response = @gateway.refund(@amount, @options)
    assert_success response
    assert_equal nil, response.message
  end

  def test_unsuccessful_refund
    @options[:order_id] = "1"
    assert response = @gateway.refund(@amount, @options)
    assert_failure response
    assert_equal "The charge does not exist or it is not suitable for this operation", response.message
  end

  def test_successful_void
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    @options[:order_id] = response.params["id"]
    assert_success response
    assert_equal nil, response.message

    assert response = @gateway.void(@amount, @options)
    assert_success response
    assert_equal nil, response.message
  end

  def test_unsuccessful_void
    @options[:order_id] = "1"
    assert response = @gateway.void(@amount, @options)
    assert_failure response
    assert_equal "The charge does not exist or it is not suitable for this operation", response.message
  end

  def test_successful_authorize
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal nil, response.message
  end

  def test_unsuccessful_authorize
    assert response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "The card was declined", response.message
  end

  def test_successful_capture
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    @options[:order_id] = response.params["id"]
    assert_success response
    assert_equal nil, response.message

    assert response = @gateway.capture(@amount, @options)
    assert_success response
    assert_equal nil, response.message
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card, {:name => "John Doe", :email => "email@example.com"})
    assert_success response
    assert_equal "customer", response.params["object"]
    assert_equal "John Doe", response.params["name"]
    assert_equal "email@example.com", response.params["email"]
    #assert_equal @credit_card.last_digits, response.params["active_card"]["last4"]
  end

  def test_successful_unstore
    creation = @gateway.store(@credit_card, {:name => "John Doe", :email => "email@example.com"})
    assert response = @gateway.unstore(creation.params['id'])
    assert_success response
    assert_equal true, response.params["deleted"]
  end

  def test_unsuccessful_capture
    @options[:order_id] = "1"
    assert response = @gateway.capture(@amount, @options)
    assert_failure response
    assert_equal "The charge does not exist or it is not suitable for this operation", response.message
  end

  def test_invalid_login
    gateway = ConektaGateway.new(:key => 'invalid_token')
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Unrecognized authentication token", response.message
  end
end
