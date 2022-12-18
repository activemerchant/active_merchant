require 'test_helper'

class InspireTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = InspireGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )
    @credit_card = credit_card('4242424242424242')
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

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.refund(nil, "identifier")
    end.check_request do |_, data, _|
      assert_match %r{identifier}, data
      assert_no_match %r{amount}, data
    end.respond_with(successful_refund_response)
    assert_success response
  end

  def test_partial_refund
    response = stub_comms do
      @gateway.refund(100, "identifier")
    end.check_request do |_, data, _|
      assert_match %r{identifier}, data
      assert_match %r{amount}, data
    end.respond_with(successful_refund_response)
    assert_success response
  end

  def test_failed_refund
    response = stub_comms do
      @gateway.refund(nil, "identifier")
    end.respond_with(failed_refund_response)
    assert_failure response
  end

  def test_add_address
    result = {}

    @gateway.send(:add_address, result, nil, billing_address: { address1: '164 Waverley Street', country: 'US', state: 'CO' })
    assert_equal %w[address1 city company country phone state zip], result.stringify_keys.keys.sort
    assert_equal 'CO', result[:state]
    assert_equal '164 Waverley Street', result[:address1]
    assert_equal 'US', result[:country]
  end

  def test_supported_countries
    assert_equal ['US'], InspireGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express], InspireGateway.supported_cardtypes
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
    @gateway.send(:add_check, post, check)
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

  private

  def successful_purchase_response
    'response=1&responsetext=SUCCESS&authcode=123456&transactionid=510695343&avsresponse=N&cvvresponse=N&orderid=ea1e0d50dcc8cfc6e4b55650c592097e&type=sale&response_code=100'
  end

  def failed_purchase_response
    'response=2&responsetext=DECLINE&authcode=&transactionid=510695919&avsresponse=N&cvvresponse=N&orderid=50357660b0b3ef16f72a3d3b83c46983&type=sale&response_code=200'
  end

  def successful_refund_response
    "response=1&responsetext=SUCCESS&authcode=&transactionid=2594884528&avsresponse=&cvvresponse=&orderid=&type=refund&response_code=100"
  end

  def failed_refund_response
    "response=3&responsetext=Invalid Transaction ID specified REFID:3150951931&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=&type=refund&response_code=300"
  end
end

