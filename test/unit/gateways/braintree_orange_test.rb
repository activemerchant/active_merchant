require 'test_helper'

class BraintreeOrangeTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = BraintreeOrangeGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )

    @credit_card = credit_card
    @amount = 100

    @options = { :billing_address => address }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '510695343', response.authorization
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)

    assert response = @gateway.store(@credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal "853162645", response.authorization
    assert_equal response.authorization, response.params["customer_vault_id"]
  end

  def test_add_processor
    result = {}

    @gateway.send(:add_processor, result,   {:processor => 'ccprocessorb'} )
    assert_equal ["processor_id"], result.stringify_keys.keys.sort
    assert_equal 'ccprocessorb', result[:processor_id]
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(successful_authorization_response, successful_void_response)
    assert_success response
  end

  def test_successful_verify_with_failed_void
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorization_response, failed_void_response)
    assert_success response
    assert_match %r{This transaction has been approved}, response.message
  end

  def test_unsuccessful_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(failed_authorization_response, successful_void_response)
    assert_failure response
    assert_match %r{Invalid Credit Card Number}, response.message
  end

  def test_add_address
    result = {}

    @gateway.send(:add_address, result,   {:address1 => '164 Waverley Street', :country => 'US', :state => 'CO'} )
    assert_equal ["address1", "city", "company", "country", "phone", "state", "zip"], result.stringify_keys.keys.sort
    assert_equal 'CO', result["state"]
    assert_equal '164 Waverley Street', result["address1"]
    assert_equal 'US', result["country"]
  end

  def test_add_shipping_address
    result = {}

    @gateway.send(:add_address, result,   {:address1 => '164 Waverley Street', :country => 'US', :state => 'CO'},"shipping" )
    assert_equal ["shipping_address1", "shipping_city", "shipping_company", "shipping_country", "shipping_phone", "shipping_state", "shipping_zip"], result.stringify_keys.keys.sort
    assert_equal 'CO', result["shipping_state"]
    assert_equal '164 Waverley Street', result["shipping_address1"]
    assert_equal 'US', result["shipping_country"]
  end

  def test_adding_store_adds_vault_id_flag
    result = {}

    @gateway.send(:add_creditcard, result, @credit_card, :store => true)
    assert_equal ["ccexp", "ccnumber", "customer_vault", "cvv", "firstname", "lastname"], result.stringify_keys.keys.sort
    assert_equal 'add_customer', result[:customer_vault]
  end

  def test_blank_store_doesnt_add_vault_flag
    result = {}

    @gateway.send(:add_creditcard, result, @credit_card, {} )
    assert_equal ["ccexp", "ccnumber", "cvv", "firstname", "lastname"], result.stringify_keys.keys.sort
    assert_nil result[:customer_vault]
  end

  def test_accept_check
    post = {}
    check = Check.new(:name => 'Fred Bloggs',
                      :routing_number => '111000025',
                      :account_number => '123456789012',
                      :account_holder_type => 'personal',
                      :account_type => 'checking')
    @gateway.send(:add_check, post, check, {})
    assert_equal %w[account_holder_type account_type checkaba checkaccount checkname payment], post.stringify_keys.keys.sort
  end

  def test_funding_source
    assert_equal :check, @gateway.send(:determine_funding_source, Check.new)
    assert_equal :credit_card, @gateway.send(:determine_funding_source, @credit_card)
    assert_equal :vault, @gateway.send(:determine_funding_source, '12345')
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'N', response.avs_result['code']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'N', response.cvv_result['code']
  end

  def test_add_eci
    @gateway.expects(:commit).with { |_, _, parameters| !parameters.has_key?(:billing_method) }
    @gateway.purchase(@amount, @credit_card, {})

    @gateway.expects(:commit).with { |_, _, parameters| parameters[:billing_method] == 'recurring' }
    @gateway.purchase(@amount, @credit_card, {:eci => 'recurring'})
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  private

  def successful_purchase_response
    'response=1&responsetext=SUCCESS&authcode=123456&transactionid=510695343&avsresponse=N&cvvresponse=N&orderid=ea1e0d50dcc8cfc6e4b55650c592097e&type=sale&response_code=100'
  end

  def failed_purchase_response
    'response=2&responsetext=DECLINE&authcode=&transactionid=510695919&avsresponse=N&cvvresponse=N&orderid=50357660b0b3ef16f72a3d3b83c46983&type=sale&response_code=200'
  end

  def successful_authorization_response
    'response=1&responsetext=SUCCESS&authcode=123456&transactionid=2313367000&avsresponse=N&cvvresponse=N&orderid=fb5fa6d66bf82a6ea48e425e5f79095c&type=auth&response_code=100'
  end

  def failed_authorization_response
    'response=3&responsetext=Invalid Credit Card Number REFID:127210770&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=0cfae165b48be9467b26dcb920bf05d6&type=auth&response_code=300'
  end

  def successful_void_response
    'response=1&responsetext=Transaction Void Successful&authcode=123456&transactionid=2313367000&avsresponse=&cvvresponse=&orderid=fb5fa6d66bf82a6ea48e425e5f79095c&type=void&response_code=100'
  end

  def failed_void_response
    'response=3&responsetext=Only transactions pending settlement can be voided REFID:127210798&authcode=&transactionid=2313369860&avsresponse=&cvvresponse=&orderid=&type=void&response_code=300'
  end

  def successful_store_response
    "response=1&responsetext=Customer Added&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=&type=&response_code=100&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id=853162645"
  end

  def transcript
    "username=demo&password=password&type=sale&orderid=8267b7f890aac7699f6ebc93c7c94d96&ccnumber=4111111111111111&cvv=123&ccexp=0916&firstname=Longbob&lastname=Longsen&address1=456+My+Street&address2=Apt+1&company=Widgets+Inc&phone=%28555%29555-5555&zip=K1C2N6&city=Ottawa&country=CA&state=ON&currency=USD&tax=&amount=77.70"
  end

  def scrubbed_transcript
    "username=demo&password=password&type=sale&orderid=8267b7f890aac7699f6ebc93c7c94d96&ccnumber=[FILTERED]&cvv=[FILTERED]&ccexp=0916&firstname=Longbob&lastname=Longsen&address1=456+My+Street&address2=Apt+1&company=Widgets+Inc&phone=%28555%29555-5555&zip=K1C2N6&city=Ottawa&country=CA&state=ON&currency=USD&tax=&amount=77.70"
  end
end
