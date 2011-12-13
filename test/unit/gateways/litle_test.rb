require File.dirname(__FILE__) + '/../../test_helper'

class LitleTest < Test::Unit::TestCase

  @gateway = LitleGateway.new(LitleGateway.initialize(:user => 'TEST',:password => 'pass'))
  	
  def test_auth
	order = {
		  'reportGroup'=>'Planets',
		  'orderId'=>'3444',
		  'orderSource'=>'ecommerce',
		  'amount'=>'106'
		}
	card = {
		  'number' => '4100000000000001',
		  'month' => '8',
		  'year' => '2012',
		  'verification_value' => '123',
		  'first_name' => 'test',
		  'last_name' => 'litle'
		}
	options = {
		   'billToAddress' => {
				 'firstName' => 'test',
				 'lastName' => 'litle',
				 'addressLine1' => '900 chelmsford st',
   			 'city' => 'lowell',
  			 'state' => 'ma',
 				 'zip' => '01851',
		 		 'country' => 'US',
				 'email'=>'test@litle.com'
				}}
     	response = LitleGateway.authorization(order, card, options)
      	assert_equal 'Valid Format', response.message
  end

  def test_captureGivenAuth
	order = {
		 'reportGroup'=>'Planets',
		 'orderId'=>'12344',
		 'authInformation' => {
		 'authDate'=>'2002-10-09','authCode'=>'543216', 'processingInstructions'=>{'bypassVelocityCheck'=>'true'},
		 'authAmount'=>'12345'
		 },
		 'amount'=>'106',
		 'orderSource'=>'ecommerce',
		 }
	card = {
		  'number' => '5100000000000001',
		  'month' => '10',
		  'year' => '2012',
		  'verification_value' => '123',
		}
	options = {
		   'shipToAddress' => {
				 'firstName' => 'test',
				 'lastName' => 'litle',
				 'addressLine1' => '900 chelmsford st',
   			 'city' => 'lowell',
  			 'state' => 'ma',
 				 'zip' => '01851',
		 		 'country' => 'US'}}
	response= LitleGateway.captureGivenAuth(order, card, options)
	assert_equal('Valid Format', response.message)
  end

  def test_credit
	order = {
		  'reportGroup'=>'Planets',
		  'orderId'=>'12344',
		  'amount'=>'106',
		  'orderSource'=>'ecommerce'
		  }
	card = {
		 'number' => '4100000000000001',
		 'month' => '10',
		 'year' => '2012',
		 'verification_value' => '123'
		  }
	options = {}
	response= LitleGateway.credit(order, card, options)
	assert_equal('Valid Format', response.message)
  end

  def test_forceCapture
	order = {
		 'reportGroup'=>'Planets',
		 'litleTxnId'=>'123456',
		 'orderId'=>'12344',
		 'amount'=>'106',
		 'orderSource'=>'ecommerce'
		}
	card = {
		 'number' => '4100000000000001',
		 'month' => '10',
		 'year' => '2012',
		 'verification_value' => '123'
		}
	options = {}
	response= LitleGateway.forceCapture(order, card, options)
	assert_equal('000', response.forceCaptureResponse.response)
  end

  def test_sale
	order = {
		'reportGroup'=>'Planets',
		'litleTxnId'=>'123456',
		'orderId'=>'12344',
		'amount'=>'106',
		'orderSource'=>'ecommerce'
		}
	card = {
		 'number' => '4100000000000001',
		 'month' => '10',
		 'year' => '2012',
		 'verification_value' => '123'
		}
	options = {
		   'billToAddress' => {
				 'firstName' => 'test',
				 'lastName' => 'litle',
				 'addressLine1' => '900 chelmsford st',
   			 'city' => 'lowell',
  			 'state' => 'ma',
 				 'zip' => '01851',
		 		 'country' => 'US',
				 'email'=>'test@litle.com'
				},
		    'shipToAddress' => {
				 'firstName' => 'test',
				 'lastName' => 'litle',
				 'addressLine1' => '900 chelmsford st',
   			 'city' => 'lowell',
  			 'state' => 'ma',
 				 'zip' => '01851',
		 		 'country' => 'US'}}
	response= LitleGateway.sale(order, card, options)
	assert_equal('Valid Format', response.message)
  end

  def test_incorrect
	order = {
		  'reportGroup'=>'Planets',
		  'orderId'=>'12344',
		  'litleTxnId' => '12345456',
		  'amount'=>'106',
		  'orderSource'=>'ecomerce'
		}
	card = {
		 'number' => '4100000000000001',
		 'month' => '10',
		 'year' => '2012',
		 'verification_value' => '123'
		}
	options = {}
	response= LitleGateway.credit(order, card, options)
	assert(response.message =~ /Error validating xml data against the schema/)
  end

