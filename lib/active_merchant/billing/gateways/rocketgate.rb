require File.dirname(__FILE__) + '/rocketgate/GatewayService'

module ActiveMerchant #:nodoc:

  module Billing #:nodoc:

    #
    #	Note that this class is a 'Basic' implementation of the
    #	RocketGate gateway API.  It contains basic failover functionality.
    #
    #	To obtain an advanced, full-featured implementation of the
    #	RockGate gateway, contact RocketGate support or visit
    #	[http://www.rocketgate.com/].
    #
    #	The login and password are not the username and password you use to 
    #	login to RocketGate.com's "Mission Control" Interface. Instead,
    #	you will use your Merchant ID as the login and GatewayPassword
    #	as the password.
    # 
   
    class RocketgateGateway < Gateway
     
    #
    #	Override superclass attributes that describe processing
    #	preferences and defaults.
    #
      self.money_format = :dollars
      self.supported_countries = ['US']		# US for now
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb, :switch, :solo, :maestro]
      self.homepage_url = 'http://www.rocketgate.com/'
      self.display_name = 'RocketGate'
      
    #
    #	Map gateway response codes to human readable errors.
    #
      @@response_codes = {
        :r0   => "Transaction Successful",
        :r100 => 'No matching transaction',
        :r101 => 'A void operation cannot be performed because the original transaction has already been voided, credited, or settled.',
        :r102 => 'A credit operation cannot be performed because the original transaction has already been voided, credited, or has not been settled.',
        :r103 =>'A ticket operation cannot be performed because the original auth-only transaction has been voided or ticketed.',
        :r104 => 'The bank has declined the transaction.',
        :r105 => 'The bank has declined the transaction because the account is over limit.',
        :r106 => 'The transaction was declined because the security code (CVV) supplied was invalid.',
        :r107 => 'The bank has declined the transaction because the card is expired.',
        :r108 =>'The bank has declined the transaction and has requested that the merchant call.',
        :r109 =>'The bank has declined the transaction and has requested that the merchant pickup the card.',
        :r110 =>'The bank has declined the transaction due to excessive use of the card.',
        :r111 => 'The bank has indicated that the account is invalid.',
        :r112 => 'The bank has indicated that the account is expired.',
        :r113 => 'The issuing bank is temporarily unavailable. May be tried again later.',
        :r117 => 'The transaction was declined because the address could not be verified.',
        :r150 => 'The transaction was declined because the address could not be verified.',
        :r151 => 'The transaction was declined because the security code (CVV) supplied was invalid.',
        :r152 => 'The TICKET request was for an invalid amount. Please verify the TICKET for less then the AUTH_ONLY.',
        :r154 => 'The transaction was declined because of missing or invalid data.',
        :r200 => 'Transaction was declined', 	# Risk Fail
        :r201 => 'Transaction was declined',	# Customer blocked
        :r300 => 'A DNS failure has prevented the merchant application from resolving gateway host names.',
        :r301 => 'The merchant application is unable to connect to an appropriate host.',
        :r302 => 'Transmit error, no payment has occured.',
        :r303 => 'A timeout occurred while waiting for a transaction response from the gateway servers.',
        :r304 => 'An error occurred while reading a transaction response.',
        :r305 => 'Service Unavailable',
        :r307 => 'Unexpected/Internal Error',
        :r311 => 'Bank Communications Error',
        :r312 => 'Bank Communications Error',
        :r313 => 'Bank Communications Error',
        :r314 => 'Bank Communications Error',
        :r315 => 'Bank Communications Error',
        :r400 => "Invalid XML",
        :r402 => "Invalid Transaction",
        :r403 => 'Invalid Card Number',
        :r404 => 'Invalid Expiration',
        :r405 => 'Invalid Amount',
        :r406 => 'Invalid Merchant ID',
        :r407 => 'Invalid Merchant Account',
        :r408 => 'The merchant account specified in the request is not setup to accept the card type included in the request.',
        :r409 => 'No Suitable Account',
        :r410 => 'Invalid Transact ID',
        :r411 => 'Invalid Access Code',
        :r412 => 'Invalid Customer Data Length',
        :r413 => 'Invalid External Data Length',
        :r418 => 'The currency requested is not invalid',
        :r419 => 'The currency requested is not accepted',
        :r420 => 'Invalid subscription parameters requested',
        :r422 => 'Invalid Country Code requested',
        :r438 => 'Invalid Site ID requested',
        :r441 => 'No Invoice ID specified',
        :r443 => 'No Customer ID specified',
        :r444 => 'No Customer Name specified',
        :r445 => 'No Address specified',
        :r446 => 'No CVV Security Code specified',
        :r448 => 'No Active Membership found',
      }


