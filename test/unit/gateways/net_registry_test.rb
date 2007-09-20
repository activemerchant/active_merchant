require 'test/unit'
require File.dirname(__FILE__) + '/../../test_helper'
require 'stringio'

class NetRegistryTest < Test::Unit::TestCase
  include ActiveMerchant::Billing

  def setup
    @log_io = StringIO.new
    @gateway = NetRegistryGateway.new(
      :login => 'X',
      :password => 'Y',
      :logger => Logger.new(@log_io)
    )

    @creditcard = CreditCard.new({
      :number => '4111111111111111',
      :month => 12,
      :year => 2010,
      :first_name => 'Longbob',
      :last_name => 'Longsen',
      :type => :visa,
    })
  end
  
  def test_purchase_success    
    @creditcard.number = 1

    assert response = @gateway.purchase(100, @creditcard)
    assert_equal Response, response.class
    assert_equal '#0001', response.params['receiptid']
    assert_equal true, response.success?
  end

  def test_purchase_error
    @creditcard.number = 2

    assert response = @gateway.purchase(100, @creditcard, :order_id => 1)
    assert_equal Response, response.class
    assert_equal '#0001', response.params['receiptid']
    assert_equal false, response.success?

  end
  
  def test_purchase_exceptions
    @creditcard.number = 3 
    
    assert_raise(Error) do
      assert response = @gateway.purchase(100, @creditcard, :order_id => 1)    
    end
  end

  def test_successful_purchase
    stub_gateway_response 'successful_purchase'
    response = @gateway.purchase(100, @creditcard)
    assert_success response
    assert_match /\A\d{16}\z/, response.authorization
  end

  def test_successful_credit
    stub_gateway_response 'successful_credit'
    response = @gateway.credit(100, '0707161858000000')
    assert_success response
  end

  def test_successful_authorization
    stub_gateway_response 'successful_authorization'
    response = @gateway.authorize(100, @creditcard)
    assert_success response
    assert_match /\A\d{6}\z/, response.authorization
  end

  def test_successful_authorization_and_capture
    stub_gateway_response 'successful_authorization'
    response = @gateway.authorize(100, @creditcard)
    assert_success response
    assert_match /\A\d{6}\z/, response.authorization

    stub_gateway_response 'successful_capture'
    response = @gateway.capture(100, response.authorization, :credit_card => @creditcard)
    assert_success response
  end

  def test_purchase_with_invalid_credit_card
    stub_gateway_response 'purchase_with_invalid_credit_card'
    response = @gateway.purchase(100, @creditcard)
    assert_failure response
    assert_equal 'INVALID CARD', response.message
  end

  def test_purchase_with_expired_credit_card
    stub_gateway_response 'purchase_with_expired_credit_card'
    response = @gateway.purchase(100, @creditcard)
    assert_failure response
    assert_equal 'CARD EXPIRED', response.message
  end

  def test_purchase_with_invalid_month
    stub_gateway_response 'purchase_with_invalid_month'
    response = @gateway.purchase(100, @creditcard)
    assert_failure response
    assert_equal 'Invalid month', response.message
  end

  def test_transaction_with_logging
    stub_gateway_response 'successful_purchase'
    response = @gateway.purchase(100, @creditcard)
    assert_success response

    # check send line
    sent_line = log_text.grep(/sending/).first
    assert sent_line
    sent_line.chomp!

    # command should appear
    assert_match /COMMAND=purchase/, sent_line
    # card number should be masked
    number = sent_line[/CCNUM=(.{16})/][6..-1]
    assert_match /\*{12}/, sent_line
    # card expiry should be masked
    expiry = sent_line[/CCEXP=([^&]*)/][6..-1]
    assert_match /\*+\/\*+/, expiry

    # check received text
    received_text = log_text.grep(/^  /).join
    assert !received_text.empty?
    # card number should be masked
    received_text.scan(/card_(?:number|no)=(.*)$/) do
      value = $1
      assert_match /\*{12}/, value
    end
    # card_expiry should be masked
    received_text.scan(/card_expiry=(.*)$/) do
      value = $1
      assert_match /\*+\/\*+/, value
    end
  end

  def test_transaction_without_logging
    stub_gateway_response 'successful_purchase'
    @gateway.logger = nil
    response = @gateway.purchase(100, @creditcard)
    assert_success response
    assert log_text.empty?
  end

  def test_bad_login
    @gateway = NetRegistryGateway.new(:login => 'bad-login', :password => 'bad-login')
    stub_gateway_response 'bad_login'
    response = @gateway.purchase(100, @creditcard)
    assert_failure response
    assert_equal 'failed', response.params['status']
  end

  private  # ---------------------------------------------------------

  #
  # Return the contents of the log file.
  #
  def log_text
    @log_io.string
  end

  #
  # Parse the response data to use in our simulations.
  #
  def parse_response_data
    data = {}
    current_key = nil
    RESPONSE_DATA.each do |line|
      if line =~ /^== (.*)$/
        current_key = $1
        data[current_key] = ''
      else
        line.sub!(/^    /, '')
        data[current_key] << line
      end
    end
    data
  end

  #
  # Make the gateway pretend the named response data text is returned
  # by the gateway server.
  #
  def stub_gateway_response(key)
    response_data = parse_response_data
    @gateway.stubs(:ssl_post).returns(response_data[key])
  end

  RESPONSE_DATA = <<EOS