#the following test do not support creditcard method

  def test_authReversal
	order = {
		  'reportGroup'=>'Planets',
		  'litleTxnId'=>'12345678',
		  'amount'=>'106',
		  'payPalNotes'=>'Notes'
		 }
	card = {}
	options = {}	
       response= LitleGateway.authReversal(order, card, options)
	assert_equal('Valid Format', response.message)
  end

  def test_capture
	order = {
		 'reportGroup'=>'Planets',
		 'litleTxnId'=>'123456', 
		 'amount'=>'106',
		 }
	card = {}
	options = {}
	response= LitleGateway.capture(order, card, options)
	assert_equal('Valid Format', response.message)
  end

  def test_echeckCredit
	order = {
		 'reportGroup'=>'Planets',
		 'litleTxnId'=>'123456789101112',
		 'amount'=>'12'
		 }
	card = {}
	options = {}
	response= LitleGateway.echeckCredit(order, card, options)
	assert_equal('Valid Format', response.message)
  end

  def test_echeckRedeposit
	order = {
		 'reportGroup'=>'Planets',
		 'litleTxnId'=>'123456'
		 }
	card = {}
	options = {}
	response= LitleGateway.echeckRedeposit(order, card, options)
	assert_equal('Valid Format', response.message)
  end

  def test_echeckSale
	order = {
		 'reportGroup'=>'Planets',
		 'amount'=>'123456',
		 'verify'=>'true',
		 'orderId'=>'12345',
		 'orderSource'=>'ecommerce',
		 'echeck' => {'accType'=>'Checking','accNum'=>'12345657890','routingNum'=>'123456789','checkNum'=>'123455'},
		 'billToAddress'=>{'name'=>'Bob','city'=>'lowell','state'=>'MA','email'=>'litle.com'}
		 }
	card = {}
	options = {}
	response= LitleGateway.echeckSale(order, card, options)
	assert_equal('Valid Format', response.message)
  end

  def test_echeckVerification
	order = {
		 'reportGroup'=>'Planets',
		 'amount'=>'123456',
		 'orderId'=>'12345',
		 'orderSource'=>'ecommerce',
		 'echeck' => {'accType'=>'Checking','accNum'=>'12345657890','routingNum'=>'123456789','checkNum'=>'123455'},
		 'billToAddress'=>{'name'=>'Bob','city'=>'lowell','state'=>'MA','email'=>'litle.com'}
		 }
	card = {}
	options = {}
	response= LitleGateway.echeckVerification(order, card, options)
	assert_equal('Valid Format', response.message)
  end

  def test_registerTokenRequest
	order = {
		 'reportGroup'=>'Planets',
		 'orderId'=>'12344',
		 'accountNumber'=>'1233456789101112'
		}
	card = {}
	options = {}
	response= LitleGateway.registerTokenRequest(order, card, options)
	assert_equal('Valid Format', response.message)
  end

  def test_runtime_error
	order = {
		 'litleTxnId'=>'123456',
		}
	card = {}
	options = {}
	exception = assert_raise(RuntimeError){LitleGateway.echeckCredit(order, card, options)}
   	assert_match /Missing Required Field: @reportGroup!!!!/, exception.message
  end

# URL test coming next

#  def test_test_url
#	assert_equal LitleGateway::TEST_URL, response.message
#  end

end
