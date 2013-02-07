# encoding: utf-8
require 'test_helper'

class RemoteBanwireTest < Test::Unit::TestCase
  def setup
    @gateway = BanwireGateway.new(fixtures(:banwire))

    @amount = 100
    @credit_card = credit_card('5204164299999999',
                               :month => 11,
                               :year => 2012,
                               :verification_value => '999')
    @declined_card = credit_card('4000300011112220')

    @options = {
      :order_id => '1',
      :email => "test@email.com",
      :billing_address => address,
      :description => 'Store Purchase'
    }

    @amex_credit_card = credit_card('375932134599999',
                                    :month => 3,
                                    :year => 2017,
                                    :first_name => "Banwire",
                                    :last_name => "Test Card",
                                    :verification_value => '9999',
                                    :brand => 'american_express')

    @amex_successful_options = {
        :order_id => '3',
        :email => 'test@email.com',
        :billing_address => address(:address1 => 'Horacio', :zipcode => '11560'),
        :description  => 'Store purchase amex'
    }

    @amex_options = {
        :order_id => '2',
        :email => 'test@email.com',
        :billing_address => address,
        :description  => 'Store purchase amex'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_successful_amex_purchase
    assert response = @gateway.purchase(@amount, @amex_credit_card, @amex_successful_options)
    assert_success response
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'denied', response.message
  end

  def test_invalid_login
    gateway = BanwireGateway.new(
                :login => 'fakeuser',
                :currency => 'MXN'
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'ID de cuenta invalido', response.message
  end

  def test_invalid_amex_address
    assert response = @gateway.purchase(@amount, @amex_credit_card, @amex_options)
    assert_equal 'Dirección y código postal requeridos para pagos con AMEX', response.message
  end
end