== successful_purchase
    approved
    00015X000000
    Transaction No: 00000000
    ------------------------
    MERCHANTNAME            
    LOCATION          AU
                            
    MERCH ID        10000000
    TERM  ID          Y0TR00
    COUNTRY CODE AU
    16/07/07           18:59
    RRN         00015X000000
    VISA
    411111-111
    CREDIT A/C         12/10
                            
    AUTHORISATION NO: 000000
    APPROVED   08
                            
    PURCHASE           $1.00
    TOTAL   AUD        $1.00
                            
    PLEASE RETAIN AS RECORD 
          OF PURCHASE       
                            
    (SUBJECT TO CARDHOLDER'S
           ACCEPTANCE)      
    ------------------------
    .
    settlement_date=16/07/07
    card_desc=VISA
    status=approved
    txn_ref=0707161858000000
    refund_mode=0
    transaction_no=000000
    rrn=00015X000000
    response_text=SIGNATURE REQUIRED
    pld=0
    total_amount=100
    card_no=4111111111111111
    version=V1.0
    merchant_index=123
    card_expiry=12/10
    training_mode=0
    operator_no=10000
    response_code=08
    card_type=6
    approved=1
    cashout_amount=0
    receipt_array=ARRAY(0x83725cc)
    account_type=CREDIT A/C
    result=1
== successful_authorization
    approved
    00015X000000
    Transaction No: 00000000
    ------------------------
    MERCHANTNAME        
    LOCATION          AU
                            
    MERCH ID        10000000
    TERM  ID          Y0TR00
    COUNTRY CODE AU
    17/07/07           15:22
    RRN         00015X000000
    VISA
    411111-111
    CREDIT A/C         12/10
                            
    AUTHORISATION NO: 000000
    APPROVED   08
                            
    PURCHASE           $1.00
    TOTAL   AUD        $1.00
                            
    PLEASE RETAIN AS RECORD 
          OF PURCHASE       
                            
    (SUBJECT TO CARDHOLDER'S
           ACCEPTANCE)      
    ------------------------
    .
    settlement_date=17/07/07
    card_desc=VISA
    status=approved
    txn_ref=0707171521000000
    refund_mode=0
    transaction_no=000000
    rrn=00015X000000
    response_text=SIGNATURE REQUIRED
    pld=0
    total_amount=100
    card_no=4111111111111111
    version=V1.0
    merchant_index=123
    card_expiry=12/10
    training_mode=0
    operator_no=10000
    response_code=08
    card_type=6
    approved=1
    cashout_amount=0
    receipt_array=ARRAY(0x836a25c)
    account_type=CREDIT A/C
    result=1
