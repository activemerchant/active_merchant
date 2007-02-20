require 'test/unit'
require File.dirname(__FILE__) + '/../test_helper'

class RemoveUsaEpayTest < Test::Unit::TestCase
  include ActiveMerchant::Billing

  # This key does not work in test mode.  I believe test mode is designed
  # to work with real credit card numbers, but not charge them.
  def setup
    ActiveMerchant::Billing::Base.gateway_mode = :production

    @gateway = UsaEpayGateway.new({
        :login => 'yCaWGYQsSVR0S48B6AKMK07RQhaxHvGu'
      })

    @creditcard = CreditCard.new({
      :number => '4000100011112224',
      :month => 9,
      :year => 2009,
      :first_name => 'Longbob',
      :last_name => 'Longsen'
    })

    @declined_card = CreditCard.new({
      :number => '4000300011112220',
      :month => 9,
      :year => 2009,
      :first_name => 'Longbob',
      :last_name => 'Longsen'
    })

    @options = { :address => { :address1 => '1234 Shady Brook Lane',
                              :zip => '90210'
                             }
               }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(Money.ca_dollar(100), @creditcard, @options)
    assert_equal 'Success', response.message
    assert response.success?
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(Money.ca_dollar(100), @declined_card, @options)
    assert_equal 'Card Declined', response.message
    assert !response.success?
  end

  def test_authorize_and_capture
    amount = Money.ca_dollar(100)
    assert auth = @gateway.authorize(amount, @creditcard, @options)
    assert auth.success?
    assert_equal 'Success', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert capture.success?
  end

  def test_failed_capture
    assert response = @gateway.capture(Money.ca_dollar(100), '')
    assert !response.success?
    assert_equal 'Unable to find original transaciton.', response.message
  end

  def test_invalid_key
    gateway = UsaEpayGateway.new({
        :login => ''
      })
    assert response = gateway.purchase(Money.ca_dollar(100), @creditcard, @options)
    assert_equal 'Specified source key not found.', response.message
    assert !response.success?
  end
end
