require 'test_helper'

class LitleTest < Test::Unit::TestCase

  def setup
    @gateway = LitleGateway.new({:merchant_id=>'101', :user=>'active', :password=>'merchant', :version=>'8.10', :url=>'https://www.testlitle.com/sandbox/communicator/online'})
    @credit_card_options = {
      :first_name => 'Steve',
      :last_name  => 'Smith',
      :month      => '9',
      :year       => '2010',
      :brand      => 'visa',
      :number     => '4242424242424242',
      :verification_value => '969'
    }
    @billing_address = {
      :name      => 'Steve Smith',
      :company   => 'testCompany',
      :address1  => '900 random st',
      :address2  => 'floor 10',
      :city      => 'lowell',
      :state     => 'ma',
      :country   => 'usa',
      :zip       => '12345',
      :phone     => '1234567890'
    }

    @shipping_address = {
      :name      => 'Steve Smith',
      :company   => '',
      :address1  => '500 nnnn st',
      :address2  => '',
      :city      => 'lowell',
      :state     => 'ma',
      :country   => 'usa',
      :zip       => '12345',
      :phone     => '1234567890'
    }

    @response_options = {
      'response' => '000',
      'message' => 'successful',
      'litleTxnId' => '1234',
      'litleToken'=>'1111222233334444'
    }
  end
  
  def test_create_credit_card_hash
    # define all inputs
    money = 1000

    creditcard = CreditCard.new(@credit_card_options)

    order_id = '1234'
    ip = '192.168.0.1'
    customer = '4000'
    invoice = '1000'
    merchant = 'ABC'
    description = 'cool stuff'
    email = 'abc@xyz.com'
    currency = 'USD'

    options = {
      :order_id=>order_id,
      :ip=>ip,
      :customer=>customer,
      :invoice=>invoice,
      :merchant=>merchant,
      :description=>description,
      :email=>email,
      :currency=>currency,
      :billing_address=>@billing_address,
      :shipping_address=>@shipping_address,
      :merchant_id=>'101'
    }

    hash_from_gateway = @gateway.send(:create_credit_card_hash, money, creditcard, options)

    assert_equal 1000, hash_from_gateway['amount']
    assert_equal 'VI', hash_from_gateway['card']['type']
    assert_equal '4242424242424242', hash_from_gateway['card']['number']
    assert_equal '0910', hash_from_gateway['card']['expDate']
    assert_equal '969', hash_from_gateway['card']['cardValidationNum']
    #billing address
    assert_equal 'Steve Smith', hash_from_gateway['billToAddress']['name']
    assert_equal 'testCompany', hash_from_gateway['billToAddress']['companyName']
    assert_equal '900 random st', hash_from_gateway['billToAddress']['addressLine1']
    assert_equal 'floor 10', hash_from_gateway['billToAddress']['addressLine2']
    assert_equal 'lowell', hash_from_gateway['billToAddress']['city']
    assert_equal 'ma', hash_from_gateway['billToAddress']['state']
    assert_equal '12345', hash_from_gateway['billToAddress']['zip']
    assert_equal 'usa', hash_from_gateway['billToAddress']['country']
    assert_equal 'abc@xyz.com', hash_from_gateway['billToAddress']['email']
    assert_equal '1234567890', hash_from_gateway['billToAddress']['phone']
    #shipping address
    assert_equal 'Steve Smith', hash_from_gateway['shipToAddress']['name']
    assert_nil hash_from_gateway['shipToAddress']['company']
    assert_equal '500 nnnn st', hash_from_gateway['shipToAddress']['addressLine1']
    assert_equal '', hash_from_gateway['shipToAddress']['addressLine2']
    assert_equal 'lowell', hash_from_gateway['shipToAddress']['city']
    assert_equal 'ma', hash_from_gateway['shipToAddress']['state']
    assert_equal '12345', hash_from_gateway['shipToAddress']['zip']
    assert_equal 'usa', hash_from_gateway['shipToAddress']['country']
    assert_equal 'abc@xyz.com', hash_from_gateway['shipToAddress']['email']
    assert_equal '1234567890', hash_from_gateway['shipToAddress']['phone']

    assert_equal '1234', hash_from_gateway['orderId']
    assert_equal '4000', hash_from_gateway['customerId']
    assert_equal 'ABC', hash_from_gateway['reportGroup']  #The option :merchant is used for Litle's Report Group
    assert_equal '101', hash_from_gateway['merchantId']

    assert_equal '1000', hash_from_gateway['enhancedData']['invoiceReferenceNumber']
    assert_equal '192.168.0.1', hash_from_gateway['fraudCheckType']['customerIpAddress']
    assert_equal 'cool stuff', hash_from_gateway['enhancedData']['customerReference']
  end

  def test_createHash_money_not_nil
    # define all inputs
    money = 1000

    order_id = '1234'
    ip = '192.168.0.1'
    customer = '4000'
    invoice = '1000'
    merchant = 'ABC'
    description = 'cool stuff'
    email = 'abc@xyz.com'
    currency = 'USD'

    options = {
      :order_id=>order_id,
      :ip=>ip,
      :customer=>customer,
      :invoice=>invoice,
      :merchant=>merchant,
      :description=>description,
      :email=>email,
      :currency=>currency,
      :billing_address=>@billing_address,
      :shipping_address=>@shipping_address,
      :merchant_id=>'101'
    }

    hashFromGateway = @gateway.send(:create_hash, money, options)

    assert_equal 1000, hashFromGateway['amount']
    #billing address
    assert_equal 'Steve Smith', hashFromGateway['billToAddress']['name']
    assert_equal 'testCompany', hashFromGateway['billToAddress']['companyName']
    assert_equal '900 random st', hashFromGateway['billToAddress']['addressLine1']
    assert_equal 'floor 10', hashFromGateway['billToAddress']['addressLine2']
    assert_equal 'lowell', hashFromGateway['billToAddress']['city']
    assert_equal 'ma', hashFromGateway['billToAddress']['state']
    assert_equal '12345', hashFromGateway['billToAddress']['zip']
    assert_equal 'usa', hashFromGateway['billToAddress']['country']
    assert_equal 'abc@xyz.com', hashFromGateway['billToAddress']['email']
    assert_equal '1234567890', hashFromGateway['billToAddress']['phone']
    #shipping address
    assert_equal 'Steve Smith', hashFromGateway['shipToAddress']['name']
    assert_nil hashFromGateway['shipToAddress']['company']
    assert_equal '500 nnnn st', hashFromGateway['shipToAddress']['addressLine1']
    assert_equal '', hashFromGateway['shipToAddress']['addressLine2']
    assert_equal 'lowell', hashFromGateway['shipToAddress']['city']
    assert_equal 'ma', hashFromGateway['shipToAddress']['state']
    assert_equal '12345', hashFromGateway['shipToAddress']['zip']
    assert_equal 'usa', hashFromGateway['shipToAddress']['country']
    assert_equal 'abc@xyz.com', hashFromGateway['shipToAddress']['email']
    assert_equal '1234567890', hashFromGateway['shipToAddress']['phone']

    assert_equal '1234', hashFromGateway['orderId']
    assert_equal '4000', hashFromGateway['customerId']
    assert_equal 'ABC', hashFromGateway['reportGroup']  #The option :merchant is used for Litle's Report Group
    assert_equal '101', hashFromGateway['merchantId']

    assert_equal '1000', hashFromGateway['enhancedData']['invoiceReferenceNumber']
    assert_equal '192.168.0.1', hashFromGateway['fraudCheckType']['customerIpAddress']
    assert_equal 'cool stuff', hashFromGateway['enhancedData']['customerReference']
  end

  def test_create_hash_money_nil
    # define all inputs
    money = nil
    
    hashFromGateway = @gateway.send(:create_hash, money, {})

    assert_nil hashFromGateway['amount']
  end
  
  def test_create_hash_money_empty_string
    # define all inputs
    money = ''
    
    hashFromGateway = @gateway.send(:create_hash, money, {})

    assert_nil hashFromGateway['amount']
  end

  def test_recognize_ax_and_some_empties
    creditcard = CreditCard.new(@credit_card_options.merge(:brand => 'american_express'))
    hashFromGateway = @gateway.send(:create_credit_card_hash, 0, creditcard, {})
    assert_equal 'AX', hashFromGateway['card']['type']
    assert_nil hashFromGateway['billToAddress']
    assert_nil hashFromGateway['shipToAddress']
  end

  def test_recognize_di
    creditcard = CreditCard.new(@credit_card_options.merge(:brand => 'discover'))
    hashFromGateway = @gateway.send(:create_credit_card_hash, 0, creditcard, {})
    assert_equal 'DI', hashFromGateway['card']['type']
  end

  def test_recognize_mastercard
    creditcard = CreditCard.new(@credit_card_options.merge(:brand => 'master'))
    hashFromGateway = @gateway.send(:create_credit_card_hash, 0,creditcard,{})
    assert_equal 'MC', hashFromGateway['card']['type']
  end

  def test_recognize_jcb
    creditcard = CreditCard.new(@credit_card_options.merge(:brand => 'jcb'))
    hashFromGateway = @gateway.send(:create_credit_card_hash, 0, creditcard, {})
    assert_equal 'DI', hashFromGateway['card']['type']
  end

  def test_recognize_diners
    creditcard = CreditCard.new(@credit_card_options.merge(:brand => 'diners_club'))
    hashFromGateway = @gateway.send(:create_credit_card_hash, 0, creditcard, {})
    assert_equal 'DI', hashFromGateway['card']['type']
  end

  def test_two_digit_month
    creditcard = CreditCard.new(@credit_card_options.merge(:month => '11'))
    hashFromGateway = @gateway.send(:create_credit_card_hash, 0, creditcard, {})
    assert_equal '1110', hashFromGateway['card']['expDate']
  end

  def test_nils_in_both_addresses
    creditcard = CreditCard.new(@credit_card_options)

    hashFromGateway = @gateway.send(:create_credit_card_hash, 0, creditcard,
    {:shipping_address=>{},:billing_address=>{}})

    %w(name companyName company addressLine1 addressLine2 city state zip country email phone).each do |att|
      #billing address
      assert_nil hashFromGateway['billToAddress'][att]
      #shipping address
      assert_nil hashFromGateway['shipToAddress'][att]
    end

  end

  def test_create_credit_hash
    hashFromGateway = @gateway.send(:create_credit_hash, 1000, '123456789012345678', {})
    assert_equal '123456789012345678', hashFromGateway['litleTxnId']
    assert_equal nil, hashFromGateway['orderSource']
    assert_equal nil, hashFromGateway['orderId']
  end

  def test_currency_USD
    creditcard = CreditCard.new(@credit_card_options)
    hashFromGateway = @gateway.send(:create_credit_card_hash, 0, creditcard, {:currency=>'USD',:merchant_id=>'101'})
    assert_equal '101', hashFromGateway['merchantId']
  end

  def test_currency_DEFAULT
    creditcard = CreditCard.new(@credit_card_options)
    hashFromGateway = @gateway.send(:create_credit_card_hash, 0, creditcard, {:merchant_id=>'101'})
    assert_equal '101', hashFromGateway['merchantId']
  end

  def test_currency_EUR
    creditcard = CreditCard.new(@credit_card_options)
    hashFromGateway = @gateway.send(:create_credit_card_hash, 0, creditcard, {:currency=>'EUR',:merchant_id=>'102'})
    assert_equal '102', hashFromGateway['merchantId']
  end

  def test_auth_pass
    authorizationResponseObj = @response_options
    retObj = {'response'=>'0','authorizationResponse'=>authorizationResponseObj}
    LitleOnline::Communications.expects(:http_post => retObj.to_xml(:root => 'litleOnlineResponse'))

    creditcard = CreditCard.new(@credit_card_options)
    responseFrom = @gateway.authorize(0, creditcard)
    assert_equal true, responseFrom.success?
    assert_equal 'successful', responseFrom.message
    assert_equal '1234', responseFrom.authorization
    assert_equal '1111222233334444', responseFrom.params['litleOnlineResponse']['authorizationResponse']['litleToken']
  end

  def test_avs
    fraudResult = {'avsResult'=>'01'}
    authorizationResponseObj = @response_options.merge('fraudResult' => fraudResult)
    retObj = {'response'=>'0','authorizationResponse'=>authorizationResponseObj}
    LitleOnline::Communications.expects(:http_post => retObj.to_xml(:root => 'litleOnlineResponse'))

    creditcard = CreditCard.new(@credit_card_options)
    responseFrom = @gateway.authorize(0, creditcard)
    assert_equal true, responseFrom.success?
    assert_equal 'X', responseFrom.avs_result['code']
    assert_equal 'Street address and 9-digit postal code match.', responseFrom.avs_result['message']
    assert_equal 'Y', responseFrom.avs_result['street_match']
    assert_equal 'Y', responseFrom.avs_result['postal_match']
  end
  
  def test_cvv
    fraudResult = {'cardValidationResult'=>'M'}
    authorizationResponseObj = @response_options.merge('fraudResult' => fraudResult)
    retObj = {'response'=>'0','authorizationResponse'=>authorizationResponseObj}
    LitleOnline::Communications.expects(:http_post => retObj.to_xml(:root => 'litleOnlineResponse'))

    creditcard = CreditCard.new(@credit_card_options)
    responseFrom = @gateway.authorize(0, creditcard)
    assert_equal true, responseFrom.success?
    assert_equal 'M', responseFrom.cvv_result['code']
    assert_equal 'Match', responseFrom.cvv_result['message']
  end

  def test_sale_avs
    fraudResult = {'avsResult'=>'10'}
    saleResponseObj = @response_options.merge('fraudResult' => fraudResult)
    retObj = {'response'=>'0','saleResponse'=>saleResponseObj}
    LitleOnline::Communications.expects(:http_post => retObj.to_xml(:root => 'litleOnlineResponse'))

    creditcard = CreditCard.new(@credit_card_options)
    responseFrom = @gateway.purchase(0, creditcard)
    assert_equal true, responseFrom.success?
    assert_equal 'Z', responseFrom.avs_result['code']
    assert_equal 'Street address does not match, but 5-digit postal code matches.', responseFrom.avs_result['message']
    assert_equal 'N', responseFrom.avs_result['street_match']
    assert_equal 'Y', responseFrom.avs_result['postal_match']
  end
  
  def test_sale_cvv
    fraudResult = {'cardValidationResult'=>''}
    saleResponseObj = @response_options.merge('fraudResult' => fraudResult)
    retObj = {'response'=>'0','saleResponse'=>saleResponseObj}
    LitleOnline::Communications.expects(:http_post => retObj.to_xml(:root => 'litleOnlineResponse'))

    creditcard = CreditCard.new(@credit_card_options)
    responseFrom = @gateway.purchase(0, creditcard)
    assert_equal true, responseFrom.success?
    assert_equal 'P', responseFrom.cvv_result['code']
    assert_equal 'Not Processed', responseFrom.cvv_result['message']
  end

    
  def test_auth_fail
    authorizationResponseObj = {'response' => '111', 'message' => 'fail', 'litleTxnId' => '1234', 'litleToken'=>'1111222233334444'}
    retObj = {'response'=>'0','authorizationResponse'=>authorizationResponseObj}
    LitleOnline::Communications.expects(:http_post => retObj.to_xml(:root => 'litleOnlineResponse'))

    creditcard = CreditCard.new(@credit_card_options)
    responseFrom = @gateway.authorize(0, creditcard)
    assert_equal false, responseFrom.success?
    assert_equal '1234', responseFrom.authorization
    assert_equal '1111222233334444', responseFrom.params['litleOnlineResponse']['authorizationResponse']['litleToken']
  end

  def test_auth_fail_schema
    retObj = {'response'=>'1','message'=>'Error validating xml data against the schema'}
    LitleOnline::Communications.expects(:http_post => retObj.to_xml(:root => 'litleOnlineResponse'))

    creditcard = CreditCard.new(@credit_card_options)
    responseFrom = @gateway.authorize(0, creditcard)
    assert_equal false, responseFrom.success?
    assert_equal 'Error validating xml data against the schema', responseFrom.message
  end

  def test_purchase_pass
    purchaseResponseObj = {'response' => '000', 'message' => 'successful', 'litleTxnId'=>'123456789012345678'}
    retObj = {'response'=>'0','saleResponse'=>purchaseResponseObj}
    LitleOnline::Communications.expects(:http_post => retObj.to_xml(:root => 'litleOnlineResponse'))

    creditcard = CreditCard.new(@credit_card_options)
    responseFrom = @gateway.purchase(0, creditcard)
    assert_equal true, responseFrom.success?
    assert_equal '123456789012345678', responseFrom.authorization
  end

  def test_purchase_fail
    purchaseResponseObj = {'response' => '111', 'message' => 'fail', 'litleTxnId'=>'123456789012345678'}
    retObj = {'response'=>'0','saleResponse'=>purchaseResponseObj}
    LitleOnline::Communications.expects(:http_post => retObj.to_xml(:root => 'litleOnlineResponse'))

    creditcard = CreditCard.new(@credit_card_options)
    responseFrom = @gateway.purchase(0, creditcard)
    assert_equal false, responseFrom.success?
    assert_equal '123456789012345678', responseFrom.authorization
  end

  def test_purchase_fail_schema
    retObj = {'response'=>'1','message'=>'Error validating xml data against the schema'}
    LitleOnline::Communications.expects(:http_post => retObj.to_xml(:root => 'litleOnlineResponse'))

    creditcard = CreditCard.new(@credit_card_options)
    responseFrom = @gateway.purchase(0, creditcard)
    assert_equal false, responseFrom.success?
    assert_equal 'Error validating xml data against the schema', responseFrom.message
  end

  def test_capture_pass
    captureResponseObj = {'response' => '000', 'message' => 'pass', 'litleTxnId'=>'123456789012345678'}
    retObj = {'response'=>'0','captureResponse'=>captureResponseObj}
    LitleOnline::Communications.expects(:http_post => retObj.to_xml(:root => 'litleOnlineResponse'))
    authorization = "1234"
    responseFrom = @gateway.capture(0, authorization)
    assert_equal true, responseFrom.success?
    assert_equal '123456789012345678', responseFrom.authorization
  end

  def test_capture_fail
    captureResponseObj = {'response' => '111', 'message' => 'fail', 'litleTxnId'=>'123456789012345678'}
    retObj = {'response'=>'0','captureResponse'=>captureResponseObj}
    LitleOnline::Communications.expects(:http_post => retObj.to_xml(:root => 'litleOnlineResponse'))
    authorization = "1234"
    responseFrom = @gateway.capture(0, authorization)
    assert_equal false, responseFrom.success?
    assert_equal '123456789012345678', responseFrom.authorization
  end

  def test_capture_fail_schema
    retObj = {'response'=>'1','message'=>'Error validating xml data against the schema'}
    LitleOnline::Communications.expects(:http_post => retObj.to_xml(:root => 'litleOnlineResponse'))
    authorization = '1234'
    responseFrom = @gateway.authorize(0, authorization)
    assert_equal false, responseFrom.success?
    assert_equal 'Error validating xml data against the schema', responseFrom.message
  end

  def test_void_pass
    voidResponseObj = {'response' => '000', 'message' => 'pass', 'litleTxnId'=>'123456789012345678'}
    retObj = {'response'=>'0','voidResponse'=>voidResponseObj}
    LitleOnline::Communications.expects(:http_post => retObj.to_xml(:root => 'litleOnlineResponse'))
    identification = "1234"
    responseFrom = @gateway.void(identification)
    assert_equal true, responseFrom.success?
    assert_equal '123456789012345678', responseFrom.authorization
  end

  def test_void_fail
    voidResponseObj = {'response' => '111', 'message' => 'fail', 'litleTxnId'=>'123456789012345678'}
    retObj = {'response'=>'0','voidResponse'=>voidResponseObj}
    LitleOnline::Communications.expects(:http_post => retObj.to_xml(:root => 'litleOnlineResponse'))
    identification = "1234"
    responseFrom = @gateway.void(identification)
    assert_equal false, responseFrom.success?
    assert_equal '123456789012345678', responseFrom.authorization
  end

  def test_void_fail_schema
    retObj = {'response'=>'1','message'=>'Error validating xml data against the schema'}
    LitleOnline::Communications.expects(:http_post => retObj.to_xml(:root => 'litleOnlineResponse'))
    identification = "1234"
    responseFrom = @gateway.void(identification)
    assert_equal false, responseFrom.success?
    assert_equal 'Error validating xml data against the schema', responseFrom.message
  end

  def test_credit_pass
    creditResponseObj = {'response' => '000', 'message' => 'pass', 'litleTxnId'=>'123456789012345678'}
    retObj = {'response'=>'0','creditResponse'=>creditResponseObj}
    LitleOnline::Communications.expects(:http_post => retObj.to_xml(:root => 'litleOnlineResponse'))
    identification = "1234"
    responseFrom = @gateway.credit(0, identification)
    assert_equal true, responseFrom.success?
    assert_equal '123456789012345678', responseFrom.authorization
  end

  def test_credit_fail
    creditResponseObj = {'response' => '111', 'message' => 'fail', 'litleTxnId'=>'123456789012345678'}
    retObj = {'response'=>'0','creditResponse'=>creditResponseObj}
    LitleOnline::Communications.expects(:http_post => retObj.to_xml(:root => 'litleOnlineResponse'))
    identification = "1234"
    responseFrom = @gateway.credit(0, identification)
    assert_equal false, responseFrom.success?
    assert_equal '123456789012345678', responseFrom.authorization
  end

  def test_capture_fail_schema
    retObj = {'response'=>'1','message'=>'Error validating xml data against the schema'}
    LitleOnline::Communications.expects(:http_post => retObj.to_xml(:root => 'litleOnlineResponse'))
    identification = '1234'
    responseFrom = @gateway.credit(0, identification)
    assert_equal false, responseFrom.success?
    assert_equal 'Error validating xml data against the schema', responseFrom.message
  end

  def test_store_pass1
    storeResponseObj = {'response' => '801', 'message' => 'successful', 'litleToken'=>'1111222233334444', 'litleTxnId'=>nil}
    retObj = {'response'=>'0','registerTokenResponse'=>storeResponseObj}
    LitleOnline::Communications.expects(:http_post => retObj.to_xml(:root => 'litleOnlineResponse'))
    creditcard = CreditCard.new(@credit_card_options)

    responseFrom = @gateway.store(creditcard,{})
    assert_equal true, responseFrom.success?
    assert_equal '1111222233334444', responseFrom.params['litleOnlineResponse']['registerTokenResponse']['litleToken']
  end

  def test_store_pass2
    storeResponseObj = {'response' => '802', 'message' => 'already registered', 'litleToken'=>'1111222233334444', 'litleTxnId'=>nil}
    retObj = {'response'=>'0','registerTokenResponse'=>storeResponseObj}
    LitleOnline::Communications.expects(:http_post => retObj.to_xml(:root => 'litleOnlineResponse'))
    creditcard = CreditCard.new(@credit_card_options)

    responseFrom = @gateway.store(creditcard,{})
    assert_equal true, responseFrom.success?
    assert_equal '1111222233334444', responseFrom.params['litleOnlineResponse']['registerTokenResponse']['litleToken']
  end

  def test_store_fail
    storeResponseObj = {'response' => '803', 'message' => 'fail', 'litleToken'=>'1111222233334444', 'litleTxnId'=>nil}
    retObj = {'response'=>'0','registerTokenResponse'=>storeResponseObj}
    LitleOnline::Communications.expects(:http_post => retObj.to_xml(:root => 'litleOnlineResponse'))
    creditcard = CreditCard.new(@credit_card_options)

    responseFrom = @gateway.store(creditcard,{})
    assert_equal false, responseFrom.success?
    assert_equal '1111222233334444', responseFrom.params['litleOnlineResponse']['registerTokenResponse']['litleToken']
  end

  def test_store_fail_schema
    retObj = {'response'=>'1','message'=>'Error validating xml data against the schema'}
    LitleOnline::Communications.expects(:http_post => retObj.to_xml(:root => 'litleOnlineResponse'))
    creditcard = CreditCard.new(@credit_card_options)

    responseFrom = @gateway.store(creditcard,{})
    assert_equal false, responseFrom.success?
    assert_equal 'Error validating xml data against the schema', responseFrom.message
  end

  def test_in_production_with_test_param_sends_request_to_test_server
    begin
      ActiveMerchant::Billing::Base.mode = :production
      @gateway = LitleGateway.new(
                   :merchant_id => 'login',
                   :login => 'login',
                   :password => 'password',
                   :test => true
                 )
      purchaseResponseObj = {'response' => '000', 'message' => 'successful', 'litleTxnId'=>'123456789012345678'}
      retObj = {'response'=>'0','saleResponse'=>purchaseResponseObj}
      LitleOnline::Communications.expects(:http_post).with(anything,has_entry('url', 'https://www.testlitle.com/sandbox/communicator/online')).returns(retObj.to_xml(:root => 'litleOnlineResponse'))

      creditcard = CreditCard.new(@credit_card_options)
      assert response = @gateway.purchase(@amount, credit_card)
      assert_instance_of Response, response
      assert_success response
      assert response.test?, response.inspect
    ensure
      ActiveMerchant::Billing::Base.mode = :test
    end
  end

end