######################################################################
#
#	initialize() - Initialization routine called during
#		       creation of object.
#
######################################################################
#  
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options			# Save the option list
        super					# Execute super class
      end  
     

######################################################################
#
#	authorize() - Perform an auth-only transaction.
#
######################################################################
# 
      def authorize(money, creditcard, options = {})
	request = RocketGate::GatewayRequest.new
	response = RocketGate::GatewayResponse.new
	service = RocketGate::GatewayService.new
	if test?				# Test transaction?
	  service.SetTestMode(true)		# Set internal test mode
	end

#
#	Add the details of the transaction to the request.
#
	add_merchant_data(request, options)	# Add merchant information
	add_customer_data(request, options)	# Add customer information
	add_invoice_data(request, money, options)
	add_creditcard(request, creditcard)	# Add credit card data
	add_address(request, options[:billing_address])
	add_business_rules_data(request, options)

#
#	Peform the transaction and return a response.
#
	service.PerformAuthOnly(request, response)
	return create_response(response)
      end

      
######################################################################
#
#	purchase() - Perform an auth-capture transaction.
#
######################################################################
# 
      def purchase(money, creditcard, options = {})
	request = RocketGate::GatewayRequest.new
	response = RocketGate::GatewayResponse.new
	service = RocketGate::GatewayService.new
	if test?				# Test transaction?
	  service.SetTestMode(true)		# Set internal test mode
	end

#
#	Add the details of the transaction to the request.
#
	add_merchant_data(request, options)	# Add merchant information
	add_customer_data(request, options)	# Add customer information
	add_invoice_data(request, money, options)
	add_creditcard(request, creditcard)	# Add credit card data
	add_address(request, options[:billing_address])
	add_business_rules_data(request, options)

#
#	Peform the transaction and return a response.
#
	service.PerformPurchase(request, response)
	return create_response(response)
      end                       

   
######################################################################
#
#	capture() - Perform a ticket of previous auth-only.
#
######################################################################
# 
      def capture(money, authorization, options = {})
	request = RocketGate::GatewayRequest.new
	response = RocketGate::GatewayResponse.new
	service = RocketGate::GatewayService.new
	if test?				# Test transaction?
	  service.SetTestMode(true)		# Set internal test mode
	end

#
#	Add the details of the transaction to the request.
#
	add_merchant_data(request, options)	# Add merchant information
	add_financial_data(request, money, options)
	request.Set(RocketGate::GatewayRequest::TRANSACT_ID, authorization)

#
#	Peform the transaction and return a response.
#
	service.PerformTicket(request, response)
	return create_response(response)
      end


######################################################################
#
#	void() - Void a previous auth-only, ticket, or purchase
#		 transaction.
#
#	Note:	If the transaction has already been settled,
#		the transaction will be switched to a credit
#		by the RocketGate gateway.
#
######################################################################
# 
def void(authorization, options = {})
	request = RocketGate::GatewayRequest.new
	response = RocketGate::GatewayResponse.new
	service = RocketGate::GatewayService.new
	if test?				# Test transaction?
	  service.SetTestMode(true)		# Set internal test mode
	end

#
#	Add the details of the transaction to the request.
#
	add_merchant_data(request, options)	# Add merchant information
	request.Set(RocketGate::GatewayRequest::TRANSACT_ID, authorization)
	request.Set(RocketGate::GatewayRequest::IPADDRESS, options[:ip])

#
#	Peform the transaction and return a response.
#
	service.PerformVoid(request, response)
	return create_response(response)
end


######################################################################
#
#	credit() - Credit a previous ticket or purchase transaction.
#
#	Note:	If the transaction has not been settled, the
#		transaction will be switched to a void  by the
#		RocketGate gateway.
#
######################################################################
# 
#			def credit(money, authorization, options = {})  # function updated by KR to refund
def refund(money, authorization, options = {})
	request = RocketGate::GatewayRequest.new
	response = RocketGate::GatewayResponse.new
	service = RocketGate::GatewayService.new
	if test?				# Test transaction?
	  service.SetTestMode(true)		# Set internal test mode
	end

#
#	Add the details of the transaction to the request.
#
	add_merchant_data(request, options)	# Add merchant information
	add_financial_data(request, money, options)
	request.Set(RocketGate::GatewayRequest::TRANSACT_ID, authorization)
	request.Set(RocketGate::GatewayRequest::IPADDRESS, options[:ip])

#
#	Peform the transaction and return a response.
#
	service.PerformCredit(request, response)
	return create_response(response)
