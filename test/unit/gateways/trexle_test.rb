require 'test_helper'

class TrexleTest < Test::Unit::TestCase
  def setup
    @gateway = TrexleGateway.new(api_key: 'THIS_IS_NOT_A_REAL_API_KEY')

    @credit_card = credit_card
    @amount = 100

    @options = {
      email: 'john@trexle.com',
      billing_address: address,
      description: 'Store Purchase',
      ip: '127.0.0.1'
    }
  end

  def test_required_api_key_on_initialization
    assert_raises ArgumentError do
      TrexleGateway.new
    end
  end

  def test_default_currency
    assert_equal 'USD', TrexleGateway.default_currency
  end

  def test_money_format
    assert_equal :cents, TrexleGateway.money_format
  end

  def test_url
    assert_equal 'https://core.trexle.com/api/v1', TrexleGateway.test_url
  end

  def test_live_url
    assert_equal 'https://core.trexle.com/api/v1', TrexleGateway.live_url
  end

  def test_supported_countries
    expected_supported_countries = %w(AD AE AT AU BD BE BG BN CA CH CY CZ DE DK EE EG ES FI FR GB
                                    GI GR HK HU ID IE IL IM IN IS IT JO KW LB LI LK LT LU LV MC
                                    MT MU MV MX MY NL NO NZ OM PH PL PT QA RO SA SE SG SI SK SM
                                    TR TT UM US VA VN ZA)
    assert_equal expected_supported_countries, TrexleGateway.supported_countries 
  end

  def test_supported_cardtypes
    assert_equal [:visa, :master, :american_express], TrexleGateway.supported_cardtypes
  end

  def test_display_name
    assert_equal 'Trexle', TrexleGateway.display_name
  end

  def test_setup_purchase_parameters
    @gateway.expects(:add_amount).with(instance_of(Hash), @amount, @options)
    @gateway.expects(:add_customer_data).with(instance_of(Hash), @options)
    @gateway.expects(:add_invoice).with(instance_of(Hash), @options)
    @gateway.expects(:add_creditcard).with(instance_of(Hash), @credit_card)
    @gateway.expects(:add_address).with(instance_of(Hash), @credit_card, @options)

    @gateway.stubs(:ssl_request).returns(successful_purchase_response)
    assert_success @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_successful_purchase
    post_data = {}
    headers = {}
    @gateway.stubs(:headers).returns(headers)
    @gateway.stubs(:post_data).returns(post_data)
    @gateway.expects(:ssl_request).with(:post, 'https://core.trexle.com/api/v1/charges', post_data, headers).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'charge_0cfad7ee5ffe75f58222bff214bfa5cc7ad7c367', response.authorization
    assert_equal JSON.parse(successful_purchase_response), response.params
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Invalid response.", response.message
  end

  def test_unparsable_body_of_successful_response
    @gateway.stubs(:raw_ssl_request).returns(MockResponse.succeeded("not-json"))

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match(/Invalid JSON response received/, response.message)
  end

  def test_successful_store
    @gateway.expects(:ssl_request).returns(successful_store_response)
    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'token_2cb443cf26b6ecdadd8144d1fac8240710aa41f1', response.authorization
    assert_equal JSON.parse(successful_store_response), response.params
    assert response.test?
  end

  def test_unsuccessful_store
    @gateway.expects(:ssl_request).returns(failed_store_response)

    assert response = @gateway.store(@credit_card, @options)
    assert_failure response
    assert_equal "Invalid response.", response.message
  end

  def test_successful_update
    token = 'token_940ade441a23d53e04017f53af6c3a1eae9978ae'
    @gateway.expects(:ssl_request).with(:put, "https://core.trexle.com/api/v1/customers/#{token}", instance_of(String), instance_of(Hash)).returns(successful_customer_store_response)
    assert response = @gateway.update('token_940ade441a23d53e04017f53af6c3a1eae9978ae', @credit_card, @options)
    assert_success response
    assert_equal 'token_940ade441a23d53e04017f53af6c3a1eae9978ae', response.authorization
    assert_equal JSON.parse(successful_customer_store_response), response.params
    assert response.test?
  end

  def test_successful_refund
    token = 'charge_0cfad7ee5ffe75f58222bff214bfa5cc7ad7c367'
    @gateway.expects(:ssl_request).with(:post, "https://core.trexle.com/api/v1/charges/#{token}/refunds", {amount: '100'}.to_json, instance_of(Hash)).returns(successful_refund_response)

    assert response = @gateway.refund(100, token)
    assert_equal 'refund_7f696a86f9cb136520c51ea90c17f687b8df40b0', response.authorization
    assert_success response
    assert response.test?
  end

  def test_unsuccessful_refund
    token = 'charge_0cfad7ee5ffe75f58222bff214bfa5cc7ad7c367'
    @gateway.expects(:ssl_request).with(:post, "https://core.trexle.com/api/v1/charges/#{token}/refunds", {amount: '100'}.to_json, instance_of(Hash)).returns(failed_refund_response)

    assert response = @gateway.refund(100, token)
    assert_failure response
    assert_equal "Invalid response.", response.message
  end

  def test_successful_authorize
    post_data = {}
    headers = {}
    @gateway.stubs(:headers).returns(headers)
    @gateway.stubs(:post_data).returns(post_data)
    @gateway.expects(:ssl_request).with(:post, 'https://core.trexle.com/api/v1/charges', post_data, headers).returns(successful_purchase_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'charge_0cfad7ee5ffe75f58222bff214bfa5cc7ad7c367', response.authorization
    assert_equal JSON.parse(successful_purchase_response), response.params
    assert response.test?
  end

  def test_successful_capture
    post_data = {}
    headers = {}
    token = 'charge_6e47a330dca67ec7f696e8b650db22fe69bb8499'
    @gateway.stubs(:headers).returns(headers)
    @gateway.stubs(:post_data).returns(post_data)
    @gateway.expects(:ssl_request).with(:put, "https://core.trexle.com/api/v1/charges/#{token}/capture", post_data, headers).returns(successful_capture_response)

    assert response = @gateway.capture(100, token)
    assert_success response
    assert_equal token, response.authorization
    assert response.test?
  end

  def test_store_parameters
    @gateway.expects(:add_creditcard).with(instance_of(Hash), @credit_card)
    @gateway.expects(:add_address).with(instance_of(Hash), @credit_card, @options)
    @gateway.expects(:ssl_request).returns(successful_store_response)
    assert_success @gateway.store(@credit_card, @options)
  end

  def test_update_parameters
    @gateway.expects(:add_creditcard).with(instance_of(Hash), @credit_card)
    @gateway.expects(:add_address).with(instance_of(Hash), @credit_card, @options)
    @gateway.expects(:ssl_request).returns(successful_store_response)
    assert_success @gateway.update('token_6b5d89f723d1aeee8ff0c588fd4ccbaae223b9aa', @credit_card, @options)
  end

  def test_add_amount
    @gateway.expects(:amount).with(100).returns('100')
    post = {}
    @gateway.send(:add_amount, post, 100, @options)
    assert_equal '100', post[:amount]
  end

  def test_set_default_currency
    @gateway.expects(:currency).with(100).returns('USD')
    post = {}
    @gateway.send(:add_amount, post, 100, @options)
    assert_equal 'USD', post[:currency]
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

    assert_equal 'john@trexle.com', post[:email]
    assert_equal '127.0.0.1', post[:ip_address]
  end

  def test_add_address
    post = {}

    @gateway.send(:add_address, post, @credit_card, @options)

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
    @gateway.send(:add_creditcard, post, 'token_f974687e4e866d6cca534e1cd42236817d315b3a')
    assert_equal 'token_f974687e4e866d6cca534e1cd42236817d315b3a', post[:card_token]
    assert_false post.has_key?(:card)
  end

  def test_add_creditcard_with_customer_token
    post = {}
    @gateway.send(:add_creditcard, post, 'token_2cb443cf26b6ecdadd8144d1fac8240710aa41f1')
    assert_equal 'token_2cb443cf26b6ecdadd8144d1fac8240710aa41f1', post[:card_token]
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
      "Authorization" => "Basic #{Base64.strict_encode64('THIS_IS_NOT_A_REAL_API_KEY:').strip}"
    }

    @gateway.expects(:ssl_request).with(:post, anything, anything, expected_headers).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, {})

    expected_headers['X-Partner-Key'] = 'MyPartnerKey'
    expected_headers['X-Safe-Card'] = '1'

    @gateway.expects(:ssl_request).with(:post, anything, anything, expected_headers).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, partner_key: 'MyPartnerKey', safe_card: '1')
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  private

  def successful_purchase_response
    '{  
      "response":{  
      "token":"charge_0cfad7ee5ffe75f58222bff214bfa5cc7ad7c367",
      "success":true,
      "captured":true
   }
   }'
  end

  def failed_purchase_response
    '{  
     "error":"Payment failed",
     "detail":"An error occurred while processing your card. Try again in a little bit."
     }'
  end

  def successful_store_response
    '{  
      "response":{  
      "token":"token_2cb443cf26b6ecdadd8144d1fac8240710aa41f1",
      "card":{  
         "token":"token_f974687e4e866d6cca534e1cd42236817d315b3a",
         "primary":true
      }
     }
    }'
  end

  def failed_store_response
    '{  
     "error":"an error has occured",
     "detail":"invalid token"
   }'
  end

  def successful_customer_store_response
    '{  
      "response":{  
      "token":"token_940ade441a23d53e04017f53af6c3a1eae9978ae",
      "card":{  
         "token":"token_9a3f559962cbf6828e2cc38a02023565b0294548",
         "scheme":"master",
         "display_number":"XXXX-XXXX-XXXX-4444",
         "expiry_year":2019,
         "expiry_month":9,
         "cvc":123,
         "name":"Longbob Longsen",
         "address_line1":"456 My Street",
         "address_line2":null,
         "address_city":"Ottawa",
         "address_state":"ON",
         "address_postcode":"K1C2N6",
         "address_country":"CA",
         "primary":true
      }
   }
   }'
  end

  def failed_customer_store_response
    '{  
     "error":"an error has occured",
     "detail":"invalid token"
   }'
  end

  def successful_refund_response
    '{  
      "response":{  
      "token":"refund_7f696a86f9cb136520c51ea90c17f687b8df40b0",
      "success":true,
      "amount":100,
      "charge":"charge_ee4542e9f4d2c50f7fea55b694423a53991a323a",
      "status_message":"Transaction approved"
      }
    }'
  end

  def failed_refund_response
    '{  
     "error":"Refund failed",
     "detail":"invalid token"
   }'
  end

  def successful_capture_response
    '{  
      "response":{  
      "token":"charge_6e47a330dca67ec7f696e8b650db22fe69bb8499",
      "success":true,
      "captured":true
   }
   }'
  end

  def transcript
    '{
      "amount":"100",
      "currency":"USD",
      "email":"john@trexle.com",
      "ip_address":"66.249.79.118",
      "description":"Store Purchase 1437598192",
      "card":{
        "number":"5555555555554444",
        "expiry_month":9,
        "expiry_year":2017,
        "cvc":"123",
        "name":"Longbob Longsen",
        "address_line1":"456 My Street",
        "address_city":"Ottawa",
        "address_postcode":"K1C2N6",
        "address_state":"ON",
        "address_country":"CA"
      }
    }'
  end

  def scrubbed_transcript
    '{
      "amount":"100",
      "currency":"USD",
      "email":"john@trexle.com",
      "ip_address":"66.249.79.118",
      "description":"Store Purchase 1437598192",
      "card":{
        "number":"[FILTERED]",
        "expiry_month":9,
        "expiry_year":2017,
        "cvc":"[FILTERED]",
        "name":"Longbob Longsen",
        "address_line1":"456 My Street",
        "address_city":"Ottawa",
        "address_postcode":"K1C2N6",
        "address_state":"ON",
        "address_country":"CA"
      }
    }'
  end

end
