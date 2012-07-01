require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BluePayGateway < Gateway
      class_attribute :live_url, :rebilling_url, :ignore_http_status

      self.live_url      = 'https://secure.bluepay.com/interfaces/bp20post'
      self.rebilling_url = 'https://secure.bluepay.com/interfaces/bp20rebadmin'
      
      self.ignore_http_status = true
 
      RESPONSE_CODE, RESPONSE_REASON_CODE, RESPONSE_REASON_TEXT = 0, 2, 3
      AVS_RESULT_CODE, TRANSACTION_ID, CARD_CODE_RESPONSE_CODE  = 5, 6, 38

      CARD_CODE_ERRORS = %w( N S )
      AVS_ERRORS = %w( A E N R W Z )
      AVS_REASON_CODES = %w(27 45)

      class_attribute :duplicate_window

      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]
      self.homepage_url        = 'http://www.bluepay.com/'
      self.display_name        = 'BluePay'
      self.money_format        = :dollars


      # Creates a new BluepayGateway
      #
      # The gateway requires that a valid Account ID and Secret Key be passed
      # in the +options+ hash.
      #
      # ==== Options
      #
      # * <tt>:account_id</tt> -- The BluePay gateway Account ID (REQUIRED)
      # * <tt>:secret_key</tt> -- The BluePay gateway Secret Key (REQUIRED)
      # * <tt>:test</tt> -- set to true for TEST mode or false for LIVE mode 
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end

      # Performs an authorization, which reserves the funds on the customer's credit card. This does not actually take funds from the customer
      # This is referred to an AUTH transaction in BluePay
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be authorized as an Integer value in cents.
      # * <tt>payment_object</tt> -- This can either be one of three things:
      #   A CreditCard object,
      #   A Check object,
      #   or a token. The token is called the Master ID. This is a unique transaction ID returned from a previous transaction. This token associates all the stored information for a previous transaction.
      # * <tt>options</tt> -- A hash of optional parameters.
      def authorize(money, payment_object, options = {})
       	post = {}
       	post[:MASTER_ID] = ''
       	if payment_object != nil && payment_object.class() != String
       	  payment_object.class() == ActiveMerchant::Billing::Check ?
          add_check(post, payment_object) :
          add_creditcard(post, payment_object)
       	else
       	  post[:MASTER_ID] = payment_object
       	end
       	add_invoice(post, options)
        add_address(post, options)
        add_customer_data(post, options)
       	if options[:rebill]     != nil
          post[:DO_REBILL]       = '1'
          post[:REB_AMOUNT]      = amount(options[:rebill_amount])
          post[:REB_FIRST_DATE]  = options[:rebill_start_date]
          post[:REB_EXPR]        = options[:rebill_expression]
          post[:REB_CYCLES]      = options[:rebill_cycles]
        end
       	post[:TRANS_TYPE]  = 'AUTH'
        commit('AUTH_ONLY', money, post)
      end

      # Perform a purchase, which is essentially an authorization and capture in a single operation. 
      # This is referred to a SALE transaction in BluePay
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be purchased as an Integer value in cents.
      # * <tt>payment_object</tt> -- This can either be one of three things:
      #   A CreditCard object,
      #   A Check object,
      #   or a token. The token is called the Master ID. This is a unique transaction ID returned from a previous transaction. This token associates all the stored information for a previous transaction.
      # * <tt>options</tt> -- A hash of optional parameters.,
      def purchase(money, payment_object, options = {})
       	post = {}
       	post[:MASTER_ID] = ''
       	if payment_object != nil && payment_object.class() != String
       	 payment_object.class() == ActiveMerchant::Billing::Check ? 
       	 add_check(post, payment_object) :
       	 add_creditcard(post, payment_object) 
       	else
       	  post[:MASTER_ID] = payment_object
       	end
       	add_invoice(post, options)
        add_address(post, options)
        add_customer_data(post, options)
       	if options[:rebill]     != nil
       	  post[:DO_REBILL]       = '1'
       	  post[:REB_AMOUNT]      = amount(options[:rebill_amount])
          post[:REB_FIRST_DATE]  = options[:rebill_start_date]
          post[:REB_EXPR]        = options[:rebill_expression]
          post[:REB_CYCLES]      = options[:rebill_cycles]
        end
       	post[:TRANS_TYPE]  = 'SALE'
        commit('AUTH_CAPTURE', money, post)
      end

      # Captures the funds from an authorize transaction.
      # This is referred to a CAPTURE transaction in BluePay
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be captured as an Integer value in cents.
      # * <tt>identification</tt> -- The Master ID, or token, returned from the previous authorize transaction.
      def capture(money, identification, options = {})
       	post = {}
       	add_address(post, options)
       	add_customer_data(post, options)
        post[:MASTER_ID] = identification
       	post[:TRANS_TYPE] = 'CAPTURE'
        commit('PRIOR_AUTH_CAPTURE', money, post)
      end

      # Void a previous transaction
      # This is referred to a VOID transaction in BluePay
      #
      # ==== Parameters
      #
      # * <tt>identification</tt> - The Master ID, or token, returned from a previous authorize transaction.
      def void(identification, options = {})
       	post = {}
        post[:MASTER_ID] = identification
       	post[:TRANS_TYPE] = 'VOID'
        commit('VOID', nil, post)
      end

      # Performs a credit.
      #
      # This transaction indicates that money should flow from the merchant to the customer.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be credited to the customer as an Integer value in cents.
      # * <tt>payment_object</tt> -- This can either be one of three things:
      #   A CreditCard object,
      #   A Check object,
      #   or a token. The token is called the Master ID. This is a unique transaction ID returned from a previous transaction. This token associates all the stored information for a previous transaction.
      #   If the payment_object is a token, then the transaction type will reverse a previous capture or purchase transaction, returning the funds to the customer. If the amount is nil, a full credit will be processed. This is referred to a REFUND transaction in BluePay.
      #   If the payment_object is either a CreditCard or Check object, then the transaction type will be an unmatched credit placing funds in the specified account. This is referred to a CREDIT transaction in BluePay.
      # * <tt>options</tt> -- A hash of parameters.
      def refund(money, payment_object, options = {})
       	post = {}
       	post[:PAYMENT_ACCOUNT] = ''
        if payment_object != nil && payment_object.class() != String
           payment_object.class() == ActiveMerchant::Billing::Check ?
           add_check(post, payment_object) :
           add_creditcard(post, payment_object)
       	   post[:TRANS_TYPE] = 'CREDIT'
        else
           post[:MASTER_ID]  = payment_object
       	   post[:TRANS_TYPE] = 'REFUND'
        end

        options[:first_name] ? post[:NAME1] = options[:first_name] : post[:NAME1] = ''
        post[:NAME2] = options[:last_name] if options[:last_name] 
        post[:ZIP] = options[:zip] if options[:zip]
        add_invoice(post, options)
        add_address(post, options)
        add_customer_data(post, options)
        commit('CREDIT', money, post)
      end

      def credit(money, identification, options = {})
        deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, identification, options)
      end

      # Create a new recurring payment.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to charge the customer at the time of the recurring payment setup, in cents. Set to zero if you do not want the customer to be charged at this time.
      # * <tt>payment_object</tt> -- This can either be one of three things:
      #   A CreditCard object,
      #   A Check object,
      #   or a token. The token is called the Master ID. This is a unique transaction ID returned from a previous transaction. This token associates all the stored information for a previous transaction.
      # * <tt>options</tt> -- A hash of optional parameters.,

      # ==== Options
      #
      # * <tt>:rebill_start_date</tt> is a string that tells the gateway when to start the rebill. (REQUIRED) 
      #   Has two valid formats:
      #   "YYYY-MM-DD HH:MM:SS" Hours, minutes, and seconds are optional.
      #   "XX UNITS" Relative date as explained below. Marked from the time of the
      #   transaction (i.e.: 10 DAYS, 1 MONTH, 1 YEAR)
      # * <tt>:rebill_expression</tt> is the period of time in-between rebillings. (REQUIRED)
      #   It uses the same "XX UNITS" format as rebill_start_date, explained above.
      #   Optional parameters include:
      # * <tt>rebill_cycles</tt>: Number of times to rebill. Don't send or set to nil for infinite rebillings (or
      #   until canceled).
      # * <tt>rebill_amount</tt>:   Amount to rebill. Defaults to amount of transaction for rebillings.
      # 
      #   For example, to charge the customer $19.95 now and then charge $39.95 in 60 days every 3 months for 5 times, the options hash would be as follows:
      #   :rebill_start_date => '60 DAYS',
      #   :rebill_expression => '3 MONTHS',
      #   :rebill_cycles     => '5',
      #   :rebill_amount     => '39.95' 
      #   A money object of 1995 cents would be passed into the 'money' parameter.
      def recurring(money, payment_object, options = {})
        requires!(options, :rebill_start_date, :rebill_expression)
       	options[:rebill] = '1'
        money == nil ? authorize(money, payment_object, options) :
        purchase(money, payment_object, options)
      end

      # View a recurring payment
      #
      # This will pull data associated with a current recurring billing
      #
      # ==== Parameters
      #
      # * <tt>rebill_id</tt> -- A string containing the rebill_id of the recurring billing that is already active (REQUIRED)
      def status_recurring(rebill_id)
       	post = {}
        requires!(rebill_id)
        post[:REBILL_ID] = rebill_id
        post[:TRANS_TYPE] = 'GET'
        commit('rebill', 'nil', post)
      end

      # Update a recurring payment's details.
      #
      # This transaction updates an existing recurring billing
      #
      # ==== Options
      #
      # * <tt>:rebill_id</tt> -- The 12 digit rebill ID used to update a particular rebilling cycle. (REQUIRED) 
      # * <tt>:rebill_amount</tt> -- A string containing the new rebilling amount.
      # * <tt>:rebill_next_date</tt> -- A string containing the new rebilling next date.
      # * <tt>:rebill_expression</tt> -- A string containing the new rebilling expression.
      # * <tt>:rebill_cycles</tt> -- A string containing the new rebilling cycles.
      # * <tt>:rebill_next_amount</tt> -- A string containing the next rebilling amount to charge the customer. This ONLY affects the next scheduled charge; all other rebillings will continue at the regular (rebill_amount) amount.
      #   Take a look above at the recurring_payment method for similar examples on how to use.
      def update_recurring(options = {})
       	post = {}
       	requires!(options, :rebill_id)
       	post[:REBILL_ID]          = options[:rebill_id]
       	post[:TRANS_TYPE]         = 'SET'
        post[:REB_AMOUNT]         = amount(options[:rebill_amount]) if !options[:rebill_amount].nil?
        post[:NEXT_DATE]          = options[:rebill_next_date] if !options[:rebill_next_date].nil?
        post[:REB_EXPR]           = options[:rebill_expression] if !options[:rebill_expression].nil?
        post[:REB_CYCLES]     	  = options[:rebill_cycles] if !options[:rebill_cycles].nil?
       	post[:NEXT_AMOUNT]        = options[:rebill_next_amount] if !options[:rebill_next_amount].nil?
       	commit('rebill', 'nil', post)	
      end

      # Cancel a recurring payment.
      #
      # This transaction cancels an existing recurring billing.
      #
      # ==== Parameters
      #
      # * <tt>rebill_id</tt> -- A string containing the rebill_id of the recurring billing that you wish to cancel/stop (REQUIRED)
      def cancel_recurring(rebill_id)
       	post = {}
        requires!(rebill_id)
        post[:REBILL_ID]         = rebill_id
        post[:TRANS_TYPE]        = 'SET'
       	post[:STATUS]            = 'stopped'
        commit('rebill', 'nil', post)
      end

      private
      
      def commit(action, money, fields)
        fields[:AMOUNT] = amount(money) unless (fields[:TRANS_TYPE] == 'VOID' or action == 'rebill')
       	test? == true || @options[:test] == true ? fields[:MODE] = 'TEST' : fields[:MODE] = 'LIVE'
       	action == 'rebill' ? begin url = rebilling_url; fields[:TAMPER_PROOF_SEAL] = calc_rebill_tps(fields) end : begin url = live_url; fields[:TAMPER_PROOF_SEAL] = calc_tps(amount(money), fields) end
        fields[:ACCOUNT_ID] = @options[:login]
        data = ssl_post url, post_data(action, fields)
        response = parse(data)
        message = message_from(response)
       	test_mode = test? || fields[:MODE] == 'TEST'
       	if (response.has_key?('TRANS_ID'))
       	  response_id = response['TRANS_ID'].to_s()
       	elsif (response.has_key?('rebill_id'))
       	  response_id = response['rebill_id'][0]
       	else
       	  response_id = response[TRANSACTION_ID]
       	end
       	response.has_key?('AVS') ? avs = response['AVS'] : avs = ''
       	response[AVS_RESULT_CODE] != '' ? avs = response[AVS_RESULT_CODE] : avs = ''
       	response.has_key?('CVV2') ? cvv2 = response['CVV2'] : cvv2 = ''
       	response[CARD_CODE_RESPONSE_CODE] != '' ? cvv2 = response[CARD_CODE_RESPONSE_CODE] : cvv2 = ''
        Response.new(success?(response), message, response,
          :test          => test_mode,
          :authorization => response_id,
	  :fraud_review => fraud_review?(response),
          :avs_result    => { :code => avs },
          :cvv_result    => cvv2
        )
      end

      def success?(response)
       	if (response['STATUS'] == '1' || message_from(response) =~ /approved/ || response.has_key?('rebill_id') || response[RESPONSE_REASON_TEXT] =~ /approved/) 
		  return true
		else 
		  return false
		end
      end

      def fraud_review?(response)
       	response['STATUS'] == 'E' || response['STATUS'] == '0' || response[RESPONSE_REASON_TEXT] =~ /being reviewed/
      end

      def get_rebill_id(response)
	return response['REBID'] if response_has.key?('REBID')
      end
     
      def parse(body)
       	fields = CGI::parse(body)
       	if fields.has_key?('MESSAGE') or fields.has_key?('rebill_id')
       	  if fields.has_key?('MESSAGE')
       	    fields['MESSAGE'][0] == "Missing ACCOUNT_ID" ? message = "The merchant login ID or password is invalid" : message = fields['MESSAGE']
       	    fields['MESSAGE'][0] =~ /Approved/ ? message = "This transaction has been approved" : message = fields['MESSAGE'] if message == fields['MESSAGE']
       	    fields['MESSAGE'][0] =~ /Expired/ ? message = "The credit card has expired" : message = fields['MESSAGE'] if message == fields['MESSAGE']
       	    fields.delete('MESSAGE')
       	  end
       	  fields.has_key?('STATUS') ? begin status = fields['STATUS']; fields.delete('STATUS') end : status = ''
       	  fields.has_key?('AVS') ? begin avs = fields['AVS']; fields.delete('AVS') end : avs = ''
       	  fields.has_key?('CVV2') ? begin cvv2 = fields['CVV2']; fields.delete('CVV2') end : cvv2 = ''
       	  fields.has_key?('MASTER_ID') ? begin trans_id = fields['MASTER_ID']; fields.delete('MASTER_ID') end : trans_id = ''
       	  fields[:avs_result_code] = avs
       	  fields[:card_code] = cvv2
       	  fields[:response_code] = status
       	  fields[:response_reason_code] = ''
       	  fields[:response_reason_text] = message
	  fields[:transaction_id] = trans_id
       	  return fields
       	end 
       	# parse response if using other old API
       	hash = Hash.new
        fields = fields.first[0].split(",")
       	fields.each_index do |x|
       	  hash[x] = fields[x].tr('$','')
       	end
       	hash
      end

      def add_invoice(post, options)
       	post[:ORDER_ID]	   = options[:order_id] if options.has_key? :order_id
        post[:INVOICE_ID]  = options[:invoice] if options.has_key? :invoice
        post[:invoice_num] = options[:order_id] if options.has_key? :order_id
        post[:MEMO]        = options[:description] if options.has_key? :description
        post[:description] = options[:description] if options.has_key? :description
      end

      def add_creditcard(post, creditcard)
       	post[:PAYMENT_TYPE]    = 'CREDIT'
        post[:PAYMENT_ACCOUNT] = creditcard.number
        post[:CARD_CVV2]       = creditcard.verification_value if 
                              creditcard.verification_value?
        post[:CARD_EXPIRE]     = expdate(creditcard)
        post[:NAME1]           = creditcard.first_name
        post[:NAME2]           = creditcard.last_name
      end

      def add_check(post, check)
       	post[:PAYMENT_TYPE]     = 'ACH'
       	post[:PAYMENT_ACCOUNT]  = check.account_type + ":" + check.routing_number + ":" + check.account_number
       	post[:NAME1]            = check.first_name
       	post[:NAME2]            = check.last_name 
      end

      def add_customer_data(post, options)
          post[:EMAIL]     = options[:email] if options.has_key? :email
       	  post[:CUSTOM_ID] = options[:customer] if options.has_key? :customer
      end

      def add_duplicate_window(post)
        unless duplicate_window.nil?
          post[:duplicate_window] = duplicate_window
       	  post[:DUPLICATE_OVERRIDE] = duplicate_window
        end
      end

      def add_address(post, options)
	if address = options[:billing_address] || options[:address]
	  post[:NAME1]	      = address[:first_name]
	  post[:NAME2]	      = address[:last_name]
          post[:ADDR1]        = address[:address1]
	  post[:ADDR2]        = address[:address2]
          post[:COMPANY_NAME] = address[:company]
          post[:PHONE]        = address[:phone]
          post[:CITY]         = address[:city]
	  post[:STATE]        = address[:state].blank?  ? 'n/a' : address[:state] 
          post[:ZIP]          = address[:zip]
          post[:COUNTRY]      = address[:country]
        end
        if address = options[:shipping_address]
          post[:NAME1]        = address[:first_name]
          post[:NAME2]        = address[:last_name]
          post[:ADDR1]        = address[:address1]
       	  post[:ADDR1]        = address[:address1]
          post[:COMPANY_NAME] = address[:company]
          post[:PHONE]        = address[:phone]
          post[:ZIP]          = address[:zip]
          post[:CITY]         = address[:city]
          post[:COUNTRY]      = address[:country]
          post[:STATE]        = address[:state].blank?  ? 'n/a' : address[:state] 
        end
      end

      def post_data(action, parameters = {})
        post = {}
        post[:version]        = '3.0'
        post[:login]          = ''
        post[:tran_key]       = ''
        post[:relay_response] = "FALSE"
        post[:type]           = action
        post[:delim_data]     = "TRUE"
        post[:delim_char]     = ","
        post[:encap_char]     = "$"
	post[:card_num]	      = '4111111111111111'
	post[:exp_date]       = '1212'
        post[:solution_ID]    = application_id if application_id.present? && application_id != "ActiveMerchant"
        request = post.merge(parameters).collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
        request
      end

      def message_from(results)
        if results[:response_code] == 2
          return CVVResult.messages[ results[:card_code] ] if CARD_CODE_ERRORS.include?(results[:card_code])
          if AVS_REASON_CODES.include?(results[:response_reason_code]) && AVS_ERRORS.include?(results[:avs_result_code])
            return AVSResult.messages[ results[:avs_result_code] ]
          end
	  return (results[:response_reason_text] ? results[:response_reason_text].chomp('.') : '')
        end
	if results.has_key?(:response_reason_text)
	  return results[:response_reason_text].to_s()
	end
	if !results.has_key?('STATUS')
	  return results[RESPONSE_REASON_TEXT] ? results[RESPONSE_REASON_TEXT].chomp('.') : ''
	end
	end	

      def expdate(creditcard)
        year  = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)

        "#{month}#{year[-2..-1]}"
      end

      def calc_tps(amount, post)
	post[:NAME1] = '' if post[:NAME1].nil?
        digest = Digest::MD5.hexdigest(@options[:password] + 
        @options[:login] + post[:TRANS_TYPE] + 
        amount.to_s() + post[:MASTER_ID].to_s() + 
        post[:NAME1].to_s() + post[:PAYMENT_ACCOUNT].to_s())
	return digest
      end


      def calc_rebill_tps(post)
        digest = Digest::MD5.hexdigest(@options[:password] + 
        @options[:login] + post[:TRANS_TYPE] + post[:REBILL_ID][0].to_s())
        return digest
      end
   
      def handle_response(response)
        if ignore_http_status then
          return response.body
        else
          case response.code.to_i
          when 200...300
            response.body
          else
            raise ResponseError.new(response)
          end
        end
      end

    end
  end
end
