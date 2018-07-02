require 'test_helper'

class FirstPayTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = FirstPayGateway.new(
      transaction_center_id: 1234,
      gateway_id: 'a91c38c3-7d7f-4d29-acc7-927b4dca0dbe'
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: SecureRandom.hex(24),
      billing_address: address
    }
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/<FIELD KEY="transaction_center_id">1234<\/FIELD>/, data)
      assert_match(/<FIELD KEY="gateway_id">a91c38c3-7d7f-4d29-acc7-927b4dca0dbe<\/FIELD>/, data)
      assert_match(/<FIELD KEY="operation_type">sale<\/FIELD>/, data)
      assert_match(/<FIELD KEY="order_id">#{@options[:order_id]}<\/FIELD>/, data)
      assert_match(/<FIELD KEY="total">1.00<\/FIELD>/, data)
      assert_match(/<FIELD KEY="card_name">#{@credit_card.brand}<\/FIELD>/, data)
      assert_match(/<FIELD KEY="card_number">#{@credit_card.number}<\/FIELD>/, data)
      assert_match(/<FIELD KEY="card_exp">#{@gateway.expdate(@credit_card)}<\/FIELD>/, data)
      assert_match(/<FIELD KEY="cvv2">#{@credit_card.verification_value}<\/FIELD>/, data)
      assert_match(/<FIELD KEY="owner_name">#{@options[:billing_address][:name]}<\/FIELD>/, data)
      assert_match(/<FIELD KEY="owner_street">#{@options[:billing_address][:address1]}<\/FIELD>/, data)
      assert_match(/<FIELD KEY="owner_street2">#{@options[:billing_address][:address2]}<\/FIELD>/, data)
      assert_match(/<FIELD KEY="owner_city">#{@options[:billing_address][:city]}<\/FIELD>/, data)
      assert_match(/<FIELD KEY="owner_state">#{@options[:billing_address][:state]}<\/FIELD>/, data)
      assert_match(/<FIELD KEY="owner_zip">#{@options[:billing_address][:zip]}<\/FIELD>/, data)
      assert_match(/<FIELD KEY="owner_country">#{@options[:billing_address][:country]}<\/FIELD>/, data)
      assert_match(/<FIELD KEY="owner_phone">/, data) # The () in phone num seems to break this?
    end.respond_with(successful_purchase_response)

    assert response
    assert_instance_of Response, response
    assert_success response
    assert_equal '47913', response.authorization
    assert_equal 'Approved', response.message
  end

  def test_failed_purchase
    @gateway.stubs(:ssl_post).returns(failed_purchase_response)
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert response
    assert_instance_of Response, response
    assert_failure response
    assert_equal '47915', response.authorization
    assert_equal 'Declined', response.message
  end

  def test_successful_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/<FIELD KEY="transaction_center_id">1234<\/FIELD>/, data)
      assert_match(/<FIELD KEY="gateway_id">a91c38c3-7d7f-4d29-acc7-927b4dca0dbe<\/FIELD>/, data)
      assert_match(/<FIELD KEY="operation_type">auth<\/FIELD>/, data)
      assert_match(/<FIELD KEY="order_id">#{@options[:order_id]}<\/FIELD>/, data)
      assert_match(/<FIELD KEY="total">1.00<\/FIELD>/, data)
      assert_match(/<FIELD KEY="card_name">#{@credit_card.brand}<\/FIELD>/, data)
      assert_match(/<FIELD KEY="card_number">#{@credit_card.number}<\/FIELD>/, data)
      assert_match(/<FIELD KEY="card_exp">#{@gateway.expdate(@credit_card)}<\/FIELD>/, data)
      assert_match(/<FIELD KEY="cvv2">#{@credit_card.verification_value}<\/FIELD>/, data)
      assert_match(/<FIELD KEY="owner_name">#{@options[:billing_address][:name]}<\/FIELD>/, data)
      assert_match(/<FIELD KEY="owner_street">#{@options[:billing_address][:address1]}<\/FIELD>/, data)
      assert_match(/<FIELD KEY="owner_street2">#{@options[:billing_address][:address2]}<\/FIELD>/, data)
      assert_match(/<FIELD KEY="owner_city">#{@options[:billing_address][:city]}<\/FIELD>/, data)
      assert_match(/<FIELD KEY="owner_state">#{@options[:billing_address][:state]}<\/FIELD>/, data)
      assert_match(/<FIELD KEY="owner_zip">#{@options[:billing_address][:zip]}<\/FIELD>/, data)
      assert_match(/<FIELD KEY="owner_country">#{@options[:billing_address][:country]}<\/FIELD>/, data)
      assert_match(/<FIELD KEY="owner_phone">/, data) # The () in phone num seems to break this?
    end.respond_with(successful_authorize_response)

    assert response
    assert_instance_of Response, response
    assert_success response
    assert_equal '47920', response.authorization
    assert_equal 'Approved', response.message
  end

  def test_failed_authorize
    @gateway.stubs(:ssl_post).returns(failed_authorize_response)
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_failure response
    assert_equal '47924', response.authorization
    assert_equal 'Declined', response.message
  end

  def test_successful_capture
    response = stub_comms do
      @gateway.capture(@amount, '47920')
    end.check_request do |endpoint, data, headers|
      assert_match(/<FIELD KEY="transaction_center_id">1234<\/FIELD>/, data)
      assert_match(/<FIELD KEY="gateway_id">a91c38c3-7d7f-4d29-acc7-927b4dca0dbe<\/FIELD>/, data)
      assert_match(/<FIELD KEY="operation_type">settle<\/FIELD>/, data)
      assert_match(/<FIELD KEY="total_number_transactions">1<\/FIELD>/, data)
      assert_match(/<FIELD KEY="reference_number1">47920<\/FIELD>/, data)
      assert_match(/<FIELD KEY="settle_amount1">1.00<\/FIELD>/, data)
    end.respond_with(successful_capture_response)

    assert response
    assert_instance_of Response, response
    assert_success response
    assert_equal '47920', response.authorization
    assert_equal 'Approved', response.message
  end

  def test_failed_capture
    @gateway.stubs(:ssl_post).returns(failed_capture_response)
    response = @gateway.capture(@amount, '47920')

    assert_failure response
    assert_equal '47920', response.authorization
    assert response.message.include?('Settle failed')
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.refund(@amount, '47925')
    end.check_request do |endpoint, data, headers|
      assert_match(/<FIELD KEY="transaction_center_id">1234<\/FIELD>/, data)
      assert_match(/<FIELD KEY="gateway_id">a91c38c3-7d7f-4d29-acc7-927b4dca0dbe<\/FIELD>/, data)
      assert_match(/<FIELD KEY="operation_type">credit<\/FIELD>/, data)
      assert_match(/<FIELD KEY="total_number_transactions">1<\/FIELD>/, data)
      assert_match(/<FIELD KEY="reference_number1">47925<\/FIELD>/, data)
      assert_match(/<FIELD KEY="credit_amount1">1.00<\/FIELD>/, data)
    end.respond_with(successful_refund_response)

    assert response
    assert_instance_of Response, response
    assert_success response
    assert_equal '47925', response.authorization
    assert_equal 'Accepted', response.message
  end

  def test_failed_refund
    @gateway.stubs(:ssl_post).returns(failed_refund_response)
    response = @gateway.capture(@amount, '47925')

    assert_failure response
    assert_equal '47925', response.authorization
    assert response.message.include?('Credit failed')
  end

  def test_successful_void
    response = stub_comms do
      @gateway.void('47934')
    end.check_request do |endpoint, data, headers|
      assert_match(/<FIELD KEY="transaction_center_id">1234<\/FIELD>/, data)
      assert_match(/<FIELD KEY="gateway_id">a91c38c3-7d7f-4d29-acc7-927b4dca0dbe<\/FIELD>/, data)
      assert_match(/<FIELD KEY="operation_type">void<\/FIELD>/, data)
      assert_match(/<FIELD KEY="total_number_transactions">1<\/FIELD>/, data)
      assert_match(/<FIELD KEY="reference_number1">47934<\/FIELD>/, data)
    end.respond_with(successful_void_response)

    assert response
    assert_instance_of Response, response
    assert_success response
    assert_equal '47934', response.authorization
    assert_equal 'Approved', response.message
  end

  def test_failed_void
    @gateway.stubs(:ssl_post).returns(failed_void_response)
    response = @gateway.void('1')

    assert_failure response
    assert_equal '1', response.authorization
    assert response.message.include?('Void failed')
  end

  private

  def successful_purchase_response
    %(<RESPONSE>
  <FIELDS>
    <FIELD KEY="status">1</FIELD>
    <FIELD KEY="auth_code">DEMO48</FIELD>
    <FIELD KEY="auth_response">APPROVED</FIELD>
    <FIELD KEY="avs_code">Z</FIELD>
    <FIELD KEY="cvv2_code"> </FIELD>
    <FIELD KEY="order_id">#{@options[:order_id]}</FIELD>
    <FIELD KEY="reference_number">47913</FIELD>
    <FIELD KEY="error" />
    <FIELD KEY="available_balance" />
    <FIELD KEY="is_partial">0</FIELD>
    <FIELD KEY="partial_amount">0</FIELD>
    <FIELD KEY="partial_id" />
    <FIELD KEY="original_full_amount" />
    <FIELD KEY="outstanding_balance">0</FIELD>
  </FIELDS>
</RESPONSE>)
  end

  def failed_purchase_response
    %(<RESPONSE>
  <FIELDS>
    <FIELD KEY="status">2</FIELD>
    <FIELD KEY="auth_code" />
    <FIELD KEY="auth_response">Declined</FIELD>
    <FIELD KEY="avs_code"> </FIELD>
    <FIELD KEY="cvv2_code"> </FIELD>
    <FIELD KEY="order_id">#{@options[:order_id]}</FIELD>
    <FIELD KEY="reference_number">47915</FIELD>
    <FIELD KEY="error" />
    <FIELD KEY="available_balance" />
    <FIELD KEY="is_partial">0</FIELD>
    <FIELD KEY="partial_amount">0</FIELD>
    <FIELD KEY="partial_id" />
    <FIELD KEY="original_full_amount" />
    <FIELD KEY="outstanding_balance">0</FIELD>
  </FIELDS>
</RESPONSE>)
  end

  def successful_authorize_response
    %(<RESPONSE>
  <FIELDS>
    <FIELD KEY="status">1</FIELD>
    <FIELD KEY="auth_code">DEMO80</FIELD>
    <FIELD KEY="auth_response">APPROVED</FIELD>
    <FIELD KEY="avs_code">Z</FIELD>
    <FIELD KEY="cvv2_code"> </FIELD>
    <FIELD KEY="order_id">#{@options[:order_id]}</FIELD>
    <FIELD KEY="reference_number">47920</FIELD>
    <FIELD KEY="error" />
    <FIELD KEY="available_balance" />
    <FIELD KEY="is_partial">0</FIELD>
    <FIELD KEY="partial_amount">0</FIELD>
    <FIELD KEY="partial_id" />
    <FIELD KEY="original_full_amount" />
    <FIELD KEY="outstanding_balance">0</FIELD>
  </FIELDS>
</RESPONSE>)
  end

  def failed_authorize_response
    %(<RESPONSE>
  <FIELDS>
    <FIELD KEY="status">2</FIELD>
    <FIELD KEY="auth_code" />
    <FIELD KEY="auth_response">Declined</FIELD>
    <FIELD KEY="avs_code"> </FIELD>
    <FIELD KEY="cvv2_code"> </FIELD>
    <FIELD KEY="order_id">#{@options[:order_id]}</FIELD>
    <FIELD KEY="reference_number">47924</FIELD>
    <FIELD KEY="error" />
    <FIELD KEY="available_balance" />
    <FIELD KEY="is_partial">0</FIELD>
    <FIELD KEY="partial_amount">0</FIELD>
    <FIELD KEY="partial_id" />
    <FIELD KEY="original_full_amount" />
    <FIELD KEY="outstanding_balance">0</FIELD>
  </FIELDS>
</RESPONSE>)
  end

  def successful_capture_response
    %(<RESPONSE>
  <FIELDS>
    <FIELD KEY="total_transactions_settled">1</FIELD>
    <FIELD KEY="total_amount_settled">1</FIELD>
    <FIELD KEY="status1">1</FIELD>
    <FIELD KEY="response1">APPROVED</FIELD>
    <FIELD KEY="reference_number1">47920</FIELD>
    <FIELD KEY="batch_number1">20140623</FIELD>
    <FIELD KEY="settle_amount1">1.00</FIELD>
    <FIELD KEY="error1" />
  </FIELDS>
</RESPONSE>)
  end

  def failed_capture_response
    %(<RESPONSE>
  <FIELDS>
    <FIELD KEY="total_transactions_settled">0</FIELD>
    <FIELD KEY="total_amount_settled">0</FIELD>
    <FIELD KEY="status1">2</FIELD>
    <FIELD KEY="response1">Settle Failed. Transaction cannot be settled. Auth not found. Make sure the settlement amount does not exceed the original auth amount and that is was authorized less then 30 days ago.</FIELD>
    <FIELD KEY="reference_number1">47920</FIELD>
    <FIELD KEY="batch_number1" />
    <FIELD KEY="settle_amount1">1.00</FIELD>
    <FIELD KEY="error1" />
  </FIELDS>
</RESPONSE>)
  end

  def successful_refund_response
    %(<RESPONSE>
  <FIELDS>
    <FIELD KEY="total_transactions_credited">1</FIELD>
    <FIELD KEY="status1">1</FIELD>
    <FIELD KEY="response1">ACCEPTED</FIELD>
    <FIELD KEY="reference_number1">47925</FIELD>
    <FIELD KEY="credit_amount1">1.00</FIELD>
    <FIELD KEY="error1" />
  </FIELDS>
</RESPONSE>)
  end

  def failed_refund_response
    %(<RESPONSE>
  <FIELDS>
    <FIELD KEY="total_transactions_credited">0</FIELD>
    <FIELD KEY="status1">2</FIELD>
    <FIELD KEY="response1">Credit Failed. Transaction cannot be credited.</FIELD>
    <FIELD KEY="reference_number1">47925</FIELD>
    <FIELD KEY="credit_amount1">1.00</FIELD>
    <FIELD KEY="error1" />
  </FIELDS>
</RESPONSE>)
  end

  def successful_void_response
    %(<RESPONSE>
  <FIELDS>
    <FIELD KEY="total_transactions_voided">1</FIELD>
    <FIELD KEY="status1">1</FIELD>
    <FIELD KEY="response1">APPROVED</FIELD>
    <FIELD KEY="reference_number1">47934</FIELD>
    <FIELD KEY="error1" />
  </FIELDS>
</RESPONSE>)
  end

  def failed_void_response
    %(<RESPONSE>
  <FIELDS>
    <FIELD KEY="total_transactions_voided">0</FIELD>
    <FIELD KEY="status1">2</FIELD>
    <FIELD KEY="response1">Void Failed. Transaction cannot be voided.</FIELD>
    <FIELD KEY="reference_number1">1</FIELD>
    <FIELD KEY="error1" />
  </FIELDS>
</RESPONSE>)
  end
end
