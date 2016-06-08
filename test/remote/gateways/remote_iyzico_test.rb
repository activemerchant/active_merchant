# encoding: utf-8
require 'test_helper'

class RemoteIyzicoTest < Test::Unit::TestCase
  def setup
    @gateway = IyzicoGateway.new(fixtures(:iyzico))

    @amount = 0.1
    @credit_card = ActiveMerchant::Billing::CreditCard.new(
        :brand => "MasterCard",
        :number => "5528790000000008",
        :verification_value => "000",
        :month => 1,
        :year => 20,
        :first_name => "Doe",
        :last_name => "John"
    )
    @declined_card = credit_card('4111111111111129')
    @options = {
        order_id: '1',
        billing_address: address,
        shipping_address: address,
        description: 'Store Purchase',
        ip: "127.0.0.1",
        customer: 'John Doe',
        email: 'john@doe.com',
        phone: '9898912233',
        name: 'John',
        lastLoginDate: "2015-10-05 12:43:35",
        registrationDate: "2013-04-21 15:12:09",
        items: [{
                    :name => 'EDC Marka Usb',
                    :category1 => 'Elektronik',
                    :category2 => 'Usb / Cable',
                    :id => 'BI103',
                    :price => 0.1,
                    :itemType => 'LISTING'
                }]
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "Kart limiti yetersiz, yetersiz bakiye", response.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "Kart limiti yetersiz, yetersiz bakiye", response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal "Geçersiz imza", response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match "Kart numarası geçersizdir", response.message
  end

  def test_invalid_login
    gateway = IyzicoGateway.new(api_id: '', secret: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match "Signature gönderilmesi zorunludur", response.message
  end

end
