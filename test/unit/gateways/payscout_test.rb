require 'test_helper'

class PayscoutTest < Test::Unit::TestCase
  def setup
    @gateway = PayscoutGateway.new(
                 :username => 'xxx',
                 :password => 'xxx'
               )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  # Purchase

  def test_approved_puschase
    @gateway.expects(:ssl_post).returns(approved_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '1234567891', response.authorization
    assert_equal 'The transaction has been approved', response.message
    assert response.test?
  end

  def test_declined_puschase
    @gateway.expects(:ssl_post).returns(declined_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response

    assert_equal '1234567892', response.authorization
    assert_equal 'The transaction has been declined', response.message
    assert response.test?
  end

  # Authorization

  def test_approved_authorization
    @gateway.expects(:ssl_post).returns(approved_authorization_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '1234567890', response.authorization
    assert_equal 'The transaction has been approved', response.message
    assert response.test?
  end

  def test_declined_authorization
    @gateway.expects(:ssl_post).returns(declined_authorization_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response

    assert_equal '1234567893', response.authorization
    assert_equal 'The transaction has been declined', response.message
    assert response.test?
  end

  # Capture

  def test_approved_capture
    @gateway.expects(:ssl_post).returns(approved_capture_response)

    assert response = @gateway.capture(@amount, '1234567894', @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '1234567894', response.authorization
    assert_equal 'The transaction has been approved', response.message
    assert response.test?
  end

  def test_invalid_amount_capture
    @gateway.expects(:ssl_post).returns(invalid_amount_capture_response)

    assert response = @gateway.capture(@amount, '1234567895', @options)
    assert_instance_of Response, response
    assert_failure response

    assert_equal '1234567895', response.authorization
    assert_equal 'The+specified+amount+of+2.00+exceeds+the+authorization+amount+of+1.00', response.message
    assert response.test?
  end

  def test_not_found_transaction_id_capture
    @gateway.expects(:ssl_post).returns(not_found_transaction_id_capture_response)

    assert capture = @gateway.capture(@amount, '1234567890')
    assert_failure capture
    assert_match 'Transaction+not+found', capture.message
  end

  def test_invalid_transaction_id_capture
    @gateway.expects(:ssl_post).returns(invalid_transaction_id_capture_response)

    assert capture = @gateway.capture(@amount, '')
    assert_failure capture
    assert_match 'Invalid+Transaction+ID', capture.message
  end

  # Refund

  def test_approved_refund
    @gateway.expects(:ssl_post).returns(approved_refund_response)

    assert refund = @gateway.refund(@amount, '1234567890')
    assert_success refund
    assert_equal "The transaction has been approved", refund.message
  end

  def test_not_found_transaction_id_refund
    @gateway.expects(:ssl_post).returns(not_found_transaction_id_refund_response)

    assert refund = @gateway.refund(@amount, '1234567890')
    assert_failure refund
    assert_match "Transaction+not+found", refund.message
  end

  def test_invalid_transaction_id_refund
    @gateway.expects(:ssl_post).returns(invalid_transaction_id_refund_response)

    assert refund = @gateway.refund(@amount, '')
    assert_failure refund
    assert_match "Invalid+Transaction+ID", refund.message
  end

  def test_invalid_amount_refund
    @gateway.expects(:ssl_post).returns(invalid_amount_refund_response)

    assert refund = @gateway.refund(200, '1234567890')
    assert_failure refund
    assert_match "Refund+amount+may+not+exceed+the+transaction+balance", refund.message
  end

  # Void

  def test_approved_void_purchase
    @gateway.expects(:ssl_post).returns(approved_void_purchase_response)

    assert void = @gateway.void('1234567890')
    assert_success void
    assert_equal "The transaction has been approved", void.message
  end

  def test_approved_void_authorization
    @gateway.expects(:ssl_post).returns(approved_void_authorization_response)

    assert void = @gateway.void('1234567890')
    assert_success void
    assert_equal "The transaction has been approved", void.message
  end

  def test_invalid_transaction_id_void
    @gateway.expects(:ssl_post).returns(invalid_transaction_id_void_response)

    assert void = @gateway.void('')
    assert_failure void
    assert_match "Invalid+Transaction+ID", void.message
  end

  def test_not_found_transaction_id_void
    @gateway.expects(:ssl_post).returns(not_found_transaction_id_void_response)

    assert void = @gateway.void('1234567890')
    assert_failure void
    assert_match "Transaction+not+found", void.message
  end

  # Methods

  def test_billing_address
    post = {}
    address = address(email: 'example@example.com')
    @gateway.send(:add_address, post, { billing_address: address })

    assert_equal address[:address1], post[:address1]
    assert_equal address[:address2], post[:address2]
    assert_equal address[:city],     post[:city]
    assert_equal address[:state],    post[:state]
    assert_equal address[:zip],      post[:zip]
    assert_equal address[:country],  post[:country]
    assert_equal address[:phone],    post[:phone]
    assert_equal address[:fax],      post[:fax]
    assert_equal address[:email],    post[:email]
  end

  def test_shipping_address
    post = {}
    address = address(email: 'example@example.com', first_name: 'John', last_name: 'Doe')
    @gateway.send(:add_address, post, { shipping_address: address })

    assert_equal address[:first_name], post[:shipping_firstname]
    assert_equal address[:last_name],  post[:shipping_lastname]
    assert_equal address[:company],    post[:shipping_company]
    assert_equal address[:address1],   post[:shipping_address1]
    assert_equal address[:address2],   post[:shipping_address2]
    assert_equal address[:city],       post[:shipping_city]
    assert_equal address[:country],    post[:shipping_country]
    assert_equal address[:state],      post[:shipping_state]
    assert_equal address[:zip],        post[:shipping_zip]
    assert_equal address[:email],      post[:shipping_email]
  end


  def test_add_currency_from_options
    post = {}
    @gateway.send(:add_currency, post, 100, { currency: 'CAD' })

    assert_equal 'CAD', post[:currency]
  end

  def test_add_currency_from_money
    post = {}
    @gateway.send(:add_currency, post, 100, {})

    assert_equal 'USD', post[:currency]
  end

  def test_add_invoice
    post = {}
    options = {description: 'Order Description', order_id: '123'}
    @gateway.send(:add_invoice, post, options)

    assert_equal 'Order Description', post[:orderdescription]
    assert_equal '123', post[:orderid]
  end

  def test_expdate
    @credit_card = credit_card
    @credit_card.year = 2015
    @credit_card.month = 8

    assert_equal "0815", @gateway.send(:expdate, @credit_card)
  end

  def test_add_creditcard
    post = {}
    @gateway.send(:add_creditcard, post, @credit_card)

    assert_equal @credit_card.number, post[:ccnumber]
    assert_equal @credit_card.verification_value, post[:cvv]
    assert_equal @gateway.send(:expdate, @credit_card), post[:ccexp]
    assert_equal @credit_card.first_name, post[:firstname]
    assert_equal @credit_card.last_name, post[:lastname]
  end

  def test_parse
    data = @gateway.send(:parse, approved_authorization_response)

    assert data.keys.include?('response')
    assert data.keys.include?('responsetext')
    assert data.keys.include?('authcode')
    assert data.keys.include?('transactionid')
    assert data.keys.include?('avsresponse')
    assert data.keys.include?('cvvresponse')
    assert data.keys.include?('orderid')
    assert data.keys.include?('type')
    assert data.keys.include?('response_code')

    assert_equal '1', data['response']
    assert_equal 'SUCCESS', data['responsetext']
    assert_equal '123456', data['authcode']
    assert_equal '1234567890', data['transactionid']
    assert_equal 'N', data['avsresponse']
    assert_equal 'M', data['cvvresponse']
    assert_equal '1', data['orderid']
    assert_equal 'auth', data['type']
    assert_equal '100', data['response_code']
  end

  def test_message_from_for_approved_response
    assert_equal 'The transaction has been approved', @gateway.send(:message_from, {'response' => '1'})
  end

  def test_message_from_for_declined_response
    assert_equal 'The transaction has been declined', @gateway.send(:message_from, {'response' => '2'})
  end

  def test_message_from_for_failed_response
    assert_equal 'Error message', @gateway.send(:message_from, {'response' => '3', 'responsetext' => 'Error message'})
  end

  def test_success
    assert @gateway.send(:success?, {'response' => '1'})
    refute @gateway.send(:success?, {'response' => '2'})
    refute @gateway.send(:success?, {'response' => '3'})
  end

  def test_post_data
    parameters = {param1: 'value1', param2: 'value2'}
    result = @gateway.send(:post_data, 'auth', parameters)

    assert_match "username=xxx", result
    assert_match "password=xxx", result
    assert_match "type=auth", result
    assert_match "param1=value1", result
    assert_match "param2=value2", result
  end

  private

  def approved_authorization_response
    %w(
      response=1
      responsetext=SUCCESS
      authcode=123456
      transactionid=1234567890
      avsresponse=N
      cvvresponse=M
      orderid=1
      type=auth
      response_code=100
    ).join('&')
  end

  def declined_authorization_response
    %w(
      response=2
      responsetext=DECLINE
      authcode=
      transactionid=1234567893
      avsresponse=N
      cvvresponse=M
      orderid=1
      type=auth
      response_code=200
    ).join('&')
  end

  def approved_purchase_response
    %w(
      response=1
      responsetext=SUCCESS
      authcode=123456
      transactionid=1234567891
      avsresponse=N
      cvvresponse=M
      orderid=1
      type=sale
      response_code=100
    ).join('&')
  end

  def declined_purchase_response
    %w(
      response=2
      responsetext=DECLINE
      authcode=
      transactionid=1234567892
      avsresponse=N
      cvvresponse=M
      orderid=1
      type=sale
      response_code=200
    ).join('&')
  end

  def approved_capture_response
    %w(
      response=1
      responsetext=SUCCESS
      authcode=123456
      transactionid=1234567894
      avsresponse=N
      cvvresponse=M
      orderid=1
      type=capture
      response_code=100
    ).join('&')
  end

  def invalid_amount_capture_response
    %w(
      response=3
      responsetext=The+specified+amount+of+2.00+exceeds+the+authorization+amount+of+1.00
      authcode=
      transactionid=1234567895
      avsresponse=N
      cvvresponse=M
      orderid=1
      type=capture
      response_code=300
    ).join('&')
  end

  def not_found_transaction_id_capture_response
    %w(
      response=3
      responsetext=Transaction+not+found+REFID:4054576
      authcode=
      transactionid=
      avsresponse=
      cvvresponse=
      orderid=1
      type=capture
      response_code=300
    ).join('&')
  end

  def invalid_transaction_id_capture_response
    %w(
      response=3
      responsetext=Invalid+Transaction+ID+/+Object+ID+specified:++REFID:4054567
      authcode=
      transactionid=
      avsresponse=
      cvvresponse=
      orderid=1
      type=capture
      response_code=300
    ).join('&')
  end

  def approved_refund_response
    %w(
      response=1
      responsetext=SUCCESS
      authcode=
      transactionid=1234567896
      avsresponse=
      cvvresponse=
      orderid=1
      type=refund
      response_code=100
    ).join('&')
  end

  def not_found_transaction_id_refund_response
    %w(
      response=3
      responsetext=Transaction+not+found+REFID:4054576
      authcode=
      transactionid=
      avsresponse=
      cvvresponse=
      orderid=1
      type=refund
      response_code=300
    ).join('&')
  end

  def invalid_transaction_id_refund_response
    %w(
      response=3
      responsetext=Invalid+Transaction+ID+/+Object+ID+specified:++REFID:4054567
      authcode=
      transactionid=
      avsresponse=
      cvvresponse=
      orderid=1
      type=refund
      response_code=300
    ).join('&')
  end

  def invalid_amount_refund_response
    %w(
      response=3
      responsetext=Refund+amount+may+not+exceed+the+transaction+balance+REFID:4054562
      authcode=
      transactionid=
      avsresponse=
      cvvresponse=
      orderid=1
      type=refund
      response_code=300
    ).join('&')
  end

  def approved_void_purchase_response
    %w(
      response=1
      responsetext=Transaction+Void+Successful
      authcode=123456
      transactionid=1234567896
      avsresponse=
      cvvresponse=
      orderid=1
      type=void
      response_code=100
    ).join('&')
  end

  def approved_void_authorization_response
    %w(
      response=1
      responsetext=Transaction+Void+Successful
      authcode=123456
      transactionid=1234567896
      avsresponse=
      cvvresponse=
      orderid=1
      type=void
      response_code=100
    ).join('&')
  end

  def invalid_transaction_id_void_response
    %w(
      response=3
      responsetext=Invalid+Transaction+ID+/+Object+ID+specified:++REFID:4054572
      authcode=
      transactionid=
      avsresponse=
      cvvresponse=
      orderid=1
      type=void
      response_code=300
    ).join('&')
  end

  def not_found_transaction_id_void_response
    %w(
      response=3
      responsetext=Transaction+not+found+REFID:4054582
      authcode=
      transactionid=
      avsresponse=
      cvvresponse=
      orderid=1
      type=void
      response_code=300
    ).join('&')
  end
end