end

 
######################################################################
#
#	recurring() - Setup a recurring payment.
#
######################################################################
#
def recurring(money, creditcard, options = {})
	requires!(options, :rebill_frequency)

	request = RocketGate::GatewayRequest.new
	response = RocketGate::GatewayResponse.new
	service = RocketGate::GatewayService.new
	if test?				# Test transaction?
	  service.SetTestMode(true)		# Set internal test mode
	end

#
#	Add the details of the transaction to the request.
#
	add_merchant_data(request, options)	# Add merchant information
	add_customer_data(request, options)	# Add customer information
	add_invoice_data(request, money, options)
	add_recurring_data(request, options)
	add_creditcard(request, creditcard)	# Add credit card data
	add_address(request, options[:billing_address])
	add_business_rules_data(request, options)

#
#	Peform the transaction and return a response.
#
	service.PerformPurchase(request, response)
	return create_response(response)
end                       

######################################################################
#
#	cancel recurring
#
#	Note:	cancel a subscription
#
######################################################################
# 
def cancel_recurring(invoice_id, options = {})
	request = RocketGate::GatewayRequest.new
	response = RocketGate::GatewayResponse.new
	service = RocketGate::GatewayService.new
	if test?				# Test transaction?
	  service.SetTestMode(true)		# Set internal test mode
	end

#
#	Add the details of the transaction to the request.
#
	add_merchant_data(request, options)	# Add merchant information
	add_customer_data(request, options) # customer id is options[:customer_id]
	request.Set(RocketGate::GatewayRequest::MERCHANT_INVOICE_ID, invoice_id)
	request.Set(RocketGate::GatewayRequest::IPADDRESS, options[:ip])

#
#	Peform the transaction and return a response.
#
	service.PerformRebillCancel(request, response)
	return create_response(response)
end

######################################################################
#
#	add_merchant_data() - Add merchant authentication data.
#
######################################################################
#
      private                       		# These are private functions
	def add_merchant_data(request, options)
	  request.Set(RocketGate::GatewayRequest::MERCHANT_ID, @options[:login])
	  request.Set(RocketGate::GatewayRequest::MERCHANT_PASSWORD, @options[:password])
	end


######################################################################
#
#	add_customer_data() - Add basic customer identification data.
#
######################################################################
#
	def add_customer_data(request, options)
	  request.Set(RocketGate::GatewayRequest::MERCHANT_CUSTOMER_ID, options[:customer_id])
	  request.Set(RocketGate::GatewayRequest::IPADDRESS, options[:ip])
	  request.Set(RocketGate::GatewayRequest::EMAIL, options[:email])
	end


######################################################################
#
#	add_invoice_data() - Add data that describes a purchase.
#
######################################################################
#
	def add_invoice_data(request, money, options)

#
#	Start with the basic transaction amount.
#
	  request.Set(RocketGate::GatewayRequest::MERCHANT_INVOICE_ID, options[:order_id])
	  request.Set(RocketGate::GatewayRequest::AMOUNT, amount(money))
	  request.Set(RocketGate::GatewayRequest::CURRENCY, options[:currency] || currency(money))

#
#	Add optional pass-through data.
#
	  request.Set(RocketGate::GatewayRequest::UDF01, options[:udf01])
	  request.Set(RocketGate::GatewayRequest::UDF02, options[:udf02])

#
#	Add optional tracking data.
#        
	  request.Set(RocketGate::GatewayRequest::MERCHANT_ACCOUNT, options[:merchant_account])
	  request.Set(RocketGate::GatewayRequest::BILLING_TYPE, options[:billing_type])
	  request.Set(RocketGate::GatewayRequest::AFFILIATE, options[:affiliate])
	  request.Set(RocketGate::GatewayRequest::MERCHANT_SITE_ID, options[:site_id])
	  request.Set(RocketGate::GatewayRequest::MERCHANT_DESCRIPTOR, options[:descriptor])
	end


######################################################################
#
#	add_financial_data() - Add financial data for a ticket
#			       or credit operation.
#
######################################################################
#
	def add_financial_data(request, money, options)
	  request.Set(RocketGate::GatewayRequest::AMOUNT, amount(money))
	  request.Set(RocketGate::GatewayRequest::CURRENCY, options[:currency] || currency(money))
	end

 
