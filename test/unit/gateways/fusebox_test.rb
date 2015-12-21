require 'test_helper'

class FuseboxTest < Test::Unit::TestCase
  def setup
    @gateway = FuseboxGateway.new(:terminal_id => 'TERM1', :location_name => 'LOC1', :chain_code => 'CH1')
    @gateway.class.force_inquiry = false

    @credit_card = credit_card
    @expiry = '09%02d' % (Time.now.year % 100 + 1)
    @amount = 100
    @token = "ID:7979582790001/0916"

    @options = {:reference => 8888888}
  end

  def test_required_arguments_on_initialization
    assert_raises ArgumentError do
      FuseboxGateway.new
    end
  end

  def test_default_currency
    assert_equal 'USD', FuseboxGateway.default_currency
  end

  def test_money_format
    assert_equal :dollars, FuseboxGateway.money_format
  end

  def test_supported_cardtypes
    assert_equal [:visa, :master, :american_express, :discover], FuseboxGateway.supported_cardtypes
  end

  def test_display_name
    assert_equal 'Elavon Fusebox', FuseboxGateway.display_name
  end

  def test_successful_purchase
    @gateway.expects(:build_request).with(:mail_order_indicator => '1', :transaction_type => '02', :tax1_indicator => '0', :tax1_amount => '0.00', :transaction_qualifier => '010', :transaction_amount => '1.00', :unique_reference => 8888888, :billing_zip_code => '', :billing_address => '', :cashier_id => '0', :customer_code => 8888888, :account_number => '4242424242424242', :expiration => '0917', :cvc => '123')
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '074393871815333', response.params['transaction_id']
    assert_equal '1115355371978807', response.params['gateway_id']
    assert_equal '1.00', response.params['amount']
    assert_match /^0000, COMPLETE, DEMO71/, response.message
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:build_request).with(:mail_order_indicator => '1', :transaction_type => '02', :tax1_indicator => '0', :tax1_amount => '0.00', :transaction_qualifier => '010', :transaction_amount => '1.00', :unique_reference => 8888888, :billing_zip_code => '', :billing_address => '', :cashier_id => '0', :customer_code => 8888888, :account_number => '4242424242424242', :expiration => '0917', :cvc => '123')
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal nil, response.params[:transaction_id]
    assert_equal '1115355372038809', response.params['gateway_id']
    assert_match /^0041 BAD ACCT NUMBER/, response.message
    assert response.test?
  end

  def test_successful_store
    @gateway.expects(:build_request).with(:token_request => 'ID:', :transaction_qualifier => '010', :transaction_amount => '0.00', :unique_reference => 8888888, :billing_zip_code => '', :billing_address => '', :cashier_id => '0', :customer_code => 8888888, :account_number => '4242424242424242', :expiration => '0917', :cvc => '123', :transaction_type => '01')
    @gateway.expects(:ssl_post).returns(successful_store_response)

    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal '074398711288593', response.params['transaction_id']
    assert_equal '1115356246424627', response.params['gateway_id']
    assert_equal @token, response.params['token']
    assert_match /^0000, COMPLETE, DEMO90/, response.message
    assert response.test?
  end

  def test_successful_store_and_auth_and_reverse
    @gateway.expects(:build_request).with(:token_request => 'ID:', :transaction_qualifier => '010', :transaction_amount => '1.00', :unique_reference => 8888888, :billing_zip_code => '', :billing_address => '', :cashier_id => '0', :customer_code => 8888888, :account_number => '4242424242424242', :expiration => '0917', :cvc => '123', :transaction_type => '01')
    @gateway.expects(:ssl_post).returns(successful_store_response)

    assert response = @gateway.store(@credit_card, @options.merge(:auth_amount => 100))
    assert_success response
    assert_equal '074398711288593', response.params['transaction_id']
    assert_equal '1115356246424627', response.params['gateway_id']
    assert_equal @token, response.params['token']
    assert_match /^0000, COMPLETE, DEMO90/, response.message
    assert response.test?

    @gateway.expects(:build_request).with(:transaction_qualifier => '010', :transaction_amount => '1.00', :unique_reference => 8888888, :billing_zip_code => '', :billing_address => '', :cashier_id => '0', :customer_code => 8888888, :account_number => '4242424242424242', :expiration => '0917', :cvc => '123', :transaction_type => '61')
    @gateway.expects(:ssl_post).returns(successful_auth_reverse_response)
    assert response = @gateway.auth_reversal(100, @credit_card, @options)
    assert_match /^0000, COMPLETE, DEMO37/, response.message
    assert response.test?
  end

  def test_successful_token_purchase
    @gateway.expects(:build_request).with(:mail_order_indicator => '1', :transaction_type => '02', :tax1_indicator => '0', :tax1_amount => '0.00', :transaction_qualifier => '010', :transaction_amount => '1.00', :unique_reference => 8888888, :billing_zip_code => '', :billing_address => '', :cashier_id => '0', :customer_code => 8888888, :account_number => 'ID:7979582790001', :expiration => '0916')
    @gateway.expects(:ssl_post).returns(successful_token_purchase_response)

    assert response = @gateway.purchase(@amount, @token, @options)
    assert_success response
    assert_equal '074398711363098', response.params['transaction_id']
    assert_equal '1115356246434628', response.params['gateway_id']
    assert_match /^0000, COMPLETE, DEMO91/, response.message
    assert_equal '7670391', response.params['reference']
    assert_equal '7670391', response.authorization
    assert_equal 'DEMO91', response.params['approval_code']

    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:build_request).with(:transaction_type => '09', :tax1_indicator => '0', :tax1_amount => '0.00', :transaction_qualifier => '010', :transaction_amount => '1.00', :unique_reference => 8888888, :billing_zip_code => '', :billing_address => '', :cashier_id => '0', :customer_code => 8888888, :account_number => 'ID:7979582790001', :expiration => '0916')
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    assert response = @gateway.refund(@amount, @token, @options)
    assert_success response
    assert_equal '074403878547105', response.params['transaction_id']
    assert_equal '1115357170899561', response.params['gateway_id']
    assert_match /^0000, COMPLETE, DEMO29/, response.message
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:build_request).with(:transaction_qualifier => '010', :transaction_amount => '1.00', :unique_reference => 8888888, :billing_zip_code => '', :billing_address => '', :cashier_id => '0', :customer_code => 8888888, :account_number => 'ID:7979582790001', :expiration => '0916', :transaction_type => '11')
    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert response = @gateway.void(@amount, @token, @options)
    assert_success response
    assert_equal '116042920367558', response.params['transaction_id']
    assert_equal '1116042203752494', response.params['gateway_id']
    assert_match /^0000, COMPLETE, CVI551/, response.message
    assert response.test?
  end

  def test_successful_inquiry
    @gateway.expects(:build_request).with(:mail_order_indicator => '1', :transaction_type => '02', :tax1_indicator => '0', :tax1_amount => '0.00', :transaction_qualifier => '010', :transaction_amount => '1.00', :unique_reference => 8888888, :billing_zip_code => '', :billing_address => '', :cashier_id => '0', :customer_code => 8888888, :account_number => 'ID:7979582790001', :expiration => '0916')
    @gateway.expects(:build_request).with(:mail_order_indicator => '1', :transaction_type => '22', :tax1_indicator => '0', :tax1_amount => '0.00', :transaction_qualifier => '010', :transaction_amount => '1.00', :unique_reference => 8888888, :billing_zip_code => '', :billing_address => '', :cashier_id => '0', :customer_code => 8888888, :account_number => 'ID:7979582790001', :expiration => '0916')
    @gateway.expects(:ssl_post).twice.returns(successful_purchase_response)

    @gateway.class.force_inquiry = true
    assert response = @gateway.purchase(@amount, @token, @options)
    assert_success response
    assert_equal '074393871815333', response.params['transaction_id']
    assert_equal '1115355371978807', response.params['gateway_id']
    assert_match /^0000, COMPLETE, DEMO71/, response.message
    assert response.test?
  end


  private

  def successful_purchase_response
    "<ProtoBase_Transaction_Batch><Settlement_Batch>false</Settlement_Batch><Transaction> <API_Field> <Field_Number>0001</Field_Number> <Field_Value>02</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0002</Field_Number> <Field_Value>1.00</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0003</Field_Number> <Field_Value>*********0001</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0004</Field_Number> <Field_Value>0916</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0006</Field_Number> <Field_Value>DEMO71</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0007</Field_Number> <Field_Value>6931962</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0009</Field_Number> <Field_Value>0012</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0030</Field_Number> <Field_Value>1</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0032</Field_Number> <Field_Value>122115</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0033</Field_Number> <Field_Value>051957</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0034</Field_Number> <Field_Value>E</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0035</Field_Number> <Field_Value>9F57</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0036</Field_Number> <Field_Value>074393871815333</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0037</Field_Number> <Field_Value>5</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0040</Field_Number> <Field_Value>N</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0050</Field_Number> <Field_Value>***</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0054</Field_Number> <Field_Value>00</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0056</Field_Number> <Field_Value>1</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0109</Field_Number> <Field_Value>TERM1</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0112</Field_Number> <Field_Value>400</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0126</Field_Number> <Field_Value>0</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0130</Field_Number> <Field_Value>1.00</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0140</Field_Number> <Field_Value>USD</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0141</Field_Number> <Field_Value>840</Field_Value> a</API_Field>
    <API_Field> <Field_Number>1000</Field_Number> <Field_Value>VI</Field_Value> a</API_Field>
    <API_Field> <Field_Number>1001</Field_Number> <Field_Value>VISA</Field_Value> a</API_Field>
    <API_Field> <Field_Number>1003</Field_Number> <Field_Value>0000</Field_Value> a</API_Field>
    <API_Field> <Field_Number>1004</Field_Number> <Field_Value>COMPLETE</Field_Value> a</API_Field>
    <API_Field> <Field_Number>1008</Field_Number> <Field_Value>*********0001</Field_Value> a</API_Field>
    <API_Field> <Field_Number>1009</Field_Number> <Field_Value>00000</Field_Value> a</API_Field>
    <API_Field> <Field_Number>1010</Field_Number> <Field_Value>COMPLETE</Field_Value> a</API_Field>
    <API_Field> <Field_Number>1012</Field_Number> <Field_Value>0012</Field_Value> a</API_Field>
    <API_Field> <Field_Number>7007</Field_Number> <Field_Value>1115355371978807</Field_Value> a</API_Field>
    <API_Field> <Field_Number>8002</Field_Number> <Field_Value>ETE MOTO</Field_Value> a</API_Field>
    <API_Field> <Field_Number>8006</Field_Number> <Field_Value>TSTLA2</Field_Value> a</API_Field>
    </Transaction></ProtoBase_Transaction_Batch>"
  end

  def failed_purchase_response
    "<ProtoBase_Transaction_Batch><Settlement_Batch>false</Settlement_Batch><Transaction> <API_Field> <Field_Number>0001</Field_Number> <Field_Value>02</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0002</Field_Number> <Field_Value>1.00</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0003</Field_Number> <Field_Value>************0000</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0004</Field_Number> <Field_Value>0916</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0007</Field_Number> <Field_Value>6932014</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0050</Field_Number> <Field_Value>***</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0054</Field_Number> <Field_Value>01</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0056</Field_Number> <Field_Value>1</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0109</Field_Number> <Field_Value>TERM1</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0126</Field_Number> <Field_Value>0</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0140</Field_Number> <Field_Value>USD</Field_Value> a</API_Field>
    <API_Field> <Field_Number>1001</Field_Number> <Field_Value>VISA</Field_Value> a</API_Field>
    <API_Field> <Field_Number>1003</Field_Number> <Field_Value>0041</Field_Value> a</API_Field>
    <API_Field> <Field_Number>1004</Field_Number> <Field_Value>BAD ACCT NUMBER</Field_Value> a</API_Field>
    <API_Field> <Field_Number>1008</Field_Number> <Field_Value>************0000</Field_Value> a</API_Field>
    <API_Field> <Field_Number>1010</Field_Number> <Field_Value>BAD ACCT NUMBER</Field_Value> a</API_Field>
    <API_Field> <Field_Number>7007</Field_Number> <Field_Value>1115355372038809</Field_Value> a</API_Field>
    <API_Field> <Field_Number>8002</Field_Number> <Field_Value>ETE MOTO</Field_Value> a</API_Field>
    <API_Field> <Field_Number>8006</Field_Number> <Field_Value>TSTLA2</Field_Value> a</API_Field>
    </Transaction></ProtoBase_Transaction_Batch>"
  end

  def successful_store_response
    "<ProtoBase_Transaction_Batch><Settlement_Batch>false</Settlement_Batch><Transaction> <API_Field> <Field_Number>0001</Field_Number>    <Field_Value>01</Field_Value> a</API_Field>
    <API_Field>    <Field_Number>0002</Field_Number> <Field_Value>0.00</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0003</Field_Number> <Field_Value>ID:7979582790001</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0004</Field_Number> <Field_Value>0916</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0006</Field_Number> <Field_Value>DEMO90</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0007</Field_Number> <Field_Value>7670391</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0009</Field_Number> <Field_Value>0012</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0030</Field_Number> <Field_Value>1</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0032</Field_Number> <Field_Value>122215</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0033</Field_Number> <Field_Value>015042</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0034</Field_Number> <Field_Value>E</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0035</Field_Number> <Field_Value>0F42</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0036</Field_Number> <Field_Value>074398711288593</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0037</Field_Number> <Field_Value>5</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0040</Field_Number> <Field_Value>N</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0050</Field_Number> <Field_Value>***</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0054</Field_Number> <Field_Value>00</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0056</Field_Number> <Field_Value>1</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0109</Field_Number> <Field_Value>TERM1</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0112</Field_Number> <Field_Value>400</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0126</Field_Number> <Field_Value>0</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0128</Field_Number> <Field_Value>0.00</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0130</Field_Number> <Field_Value>0.00</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0131</Field_Number> <Field_Value>00</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0140</Field_Number> <Field_Value>USD</Field_Value> a</API_Field>
    <API_Field> <Field_Number>0141</Field_Number> <Field_Value>840</Field_Value> a</API_Field>
    <API_Field> <Field_Number>1000</Field_Number> <Field_Value>VI</Field_Value> a</API_Field>
    <API_Field> <Field_Number>1001</Field_Number> <Field_Value>VISA</Field_Value> a</API_Field>
    <API_Field> <Field_Number>1003</Field_Number> <Field_Value>0000</Field_Value> a</API_Field>
    <API_Field> <Field_Number>1004</Field_Number> <Field_Value>COMPLETE</Field_Value> a</API_Field>
    <API_Field> <Field_Number>1008</Field_Number> <Field_Value>*********0001</Field_Value> a</API_Field>
    <API_Field> <Field_Number>1009</Field_Number> <Field_Value>00000</Field_Value> a</API_Field>
    <API_Field> <Field_Number>1010</Field_Number> <Field_Value>COMPLETE</Field_Value> a</API_Field>
    <API_Field> <Field_Number>1012</Field_Number> <Field_Value>0012</Field_Value> a</API_Field>
    <API_Field> <Field_Number>7007</Field_Number> <Field_Value>1115356246424627</Field_Value> a</API_Field>
    <API_Field> <Field_Number>8002</Field_Number> <Field_Value>ETE MOTO</Field_Value> a</API_Field>
    <API_Field> <Field_Number>8006</Field_Number> <Field_Value>TSTLA2</Field_Value> a</API_Field>
    </Transaction></ProtoBase_Transaction_Batch> "
  end

  def successful_token_purchase_response
    "<ProtoBase_Transaction_Batch><Settlement_Batch>false</Settlement_Batch><Transaction> <API_Field>    <Field_Number>0001</Field_Number>    <Field_Value>02</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0002</Field_Number>    <Field_Value>1.00</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0003</Field_Number>    <Field_Value>ID:7979582790001</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0006</Field_Number>    <Field_Value>DEMO91</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0007</Field_Number>    <Field_Value>7670391</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0009</Field_Number>    <Field_Value>0012</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0030</Field_Number>    <Field_Value>1</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0032</Field_Number>    <Field_Value>122215</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0033</Field_Number>    <Field_Value>015043</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0034</Field_Number>    <Field_Value>E</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0035</Field_Number>    <Field_Value>0F43</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0036</Field_Number>    <Field_Value>074398711363098</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0037</Field_Number>    <Field_Value>5</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0054</Field_Number>    <Field_Value>00</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0109</Field_Number>    <Field_Value>TERM1</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0112</Field_Number>    <Field_Value>400</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0126</Field_Number>    <Field_Value>0</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0130</Field_Number>    <Field_Value>1.00</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0140</Field_Number>    <Field_Value>USD</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0141</Field_Number>    <Field_Value>840</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>1000</Field_Number>    <Field_Value>VI</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>1001</Field_Number>    <Field_Value>VISA</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>1003</Field_Number>    <Field_Value>0000</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>1004</Field_Number>    <Field_Value>COMPLETE</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>1008</Field_Number>    <Field_Value>*********0001</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>1009</Field_Number>    <Field_Value>00000</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>1010</Field_Number>    <Field_Value>COMPLETE</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>1012</Field_Number>    <Field_Value>0012</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>7007</Field_Number>    <Field_Value>1115356246434628</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>8002</Field_Number>    <Field_Value>ETE MOTO</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>8006</Field_Number>    <Field_Value>TSTLA2</Field_Value>    a</API_Field>
    </Transaction></ProtoBase_Transaction_Batch>
    "
  end

  def successful_refund_response
    "<ProtoBase_Transaction_Batch><Settlement_Batch>false</Settlement_Batch><Transaction> <API_Field>    <Field_Number>0001</Field_Number>    <Field_Value>11</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0002</Field_Number>    <Field_Value>1.00</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0003</Field_Number>    <Field_Value>ID:7979582790001</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0006</Field_Number>    <Field_Value>DEMO29</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0007</Field_Number>    <Field_Value>8458862</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0009</Field_Number>    <Field_Value>0012</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0030</Field_Number>    <Field_Value>1</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0032</Field_Number>    <Field_Value>122215</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0033</Field_Number>    <Field_Value>234448</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0034</Field_Number>    <Field_Value>E</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0035</Field_Number>    <Field_Value>4F48</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0036</Field_Number>    <Field_Value>074403878547105</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0037</Field_Number>    <Field_Value>5</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0054</Field_Number>    <Field_Value>01</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0109</Field_Number>    <Field_Value>TERM1</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0112</Field_Number>    <Field_Value>400</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0126</Field_Number>    <Field_Value>0</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0128</Field_Number>    <Field_Value>1.00</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0130</Field_Number>    <Field_Value>1.00</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0131</Field_Number>    <Field_Value>00</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0132</Field_Number>    <Field_Value>0</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0140</Field_Number>    <Field_Value>USD</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>0141</Field_Number>    <Field_Value>840</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>1000</Field_Number>    <Field_Value>VI</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>1001</Field_Number>    <Field_Value>VISA</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>1003</Field_Number>    <Field_Value>0000</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>1004</Field_Number>    <Field_Value>ACKNOWLEDGED</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>1005</Field_Number>    <Field_Value>0010600008014593738999</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>1008</Field_Number>    <Field_Value>*********0001</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>1010</Field_Number>    <Field_Value>COMPLETE</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>1012</Field_Number>    <Field_Value>0012</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>7007</Field_Number>    <Field_Value>1115357170899561</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>8002</Field_Number>    <Field_Value>ETE MOTO</Field_Value>    a</API_Field>
    <API_Field>    <Field_Number>8006</Field_Number>    <Field_Value>TSTLA2</Field_Value>    a</API_Field>
    </Transaction></ProtoBase_Transaction_Batch>
    "
  end

  def successful_void_response
    "<ProtoBase_Transaction_Batch><Settlement_Batch>false</Settlement_Batch><Transaction> <API_Field> <Field_Number>0001</Field_Number> <Field_Value>11</Field_Value> </API_Field>
    <API_Field> <Field_Number>0002</Field_Number> <Field_Value>90.00</Field_Value> </API_Field>
    <API_Field> <Field_Number>0003</Field_Number> <Field_Value>ID:4357191872120689</Field_Value> </API_Field>
    <API_Field> <Field_Number>0004</Field_Number> <Field_Value>1221</Field_Value> </API_Field>
    <API_Field> <Field_Number>0006</Field_Number> <Field_Value>CVI551</Field_Value> </API_Field>
    <API_Field> <Field_Number>0007</Field_Number> <Field_Value>69165135</Field_Value> </API_Field>
    <API_Field> <Field_Number>0009</Field_Number> <Field_Value>0006</Field_Value> </API_Field>
    <API_Field> <Field_Number>0030</Field_Number> <Field_Value>1</Field_Value> </API_Field>
    <API_Field> <Field_Number>0032</Field_Number> <Field_Value>021116</Field_Value> </API_Field>
    <API_Field> <Field_Number>0033</Field_Number> <Field_Value>003927</Field_Value> </API_Field>
    <API_Field> <Field_Number>0034</Field_Number> <Field_Value>W</Field_Value> </API_Field>
    <API_Field> <Field_Number>0035</Field_Number> <Field_Value>788F</Field_Value> </API_Field>
    <API_Field> <Field_Number>0036</Field_Number> <Field_Value>116042920367558</Field_Value> </API_Field>
    <API_Field> <Field_Number>0037</Field_Number> <Field_Value>0</Field_Value> </API_Field>
    <API_Field> <Field_Number>0043</Field_Number> <Field_Value>102701</Field_Value> </API_Field>
    <API_Field> <Field_Number>0049</Field_Number> <Field_Value>J3</Field_Value> </API_Field>
    <API_Field> <Field_Number>0054</Field_Number> <Field_Value>01</Field_Value> </API_Field>
    <API_Field> <Field_Number>0070</Field_Number> <Field_Value>69165135</Field_Value> </API_Field>
    <API_Field> <Field_Number>0109</Field_Number> <Field_Value>TERM1</Field_Value> </API_Field>
    <API_Field> <Field_Number>0110</Field_Number> <Field_Value>0</Field_Value> </API_Field>
    <API_Field> <Field_Number>0112</Field_Number> <Field_Value>400</Field_Value> </API_Field>
    <API_Field> <Field_Number>0125</Field_Number> <Field_Value>211003927</Field_Value> </API_Field>
    <API_Field> <Field_Number>0126</Field_Number> <Field_Value>0</Field_Value> </API_Field>
    <API_Field> <Field_Number>0128</Field_Number> <Field_Value>90.00</Field_Value> </API_Field>
    <API_Field> <Field_Number>0129</Field_Number> <Field_Value>1</Field_Value> </API_Field>
    <API_Field> <Field_Number>0130</Field_Number> <Field_Value>90.00</Field_Value> </API_Field>
    <API_Field> <Field_Number>0131</Field_Number> <Field_Value>00</Field_Value> </API_Field>
    <API_Field> <Field_Number>0132</Field_Number> <Field_Value>0</Field_Value> </API_Field>
    <API_Field> <Field_Number>0140</Field_Number> <Field_Value>USD</Field_Value>   </API_Field>
    <API_Field> <Field_Number>0141</Field_Number> <Field_Value>840</Field_Value>   </API_Field>
    <API_Field> <Field_Number>0190</Field_Number> <Field_Value>7</Field_Value> </API_Field>
    <API_Field> <Field_Number>0651</Field_Number> <Field_Value>0000000</Field_Value> </API_Field>
    <API_Field> <Field_Number>0712</Field_Number> <Field_Value>2</Field_Value> </API_Field>
    <API_Field> <Field_Number>1000</Field_Number> <Field_Value>VI</Field_Value> </API_Field>
    <API_Field> <Field_Number>1001</Field_Number> <Field_Value>VISA</Field_Value>  </API_Field>
    <API_Field> <Field_Number>1003</Field_Number> <Field_Value>0000</Field_Value>  </API_Field>
    <API_Field> <Field_Number>1004</Field_Number> <Field_Value>ACKNOWLEDGED</Field_Value> </API_Field>
    <API_Field> <Field_Number>1005</Field_Number> <Field_Value>0010600008014594231999</Field_Value> </API_Field>
    <API_Field> <Field_Number>1008</Field_Number> <Field_Value>************0689</Field_Value> </API_Field>
    <API_Field> <Field_Number>1010</Field_Number> <Field_Value>COMPLETE</Field_Value> </API_Field>
    <API_Field> <Field_Number>1012</Field_Number> <Field_Value>0006</Field_Value>  </API_Field>
    <API_Field> <Field_Number>1200</Field_Number> <Field_Value>0000AA</Field_Value> </API_Field>
    <API_Field> <Field_Number>7007</Field_Number> <Field_Value>1116042203752494</Field_Value> </API_Field>
    <API_Field> <Field_Number>8002</Field_Number> <Field_Value>CHARGIFY</Field_Value> </API_Field>
    <API_Field> <Field_Number>8006</Field_Number> <Field_Value>TSTLA3</Field_Value> </API_Field>
    </Transaction></ProtoBase_Transaction_Batch>
    "
  end

  def successful_auth_reverse_response
    "<ProtoBase_Transaction_Batch><Settlement_Batch>false</Settlement_Batch><Transaction>
    <API_Field><Field_Number>0001</Field_Number><Field_Value>61</Field_Value></API_Field>
    <API_Field><Field_Number>0002</Field_Number><Field_Value>1.00</Field_Value></API_Field>
    <API_Field><Field_Number>0003</Field_Number><Field_Value>ID:7979582790001</Field_Value></API_Field>
    <API_Field><Field_Number>0004</Field_Number><Field_Value>0917</Field_Value></API_Field>
    <API_Field><Field_Number>0006</Field_Number><Field_Value>DEMO37</Field_Value></API_Field>
    <API_Field><Field_Number>0007</Field_Number><Field_Value>11437951</Field_Value></API_Field>
    <API_Field><Field_Number>0009</Field_Number><Field_Value>0021</Field_Value></API_Field>
    <API_Field><Field_Number>0030</Field_Number><Field_Value>1</Field_Value></API_Field>
    <API_Field><Field_Number>0032</Field_Number><Field_Value>042016</Field_Value></API_Field>
    <API_Field><Field_Number>0033</Field_Number><Field_Value>051639</Field_Value></API_Field>
    <API_Field><Field_Number>0034</Field_Number><Field_Value>E</Field_Value></API_Field>
    <API_Field><Field_Number>0035</Field_Number><Field_Value>6F39</Field_Value></API_Field>
    <API_Field><Field_Number>0036</Field_Number><Field_Value>075078762457213</Field_Value></API_Field>
    <API_Field><Field_Number>0037</Field_Number><Field_Value>5</Field_Value></API_Field>
    <API_Field><Field_Number>0040</Field_Number><Field_Value>N</Field_Value></API_Field>
    <API_Field><Field_Number>0054</Field_Number><Field_Value>00</Field_Value></API_Field>
    <API_Field><Field_Number>0070</Field_Number><Field_Value>11437951</Field_Value></API_Field>
    <API_Field><Field_Number>0109</Field_Number><Field_Value>TERM1</Field_Value></API_Field>
    <API_Field><Field_Number>0110</Field_Number><Field_Value>0</Field_Value></API_Field>
    <API_Field><Field_Number>0112</Field_Number><Field_Value>400</Field_Value></API_Field>
    <API_Field><Field_Number>0115</Field_Number><Field_Value>010</Field_Value></API_Field>
    <API_Field><Field_Number>0126</Field_Number><Field_Value>0</Field_Value></API_Field>
    <API_Field><Field_Number>0128</Field_Number><Field_Value>1.00</Field_Value></API_Field>
    <API_Field><Field_Number>0130</Field_Number><Field_Value>1.00</Field_Value></API_Field>
    <API_Field><Field_Number>0131</Field_Number><Field_Value>00</Field_Value></API_Field>
    <API_Field><Field_Number>0132</Field_Number><Field_Value>0</Field_Value></API_Field>
    <API_Field><Field_Number>0140</Field_Number><Field_Value>USD</Field_Value></API_Field>
    <API_Field><Field_Number>0141</Field_Number><Field_Value>840</Field_Value></API_Field>
    <API_Field><Field_Number>1000</Field_Number><Field_Value>VI</Field_Value></API_Field>
    <API_Field><Field_Number>1001</Field_Number><Field_Value>VISA</Field_Value></API_Field>
    <API_Field><Field_Number>1003</Field_Number><Field_Value>0000</Field_Value></API_Field>
    <API_Field><Field_Number>1004</Field_Number><Field_Value>COMPLETE</Field_Value></API_Field>
    <API_Field><Field_Number>1008</Field_Number><Field_Value>*********0001</Field_Value></API_Field>
    <API_Field><Field_Number>1009</Field_Number><Field_Value>00000</Field_Value></API_Field>
    <API_Field><Field_Number>1010</Field_Number><Field_Value>COMPLETE</Field_Value></API_Field>
    <API_Field><Field_Number>1012</Field_Number><Field_Value>0021</Field_Value></API_Field>
    <API_Field><Field_Number>7007</Field_Number><Field_Value>1116111333997614</Field_Value></API_Field>
    <API_Field><Field_Number>8002</Field_Number><Field_Value>ETE MOTO</Field_Value></API_Field>
    <API_Field><Field_Number>8006</Field_Number><Field_Value>TSTLA2</Field_Value></API_Field>
    </Transaction></ProtoBase_Transaction_Batch>
    "
  end
end
