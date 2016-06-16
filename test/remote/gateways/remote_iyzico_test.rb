# encoding: utf-8
require 'test_helper'

class RemoteIyzicoTest < Test::Unit::TestCase
  def setup
    @gateway = IyzicoGateway.new(api_id: 'sandbox-aKksNes17V1KPuAA1xw3Y431INO9iU8P', secret: 'sandbox-c5mxNw5RsciXzwCp1Sw9Pm4IZUSweBcM')

    @amount = 0.1
    @credit_card = ActiveMerchant::Billing::CreditCard.new(
        :brand => "MasterCard",
        :number => "5528790000000008",
        :verification_value => "000",
        :month => 1,
        :year => 20,
        :first_name => "John",
        :last_name => "Doe"
    )
    @declined_card = credit_card('4111111111111129')
    @options = {
        billing_address: address,
        shipping_address: address,
        description: 'Store Purchase',
        ip: "127.0.0.1",
        customer: 'John Doe',
        email: 'john@doe.com',
        phone: '9898912233',
        name: 'John',
        surname: 'Doe',
        lastLoginDate: "2015-10-05 12:43:35",
        registrationDate: "2013-04-21 15:12:09",
        currency: 'TRY',
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

  def test_successful_purchase_with_try
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'success', response.params['status']
    assert_equal 'tr', response.params['locale']
    assert_equal 0.1, response.params['price']
    assert_equal 0.1, response.params['paidPrice']
    assert_equal 'TRY', response.params['currency']
    assert_equal 1, response.params['fraudStatus']
    assert_success response
  end

  def test_successful_purchase_with_euro
    @options[:currency] = 'EUR'
    response = @gateway.purchase(@amount, credit_card('5412750000000001'), @options)
    assert_equal 'success', response.params['status']
    assert_equal 'tr', response.params['locale']
    assert_equal 0.1, response.params['price']
    assert_equal 0.1, response.params['paidPrice']
    assert_equal 'EUR', response.params['currency']
    assert_equal 1, response.params['fraudStatus']
    assert_success response
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_equal 'failure', response.params['status']
    assert_failure response
    assert_equal "Kart limiti yetersiz, yetersiz bakiye", response.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_equal 'failure', response.params['status']
    assert_failure response
    assert_equal "Kart limiti yetersiz, yetersiz bakiye", response.message
  end

  def test_successful_void
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal 'success', response.params['status']
    assert_success response

    assert void = @gateway.void(response.authorization)
    assert_success void
  end

  def test_failed_void
    response = @gateway.void('')
    assert_equal 'failure', response.params['status']
    assert_failure response
    assert_equal "paymentId gönderilmesi zorunludur", response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_equal 'success', response.params['status']
    assert_success response
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_equal 'failure', response.params['status']
    assert_failure response
    assert_match "Kart limiti yetersiz, yetersiz bakiye", response.message
  end

  def test_invalid_login
    gateway = IyzicoGateway.new(api_id: '', secret: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'failure', response.params['status']
    assert_failure response
    assert_match "Signature gönderilmesi zorunludur", response.message
  end

end