== successful_capture
    approved
    00015X000000
    Transaction No: 00000000
    ------------------------
    MERCHANTNAME        
    LOCATION          AU
                            
    MERCH ID        10000000
    TERM  ID          Y0TR00
    COUNTRY CODE AU
    17/07/07           15:23
    RRN         00015X000000
    VISA
    411111-111
    CREDIT A/C         12/10
                            
    AUTHORISATION NO: 000000
    APPROVED   08
                            
    PURCHASE           $1.00
    TOTAL   AUD        $1.00
                            
    PLEASE RETAIN AS RECORD 
          OF PURCHASE       
                            
    (SUBJECT TO CARDHOLDER'S
           ACCEPTANCE)      
    ------------------------
    .
    settlement_date=17/07/07
    card_desc=VISA
    status=approved
    txn_ref=0707171522000000
    refund_mode=0
    transaction_no=000000
    rrn=00015X000000
    response_text=SIGNATURE REQUIRED
    pld=0
    total_amount=100
    card_no=4111111111111111
    version=V1.0
    merchant_index=123
    card_expiry=12/10
    training_mode=0
    operator_no=10000
    response_code=08
    card_type=6
    approved=1
    cashout_amount=0
    receipt_array=ARRAY(0x8378200)
    account_type=CREDIT A/C
    result=1
== successful_credit
    approved
    00015X000000
    Transaction No: 00000000
    ------------------------
    MERCHANTNAME        
    LOCATION          AU
                            
    MERCH ID        10000000
    TERM  ID          Y0TR00
    COUNTRY CODE AU
    16/07/07           19:03
    RRN         00015X000000
    VISA
    411111-111
    CREDIT A/C         12/10
                            
    AUTHORISATION NO:
    APPROVED   08
                            
    ** REFUND **       $1.00
    TOTAL   AUD        $1.00
                            
    PLEASE RETAIN AS RECORD 
          OF REFUND         
                            
    (SUBJECT TO CARDHOLDER'S
           ACCEPTANCE)      
    ------------------------
    .
    settlement_date=16/07/07
    card_desc=VISA
    status=approved
    txn_ref=0707161902000000
    refund_mode=1
    transaction_no=000000
    rrn=00015X000000
    response_text=SIGNATURE REQUIRED
    pld=0
    total_amount=100
    card_no=4111111111111111
    version=V1.0
    merchant_index=123
    card_expiry=12/10
    training_mode=0
    operator_no=10000
    response_code=08
    card_type=6
    approved=1
    cashout_amount=0
    receipt_array=ARRAY(0x837241c)
    account_type=CREDIT A/C
    result=1
== purchase_with_invalid_credit_card
    declined
    00015X000000
    Transaction No: 00000000
    ------------------------
    MERCHANTNAME        
    LOCATION          AU
                            
    MERCH ID        10000000
    TERM  ID          Y0TR40
    COUNTRY CODE AU
    16/07/07           19:20
    RRN         00015X000000
    VISA
    411111-111
    CREDIT A/C         12/10
                            
    AUTHORISATION NO:
    DECLINED   31
                            
    PURCHASE           $1.00
    TOTAL   AUD        $1.00
                            
    (SUBJECT TO CARDHOLDER'S
           ACCEPTANCE)      
    ------------------------
    .
    settlement_date=16/07/07
    card_desc=VISA
    status=declined
    txn_ref=0707161919000000
    refund_mode=0
    transaction_no=000000
    rrn=00015X000000
    response_text=INVALID CARD
    pld=0
    total_amount=100
    card_no=4111111111111111
    version=V1.0
    merchant_index=123
    card_expiry=12/10
    training_mode=0
    operator_no=10000
    response_code=31
    card_type=6
    approved=0
    cashout_amount=0
    receipt_array=ARRAY(0x83752d0)
    account_type=CREDIT A/C
    result=0
== purchase_with_expired_credit_card
    failed
    
    
    .
    response_text=CARD EXPIRED
    approved=0
    status=failed
    txn_ref=0707161910000000
    version=V1.0
    pld=0
    response_code=Q816
    result=-1
== purchase_with_invalid_month
    failed
    Invalid month
== bad_login
    failed
    
    
    .
    status=failed
    result=-1
EOS
end
