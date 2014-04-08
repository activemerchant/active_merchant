require 'test_helper'

class PinTest < Test::Unit::TestCase
  def setup
    @gateway = PinGateway.new(:api_key => 'I_THISISNOTAREALAPIKEY')

    @credit_card = credit_card
    @amount = 100

    @options = {
      :email => 'roland@pin.net.au',
      :billing_address => address,
      :description => 'Store Purchase',
      :ip => '127.0.0.1'
    }
  end

  def test_required_api_key_on_initialization
    assert_raises ArgumentError do
      PinGateway.new
    end
  end

  def test_default_currency
    assert_equal 'AUD', PinGateway.default_currency
  end

  def test_money_format
    assert_equal :cents, PinGateway.money_format
  end

  def test_url
    assert_equal 'https://test-api.pin.net.au/1', PinGateway.test_url
  end

  def test_live_url
    assert_equal 'https://api.pin.net.au/1', PinGateway.live_url
  end

  def test_supported_countries
    assert_equal ['AU'], PinGateway.supported_countries
  end

  def test_supported_cardtypes
    assert_equal [:visa, :master, :american_express], PinGateway.supported_cardtypes
  end

  def test_display_name
    assert_equal 'Pin', PinGateway.display_name
  end

  def test_setup_purchase_parameters
    @gateway.expects(:add_amount).with(instance_of(Hash), @amount, @options)
    @gateway.expects(:add_customer_data).with(instance_of(Hash), @options)
    @gateway.expects(:add_invoice).with(instance_of(Hash), @options)
    @gateway.expects(:add_creditcard).with(instance_of(Hash), @credit_card)
    @gateway.expects(:add_address).with(instance_of(Hash), @credit_card, @options)

    @gateway.stubs(:ssl_post).returns(successful_purchase_response)
    assert_success @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_successful_purchase
    post_data = {}
    headers = {}
    @gateway.stubs(:headers).returns(headers)
    @gateway.stubs(:post_data).returns(post_data)
    @gateway.expects(:ssl_post).with('https://test-api.pin.net.au/1/charges', post_data, headers).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'ch_Kw_JxmVqMeSOQU19_krRdw', response.authorization
    assert_equal JSON.parse(successful_purchase_response), response.params
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "The current resource was deemed invalid.", response.message
    assert response.test?
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)
    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'card_sVOs8D9nANoNgDc38NvKow', response.authorization
    assert_equal JSON.parse(successful_store_response), response.params
    assert response.test?
  end

  def test_unsuccessful_store
    @gateway.expects(:ssl_post).returns(failed_store_response)

    assert response = @gateway.store(@credit_card, @options)
    assert_failure response
    assert_equal "The current resource was deemed invalid.", response.message
    assert response.test?
  end

  def test_successful_refund
    token = 'ch_encBuMDf17qTabmVjDsQlg'
    @gateway.expects(:ssl_post).with("https://test-api.pin.net.au/1/charges/#{token}/refunds", {:amount => '100'}.to_json, instance_of(Hash)).returns(successful_refund_response)

    assert response = @gateway.refund(100, token)
    assert_equal 'rf_d2C7M6Mn4z2m3APqarNN6w', response.authorization
    assert_success response
    assert response.test?
  end

  def test_unsuccessful_refund
    token = 'ch_encBuMDf17qTabmVjDsQlg'
    @gateway.expects(:ssl_post).with("https://test-api.pin.net.au/1/charges/#{token}/refunds", {:amount => '100'}.to_json, instance_of(Hash)).returns(failed_refund_response)

    assert response = @gateway.refund(100, token)
    assert_failure response
    assert_equal "The current resource was deemed invalid.", response.message
    assert response.test?
  end

  def test_store_parameters
    @gateway.expects(:add_creditcard).with(instance_of(Hash), @credit_card)
    @gateway.expects(:add_address).with(instance_of(Hash), @credit_card, @options)
    @gateway.expects(:ssl_post).returns(successful_store_response)
    assert_success @gateway.store(@credit_card, @options)
  end

  def test_add_amount
    @gateway.expects(:amount).with(100).returns('100')
    post = {}
    @gateway.send(:add_amount, post, 100, @options)
    assert_equal '100', post[:amount]
  end

  def test_set_default_currency
    @gateway.expects(:currency).with(100).returns('AUD')
    post = {}
    @gateway.send(:add_amount, post, 100, @options)
    assert_equal 'AUD', post[:currency]
  end

  def test_set_currency
    @gateway.expects(:currency).never
    post = {}
    @options[:currency] = 'USD'
    @gateway.send(:add_amount, post, 100, @options)
    assert_equal 'USD', post[:currency]
  end

  def test_set_currency_case
    @gateway.expects(:currency).never
    post = {}
    @options[:currency] = 'usd'
    @gateway.send(:add_amount, post, 100, @options)
    assert_equal 'USD', post[:currency]
  end

  def test_add_customer_data
    post = {}

    @gateway.send(:add_customer_data, post, @options)

    assert_equal 'roland@pin.net.au', post[:email]
    assert_equal '127.0.0.1', post[:ip_address]
  end

  def test_add_address
    post = {}

    @gateway.send(:add_address, post, @creditcard, @options)

    assert_equal @options[:billing_address][:address1], post[:card][:address_line1]
    assert_equal @options[:billing_address][:city], post[:card][:address_city]
    assert_equal @options[:billing_address][:zip], post[:card][:address_postcode]
    assert_equal @options[:billing_address][:state], post[:card][:address_state]
    assert_equal @options[:billing_address][:country], post[:card][:address_country]
  end

  def test_add_address_with_card_token
    post = {}

    @gateway.send(:add_address, post, 'somecreditcardtoken', @options)

    assert_equal false, post.has_key?(:card)
  end

  def test_add_invoice
    post = {}
    @gateway.send(:add_invoice, post, @options)

    assert_equal @options[:description], post[:description]
  end

  def test_add_creditcard
    post = {}
    @gateway.send(:add_creditcard, post, @credit_card)

    assert_equal @credit_card.number, post[:card][:number]
    assert_equal @credit_card.month, post[:card][:expiry_month]
    assert_equal @credit_card.year, post[:card][:expiry_year]
    assert_equal @credit_card.verification_value, post[:card][:cvc]
    assert_equal @credit_card.name, post[:card][:name]
  end

  def test_add_creditcard_with_card_token
    post = {}
    @gateway.send(:add_creditcard, post, 'card_nytGw7koRg23EEp9NTmz9w')
    assert_equal 'card_nytGw7koRg23EEp9NTmz9w', post[:card_token]
    assert_false post.has_key?(:card)
  end

  def test_add_creditcard_with_customer_token
    post = {}
    @gateway.send(:add_creditcard, post, 'cus_XZg1ULpWaROQCOT5PdwLkQ')
    assert_equal 'cus_XZg1ULpWaROQCOT5PdwLkQ', post[:customer_token]
    assert_false post.has_key?(:card)
  end

  def test_post_data
    post = {}
    @gateway.send(:add_creditcard, post, @credit_card)
    assert_equal post.to_json, @gateway.send(:post_data, post)
  end

  def test_headers
    expected_headers = {
      "Content-Type" => "application/json",
      "Authorization" => "Basic #{Base64.strict_encode64('I_THISISNOTAREALAPIKEY:').strip}"
    }

    @gateway.expects(:ssl_post).with(anything, anything, expected_headers).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, {})

    expected_headers['X-Partner-Key'] = 'MyPartnerKey'
    expected_headers['X-Safe-Card'] = '1'

    @gateway.expects(:ssl_post).with(anything, anything, expected_headers).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, :partner_key => 'MyPartnerKey', :safe_card => '1')
  end


  private

  def successful_purchase_response
    '{
      "response":{
        "token":"ch_Kw_JxmVqMeSOQU19_krRdw",
        "success":true,
        "amount":400,
        "currency":"AUD",
        "description":"test charge",
        "email":"roland@pin.net.au",
        "ip_address":"203.192.1.172",
        "created_at":"2013-01-14T03:00:41Z",
        "status_message":"Success!",
        "error_message":null,
        "card":{
          "token":"card_0oG1hjachN7g8KsOnWlOcg",
          "display_number":"XXXX-XXXX-XXXX-0000",
          "scheme":"master",
          "address_line1":"42 Sevenoaks St",
          "address_line2":null,
          "address_city":"Lathlain",
          "address_postcode":"6454",
          "address_state":"WA",
          "address_country":"AU"
        },
        "transfer":[

        ],
        "amount_refunded":0,
        "total_fees":62,
        "merchant_entitlement":338,
        "refund_pending":false
      }
    }'
  end

  def failed_purchase_response
    '{
      "error":"invalid_resource",
      "error_description":"The current resource was deemed invalid.",
      "messages":[
        {
          "param":"card.brand",
          "code":"card_brand_invalid",
          "message":"Card brand [\"is required\"]"
        },
        {
          "param":"card.number",
          "code":"card_number_invalid",
          "message":"Card number []"
        }
      ]
    }'
  end

  def successful_store_response
    '{
      "response":{
        "token":"card_sVOs8D9nANoNgDc38NvKow",
        "display_number":"XXXX-XXXX-XXXX-0000",
        "scheme":"master",
        "address_line1":"42 Sevenoaks St",
        "address_line2":null,
        "address_city":"Lathlain",
        "address_postcode":"6454",
        "address_state":"WA",
        "address_country":"Australia"
      }
    }'
  end

  def failed_store_response
    '{
      "error":"invalid_resource",
      "error_description":"The current resource was deemed invalid.",
      "messages":[
        {
          "param":"number",
          "code":"number_invalid",
          "message":"Number [\"is not a valid credit card number\"]"
        }
      ]
    }'
  end

  def successful_customer_store_response
    '{
      "response":{
        "token":"cus_05p0n7UFPmcyCNjD8c6HdA",
        "email":"roland@pin.net.au",
        "created_at":"2013-01-16T03:16:11Z",
        "card":{
          "token":"card__o8I8GmoXDF0d35LEDZbNQ",
          "display_number":"XXXX-XXXX-XXXX-0000",
          "scheme":"master",
          "address_line1":"42 Sevenoaks St",
          "address_line2":null,
          "address_city":"Lathlain",
          "address_postcode":"6454",
          "address_state":"WA",
          "address_country":"Australia"
        }
      }
    }'
  end

  def failed_customer_store_response
    '{
      "error":"invalid_resource",
      "error_description":"The current resource was deemed invalid.",
      "messages":[
        {
          "param":"card.number",
          "code":"card_number_invalid",
          "message":"Card number [\"is not a valid credit card number\"]"
        }
      ]
    }'
  end

  def successful_refund_response
    '{
      "response":{
        "token":"rf_d2C7M6Mn4z2m3APqarNN6w",
        "success":null,
        "amount":400,
        "currency":"AUD",
        "charge":"ch_encBuMDf17qTabmVjDsQlg",
        "created_at":"2013-01-16T05:33:34Z",
        "error_message":null,
        "status_message":"Pending"
      }
    }'
  end

  def failed_refund_response
    '{
      "error":"invalid_resource",
      "error_description":"The current resource was deemed invalid.",
      "messages":{
        "charge":[
          "You have tried to refund more than the original charge"
        ]
      }
    }'
  end
end