######################################################################
#
#	add_creditcard() - Add customer credit card data.
#
######################################################################
#
	def add_creditcard(request, creditcard) 
	  
	  cardNo = creditcard.number
	  cardNo.strip!
	  if ((cardNo.length == 44) || (cardNo =~ /[A-Z]/i) || (cardNo =~ /\+/) || (cardNo =~ /\=/))
	    request.Set(RocketGate::GatewayRequest::CARD_HASH, creditcard.number)
	  else
	    request.Set(RocketGate::GatewayRequest::CARDNO, creditcard.number)
	    request.Set(RocketGate::GatewayRequest::CVV2, creditcard.verification_value)
	    request.Set(RocketGate::GatewayRequest::EXPIRE_MONTH, creditcard.month)
	    request.Set(RocketGate::GatewayRequest::EXPIRE_YEAR, creditcard.year)
	    request.Set(RocketGate::GatewayRequest::CUSTOMER_FIRSTNAME, creditcard.first_name)
	    request.Set(RocketGate::GatewayRequest::CUSTOMER_LASTNAME, creditcard.last_name)
	  end
	end


######################################################################
#
#	add_address() - Add billing address associated with
#			a credit card.
#
######################################################################
#
	def add_address(request, address)
	  return if address.nil?
	  request.Set(RocketGate::GatewayRequest::BILLING_ADDRESS, address[:address1])
	  request.Set(RocketGate::GatewayRequest::BILLING_CITY, address[:city])
	  request.Set(RocketGate::GatewayRequest::BILLING_ZIPCODE, address[:zip])
	  request.Set(RocketGate::GatewayRequest::BILLING_COUNTRY, address[:country])

#
#	Only add the state if the country is the US or Canada.
#	          
          if address[:state] =~ /[A-Za-z]{2}/ && address[:country] =~ /^(us|ca)$/i
	    request.Set(RocketGate::GatewayRequest::BILLING_STATE, address[:state].upcase)
          end
	end


######################################################################
#
#	add_business_rules() - Add data that decides which
#			       fraud scrubbing attributes should
#			       be utilized, disabled, or ignored.
#
######################################################################
#
	def add_business_rules_data(request, options)
	  request.Set(RocketGate::GatewayRequest::AVS_CHECK, convert_rule_flag(options[:ignore_avs]))
	  request.Set(RocketGate::GatewayRequest::CVV2_CHECK, convert_rule_flag(options[:ignore_cvv]))
	  request.Set(RocketGate::GatewayRequest::SCRUB, options[:scrub])
	end


######################################################################
#
#	convert_rule_flag() - Convert an 'ignore_XXX' flag to
#			      the proper value for the gateway.
#
######################################################################
#
	def convert_rule_flag(value)
	  if value == 'ignore'
	    return value
	  end
	  if value == 'IGNORE'
	    return value
	  end
	  return (value) ? false : true
	end


######################################################################
#
#	add_recurring_data() - Add data that describes a recurring
#			       billing operation.
#
#	Note:	:rebill_frequency is the only option that is
#		required.
#
######################################################################
#
	def add_recurring_data(request, options) 
	  request.Set(RocketGate::GatewayRequest::REBILL_FREQUENCY, options[:rebill_frequency])
	  request.Set(RocketGate::GatewayRequest::REBILL_AMOUNT, options[:rebill_amount]) 
	  request.Set(RocketGate::GatewayRequest::REBILL_START, options[:rebill_start])
	end

     
######################################################################
#
#	create_response() - Create an active-merchant response
#			    object using the details in the
#			    response hash.
#
######################################################################

	def create_response(response)

#
#	Setup default response values.
#
	  message = nil
	  authorization = nil
	  success = false
	  exception = nil
#
#	Extract key elements from the response.
#
	  reasonCode = response.Get(RocketGate::GatewayResponse::REASON_CODE);
	  message = @@response_codes[('r' + reasonCode).to_sym]  || "ERROR - " + reasonCode
	  responseCode = response.Get(RocketGate::GatewayResponse::RESPONSE_CODE);
	  if ((responseCode != nil) && (responseCode == "0"))
	    success = true;			# Transaction succeeded
	    authorization = response.Get(RocketGate::GatewayResponse::TRANSACT_ID);
	  else 
	    exception = response.Get(RocketGate::GatewayResponse::EXCEPTION);
	  end

#
#	Extract values that are not dependent up success/failure.
#
	  avsResponse = response.Get(RocketGate::GatewayResponse::AVS_RESPONSE)
	  cvv2Response = response.Get(RocketGate::GatewayResponse::CVV2_CODE)
	  fraudResponse = response.Get(RocketGate::GatewayResponse::SCRUB_RESULTS)

#
#	Create the response object.
#
	  card_hash = response.Get(RocketGate::GatewayResponse::CARD_HASH)
	  Response.new(success, message, {:result => responseCode, :exception => exception, :card_hash => card_hash},
		       :test => test?,
		       :authorization => authorization,
		       :avs_result => { :code => avsResponse },
		       :cvv_result => cvv2Response,
		       :fraud_review  => fraudResponse
		      )
	end
    end
  end
end

