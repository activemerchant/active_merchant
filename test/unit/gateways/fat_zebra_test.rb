require 'test_helper'

class FatZebraTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = FatZebraGateway.new(
                 :username => 'TEST',
                 :token    => 'TEST'
               )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => rand(10000),
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '001-P-12345AA', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_token
    @gateway.expects(:ssl_request).with { |method, url, body, headers|
      body.match '"card_token":"e1q7dbj2"'
    }.returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, "e1q7dbj2", @options)
    assert_success response

    assert_equal '001-P-12345AA', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_token_string
    @gateway.expects(:ssl_request).with { |method, url, body, headers|
      body.match '"card_token":"e1q7dbj2"'
    }.returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, "e1q7dbj2", @options)
    assert_success response

    assert_equal '001-P-12345AA', response.authorization
    assert response.test?
  end

  def test_successful_multi_currency_purchase
    @gateway.expects(:ssl_request).with { |method, url, body, headers|
      body.match '"currency":"USD"'
    }.returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, "e1q7dbj2", @options.merge(:currency => 'USD'))
    assert_success response

    assert_equal '001-P-12345AA', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_recurring_flag
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options.merge(recurring: true))
    end.check_request do |method, endpoint, data, headers|
      assert_match(%r("extra":{"ecm":"32"}), data)
    end.respond_with(successful_purchase_response)
  end

  def test_successful_purchase_with_descriptor
    @gateway.expects(:ssl_request).with { |method, url, body, headers|
      json = JSON.parse(body)
      json['extra']['name'] == 'Merchant' && json['extra']['location'] == 'Location'
    }.returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, "e1q7dbj2", @options.merge(:merchant => 'Merchant', :merchant_location => 'Location'))
    assert_success response

    assert_equal '001-P-12345AA', response.authorization
    assert response.test?
  end

  def test_successful_authorization
    @gateway.expects(:ssl_request).with { |method, url, body, headers|
      body.match '"capture":false'
    }.returns(successful_purchase_response)

    assert response = @gateway.authorize(@amount, "e1q7dbj2", @options)
    assert_success response

    assert_equal '001-P-12345AA', response.authorization
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_request).with { |method, url, body, headers|
      url =~ %r[purchases/e1q7dbj2/capture\z]
    }.returns(successful_purchase_response)

    response = @gateway.capture(@amount, "e1q7dbj2", @options)
    assert_success response
    assert_equal '001-P-12345AA', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_match %r{Invalid Card Number}, response.message
  end

  def test_declined_purchase
    @gateway.expects(:ssl_request).returns(declined_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_match %r{Card Declined}, response.message
  end

  def test_parse_error
    @gateway.expects(:ssl_request).returns("{") # Some invalid JSON
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Invalid JSON response}, response.message
  end

  def test_request_error
    @gateway.expects(:ssl_request).returns(missing_data_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Card Number is required}, response.message
  end

  def test_successful_tokenization
    @gateway.expects(:ssl_request).returns(successful_tokenize_response)

    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal "e1q7dbj2", response.authorization
  end

  def test_unsuccessful_tokenization
    @gateway.expects(:ssl_request).returns(failed_tokenize_response)

    assert response = @gateway.store(@credit_card)
    assert_failure response
  end

  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_refund_response)

    assert response = @gateway.refund(100, "TEST")
    assert_success response
    assert_equal '003-R-7MNIUMY6', response.authorization
    assert response.test?
  end

  def test_unsuccessful_refund
    @gateway.expects(:ssl_request).returns(unsuccessful_refund_response)

    assert response = @gateway.refund(100, "TEST")
    assert_failure response
    assert response.test?
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<-'PRE_SCRUBBED'
opening connection to gateway.sandbox.fatzebra.com.au:443...
opened
starting SSL for gateway.sandbox.fatzebra.com.au:443...
SSL established
<- "POST /v1.0/credit_cards HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic VEVTVDpURVNU\r\nUser-Agent: Fat Zebra v1.0/ActiveMerchant 1.56.0\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: gateway.sandbox.fatzebra.com.au\r\nContent-Length: 93\r\n\r\n"
<- "{\"card_number\":\"5123456789012346\",\"card_expiry\":\"5/2017\",\"cvv\":\"111\",\"card_holder\":\"Foo Bar\"}"
-> "HTTP/1.1 200 OK\r\n"
-> "Content-Type: application/json; charset=utf-8\r\n"
-> "Connection: close\r\n"
-> "Status: 200 OK\r\n"
-> "Cache-control: no-store\r\n"
-> "Pragma: no-cache\r\n"
-> "X-Request-Id: 3BA78272_F214_AC10001D_01BB_566A58EC_222F1D_49F4\r\n"
-> "X-Runtime: 0.142463\r\n"
-> "Date: Fri, 11 Dec 2015 05:02:36 GMT\r\n"
-> "X-Rack-Cache: invalidate, pass\r\n"
-> "X-Sandbox: true\r\n"
-> "X-Backend-Server: app-3\r\n"
-> "\r\n"
reading all...
-> "{\"successful\":true,\"response\":{\"token\":\"nkk9rhwu\",\"card_holder\":\"Foo Bar\",\"card_number\":\"512345XXXXXX2346\",\"card_expiry\":\"2017-05-31T23:59:59+10:00\",\"authorized\":true,\"transaction_count\":0},\"errors\":[],\"test\":true}"
read 214 bytes
Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-'POST_SCRUBBED'
opening connection to gateway.sandbox.fatzebra.com.au:443...
opened
starting SSL for gateway.sandbox.fatzebra.com.au:443...
SSL established
<- "POST /v1.0/credit_cards HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic [FILTERED]\r\nUser-Agent: Fat Zebra v1.0/ActiveMerchant 1.56.0\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: gateway.sandbox.fatzebra.com.au\r\nContent-Length: 93\r\n\r\n"
<- "{\"card_number\":\"[FILTERED]\",\"card_expiry\":\"5/2017\",\"cvv\":\"[FILTERED]\",\"card_holder\":\"Foo Bar\"}"
-> "HTTP/1.1 200 OK\r\n"
-> "Content-Type: application/json; charset=utf-8\r\n"
-> "Connection: close\r\n"
-> "Status: 200 OK\r\n"
-> "Cache-control: no-store\r\n"
-> "Pragma: no-cache\r\n"
-> "X-Request-Id: 3BA78272_F214_AC10001D_01BB_566A58EC_222F1D_49F4\r\n"
-> "X-Runtime: 0.142463\r\n"
-> "Date: Fri, 11 Dec 2015 05:02:36 GMT\r\n"
-> "X-Rack-Cache: invalidate, pass\r\n"
-> "X-Sandbox: true\r\n"
-> "X-Backend-Server: app-3\r\n"
-> "\r\n"
reading all...
-> "{\"successful\":true,\"response\":{\"token\":\"nkk9rhwu\",\"card_holder\":\"Foo Bar\",\"card_number\":\"[FILTERED]\",\"card_expiry\":\"2017-05-31T23:59:59+10:00\",\"authorized\":true,\"transaction_count\":0},\"errors\":[],\"test\":true}"
read 214 bytes
Conn close
    POST_SCRUBBED
  end
  # Place raw successful response from gateway here
  def successful_purchase_response
    {
      :successful => true,
      :response => {
        :authorization => "55355",
        :id => "001-P-12345AA",
        :card_number => "XXXXXXXXXXXX1111",
        :card_holder => "John Smith",
        :card_expiry => "10/2011",
        :card_token => "a1bhj98j",
        :amount => 349,
        :successful => true,
        :reference => "ABC123",
        :message => "Approved",
      },
      :test => true,
      :errors => []
    }.to_json
  end

  def declined_purchase_response
    {
      :successful => true,
      :response => {
          :authorization_id => nil,
          :id => nil,
          :card_number => "XXXXXXXXXXXX1111",
          :card_holder => "John Smith",
          :card_expiry => "10/2011",
          :amount => 100,
          :authorized => false,
          :reference => "ABC123",
          :message => "Card Declined - check with issuer",
      },
      :test => true,
      :errors => []
    }.to_json
  end

  def successful_refund_response
    {
      :successful => true,
      :response => {
        :authorization => "1339973263",
        :id => "003-R-7MNIUMY6",
        :amount => -10,
        :refunded => "Approved",
        :message => "08 Approved",
        :card_holder => "Harry Smith",
        :card_number => "XXXXXXXXXXXX4444",
        :card_expiry => "2013-05-31",
        :card_type => "MasterCard",
        :transaction_id => "003-R-7MNIUMY6",
        :successful => true
      },
      :errors => [

      ],
      :test => true
    }.to_json
  end

  def unsuccessful_refund_response
    {
      :successful => false,
      :response => {
        :authorization => nil,
        :id => nil,
        :amount => nil,
        :refunded => nil,
        :message => nil,
        :card_holder => "Matthew Savage",
        :card_number => "XXXXXXXXXXXX4444",
        :card_expiry => "2013-05-31",
        :card_type => "MasterCard",
        :transaction_id => nil,
        :successful => false
      },
      :errors => [
        "Reference can't be blank"
      ],
      :test => true
    }.to_json
  end

  def successful_tokenize_response
    {
      :successful => true,
      :response => {
        :token => "e1q7dbj2",
        :card_holder => "Bob Smith",
        :card_number => "XXXXXXXXXXXX2346",
        :card_expiry => "2013-05-31T23:59:59+10:00",
        :authorized => true,
        :transaction_count => 0
      },
      :errors => [],
      :test => true
    }.to_json
  end

  def failed_tokenize_response
    {
      :successful => false,
      :response => {
        :token => nil,
        :card_holder => "Bob ",
        :card_number => "512345XXXXXX2346",
        :card_expiry => nil,
        :authorized => false,
        :transaction_count => 10
      },
      :errors => [
        "Expiry date can't be blank"
      ],
      :test => false
    }.to_json
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    {
      :successful => false,
      :response => {},
      :test => true,
      :errors => ["Invalid Card Number"]
    }.to_json
  end

  def missing_data_response
    {
      :successful => false,
      :response => {},
      :test => true,
      :errors => ["Card Number is required"]
    }.to_json
  end
end
