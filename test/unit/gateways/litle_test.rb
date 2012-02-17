require 'test_helper'

class LitleTest < Test::Unit::TestCase
  # * <tt>:order_id</tt> - The order number
  # * <tt>:ip</tt> - The IP address of the customer making the purchase
  # * <tt>:customer</tt> - The name, customer number, or other information that identifies the customer
  # * <tt>:invoice</tt> - The invoice number
  # * <tt>:merchant</tt> - The name or description of the merchant offering the product
  # * <tt>:description</tt> - A description of the transaction
  # * <tt>:email</tt> - The email address of the customer
  # * <tt>:currency</tt> - The currency of the transaction.  Only important when you are using a currency that is not the default with a gateway that supports multiple currencies.
  # * <tt>:billing_address</tt> - A hash containing the billing address of the customer.
  # * <tt>:shipping_address</tt> - A hash containing the shipping address of the customer.
  #
  # The <tt>:billing_address</tt>, and <tt>:shipping_address</tt> hashes can have the following keys:
  #
  # * <tt>:name</tt> - The full name of the customer.
  # * <tt>:company</tt> - The company name of the customer.
  # * <tt>:address1</tt> - The primary street address of the customer.
  # * <tt>:address2</tt> - Additional line of address information.
  # * <tt>:city</tt> - The city of the customer.
  # * <tt>:state</tt> - The state of the customer.  The 2 digit code for US and Canadian addresses. The full name of the state or province for foreign addresses.
  # * <tt>:country</tt> - The [ISO 3166-1-alpha-2 code](http://www.iso.org/iso/country_codes/iso_3166_code_lists/english_country_names_and_code_elements.htm) for the customer.
  # * <tt>:zip</tt> - The zip or postal code of the customer.
  # * <tt>:phone</tt> - The phone number of the customer.
  # money (int in cents), creditcard, options = {}
  def setup
    @gateway = LitleGateway.new
    @gateway.configuration = {
      'currency_merchant_map' =>
      {
      'DEFAULT'=>'101',
      'USD'=>'101',
      'EUR'=>'102'
      }
    }
  end

  def test_createCreditCardHash
    # define all inputs
    money = 1000

    creditcard = CreditCard.new(
    :first_name => 'Steve',
    :last_name  => 'Smith',
    :month      => '9',
    :year       => '2010',
    :type       => 'visa',
    :number     => '4242424242424242',
    :verification_value => '969'
    )

    order_id = '1234'
    ip = '192.168.0.1'
    customer = '4000'
    invoice = '1000'
    merchant = 'ABC'
    description = 'cool stuff'
    email = 'abc@xyz.com'
    currency = 'USD'

    billing_address = {
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

    shipping_address = {
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

    options = {
      :order_id=>order_id,
      :ip=>ip,
      :customer=>customer,
      :invoice=>invoice,
      :merchant=>merchant,
      :description=>description,
      :email=>email,
      :currency=>currency,
      :billing_address=>billing_address,
      :shipping_address=>shipping_address
    }

    hashFromGateway = @gateway.send(:createCreditCardHash, money, creditcard, options)

    assert_equal 1000, hashFromGateway['amount']
    assert_equal 'VI', hashFromGateway['card']['type']
    assert_equal '4242424242424242', hashFromGateway['card']['number']
    assert_equal '0910', hashFromGateway['card']['expDate']
    assert_equal '969', hashFromGateway['card']['cardValidationNum']
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
    assert_equal '101', hashFromGateway['merchantId'] #The option :currency is used to select the Litle Merchant Id

    assert_equal '1000', hashFromGateway['enhancedData']['invoiceReferenceNumber']
    assert_equal '192.168.0.1', hashFromGateway['fraudCheckType']['customerIpAddress']
    assert_equal 'cool stuff', hashFromGateway['enhancedData']['customerReference']
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

    billing_address = {
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

    shipping_address = {
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

    options = {
      :order_id=>order_id,
      :ip=>ip,
      :customer=>customer,
      :invoice=>invoice,
      :merchant=>merchant,
      :description=>description,
      :email=>email,
      :currency=>currency,
      :billing_address=>billing_address,
      :shipping_address=>shipping_address
    }

    hashFromGateway = @gateway.send(:createHash, money, options)

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
    assert_equal '101', hashFromGateway['merchantId'] #The option :currency is used to select the Litle Merchant Id

    assert_equal '1000', hashFromGateway['enhancedData']['invoiceReferenceNumber']
    assert_equal '192.168.0.1', hashFromGateway['fraudCheckType']['customerIpAddress']
    assert_equal 'cool stuff', hashFromGateway['enhancedData']['customerReference']
  end

  def test_createHash_money_nil
    # define all inputs
    money = nil
    
    hashFromGateway = @gateway.send(:createHash, money, {})

    assert_nil hashFromGateway['amount']
  end
  
  def test_createHash_money_empty_string
    # define all inputs
    money = ''
    
    hashFromGateway = @gateway.send(:createHash, money, {})

    assert_nil hashFromGateway['amount']
  end

  def test_recognize_ax_and_some_empties
    creditcard = CreditCard.new(
    :month       => '9',
    :year       => '2010',
    :type       => 'american_express'
    )
    hashFromGateway = @gateway.send(:createCreditCardHash, 0, creditcard, {})
    assert_equal 'AX', hashFromGateway['card']['type']
    assert_nil hashFromGateway['billToAddress']
    assert_nil hashFromGateway['shipToAddress']
  end

  def test_recognize_di
    creditcard = CreditCard.new(
    :month      => '9',
    :year       => '2010',
    :type       => 'discover'
    )
    hashFromGateway = @gateway.send(:createCreditCardHash, 0, creditcard, {})
    assert_equal 'DI', hashFromGateway['card']['type']
  end

  def test_recognize_mastercard
    creditcard = CreditCard.new(
    :month      => '9',
    :year       => '2010',
    :type       => 'master'
    )
    hashFromGateway = @gateway.send(:createCreditCardHash, 0,creditcard,{})
    assert_equal 'MC', hashFromGateway['card']['type']
  end

  def test_recognize_jcb
    creditcard = CreditCard.new(
    :month      => '9',
    :year       => '2010',
    :type       => 'jcb'
    )
    hashFromGateway = @gateway.send(:createCreditCardHash, 0, creditcard, {})
    assert_equal 'DI', hashFromGateway['card']['type']
  end

  def test_recognize_diners
    creditcard = CreditCard.new(
    :month      => '9',
    :year       => '2010',
    :type       => 'diners_club'
    )
    hashFromGateway = @gateway.send(:createCreditCardHash, 0, creditcard, {})
    assert_equal 'DI', hashFromGateway['card']['type']
  end

  def test_two_digit_month
    creditcard = CreditCard.new(
    :month      => '11',
    :year       => '2010',
    :type       => 'diners_club'
    )
    hashFromGateway = @gateway.send(:createCreditCardHash, 0, creditcard, {})
    assert_equal '1110', hashFromGateway['card']['expDate']
  end

  def test_nils_in_both_addresses
    creditcard = CreditCard.new(
    :month      => '9',
    :year       => '2010',
    :type       => 'visa'
    )

    billing_address = {
      :name      => nil,
      :company   => nil,
      :address1  => nil,
      :address2  => nil,
      :city      => nil,
      :state     => nil,
      :country   => nil,
      :zip       => nil,
      :phone     => nil
    }

    shipping_address = {
      :name      => nil,
      :company   => nil,
      :address1  => nil,
      :address2  => nil,
      :city      => nil,
      :state     => nil,
      :country   => nil,
      :zip       => nil,
      :phone     => nil
    }

    hashFromGateway = @gateway.send(:createCreditCardHash, 0, creditcard,
    {:shipping_address=>shipping_address,:billing_address=>billing_address})

    #billing address
    assert_nil hashFromGateway['billToAddress']['name']
    assert_nil hashFromGateway['billToAddress']['companyName']
    assert_nil hashFromGateway['billToAddress']['addressLine1']
    assert_nil hashFromGateway['billToAddress']['addressLine2']
    assert_nil hashFromGateway['billToAddress']['city']
    assert_nil hashFromGateway['billToAddress']['state']
    assert_nil hashFromGateway['billToAddress']['zip']
    assert_nil hashFromGateway['billToAddress']['country']
    assert_nil hashFromGateway['billToAddress']['email']
    assert_nil hashFromGateway['billToAddress']['phone']
    #shipping address
    assert_nil hashFromGateway['shipToAddress']['name']
    assert_nil hashFromGateway['shipToAddress']['company']
    assert_nil hashFromGateway['shipToAddress']['addressLine1']
    assert_nil hashFromGateway['shipToAddress']['addressLine2']
    assert_nil hashFromGateway['shipToAddress']['city']
    assert_nil hashFromGateway['shipToAddress']['state']
    assert_nil hashFromGateway['shipToAddress']['zip']
    assert_nil hashFromGateway['shipToAddress']['country']
    assert_nil hashFromGateway['shipToAddress']['email']
    assert_nil hashFromGateway['shipToAddress']['phone']

  end

  def test_create_credit_hash
    hashFromGateway = @gateway.send(:createCreditHash, 1000, '123456789012345678', {})
    assert_equal '123456789012345678', hashFromGateway['litleTxnId']
    assert_equal nil, hashFromGateway['orderSource']
    assert_equal nil, hashFromGateway['orderId']
  end

  def test_currency_USD
    creditcard = CreditCard.new(
    :month      => '11',
    :year       => '2010',
    :type       => 'diners_club'
    )
    hashFromGateway = @gateway.send(:createCreditCardHash, 0, creditcard, {'currency'=>'USD'})
    assert_equal '101', hashFromGateway['merchantId']
  end

  def test_currency_DEFAULT
    creditcard = CreditCard.new(
    :month      => '11',
    :year       => '2010',
    :type       => 'diners_club'
    )
    hashFromGateway = @gateway.send(:createCreditCardHash, 0, creditcard, {})
    assert_equal '101', hashFromGateway['merchantId']
  end

  def test_currency_EUR
    creditcard = CreditCard.new(
    :month      => '11',
    :year       => '2010',
    :type       => 'diners_club'
    )
    hashFromGateway = @gateway.send(:createCreditCardHash, 0, creditcard, {:currency=>'EUR'})
    assert_equal '102', hashFromGateway['merchantId']
  end

  def test_auth_pass
    authorizationResponseObj = Hashit.new({
      'response' => '000',
      'message' => 'successful',
      'litleTxnId' => '1234',
      'litleToken'=>'1111222233334444'
    })
    retObj = Hashit.new({'response'=>'0','authorizationResponse'=>authorizationResponseObj})
    LitleOnlineRequest.any_instance.expects(:authorization).returns(retObj)

    creditcard = CreditCard.new(
    :month      => '11',
    :year       => '2010',
    :type       => 'diners_club'
    )
    responseFrom = @gateway.authorize(0, creditcard)
    assert_equal true, responseFrom.success?
    assert_equal 'successful', responseFrom.message
    assert_equal '1234', responseFrom.authorization
    assert_equal '1111222233334444', responseFrom.params['litleOnlineResponse'].authorizationResponse.litleToken
  end

  def test_avs
    fraudResult = Hashit.new({'avsResult'=>'01'})
    authorizationResponseObj = Hashit.new({
      'response' => '000',
      'message' => 'successful',
      'litleTxnId' => '1234',
      'litleToken'=>'1111222233334444',
      'fraudResult' => fraudResult
    })
    retObj = Hashit.new({'response'=>'0','authorizationResponse'=>authorizationResponseObj})
    LitleOnlineRequest.any_instance.expects(:authorization).returns(retObj)

    creditcard = CreditCard.new(
    :month      => '11',
    :year       => '2010',
    :type       => 'diners_club'
    )
    responseFrom = @gateway.authorize(0, creditcard)
    assert_equal true, responseFrom.success?
    assert_equal 'X', responseFrom.avs_result['code']
    assert_equal 'Street address and 9-digit postal code match.', responseFrom.avs_result['message']
    assert_equal 'Y', responseFrom.avs_result['street_match']
    assert_equal 'Y', responseFrom.avs_result['postal_match']
  end
  
  def test_cvv
    fraudResult = Hashit.new({'cardValidationResult'=>'M'})
    authorizationResponseObj = Hashit.new({
      'response' => '000',
      'message' => 'successful',
      'litleTxnId' => '1234',
      'litleToken'=>'1111222233334444',
      'fraudResult' => fraudResult
    })
    retObj = Hashit.new({'response'=>'0','authorizationResponse'=>authorizationResponseObj})
    LitleOnlineRequest.any_instance.expects(:authorization).returns(retObj)

    creditcard = CreditCard.new(
    :month      => '11',
    :year       => '2010',
    :type       => 'diners_club'
    )
    responseFrom = @gateway.authorize(0, creditcard)
    assert_equal true, responseFrom.success?
    assert_equal 'M', responseFrom.cvv_result['code']
    assert_equal 'Match', responseFrom.cvv_result['message']
  end

  def test_sale_avs
    fraudResult = Hashit.new({'avsResult'=>'10'})
    saleResponseObj = Hashit.new({
      'response' => '000',
      'message' => 'successful',
      'litleTxnId' => '1234',
      'fraudResult' => fraudResult
    })
    retObj = Hashit.new({'response'=>'0','saleResponse'=>saleResponseObj})
    LitleOnlineRequest.any_instance.expects(:sale).returns(retObj)

    creditcard = CreditCard.new(
    :month      => '11',
    :year       => '2010',
    :type       => 'diners_club'
    )
    responseFrom = @gateway.purchase(0, creditcard)
    assert_equal true, responseFrom.success?
    assert_equal 'Z', responseFrom.avs_result['code']
    assert_equal 'Street address does not match, but 5-digit postal code matches.', responseFrom.avs_result['message']
    assert_equal 'N', responseFrom.avs_result['street_match']
    assert_equal 'Y', responseFrom.avs_result['postal_match']
  end
  
  def test_sale_cvv
    fraudResult = Hashit.new({'cardValidationResult'=>''})
    saleResponseObj = Hashit.new({
      'response' => '000',
      'message' => 'successful',
      'litleTxnId' => '1234',
      'litleToken'=>'1111222233334444',
      'fraudResult' => fraudResult
    })
    retObj = Hashit.new({'response'=>'0','saleResponse'=>saleResponseObj})
    LitleOnlineRequest.any_instance.expects(:sale).returns(retObj)

    creditcard = CreditCard.new(
    :month      => '11',
    :year       => '2010',
    :type       => 'diners_club'
    )
    responseFrom = @gateway.purchase(0, creditcard)
    assert_equal true, responseFrom.success?
    assert_equal 'P', responseFrom.cvv_result['code']
    assert_equal 'Not Processed', responseFrom.cvv_result['message']
  end

    
  def test_auth_fail
    authorizationResponseObj = Hashit.new({'response' => '111', 'message' => 'fail', 'litleTxnId' => '1234', 'litleToken'=>'1111222233334444'})
    retObj = Hashit.new({'response'=>'0','authorizationResponse'=>authorizationResponseObj})
    LitleOnlineRequest.any_instance.expects(:authorization).returns(retObj)

    creditcard = CreditCard.new(
    :month      => '11',
    :year       => '2010',
    :type       => 'diners_club'
    )
    responseFrom = @gateway.authorize(0, creditcard)
    assert_equal false, responseFrom.success?
    assert_equal '1234', responseFrom.authorization
    assert_equal '1111222233334444', responseFrom.params['litleOnlineResponse'].authorizationResponse.litleToken
  end

  def test_auth_fail_schema
    retObj = Hashit.new({'response'=>'1','message'=>'Error validating xml data against the schema'})
    LitleOnlineRequest.any_instance.expects(:authorization).returns(retObj)

    creditcard = CreditCard.new(
    :month      => '11',
    :year       => '2010',
    :type       => 'diners_club'
    )
    responseFrom = @gateway.authorize(0, creditcard)
    assert_equal false, responseFrom.success?
    assert_equal 'Error validating xml data against the schema', responseFrom.message
  end

  def test_purchase_pass
    purchaseResponseObj = Hashit.new({'response' => '000', 'message' => 'successful', 'litleTxnId'=>'123456789012345678'})
    retObj = Hashit.new({'response'=>'0','saleResponse'=>purchaseResponseObj})
    LitleOnlineRequest.any_instance.expects(:sale).returns(retObj)

    creditcard = CreditCard.new(
    :month      => '11',
    :year       => '2010',
    :type       => 'diners_club'
    )
    responseFrom = @gateway.purchase(0, creditcard)
    assert_equal true, responseFrom.success?
    assert_equal '123456789012345678', responseFrom.params['litleOnlineResponse'].saleResponse.litleTxnId
  end

  def test_purchase_fail
    purchaseResponseObj = Hashit.new({'response' => '111', 'message' => 'fail', 'litleTxnId'=>'123456789012345678'})
    retObj = Hashit.new({'response'=>'0','saleResponse'=>purchaseResponseObj})
    LitleOnlineRequest.any_instance.expects(:sale).returns(retObj)

    creditcard = CreditCard.new(
    :month      => '11',
    :year       => '2010',
    :type       => 'diners_club'
    )
    responseFrom = @gateway.purchase(0, creditcard)
    assert_equal false, responseFrom.success?
    assert_equal '123456789012345678', responseFrom.params['litleOnlineResponse'].saleResponse.litleTxnId
  end

  def test_purchase_fail_schema
    retObj = Hashit.new({'response'=>'1','message'=>'Error validating xml data against the schema'})
    LitleOnlineRequest.any_instance.expects(:sale).returns(retObj)

    creditcard = CreditCard.new(
    :month      => '11',
    :year       => '2010',
    :type       => 'diners_club'
    )
    responseFrom = @gateway.purchase(0, creditcard)
    assert_equal false, responseFrom.success?
    assert_equal 'Error validating xml data against the schema', responseFrom.message
  end

  def test_capture_pass
    captureResponseObj = Hashit.new({'response' => '000', 'message' => 'pass', 'litleTxnId'=>'123456789012345678'})
    retObj = Hashit.new({'response'=>'0','captureResponse'=>captureResponseObj})
    LitleOnlineRequest.any_instance.expects(:capture).returns(retObj)
    authorization = "1234"
    responseFrom = @gateway.capture(0, authorization)
    assert_equal true, responseFrom.success?
    assert_equal '123456789012345678', responseFrom.params['litleOnlineResponse'].captureResponse.litleTxnId
  end

  def test_capture_fail
    captureResponseObj = Hashit.new({'response' => '111', 'message' => 'fail', 'litleTxnId'=>'123456789012345678'})
    retObj = Hashit.new({'response'=>'0','captureResponse'=>captureResponseObj})
    LitleOnlineRequest.any_instance.expects(:capture).returns(retObj)
    authorization = "1234"
    responseFrom = @gateway.capture(0, authorization)
    assert_equal false, responseFrom.success?
    assert_equal '123456789012345678', responseFrom.params['litleOnlineResponse'].captureResponse.litleTxnId
  end

  def test_capture_fail_schema
    retObj = Hashit.new({'response'=>'1','message'=>'Error validating xml data against the schema'})
    LitleOnlineRequest.any_instance.expects(:capture).returns(retObj)
    authorization = '1234'
    responseFrom = @gateway.authorize(0, authorization)
    assert_equal false, responseFrom.success?
    assert_equal 'Error validating xml data against the schema', responseFrom.message
  end

  def test_void_pass
    voidResponseObj = Hashit.new({'response' => '000', 'message' => 'pass', 'litleTxnId'=>'123456789012345678'})
    retObj = Hashit.new({'response'=>'0','voidResponse'=>voidResponseObj})
    LitleOnlineRequest.any_instance.expects(:void).returns(retObj)
    identification = "1234"
    responseFrom = @gateway.void(identification)
    assert_equal true, responseFrom.success?
    assert_equal '123456789012345678', responseFrom.params['litleOnlineResponse'].voidResponse.litleTxnId
  end

  def test_void_fail
    voidResponseObj = Hashit.new({'response' => '111', 'message' => 'fail', 'litleTxnId'=>'123456789012345678'})
    retObj = Hashit.new({'response'=>'0','voidResponse'=>voidResponseObj})
    LitleOnlineRequest.any_instance.expects(:void).returns(retObj)
    identification = "1234"
    responseFrom = @gateway.void(identification)
    assert_equal false, responseFrom.success?
    assert_equal '123456789012345678', responseFrom.params['litleOnlineResponse'].voidResponse.litleTxnId
  end

  def test_void_fail_schema
    retObj = Hashit.new({'response'=>'1','message'=>'Error validating xml data against the schema'})
    LitleOnlineRequest.any_instance.expects(:void).returns(retObj)
    identification = "1234"
    responseFrom = @gateway.void(identification)
    assert_equal false, responseFrom.success?
    assert_equal 'Error validating xml data against the schema', responseFrom.message
  end

  def test_credit_pass
    creditResponseObj = Hashit.new({'response' => '000', 'message' => 'pass', 'litleTxnId'=>'123456789012345678'})
    retObj = Hashit.new({'response'=>'0','creditResponse'=>creditResponseObj})
    LitleOnlineRequest.any_instance.expects(:credit).returns(retObj)
    identification = "1234"
    responseFrom = @gateway.credit(0, identification)
    assert_equal true, responseFrom.success?
    assert_equal '123456789012345678', responseFrom.params['litleOnlineResponse'].creditResponse.litleTxnId
  end

  def test_credit_fail
    creditResponseObj = Hashit.new({'response' => '111', 'message' => 'fail', 'litleTxnId'=>'123456789012345678'})
    retObj = Hashit.new({'response'=>'0','creditResponse'=>creditResponseObj})
    LitleOnlineRequest.any_instance.expects(:credit).returns(retObj)
    identification = "1234"
    responseFrom = @gateway.credit(0, identification)
    assert_equal false, responseFrom.success?
    assert_equal '123456789012345678', responseFrom.params['litleOnlineResponse'].creditResponse.litleTxnId
  end

  def test_capture_fail_schema
    retObj = Hashit.new({'response'=>'1','message'=>'Error validating xml data against the schema'})
    LitleOnlineRequest.any_instance.expects(:credit).returns(retObj)
    identification = '1234'
    responseFrom = @gateway.credit(0, identification)
    assert_equal false, responseFrom.success?
    assert_equal 'Error validating xml data against the schema', responseFrom.message
  end

  def test_store_pass1
    storeResponseObj = Hashit.new({'response' => '801', 'message' => 'successful', 'litleToken'=>'1111222233334444'})
    retObj = Hashit.new({'response'=>'0','registerTokenResponse'=>storeResponseObj})
    LitleOnlineRequest.any_instance.expects(:registerTokenRequest).returns(retObj)
    creditcard = CreditCard.new(
    :number => '4242424242424242'
    )
    responseFrom = @gateway.store(creditcard,{})
    assert_equal true, responseFrom.success?
    assert_equal '1111222233334444', responseFrom.params['litleOnlineResponse'].registerTokenResponse.litleToken
  end

  def test_store_pass2
    storeResponseObj = Hashit.new({'response' => '802', 'message' => 'already registered', 'litleToken'=>'1111222233334444'})
    retObj = Hashit.new({'response'=>'0','registerTokenResponse'=>storeResponseObj})
    LitleOnlineRequest.any_instance.expects(:registerTokenRequest).returns(retObj)
    creditcard = CreditCard.new(
    :number => '4242424242424242'
    )
    responseFrom = @gateway.store(creditcard,{})
    assert_equal true, responseFrom.success?
    assert_equal '1111222233334444', responseFrom.params['litleOnlineResponse'].registerTokenResponse.litleToken
  end

  def test_store_fail
    storeResponseObj = Hashit.new({'response' => '803', 'message' => 'fail', 'litleToken'=>'1111222233334444'})
    retObj = Hashit.new({'response'=>'0','registerTokenResponse'=>storeResponseObj})
    LitleOnlineRequest.any_instance.expects(:registerTokenRequest).returns(retObj)
    creditcard = CreditCard.new(
    :number => '4242424242424242'
    )
    responseFrom = @gateway.store(creditcard,{})
    assert_equal false, responseFrom.success?
    assert_equal '1111222233334444', responseFrom.params['litleOnlineResponse'].registerTokenResponse.litleToken
  end

  def test_store_fail_schema
    retObj = Hashit.new({'response'=>'1','message'=>'Error validating xml data against the schema'})
    LitleOnlineRequest.any_instance.expects(:registerTokenRequest).returns(retObj)
    creditcard = CreditCard.new(
    :number => '4242424242424242'
    )
    responseFrom = @gateway.store(creditcard,{})
    assert_equal false, responseFrom.success?
    assert_equal 'Error validating xml data against the schema', responseFrom.message
  end

  class Hashit
    def initialize(hash)
      @original = hash
      hash.each do |k,v|
        self.instance_variable_set("@#{k}", v)  ## create and initialize an instance variable for this key/value pair
        self.class.send(:define_method, k, proc{self.instance_variable_get("@#{k}")})  ## create the getter that returns the instance variable
        self.class.send(:define_method, "#{k}=", proc{|v| self.instance_variable_set("@#{k}", v)})  ## create the setter that sets the instance variable
      end
    end
    def to_hash
      return @original
    end
  end

end
