require 'test_helper'

class RemoteIyzicoTest < Test::Unit::TestCase
  def setup
    @gateway = IyzicoGateway.new(api_id: 'izzHF4CC6ZCU5Mb9PKXZl6neexytWjfu', secret: 'koN27VKnj8zD2poBhaGuFUcSaOe0Rhlz')
    @credit_card = credit_card_data
    @amount = 0.1

    @options = {
        order_id: '1',
        billing_address: address,
        shipping_address: address,
        description: 'Store Purchase',
        items: basket_items,
        ip: "127.0.0.1",
        customer:  'Jim Smith',
        email: 'dharmesh.vasani@multidots.in',
        phone: '9898912233',
        name: 'Jim'
    }

  end

  def test_default_currency
    assert_equal 'TRY', IyzicoGateway.default_currency
  end

  def test_url
    assert_equal 'https://stg.iyzipay.com', IyzicoGateway.test_url
  end

  def test_live_url
    assert_equal 'https://stg.iyzipay.com', IyzicoGateway.live_url
  end

  def test_supported_countries
    assert_equal ['TR'], IyzicoGateway.supported_countries
  end

  def test_supported_cardtypes
    assert_equal [:visa, :master, :american_express], IyzicoGateway.supported_cardtypes
  end

  def test_display_name
    assert_equal 'iyzico', IyzicoGateway.display_name
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "5152", response.params['errorCode']
    assert_equal "failure", response.params['status']
    assert_equal "tr", response.params['locale']
  end

  def test_failed_void
    authorization = 4374
    response = @gateway.void(authorization, options={})
    assert_equal "5088", response.params['errorCode']
    assert_equal "failure", response.params['status']
    assert_equal "tr", response.params['locale']
  end

  def test_add_billing_address
    response = @gateway.add_billing_address(@options)
    assert_equal "K1C2N6", response.zipCode
    assert_equal "Ottawa", response.city
    assert_equal "CA", response.country
    assert_equal "456 My Street", response.address
    assert_equal "Jim Smith", response.contactName
  end

  def test_add_shipping_address
    response = @gateway.add_shipping_address(@options)
    assert_equal "Ottawa", response.city
    assert_equal "CA", response.country
    assert_equal "456 My Street", response.address
    assert_equal "Jim Smith", response.contactName
  end

  def test_add_buyer_data
    response = @gateway.add_buyer_data(@options)
    assert_equal "Jim Smith", response.id
    assert_equal "dharmesh.vasani@multidots.in", response.email
    assert_equal "SHOPIFY_Jim", response.identityNumber
    assert_equal "127.0.0.1", response.ip
    assert_equal "Jim", response.name
    assert_equal "Jim", response.surname
    assert_equal "Ottawa", response.city
    assert_equal "CA", response.country
    assert_equal "(555)555-5555", response.gsmNumber
    assert_equal "456 My Street", response.registrationAddress
  end

  def test_card_data
    response = @gateway.add_card_data(@credit_card)
    assert_equal "4242424242424242", response.cardNumber
    assert_equal "000", response.cvc
    assert_equal "Dharmesh Vasani", response.cardHolderName
    assert_equal "01", response.expireMonth
    assert_equal "20", response.expireYear
  end

  private

  def credit_card_data
    credit_card = ActiveMerchant::Billing::CreditCard.new(
        :type => "MasterCard",
        :number => "4242424242424242",
        :verification_value => "000",
        :month => 1,
        :year => 20,
        :first_name => "Dharmesh",
        :last_name => "Vasani"
    )
    credit_card
  end

  def basket_items(options ={})
    items = [{
                 :name => 'item1',
                 :category => 'category1',
                 :sku => 'sku1',
                 :amount => 0.1
             }, {
                 :name => 'item1',
                 :category => 'category1',
                 :sku => 'sku1',
                 :amount => 0.1
             }]
    items
  end

end
