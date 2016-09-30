# encoding: utf-8
require 'test_helper'
require 'logger'

class UsaEpayAdvancedTest < Test::Unit::TestCase
  include CommStub

  def setup
    # Optional Logger Setup
    # UsaEpayAdvancedGateway.logger = Logger.new('/tmp/usa_epay.log')
    # UsaEpayAdvancedGateway.logger.level = Logger::DEBUG

    # Optional Wiredump Setup
    # UsaEpayAdvancedGateway.wiredump_device = File.open('/tmp/usa_epay_dump.log', 'a+')
    # UsaEpayAdvancedGateway.wiredump_device.sync = true

    @gateway = UsaEpayAdvancedGateway.new(
                 :login => 'X',
                 :password => 'Y',
                 :software_id => 'Z'
               )

    @credit_card = ActiveMerchant::Billing::CreditCard.new(
      :number => '4000100011112224',
      :month => 12,
      :year => 12,
      :brand => 'visa',
      :verification_value => '123',
      :first_name => "Fred",
      :last_name => "Flintstone"
    )

    @check = ActiveMerchant::Billing::Check.new(
      :account_number => '123456789012',
      :routing_number => '123456789',
      :account_type => 'checking',
      :first_name => "Fred",
      :last_name => "Flintstone"
    )

    payment_methods = [
      {
        :name => "My Visa", # optional
        :sort => 2, # optional
        :method => @credit_card
      },
      {
        :name => "My Checking",
        :method => @check
      }
    ]

    payment_method = {
      :name => "My new Visa", # optional
      :method => @credit_card
    }

    @customer_options = {
      :id => 1, # optional: merchant assigned id, usually db id
      :notes =>  "Note about customer", # optional
      :data => "Some Data", # optional
      :url => "awesomesite.com", # optional
      :payment_methods => payment_methods # optional
    }

    @payment_options = {
      :payment_method => payment_method
    }

    @transaction_options = {
      :payment_method => @credit_card,
      :recurring => {
        :schedule => 'monthly',
        :amount => 4000
      }
    }

    @standard_transaction_options = {
      :method_id => 0,
      :command => 'Sale',
      :amount => 2000 #20.00
    }

    @get_payment_options = {
      :method_id => 0
    }

    @delete_customer_options = {
      :customer_number => 299461
    }

    @custom_options = {
      :fields => ['Response.StatusCode', 'Response.Status']
    }

    @options = {
      :client_ip => '127.0.0.1',
      :billing_address => address,

      :customer_number => 298741,
      :reference_number => 9999
    }
  end

  # Standard Gateway ==================================================

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(1234, @credit_card, @options)

    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal 'Approved', response.message['result']
    assert_equal '47602591', response.authorization
    assert_avs_cvv_match response
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    assert response = @gateway.authorize(1234, @credit_card, @options)

    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal 'Approved', response.message['result']
    assert_equal '47602592', response.authorization
    assert_avs_cvv_match response
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    assert response = @gateway.capture(1234, @credit_card, @options)

    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal 'Approved', response.message['result']
    assert_equal '47602593', response.authorization
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)
    assert response = @gateway.void(@credit_card, @options)

    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal 'true', response.message
  end

  def test_successful_credit
    @gateway.expects(:ssl_post).returns(successful_credit_response)
    assert_deprecation_warning(Gateway::CREDIT_DEPRECATION_MESSAGE) do
      assert response = @gateway.credit(1234, @credit_card, @options)
      assert_instance_of Response, response
      assert response.test?
      assert_success response
      assert_equal 'Approved', response.message['result']
      assert_equal '47602599', response.authorization
    end
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_credit_response)
    assert response = @gateway.refund(1234, @credit_card, @options)

    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal 'Approved', response.message['result']
    assert_equal '47602599', response.authorization
  end

  # Customer ==========================================================

  def test_successful_add_customer
    @options.merge!(@customer_options)
    @gateway.expects(:ssl_post).returns(successful_add_customer_response)

    assert response = @gateway.add_customer(@options)
    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal '274141', response.params['add_customer_return']
    assert_equal '274141', response.message
    assert_nil response.authorization
  end

  def test_successful_update_customer
    @options.merge!(@customer_options)
    @gateway.expects(:ssl_post).returns(successful_customer_response('updateCustomer'))

    assert response = @gateway.update_customer(@options)
    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal 'true', response.message
    assert_nil response.authorization
  end

  def test_successful_quick_update_customer
    @gateway.expects(:ssl_post).returns(successful_customer_response('quickUpdateCustomer'))

    assert response = @gateway.quick_update_customer({customer_number: @options[:customer_number], update_data: @customer_options})
    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal 'true', response.params['quick_update_customer_return']
    assert_equal 'true', response.message
    assert_nil response.authorization
  end

  def test_successful_enable_customer
    @options.merge!(@standard_transaction_options)
    @gateway.expects(:ssl_post).returns(successful_customer_response('enableCustomer'))

    assert response = @gateway.enable_customer(@options)
    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal 'true', response.message
    assert_nil response.authorization
  end

  def test_successful_disable_customer
    @options.merge!(@standard_transaction_options)
    @gateway.expects(:ssl_post).returns(successful_customer_response('disableCustomer'))

    assert response = @gateway.disable_customer(@options)
    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal 'true', response.message
    assert_nil response.authorization
  end

  def test_successful_add_customer_payment_method
    @options.merge!(@payment_options)
    @gateway.expects(:ssl_post).returns(successful_add_customer_payment_method_response)

    assert response = @gateway.add_customer_payment_method(@options)
    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal '77', response.params['add_customer_payment_method_return']
    assert_equal '77', response.message
    assert_nil response.authorization
  end

  def test_failed_add_customer_payment_method
    @options.merge!(@payment_options)
    @gateway.expects(:ssl_post).returns(failed_add_customer_payment_method_response)

    assert response = @gateway.add_customer_payment_method(@options)
    assert_instance_of Response, response
    assert response.test?
    assert_failure response
    assert_nil response.authorization
    assert_equal '40459: Payment method not added because verification returned a Declined:10127:Card Declined (00)', response.message
  end

  def test_successful_get_customer_payment_method
    @options.merge!(@get_payment_options)
    @gateway.expects(:ssl_post).returns(successful_get_customer_payment_method_response)

    assert response = @gateway.get_customer_payment_method(@options)
    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_nil response.authorization
    assert_equal 'cc', response.params['get_customer_payment_method_return']['method_type']
    assert_equal '103', response.params['get_customer_payment_method_return']['method_id']
    assert_instance_of Hash, response.message
    assert_equal '103', response.message['method_id']
  end

  def test_successful_get_customer_payment_methods
    @gateway.expects(:ssl_post).returns(successful_get_customer_payment_methods_response)

    assert response = @gateway.get_customer_payment_methods(@options.merge!(:customer_number => 298741))
    assert_instance_of Response, response
    assert_success response
    assert response.test?
    assert_nil response.authorization
    assert_instance_of Array, response.message
    assert_equal 2, response.params['get_customer_payment_methods_return']['item'].length
    assert_equal 2, response.message.length
  end

  def test_successful_update_customer_payment_method
    @options.merge!(@payment_options).merge!(:method_id => 1)
    @gateway.expects(:ssl_post).returns(successful_update_customer_payment_method_response)

    assert response = @gateway.update_customer_payment_method(@options)
    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal 'true', response.params['update_customer_payment_method_return']
    assert_equal 'true', response.message
    assert_nil response.authorization
  end

  def test_successful_delete_customer_payment_method
    @gateway.expects(:ssl_post).returns(successful_delete_customer_payment_method_response)

    assert response = @gateway.delete_customer_payment_method(@options.merge!(:customer_number => 298741, :method_id => 15))
    assert_instance_of Response, response
    assert_success response
    assert_equal 'true', response.message
    assert response.test?
    assert_nil response.authorization
  end

  def test_successful_run_customer_transaction
    @options.merge!(@standard_transaction_options)
    @gateway.expects(:ssl_post).returns(successful_run_customer_transaction_response)

    assert response = @gateway.run_customer_transaction(@options)
    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal 'Approved', response.message['result']
    assert_equal '47555081', response.authorization
    assert_equal 'Y', response.avs_result['code']
    assert_equal 'Y', response.avs_result['street_match']
    assert_equal 'Y', response.avs_result['postal_match']
    assert_equal 'P', response.cvv_result['code']
  end

  def test_successful_delete_customer
    @options.merge! @delete_customer_options
    @gateway.expects(:ssl_post).returns(successful_customer_response('deleteCustomer'))

    assert response = @gateway.delete_customer(@options)
    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal 'true', response.message
  end

  # Transactions ======================================================

  def test_successful_run_transaction
    @options.merge!(@transaction_options)
    @gateway.expects(:ssl_post).returns(successful_avs_cvv_transaction_response('runTransaction'))

    assert response = @gateway.run_transaction(@options)
    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal 'Approved', response.message['result']
    assert_equal '47567593', response.authorization
    assert_avs_cvv_match response
  end

  def test_successful_run_sale
    @options.merge!(@transaction_options)
    @gateway.expects(:ssl_post).returns(successful_avs_cvv_transaction_response('runSale'))

    assert response = @gateway.run_sale(@options)
    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal '47567593', response.authorization
    assert_avs_cvv_match response
  end

  def test_successful_run_auth_only
    @options.merge!(@transaction_options)
    @gateway.expects(:ssl_post).returns(successful_avs_cvv_transaction_response('runAuthOnly'))

    assert response = @gateway.run_auth_only(@options)
    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal 'Approved', response.message['result']
    assert_equal '47567593', response.authorization
    assert_avs_cvv_match response
  end

  def test_successful_run_credit
    @options.merge!(@transaction_options)
    @gateway.expects(:ssl_post).returns(successful_transaction_response('runCredit'))

    assert response = @gateway.run_credit(@options)
    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal 'Approved', response.message['result']
    assert_equal '47568689', response.authorization
  end

  def test_successful_run_check_sale
    @options.merge!(@transaction_options)

    response = stub_comms do
      @gateway.run_check_sale(@options.merge(:payment_method => @check))
    end.check_request do |endpoint, data, headers|
      assert_match(/123456789012/, data)
    end.respond_with(successful_transaction_response('runCheckSale'))

    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal 'Approved', response.message['result']
    assert_equal '47568689', response.authorization
  end

  def test_successful_run_check_credit
    @options.merge!(@transaction_options)
    @gateway.expects(:ssl_post).returns(successful_transaction_response('runCheckCredit'))

    assert response = @gateway.run_check_credit(@options)
    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal 'Approved', response.message['result']
    assert_equal '47568689', response.authorization
  end

  # TODO get post_auth response
  #def test_successful_post_auth
  #  @options.merge!(:authorization_code => 'bogus')
  #  @gateway.expects(:ssl_post).returns(successful_post_auth_response)

  #  assert response = @gateway.post_auth(@options)
  #  assert_instance_of Response, response
  #  assert response.test?
  #  assert_success response
  #  assert_equal 'Approved', response.message
  #  #assert_equal '47568732', response.authorization

  #  puts response.inspect
  #end

  def test_successful_run_quick_sale
    @options.merge!(@transaction_options)
    @options.merge!(@standard_transaction_options)
    @gateway.expects(:ssl_post).returns(successful_transaction_response('runQuickSale'))

    assert response = @gateway.run_quick_sale(@options)
    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal 'Approved', response.message['result']
    assert_equal '47568689', response.authorization
  end

  def test_successful_run_quick_credit
    @options.merge!(@transaction_options)
    @gateway.expects(:ssl_post).returns(successful_transaction_response('runQuickCredit'))

    assert response = @gateway.run_quick_credit(@options)
    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal 'Approved', response.message['result']
    assert_equal '47568689', response.authorization
  end

  def test_successful_capture_transaction
    @gateway.expects(:ssl_post).returns(successful_capture_transaction_response)

    assert response = @gateway.capture_transaction(@options)
    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal 'Approved', response.message['result']
    assert_equal '47587252', response.authorization
  end

  def test_successful_void_transaction
    @gateway.expects(:ssl_post).returns(successful_void_transaction_response)

    assert response = @gateway.void_transaction(@options)
    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal 'true', response.message
    assert_nil response.authorization
  end

  def test_successful_refund_transaction
    @options.merge!(@standard_transaction_options)
    @gateway.expects(:ssl_post).returns(successful_refund_transaction_response)

    assert response = @gateway.refund_transaction(@options)
    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal 'Approved', response.message['result']
    assert_equal '47587258', response.authorization
  end

  # TODO get override_transaction response
  #def test_successful_override_transaction
  #  @gateway.expects(:ssl_post).returns(successful_override_transaction_response)

  #  assert response = @gateway.override_transaction(@options)
  #  assert_instance_of Response, response
  #  assert_success response
  #  assert response.test?

  #  puts response.inspect
  #end

  # Transaction Status ================================================

  def test_successful_get_transaction
    @gateway.expects(:ssl_post).returns(successful_get_transaction_response)

    assert response = @gateway.get_transaction(@options)
    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal 'XXXXXXXXXXXX2224', response.message['credit_card_data']['card_number']
  end

  def test_successful_get_transaction_status
    @gateway.expects(:ssl_post).returns(successful_get_transaction_status_response)

    assert response = @gateway.get_transaction_status(@options)
    assert_instance_of Response, response
    assert_success response
    assert response.test?
    assert_equal '050162', response.message['auth_code']
    assert_equal '47569011', response.authorization
    assert_avs_cvv_match response
  end

  def test_successful_get_transaction_custom
    @options.merge!(@custom_options)
    @gateway.expects(:ssl_post).returns(successful_get_transaction_custom_response)

    assert response = @gateway.get_transaction_custom(@options)
    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal 'P', response.message['Response.StatusCode']
  end

  def test_successful_get_check_trace
    @gateway.expects(:ssl_post).returns(successful_get_check_trace_response)

    assert response = @gateway.get_check_trace(@options)
    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal '11061908516155', response.message['tracking_num']
  end

  # Account ===========================================================

  def test_successful_get_account_details
    @gateway.expects(:ssl_post).returns(successful_get_account_details)

    assert response = @gateway.get_account_details
    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal 'TestBed', response.message['check_platform']
    assert_equal 'Test Bed', response.message['credit_card_platform']
  end

  # Misc ==============================================================

  def test_mismatch_response
    @gateway.expects(:ssl_post).returns(successful_get_check_trace_response)

    assert response = @gateway.get_account_details
    assert_instance_of Response, response
    assert response.test?
    assert_failure response
  end

  private

  # Standard Gateway ==================================================

  def successful_purchase_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:usaepay" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Body><ns1:runSaleResponse><runSaleReturn xsi:type="ns1:TransactionResponse"><AcsUrl xsi:type="xsd:string"></AcsUrl><AuthAmount xsi:type="xsd:double">0</AuthAmount><AuthCode xsi:type="xsd:string">017523</AuthCode><AvsResult xsi:type="xsd:string">Address: Match &amp; 5 Digit Zip: Match</AvsResult><AvsResultCode xsi:type="xsd:string">YYY</AvsResultCode><BatchNum xsi:type="xsd:integer">1</BatchNum><BatchRefNum xsi:type="xsd:integer">14004</BatchRefNum><CardCodeResult xsi:type="xsd:string">Match</CardCodeResult><CardCodeResultCode xsi:type="xsd:string">M</CardCodeResultCode><CardLevelResult xsi:type="xsd:string">Visa Traditional</CardLevelResult><CardLevelResultCode xsi:type="xsd:string">A</CardLevelResultCode><ConversionRate xsi:type="xsd:double">0</ConversionRate><ConvertedAmount xsi:type="xsd:double">0</ConvertedAmount><ConvertedAmountCurrency xsi:type="xsd:string">840</ConvertedAmountCurrency><CustNum xsi:type="xsd:integer">0</CustNum><Error xsi:type="xsd:string">Approved</Error><ErrorCode xsi:type="xsd:integer">0</ErrorCode><isDuplicate xsi:type="xsd:boolean">false</isDuplicate><Payload xsi:type="xsd:string"></Payload><RefNum xsi:type="xsd:integer">47602591</RefNum><Result xsi:type="xsd:string">Approved</Result><ResultCode xsi:type="xsd:string">A</ResultCode><Status xsi:type="xsd:string">Pending</Status><StatusCode xsi:type="xsd:string">P</StatusCode><VpasResultCode xsi:type="xsd:string"></VpasResultCode></runSaleReturn></ns1:runSaleResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  def successful_authorize_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:usaepay" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Body><ns1:runAuthOnlyResponse><runAuthOnlyReturn xsi:type="ns1:TransactionResponse"><AcsUrl xsi:type="xsd:string"></AcsUrl><AuthAmount xsi:type="xsd:double">0</AuthAmount><AuthCode xsi:type="xsd:string">017524</AuthCode><AvsResult xsi:type="xsd:string">Address: Match &amp; 5 Digit Zip: Match</AvsResult><AvsResultCode xsi:type="xsd:string">YYY</AvsResultCode><BatchNum xsi:type="xsd:integer">1</BatchNum><BatchRefNum xsi:type="xsd:integer">14004</BatchRefNum><CardCodeResult xsi:type="xsd:string">Match</CardCodeResult><CardCodeResultCode xsi:type="xsd:string">M</CardCodeResultCode><CardLevelResult xsi:type="xsd:string">Visa Traditional</CardLevelResult><CardLevelResultCode xsi:type="xsd:string">A</CardLevelResultCode><ConversionRate xsi:type="xsd:double">0</ConversionRate><ConvertedAmount xsi:type="xsd:double">0</ConvertedAmount><ConvertedAmountCurrency xsi:type="xsd:string">840</ConvertedAmountCurrency><CustNum xsi:type="xsd:integer">0</CustNum><Error xsi:type="xsd:string">Approved</Error><ErrorCode xsi:type="xsd:integer">0</ErrorCode><isDuplicate xsi:type="xsd:boolean">false</isDuplicate><Payload xsi:type="xsd:string"></Payload><RefNum xsi:type="xsd:integer">47602592</RefNum><Result xsi:type="xsd:string">Approved</Result><ResultCode xsi:type="xsd:string">A</ResultCode><Status xsi:type="xsd:string">Pending</Status><StatusCode xsi:type="xsd:string">P</StatusCode><VpasResultCode xsi:type="xsd:string"></VpasResultCode></runAuthOnlyReturn></ns1:runAuthOnlyResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  def successful_capture_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:usaepay" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Body><ns1:captureTransactionResponse><captureTransactionReturn xsi:type="ns1:TransactionResponse"><AcsUrl xsi:type="xsd:string"></AcsUrl><AuthAmount xsi:type="xsd:double">0</AuthAmount><AuthCode xsi:type="xsd:string">017525</AuthCode><AvsResult xsi:type="xsd:string">No AVS response (Typically no AVS data sent or swiped transaction)</AvsResult><AvsResultCode xsi:type="xsd:string"></AvsResultCode><BatchNum xsi:type="xsd:integer">0</BatchNum><BatchRefNum xsi:type="xsd:integer">0</BatchRefNum><CardCodeResult xsi:type="xsd:string">No CVV2/CVC data available for transaction.</CardCodeResult><CardCodeResultCode xsi:type="xsd:string"></CardCodeResultCode><CardLevelResult xsi:type="xsd:string">Unknown Code </CardLevelResult><CardLevelResultCode xsi:type="xsd:string"></CardLevelResultCode><ConversionRate xsi:type="xsd:double">0</ConversionRate><ConvertedAmount xsi:type="xsd:double">0</ConvertedAmount><ConvertedAmountCurrency xsi:type="xsd:string">840</ConvertedAmountCurrency><CustNum xsi:type="xsd:integer">0</CustNum><Error xsi:type="xsd:string">Approved</Error><ErrorCode xsi:type="xsd:integer">0</ErrorCode><isDuplicate xsi:type="xsd:boolean">false</isDuplicate><Payload xsi:type="xsd:string"></Payload><RefNum xsi:type="xsd:integer">47602593</RefNum><Result xsi:type="xsd:string">Approved</Result><ResultCode xsi:type="xsd:string">A</ResultCode><Status xsi:type="xsd:string">Pending</Status><StatusCode xsi:type="xsd:string">P</StatusCode><VpasResultCode xsi:type="xsd:string"></VpasResultCode></captureTransactionReturn></ns1:captureTransactionResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  def successful_void_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:usaepay" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Body><ns1:voidTransactionResponse><voidTransactionReturn xsi:type="xsd:boolean">true</voidTransactionReturn></ns1:voidTransactionResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  def successful_credit_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:usaepay" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Body><ns1:refundTransactionResponse><refundTransactionReturn xsi:type="ns1:TransactionResponse"><AcsUrl xsi:nil="true"/><AuthAmount xsi:type="xsd:double">0</AuthAmount><AuthCode xsi:type="xsd:string">47612622</AuthCode><AvsResult xsi:type="xsd:string">Unmapped AVS response (   )</AvsResult><AvsResultCode xsi:type="xsd:string"></AvsResultCode><BatchNum xsi:nil="true"/><BatchRefNum xsi:nil="true"/><CardCodeResult xsi:type="xsd:string">No CVV2/CVC data available for transaction.</CardCodeResult><CardCodeResultCode xsi:type="xsd:string"></CardCodeResultCode><CardLevelResult xsi:type="xsd:string">Unknown Code </CardLevelResult><CardLevelResultCode xsi:type="xsd:string"></CardLevelResultCode><ConversionRate xsi:type="xsd:double">0</ConversionRate><ConvertedAmount xsi:type="xsd:double">0</ConvertedAmount><ConvertedAmountCurrency xsi:nil="true"/><CustNum xsi:type="xsd:integer">0</CustNum><Error xsi:type="xsd:string"></Error><ErrorCode xsi:nil="true"/><isDuplicate xsi:type="xsd:boolean">false</isDuplicate><Payload xsi:nil="true"/><RefNum xsi:type="xsd:integer">47602599</RefNum><Result xsi:type="xsd:string">Approved</Result><ResultCode xsi:type="xsd:string">A</ResultCode><Status xsi:type="xsd:string">Pending</Status><StatusCode xsi:type="xsd:string">P</StatusCode><VpasResultCode xsi:type="xsd:string"></VpasResultCode></refundTransactionReturn></ns1:refundTransactionResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  # Customer ==========================================================

  def successful_add_customer_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:usaepay" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Body><ns1:addCustomerResponse><addCustomerReturn xsi:type="xsd:integer">274141</addCustomerReturn></ns1:addCustomerResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  def invalid_checking_add_customer_response
    <<-XML
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"><SOAP-ENV:Body><SOAP-ENV:Fault><faultcode>SOAP-ENV:Server</faultcode><faultstring>39: Invalid Checking Account Number.</faultstring></SOAP-ENV:Fault></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  def successful_customer_response(method)
    <<-XML
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:usaepay" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Body><ns1:#{method}Response><#{method}Return xsi:type="xsd:boolean">true</#{method}Return></ns1:#{method}Response></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  def successful_run_customer_transaction_response
    <<-XML
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:usaepay" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Body><ns1:runCustomerTransactionResponse><runCustomerTransactionReturn xsi:type="ns1:TransactionResponse"><AcsUrl xsi:type="xsd:string"></AcsUrl><AuthAmount xsi:nil="true"/><AuthCode xsi:type="xsd:string">038460</AuthCode><AvsResult xsi:type="xsd:string">Address: Match &amp; 5 Digit Zip: Match</AvsResult><AvsResultCode xsi:type="xsd:string">YYY</AvsResultCode><BatchNum xsi:type="xsd:integer">1</BatchNum><BatchRefNum xsi:type="xsd:integer">14004</BatchRefNum><CardCodeResult xsi:type="xsd:string">Not Processed</CardCodeResult><CardCodeResultCode xsi:type="xsd:string">P</CardCodeResultCode><CardLevelResult xsi:nil="true"/><CardLevelResultCode xsi:nil="true"/><ConversionRate xsi:type="xsd:double">0</ConversionRate><ConvertedAmount xsi:type="xsd:double">0</ConvertedAmount><ConvertedAmountCurrency xsi:nil="true"/><CustNum xsi:type="xsd:integer">0</CustNum><Error xsi:type="xsd:string">Approved</Error><ErrorCode xsi:type="xsd:integer">0</ErrorCode><isDuplicate xsi:type="xsd:boolean">false</isDuplicate><Payload xsi:type="xsd:string"></Payload><RefNum xsi:type="xsd:integer">47555081</RefNum><Result xsi:type="xsd:string">Approved</Result><ResultCode xsi:type="xsd:string">A</ResultCode><Status xsi:type="xsd:string">Pending</Status><StatusCode xsi:type="xsd:string">P</StatusCode><VpasResultCode xsi:nil="true"/></runCustomerTransactionReturn></ns1:runCustomerTransactionResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  def successful_add_customer_payment_method_response
    <<-XML
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:usaepay" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Body><ns1:addCustomerPaymentMethodResponse><addCustomerPaymentMethodReturn xsi:type="xsd:integer">77</addCustomerPaymentMethodReturn></ns1:addCustomerPaymentMethodResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  def failed_add_customer_payment_method_response
    <<-XML
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"><SOAP-ENV:Body><SOAP-ENV:Fault><faultcode>SOAP-ENV:Server</faultcode><faultstring>40459: Payment method not added because verification returned a Declined:10127:Card Declined (00)</faultstring></SOAP-ENV:Fault></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  def successful_get_customer_payment_method_response
    <<-XML
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:usaepay" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Body><ns1:getCustomerPaymentMethodResponse><getCustomerPaymentMethodReturn xsi:type="ns1:PaymentMethod"><MethodType xsi:type="xsd:string">cc</MethodType><MethodID xsi:type="xsd:integer">103</MethodID><MethodName xsi:type="xsd:string">My CC</MethodName><SecondarySort xsi:type="xsd:integer">5</SecondarySort><Created xsi:type="xsd:dateTime">2011-06-09T13:48:57+08:00</Created><Modified xsi:type="xsd:dateTime">2011-06-09T13:48:57+08:00</Modified><AvsStreet xsi:type="xsd:string">456 My Street</AvsStreet><AvsZip xsi:type="xsd:string">K1C2N6</AvsZip><CardExpiration xsi:type="xsd:string">2012-12</CardExpiration><CardNumber xsi:type="xsd:string">XXXXXXXXXXXX2224</CardNumber><CardType xsi:type="xsd:string">V</CardType></getCustomerPaymentMethodReturn></ns1:getCustomerPaymentMethodResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  def failed_get_customer_payment_method_response
    <<-XML
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"><SOAP-ENV:Body><SOAP-ENV:Fault><faultcode>SOAP-ENV:Server</faultcode><faultstring>40453: Unable to locate requested payment method.</faultstring></SOAP-ENV:Fault></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  def successful_get_customer_payment_methods_response
    <<-XML
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:usaepay" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Body><ns1:getCustomerPaymentMethodsResponse><getCustomerPaymentMethodsReturn SOAP-ENC:arrayType="ns1:PaymentMethod[2]" xsi:type="ns1:PaymentMethodArray"><item xsi:type="ns1:PaymentMethod"><MethodType xsi:type="xsd:string">cc</MethodType><MethodID xsi:type="xsd:integer">93</MethodID><MethodName xsi:type="xsd:string">My CC</MethodName><SecondarySort xsi:type="xsd:integer">5</SecondarySort><Created xsi:type="xsd:dateTime">2011-06-09T08:10:44+08:00</Created><Modified xsi:type="xsd:dateTime">2011-06-09T08:10:44+08:00</Modified><AvsStreet xsi:type="xsd:string">456 My Street</AvsStreet><AvsZip xsi:type="xsd:string">K1C2N6</AvsZip><CardExpiration xsi:type="xsd:string">2012-12</CardExpiration><CardNumber xsi:type="xsd:string">XXXXXXXXXXXX2224</CardNumber><CardType xsi:type="xsd:string">V</CardType></item><item xsi:type="ns1:PaymentMethod"><MethodType xsi:type="xsd:string">cc</MethodType><MethodID xsi:type="xsd:integer">94</MethodID><MethodName xsi:type="xsd:string">Other CC</MethodName><SecondarySort xsi:type="xsd:integer">12</SecondarySort><Created xsi:type="xsd:dateTime">2011-06-09T08:10:44+08:00</Created><Modified xsi:type="xsd:dateTime">2011-06-09T08:10:44+08:00</Modified><AvsStreet xsi:type="xsd:string">456 My Street</AvsStreet><AvsZip xsi:type="xsd:string">K1C2N6</AvsZip><CardExpiration xsi:type="xsd:string">2012-12</CardExpiration><CardNumber xsi:type="xsd:string">XXXXXXXXXXXX2224</CardNumber><CardType xsi:type="xsd:string">V</CardType></item></getCustomerPaymentMethodsReturn></ns1:getCustomerPaymentMethodsResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  def successful_single_get_customer_payment_methods_response
    <<-XML
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:usaepay" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Body><ns1:getCustomerPaymentMethodsResponse><getCustomerPaymentMethodsReturn SOAP-ENC:arrayType="ns1:PaymentMethod[1]" xsi:type="ns1:PaymentMethodArray"><item xsi:type="ns1:PaymentMethod"><MethodType xsi:type="xsd:string">cc</MethodType><MethodID xsi:type="xsd:integer">15</MethodID><MethodName xsi:type="xsd:string">My Visa</MethodName><SecondarySort xsi:type="xsd:integer">2</SecondarySort><Created xsi:type="xsd:dateTime">2011-06-05T19:44:09+08:00</Created><Modified xsi:type="xsd:dateTime">2011-06-05T19:44:09+08:00</Modified><AvsStreet xsi:type="xsd:string">456 My Street</AvsStreet><AvsZip xsi:type="xsd:string">K1C2N6</AvsZip><CardExpiration xsi:type="xsd:string">2012-09</CardExpiration><CardNumber xsi:type="xsd:string">XXXXXXXXXXXX4242</CardNumber><CardType xsi:type="xsd:string">V</CardType></item></getCustomerPaymentMethodsReturn></ns1:getCustomerPaymentMethodsResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  def successful_update_customer_payment_method_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:usaepay" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Body><ns1:updateCustomerPaymentMethodResponse><updateCustomerPaymentMethodReturn xsi:type="xsd:boolean">true</updateCustomerPaymentMethodReturn></ns1:updateCustomerPaymentMethodResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  def successful_delete_customer_payment_method_response
    <<-XML
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:usaepay" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Body><ns1:deleteCustomerPaymentMethodResponse><deleteCustomerPaymentMethodReturn xsi:type="xsd:boolean">true</deleteCustomerPaymentMethodReturn></ns1:deleteCustomerPaymentMethodResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  def failed_delete_customer_payment_method_response
    <<-XML
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"><SOAP-ENV:Body><SOAP-ENV:Fault><faultcode>SOAP-ENV:Server</faultcode><faultstring>40453: Unable to locate requested payment method.</faultstring></SOAP-ENV:Fault></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  def failed_delete_customer_response
    <<-XML
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"><SOAP-ENV:Body><SOAP-ENV:Fault><faultcode>SOAP-ENV:Server</faultcode><faultstring>40030: Customer Not Found</faultstring></SOAP-ENV:Fault></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  # Transaction =======================================================
  def successful_avs_cvv_transaction_response(method)
    <<-XML
 <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:usaepay" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Body><ns1:#{method}Response><#{method}Return xsi:type="ns1:TransactionResponse"><AcsUrl xsi:type="xsd:string"></AcsUrl><AuthAmount xsi:type="xsd:double">0</AuthAmount><AuthCode xsi:type="xsd:string">048867</AuthCode><AvsResult xsi:type="xsd:string">Address: Match &amp; 5 Digit Zip: Match</AvsResult><AvsResultCode xsi:type="xsd:string">YYY</AvsResultCode><BatchNum xsi:type="xsd:integer">1</BatchNum><BatchRefNum xsi:type="xsd:integer">14004</BatchRefNum><CardCodeResult xsi:type="xsd:string">Match</CardCodeResult><CardCodeResultCode xsi:type="xsd:string">M</CardCodeResultCode><CardLevelResult xsi:type="xsd:string">Visa Traditional</CardLevelResult><CardLevelResultCode xsi:type="xsd:string">A</CardLevelResultCode><ConversionRate xsi:type="xsd:double">0</ConversionRate><ConvertedAmount xsi:type="xsd:double">0</ConvertedAmount><ConvertedAmountCurrency xsi:type="xsd:string">840</ConvertedAmountCurrency><CustNum xsi:type="xsd:integer">0</CustNum><Error xsi:type="xsd:string">Approved</Error><ErrorCode xsi:type="xsd:integer">0</ErrorCode><isDuplicate xsi:type="xsd:boolean">false</isDuplicate><Payload xsi:type="xsd:string"></Payload><RefNum xsi:type="xsd:integer">47567593</RefNum><Result xsi:type="xsd:string">Approved</Result><ResultCode xsi:type="xsd:string">A</ResultCode><Status xsi:type="xsd:string">Pending</Status><StatusCode xsi:type="xsd:string">P</StatusCode><VpasResultCode xsi:type="xsd:string"></VpasResultCode></#{method}Return></ns1:#{method}Response></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  def successful_transaction_response(method)
    <<-XML
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:usaepay" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Body><ns1:#{method}Response><#{method}Return xsi:type="ns1:TransactionResponse"><AcsUrl xsi:type="xsd:string"></AcsUrl><AuthAmount xsi:type="xsd:double">0</AuthAmount><AuthCode xsi:type="xsd:string">47578712</AuthCode><AvsResult xsi:type="xsd:string">Unmapped AVS response (   )</AvsResult><AvsResultCode xsi:type="xsd:string"></AvsResultCode><BatchNum xsi:type="xsd:integer">0</BatchNum><BatchRefNum xsi:type="xsd:integer">0</BatchRefNum><CardCodeResult xsi:type="xsd:string">No CVV2/CVC data available for transaction.</CardCodeResult><CardCodeResultCode xsi:type="xsd:string"></CardCodeResultCode><CardLevelResult xsi:type="xsd:string">Unknown Code </CardLevelResult><CardLevelResultCode xsi:type="xsd:string"></CardLevelResultCode><ConversionRate xsi:type="xsd:double">0</ConversionRate><ConvertedAmount xsi:type="xsd:double">0</ConvertedAmount><ConvertedAmountCurrency xsi:type="xsd:string">840</ConvertedAmountCurrency><CustNum xsi:type="xsd:integer">0</CustNum><Error xsi:type="xsd:string"></Error><ErrorCode xsi:type="xsd:integer">0</ErrorCode><isDuplicate xsi:type="xsd:boolean">false</isDuplicate><Payload xsi:type="xsd:string"></Payload><RefNum xsi:type="xsd:integer">47568689</RefNum><Result xsi:type="xsd:string">Approved</Result><ResultCode xsi:type="xsd:string">A</ResultCode><Status xsi:type="xsd:string">Pending</Status><StatusCode xsi:type="xsd:string">P</StatusCode><VpasResultCode xsi:type="xsd:string"></VpasResultCode></#{method}Return></ns1:#{method}Response></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  def failed_run_check_sale_response
    <<-XML
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:usaepay" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Body><ns1:runCheckSaleResponse><runCheckSaleReturn xsi:type="ns1:TransactionResponse"><AcsUrl xsi:type="xsd:string"></AcsUrl><AuthAmount xsi:type="xsd:double">0</AuthAmount><AuthCode xsi:type="xsd:string">000000</AuthCode><AvsResult xsi:type="xsd:string">No AVS response (Typically no AVS data sent or swiped transaction)</AvsResult><AvsResultCode xsi:type="xsd:string"></AvsResultCode><BatchNum xsi:type="xsd:integer">0</BatchNum><BatchRefNum xsi:type="xsd:integer">0</BatchRefNum><CardCodeResult xsi:type="xsd:string">No CVV2/CVC data available for transaction.</CardCodeResult><CardCodeResultCode xsi:type="xsd:string"></CardCodeResultCode><CardLevelResult xsi:type="xsd:string">Unknown Code </CardLevelResult><CardLevelResultCode xsi:type="xsd:string"></CardLevelResultCode><ConversionRate xsi:type="xsd:double">0</ConversionRate><ConvertedAmount xsi:type="xsd:double">0</ConvertedAmount><ConvertedAmountCurrency xsi:type="xsd:string"></ConvertedAmountCurrency><CustNum xsi:type="xsd:integer">0</CustNum><Error xsi:type="xsd:string">Invalid Routing Number.</Error><ErrorCode xsi:type="xsd:integer">38</ErrorCode><isDuplicate xsi:type="xsd:boolean">false</isDuplicate><Payload xsi:type="xsd:string"></Payload><RefNum xsi:type="xsd:integer">0</RefNum><Result xsi:type="xsd:string">Error</Result><ResultCode xsi:type="xsd:string">E</ResultCode><Status xsi:type="xsd:string">Pending</Status><StatusCode xsi:type="xsd:string">P</StatusCode><VpasResultCode xsi:type="xsd:string"></VpasResultCode></runCheckSaleReturn></ns1:runCheckSaleResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  def failed_run_check_credit_response
    <<-XML
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:usaepay" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Body><ns1:runCheckCreditResponse><runCheckCreditReturn xsi:type="ns1:TransactionResponse"><AcsUrl xsi:type="xsd:string"></AcsUrl><AuthAmount xsi:type="xsd:double">0</AuthAmount><AuthCode xsi:type="xsd:string">000000</AuthCode><AvsResult xsi:type="xsd:string">No AVS response (Typically no AVS data sent or swiped transaction)</AvsResult><AvsResultCode xsi:type="xsd:string"></AvsResultCode><BatchNum xsi:type="xsd:integer">0</BatchNum><BatchRefNum xsi:type="xsd:integer">0</BatchRefNum><CardCodeResult xsi:type="xsd:string">No CVV2/CVC data available for transaction.</CardCodeResult><CardCodeResultCode xsi:type="xsd:string"></CardCodeResultCode><CardLevelResult xsi:type="xsd:string">Unknown Code </CardLevelResult><CardLevelResultCode xsi:type="xsd:string"></CardLevelResultCode><ConversionRate xsi:type="xsd:double">0</ConversionRate><ConvertedAmount xsi:type="xsd:double">0</ConvertedAmount><ConvertedAmountCurrency xsi:type="xsd:string"></ConvertedAmountCurrency><CustNum xsi:type="xsd:integer">0</CustNum><Error xsi:type="xsd:string">Invalid Routing Number.</Error><ErrorCode xsi:type="xsd:integer">38</ErrorCode><isDuplicate xsi:type="xsd:boolean">false</isDuplicate><Payload xsi:type="xsd:string"></Payload><RefNum xsi:type="xsd:integer">0</RefNum><Result xsi:type="xsd:string">Error</Result><ResultCode xsi:type="xsd:string">E</ResultCode><Status xsi:type="xsd:string">Pending</Status><StatusCode xsi:type="xsd:string">P</StatusCode><VpasResultCode xsi:type="xsd:string"></VpasResultCode></runCheckCreditReturn></ns1:runCheckCreditResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  def successful_post_auth_response
    <<-XML
    XML
  end

  def failed_post_auth_response
    <<-XML
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:usaepay" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Body><ns1:postAuthResponse><postAuthReturn xsi:type="ns1:TransactionResponse"><AcsUrl xsi:type="xsd:string"></AcsUrl><AuthAmount xsi:type="xsd:double">0</AuthAmount><AuthCode xsi:type="xsd:string">000000</AuthCode><AvsResult xsi:type="xsd:string">No AVS response (Typically no AVS data sent or swiped transaction)</AvsResult><AvsResultCode xsi:type="xsd:string"></AvsResultCode><BatchNum xsi:type="xsd:integer">0</BatchNum><BatchRefNum xsi:type="xsd:integer">0</BatchRefNum><CardCodeResult xsi:type="xsd:string">No CVV2/CVC data available for transaction.</CardCodeResult><CardCodeResultCode xsi:type="xsd:string"></CardCodeResultCode><CardLevelResult xsi:type="xsd:string">Unknown Code </CardLevelResult><CardLevelResultCode xsi:type="xsd:string"></CardLevelResultCode><ConversionRate xsi:type="xsd:double">0</ConversionRate><ConvertedAmount xsi:type="xsd:double">0</ConvertedAmount><ConvertedAmountCurrency xsi:type="xsd:string"></ConvertedAmountCurrency><CustNum xsi:type="xsd:integer">0</CustNum><Error xsi:type="xsd:string">Valid AuthCode required for PostAuth</Error><ErrorCode xsi:type="xsd:integer">108</ErrorCode><isDuplicate xsi:type="xsd:boolean">false</isDuplicate><Payload xsi:type="xsd:string"></Payload><RefNum xsi:type="xsd:integer">0</RefNum><Result xsi:type="xsd:string">Error</Result><ResultCode xsi:type="xsd:string">E</ResultCode><Status xsi:type="xsd:string">Pending</Status><StatusCode xsi:type="xsd:string">P</StatusCode><VpasResultCode xsi:type="xsd:string"></VpasResultCode></postAuthReturn></ns1:postAuthResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  def successful_capture_transaction_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:usaepay" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Body><ns1:captureTransactionResponse><captureTransactionReturn xsi:type="ns1:TransactionResponse"><AcsUrl xsi:type="xsd:string"></AcsUrl><AuthAmount xsi:type="xsd:double">0</AuthAmount><AuthCode xsi:type="xsd:string">004043</AuthCode><AvsResult xsi:type="xsd:string">No AVS response (Typically no AVS data sent or swiped transaction)</AvsResult><AvsResultCode xsi:type="xsd:string"></AvsResultCode><BatchNum xsi:type="xsd:integer">0</BatchNum><BatchRefNum xsi:type="xsd:integer">0</BatchRefNum><CardCodeResult xsi:type="xsd:string">No CVV2/CVC data available for transaction.</CardCodeResult><CardCodeResultCode xsi:type="xsd:string"></CardCodeResultCode><CardLevelResult xsi:type="xsd:string">Unknown Code </CardLevelResult><CardLevelResultCode xsi:type="xsd:string"></CardLevelResultCode><ConversionRate xsi:type="xsd:double">0</ConversionRate><ConvertedAmount xsi:type="xsd:double">0</ConvertedAmount><ConvertedAmountCurrency xsi:type="xsd:string">840</ConvertedAmountCurrency><CustNum xsi:type="xsd:integer">0</CustNum><Error xsi:type="xsd:string">Approved</Error><ErrorCode xsi:type="xsd:integer">0</ErrorCode><isDuplicate xsi:type="xsd:boolean">false</isDuplicate><Payload xsi:type="xsd:string"></Payload><RefNum xsi:type="xsd:integer">47587252</RefNum><Result xsi:type="xsd:string">Approved</Result><ResultCode xsi:type="xsd:string">A</ResultCode><Status xsi:type="xsd:string">Pending</Status><StatusCode xsi:type="xsd:string">P</StatusCode><VpasResultCode xsi:type="xsd:string"></VpasResultCode></captureTransactionReturn></ns1:captureTransactionResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  def successful_override_transaction_response
    <<-XML
    XML
  end

  def failed_override_transaction_response
    <<-XML
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"><SOAP-ENV:Body><SOAP-ENV:Fault><faultcode>SOAP-ENV:Server</faultcode><faultstring>105: Override not available for requested transaction.</faultstring></SOAP-ENV:Fault></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  def successful_void_transaction_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:usaepay" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Body><ns1:voidTransactionResponse><voidTransactionReturn xsi:type="xsd:boolean">true</voidTransactionReturn></ns1:voidTransactionResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  def successful_refund_transaction_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:usaepay" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Body><ns1:refundTransactionResponse><refundTransactionReturn xsi:type="ns1:TransactionResponse"><AcsUrl xsi:nil="true"/><AuthAmount xsi:type="xsd:double">0</AuthAmount><AuthCode xsi:type="xsd:string">47597281</AuthCode><AvsResult xsi:type="xsd:string">Unmapped AVS response (   )</AvsResult><AvsResultCode xsi:type="xsd:string"></AvsResultCode><BatchNum xsi:nil="true"/><BatchRefNum xsi:nil="true"/><CardCodeResult xsi:type="xsd:string">No CVV2/CVC data available for transaction.</CardCodeResult><CardCodeResultCode xsi:type="xsd:string"></CardCodeResultCode><CardLevelResult xsi:type="xsd:string">Unknown Code </CardLevelResult><CardLevelResultCode xsi:type="xsd:string"></CardLevelResultCode><ConversionRate xsi:type="xsd:double">0</ConversionRate><ConvertedAmount xsi:type="xsd:double">0</ConvertedAmount><ConvertedAmountCurrency xsi:nil="true"/><CustNum xsi:type="xsd:integer">0</CustNum><Error xsi:type="xsd:string"></Error><ErrorCode xsi:nil="true"/><isDuplicate xsi:type="xsd:boolean">false</isDuplicate><Payload xsi:nil="true"/><RefNum xsi:type="xsd:integer">47587258</RefNum><Result xsi:type="xsd:string">Approved</Result><ResultCode xsi:type="xsd:string">A</ResultCode><Status xsi:type="xsd:string">Pending</Status><StatusCode xsi:type="xsd:string">P</StatusCode><VpasResultCode xsi:type="xsd:string"></VpasResultCode></refundTransactionReturn></ns1:refundTransactionResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  # Transaction Response ==============================================

  def successful_get_transaction_status_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:usaepay" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Body><ns1:getTransactionStatusResponse><getTransactionStatusReturn xsi:type="ns1:TransactionResponse"><AcsUrl xsi:nil="true"/><AuthAmount xsi:type="xsd:double">50</AuthAmount><AuthCode xsi:type="xsd:string">050162</AuthCode><AvsResult xsi:type="xsd:string">Address: Match &amp; 5 Digit Zip: Match</AvsResult><AvsResultCode xsi:type="xsd:string">YYY</AvsResultCode><BatchNum xsi:type="xsd:integer">1</BatchNum><BatchRefNum xsi:type="xsd:integer">14004</BatchRefNum><CardCodeResult xsi:type="xsd:string">Match</CardCodeResult><CardCodeResultCode xsi:type="xsd:string">M</CardCodeResultCode><CardLevelResult xsi:nil="true"/><CardLevelResultCode xsi:nil="true"/><ConversionRate xsi:type="xsd:double">0</ConversionRate><ConvertedAmount xsi:type="xsd:double">0</ConvertedAmount><ConvertedAmountCurrency xsi:type="xsd:string"></ConvertedAmountCurrency><CustNum xsi:type="xsd:integer">0</CustNum><Error xsi:type="xsd:string">Approved</Error><ErrorCode xsi:type="xsd:integer">0</ErrorCode><isDuplicate xsi:type="xsd:boolean">false</isDuplicate><Payload xsi:nil="true"/><RefNum xsi:type="xsd:integer">47569011</RefNum><Result xsi:type="xsd:string">Approved</Result><ResultCode xsi:type="xsd:string">A</ResultCode><Status xsi:type="xsd:string">Pending</Status><StatusCode xsi:type="xsd:string">P</StatusCode><VpasResultCode xsi:nil="true"/></getTransactionStatusReturn></ns1:getTransactionStatusResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  def successful_get_transaction_custom_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:usaepay" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Body><ns1:getTransactionCustomResponse><getTransactionCustomReturn SOAP-ENC:arrayType="ns1:FieldValue[2]" xsi:type="ns1:FieldValueArray"><item xsi:type="ns1:FieldValue"><Field xsi:type="xsd:string">Response.StatusCode</Field><Value xsi:type="xsd:string">P</Value></item><item xsi:type="ns1:FieldValue"><Field xsi:type="xsd:string">Response.Status</Field><Value xsi:type="xsd:string">Pending</Value></item></getTransactionCustomReturn></ns1:getTransactionCustomResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  def successful_get_check_trace_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:usaepay" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Body><ns1:getCheckTraceResponse><getCheckTraceReturn xsi:type="ns1:CheckTrace"><Status xsi:type="xsd:string">Pending</Status><StatusCode xsi:type="xsd:string">P</StatusCode><Effective xsi:type="xsd:string">2011-06-21</Effective><TrackingNum xsi:type="xsd:string">11061908516155</TrackingNum></getCheckTraceReturn></ns1:getCheckTraceResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  def successful_get_transaction_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:usaepay" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Body><ns1:getTransactionResponse><getTransactionReturn xsi:type="ns1:TransactionObject"><AccountHolder xsi:type="xsd:string"></AccountHolder><BillingAddress xsi:type="ns1:Address"><City xsi:type="xsd:string">Ottawa</City><Company xsi:type="xsd:string">Widgets Inc</Company><Country xsi:type="xsd:string">CA</Country><Email xsi:type="xsd:string"></Email><Fax xsi:type="xsd:string"></Fax><FirstName xsi:type="xsd:string">Jim</FirstName><LastName xsi:type="xsd:string">Smith</LastName><Phone xsi:type="xsd:string">(555)555-5555</Phone><State xsi:type="xsd:string">ON</State><Street xsi:type="xsd:string">456 My Street</Street><Street2 xsi:type="xsd:string">Apt 1</Street2><Zip xsi:type="xsd:string">K1C2N6</Zip></BillingAddress><CheckData xsi:type="ns1:CheckData"><Account xsi:nil="true"/><Routing xsi:nil="true"/></CheckData><CheckTrace xsi:type="ns1:CheckTrace"/><ClientIP xsi:type="xsd:string">127.0.0.1</ClientIP><CreditCardData xsi:type="ns1:CreditCardData"><AvsStreet xsi:type="xsd:string">456 My Street</AvsStreet><AvsZip xsi:type="xsd:string">K1C2N6</AvsZip><CardCode xsi:type="xsd:string">XXX</CardCode><CardExpiration xsi:type="xsd:string">XXXX</CardExpiration><CardNumber xsi:type="xsd:string">XXXXXXXXXXXX2224</CardNumber><CardPresent xsi:type="xsd:boolean">false</CardPresent><CardType xsi:type="xsd:string">V</CardType><InternalCardAuth xsi:type="xsd:boolean">false</InternalCardAuth><MagStripe xsi:type="xsd:string"></MagStripe><MagSupport xsi:type="xsd:string"></MagSupport><Pares xsi:type="xsd:string"></Pares><TermType xsi:type="xsd:string"></TermType></CreditCardData><CustomerID xsi:type="xsd:string"></CustomerID><CustomFields SOAP-ENC:arrayType="ns1:FieldValue[0]" xsi:type="ns1:FieldValueArray"/><DateTime xsi:type="xsd:string">2011-06-11 19:23:37</DateTime><Details xsi:type="ns1:TransactionDetail"><Amount xsi:type="xsd:double">50</Amount><Clerk xsi:type="xsd:string"></Clerk><Currency xsi:type="xsd:string"></Currency><Description xsi:type="xsd:string"></Description><Comments xsi:type="xsd:string"></Comments><Discount xsi:type="xsd:double">0</Discount><Invoice xsi:type="xsd:string"></Invoice><NonTax xsi:type="xsd:boolean">false</NonTax><OrderID xsi:type="xsd:string"></OrderID><PONum xsi:type="xsd:string"></PONum><Shipping xsi:type="xsd:double">0</Shipping><Subtotal xsi:type="xsd:double">0</Subtotal><Table xsi:type="xsd:string"></Table><Tax xsi:type="xsd:double">0</Tax><Terminal xsi:type="xsd:string"></Terminal><Tip xsi:type="xsd:double">0</Tip></Details><LineItems SOAP-ENC:arrayType="ns1:LineItem[0]" xsi:type="ns1:LineItemArray"/><Response xsi:type="ns1:TransactionResponse"><AcsUrl xsi:nil="true"/><AuthAmount xsi:type="xsd:double">50</AuthAmount><AuthCode xsi:type="xsd:string">050129</AuthCode><AvsResult xsi:type="xsd:string">Address: Match &amp; 5 Digit Zip: Match</AvsResult><AvsResultCode xsi:type="xsd:string">YYY</AvsResultCode><BatchNum xsi:type="xsd:integer">1</BatchNum><BatchRefNum xsi:type="xsd:integer">14004</BatchRefNum><CardCodeResult xsi:type="xsd:string">Match</CardCodeResult><CardCodeResultCode xsi:type="xsd:string">M</CardCodeResultCode><CardLevelResult xsi:nil="true"/><CardLevelResultCode xsi:nil="true"/><ConversionRate xsi:type="xsd:double">0</ConversionRate><ConvertedAmount xsi:type="xsd:double">0</ConvertedAmount><ConvertedAmountCurrency xsi:type="xsd:string"></ConvertedAmountCurrency><CustNum xsi:type="xsd:integer">0</CustNum><Error xsi:type="xsd:string">Approved</Error><ErrorCode xsi:type="xsd:integer">0</ErrorCode><isDuplicate xsi:type="xsd:boolean">false</isDuplicate><Payload xsi:nil="true"/><RefNum xsi:type="xsd:integer">47568950</RefNum><Result xsi:type="xsd:string">Approved</Result><ResultCode xsi:type="xsd:string">A</ResultCode><Status xsi:type="xsd:string">Pending</Status><StatusCode xsi:type="xsd:string">P</StatusCode><VpasResultCode xsi:nil="true"/></Response><ServerIP xsi:type="xsd:string">67.168.21.42</ServerIP><ShippingAddress xsi:type="ns1:Address"><City xsi:type="xsd:string">Ottawa</City><Company xsi:type="xsd:string">Widgets Inc</Company><Country xsi:type="xsd:string">CA</Country><Email xsi:type="xsd:string"></Email><Fax xsi:type="xsd:string"></Fax><FirstName xsi:type="xsd:string">Jim</FirstName><LastName xsi:type="xsd:string">Smith</LastName><Phone xsi:type="xsd:string">(555)555-5555</Phone><State xsi:type="xsd:string">ON</State><Street xsi:type="xsd:string">456 My Street</Street><Street2 xsi:type="xsd:string">Apt 1</Street2><Zip xsi:type="xsd:string">K1C2N6</Zip></ShippingAddress><Source xsi:type="xsd:string">test</Source><Status xsi:type="xsd:string">Authorized (Pending Settlement)</Status><TransactionType xsi:type="xsd:string">Sale</TransactionType><User xsi:type="xsd:string">auto</User></getTransactionReturn></ns1:getTransactionResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  # Account ===========================================================

  def successful_get_account_details
    <<-XML
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:usaepay" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Body><ns1:getAccountDetailsResponse><getAccountDetailsReturn xsi:type="ns1:AccountDetails"><CardholderAuthentication xsi:type="xsd:string">Disabled</CardholderAuthentication>
<CheckPlatform xsi:type="xsd:string">TestBed</CheckPlatform><CreditCardPlatform xsi:type="xsd:string">Test Bed</CreditCardPlatform><DebitCardSupport xsi:type="xsd:boolean">false</DebitCardSupport><DirectPayPlatform xsi:type="xsd:string">Disabled</DirectPayPlatform><Industry xsi:type="xsd:string">eCommerce</Industry><SupportedCurrencies SOAP-ENC:arrayType="ns1:CurrencyObject[0]" xsi:type="ns1:CurrencyObjectArray"/></getAccountDetailsReturn></ns1:getAccountDetailsResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
    XML
  end

  # Assertion Helpers =================================================

  def assert_avs_cvv_match(response)
    assert_equal 'Y', response.avs_result['code']
    assert_equal 'Y', response.avs_result['street_match']
    assert_equal 'Y', response.avs_result['postal_match']
    assert_equal 'M', response.cvv_result['code']
  end
end
