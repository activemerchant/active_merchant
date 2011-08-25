require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BluepayGateway < Gateway
      class_inheritable_accessor :live_url, :rebilling_url

      self.live_url      = 'https://secure.bluepay.com/interfaces/bp10emu'
      self.rebilling_url = 'https://secure.bluepay.com/interfaces/bp20rebadmin'
 
      APPROVED, DECLINED, ERROR = "APPROVED", "DECLINED", "ERROR" 


      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
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
      # * <tt>:transaction_mode</tt> -- This can either be set to TEST or LIVE mode 
      def initialize(options = {})
        requires!(options, :account_id, :secret_key)
        $options = options
        super
      end

      # Performs an authorization, which reserves the funds on the customer's credit card. This does not actually take funds from the customer
      # This is referred to an AUTH transaction in BluePay
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be authorized as an Integer value in cents.
      # * <tt>payment_object</tt> -- This can either be one of three things:
      # * A CreditCard object,
      # * A Check object,
      # * or a token. The token is called the Master ID. This is a unique transaction ID returned from a previous transaction. This token associates all the stored information for a previous transaction.
      # * <tt>options</tt> -- A hash of optional parameters.
      def authorize(money, payment_object, options = {})
	post = {}
	if payment_object != nil && payment_object.class() != String
	  payment_object.class() == ActiveMerchant::Billing::Check ?
          add_check(post, payment_object) :
          add_creditcard(post, payment_object)
	else
	  post[:RRNO] = payment_object
	end
	add_invoice(post, options)
        add_address(post, options)
        add_customer_data(post, options)
	if options[:rebill] != nil
          post[:REBILLING]       = '1'
          post[:REB_AMOUNT]      = options[:rebill][:rebill_amount]
          post[:REB_FIRST_DATE]  = options[:rebill][:rebill_start_date]
          post[:REB_EXPR]        = options[:rebill][:rebill_expression]
          post[:REB_CYCLES]      = options[:rebill][:rebill_cycles]
        end
	post[:TRANSACTION_TYPE]  = 'AUTH'
	post[:MODE]              = $options[:transaction_mode]
        post[:TAMPER_PROOF_SEAL] = calc_tps(amount(money), post)
        commit(money, post)
      end

      # Perform a purchase, which is essentially an authorization and capture in a single operation. 
      # This is referred to a SALE transaction in BluePay
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be purchased as an Integer value in cents.
      # * <tt>payment_object</tt> -- This can either be one of three things:
      # * A CreditCard object,
      # * A Check object,
      # * or a token. The token is called the Master ID. This is a unique transaction ID returned from a previous transaction. This token associates all the stored information for a previous transaction.
      # * <tt>options</tt> -- A hash of optional parameters.,
      def purchase(money, payment_object, options = {})
	post = {}
	if payment_object != nil && payment_object.class() != String
	 payment_object.class() == ActiveMerchant::Billing::Check ? 
	 add_check(post, payment_object) :
	 add_creditcard(post, payment_object) 
	else
	  post[:RRNO] = payment_object
	end
	add_invoice(post, options)
        add_address(post, options)
        add_customer_data(post, options)
	if options[:rebill] != nil
	  post[:REBILLING]       = '1'
	  post[:REB_AMOUNT]      = options[:rebill][:rebill_amount]
          post[:REB_FIRST_DATE]  = options[:rebill][:rebill_start_date]
          post[:REB_EXPR]        = options[:rebill][:rebill_expression]
          post[:REB_CYCLES]      = options[:rebill][:rebill_cycles]
        end
	post[:TRANSACTION_TYPE]  = 'SALE'
	post[:MODE]              = $options[:transaction_mode]
	post[:TAMPER_PROOF_SEAL] = calc_tps(amount(money), post)
        commit(money, post)
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
        post[:RRNO]              = identification
	post[:TRANSACTION_TYPE]  = 'CAPTURE'
	post[:MODE]	         = $options[:transaction_mode]
	post[:TAMPER_PROOF_SEAL] = calc_tps(amount(money), post)
        commit(money, post)
      end

      # Void a previous transaction
      # This is referred to a VOID transaction in BluePay
      #
      # ==== Parameters
      #
      # * <tt>identification</tt> - The Master ID, or token, returned from a previous authorize transaction.
      def void(identification, options = {})
	post = {}
        post[:RRNO]              = indentification
	post[:TRANSACTION_TYPE]  = 'VOID'
	post[:MODE]	         = $options[:transaction_mode]
	post[:TAMPER_PROOF_SEAL] = calc_tps(nil, post)
        commit(nil, post)
      end

      # Performs a credit.
      #
      # This transaction indicates that money should flow from the merchant to the customer.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be credited to the customer as an Integer value in cents.
      # * <tt>payment_object</tt> -- This can either be one of three things:
      # * A CreditCard object,
      # * A Check object,
      # * or a token. The token is called the Master ID. This is a unique transaction ID returned from a previous transaction. This token associates all the stored information for a previous transaction.
      # * If the payment_object is a token, then the transaction type will reverse a previous capture or purchase transaction, returning the funds to the customer. If the amount is nil, a full credit will be processed. This is referred to a REFUND transaction in BluePay.
     # * If the payment_object is either a CreditCard or Check object, then the transaction type will be an unmatched credit placing funds in the specified account. This is referred to a CREDIT transaction in BluePay.
      # * <tt>options</tt> -- A hash of parameters.
      def credit(money, payment_object, options = {})
	post = {}
        if payment_object != nil && payment_object.class() != String
           payment_object.class() == ActiveMerchant::Billing::Check ?
           add_check(post, payment_object) :
           add_creditcard(post, payment_object)
	   post[:TRANSACTION_TYPE] = 'CREDIT'
        else
           post[:RRNO]             = payment_object
	   post[:TRANSACTION_TYPE] = 'REFUND'
        end
	post[:MODE]		   = $options[:transaction_mode]
	post[:TAMPER_PROOF_SEAL]   = calc_tps(amount(money), post)
        add_invoice(post, options)
        add_address(post, options)
        add_customer_data(post, options)
        commit(money, post)
      end

      # Set up a new recurring payment.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be purchased as an Integer value in cents.
      # * <tt>payment_object</tt> -- This can either be one of three things:
      # * A CreditCard object,
      # * A Check object,
      # * or a token. The token is called the Master ID. This is a unique transaction ID returned from a previous transaction. This token associates all the stored information for a previous transaction.
      # * <tt>options</tt> -- A hash of optional parameters.,

      # ==== Options
      #
      # * <tt>:rebill</tt> -- A hash containing information about adding a recurring payment to the purchase. Must
      #   contain the keys <tt>:rebill_start_date</tt> and <tt>:rebill_expression</tt>. <tt>:rebill_start_date</tt> is a string that tells the gateway when to start the rebill. 
      #   Has two valid formats:
      #   "YYYY-MM-DD HH:MM:SS" Hours, minutes, and seconds are optional.
      #   "XX UNITS" Relative date as explained below. Marked from the time of the
      #   transaction (i.e.: 10 DAYS, 1 MONTH, 1 YEAR)
      #   rebill_expression is the period of time in-between rebillings.
      #   It uses the same "XX UNITS" format as rebill_start_date, explained above.
      #   Optional parameters include:
      #   rebill_cycles: Number of times to rebill. Don't send or set to nil for infinite rebillings (or
      #   until canceled).
      #   rebill_amount:   Amount to rebill. Defaults to amount of transaction for rebillings.
      # 
      #   For example, to charge the customer $49.95 now and then charge $19.95 in 60 days every 3 months for 5 times, the hash would be as follows:
      #   :rebill => { 
      #     :rebill_start_date => '3 MONTHS',
      #     :rebill_expression => '60 DAYS',
      #     :rebill_cycles     => '5',
      #     :rebill_amount     => '19.95' 
      #   }
      #   A money object of 4995 cents would be passed into the 'money' parameter.
      #   A second example: to charge the customer $0.00 now and then charge $29.95 in 10 days every month for a year, the hash would be as follows:
      #   :rebill => { 
      #     :rebill_start_date => '10 DAYS',
      #     :rebill_expression => '30 DAYS',
      #     :rebill_cycles     => '12',
      #     :rebill_amount     => '29.95' 
      #   }
      #   A money object of nil would be passed into the 'money' parameter.

      def recurring_payment(money, payment_object, options = {})
        requires!(options[:rebill], :rebill_start_date, :rebill_expression)
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
      def view_rebilling(rebill_id)
	post = {}
        requires!(rebill_id)
	$options[:view_rebilling] = '1'
        post[:ACCOUNT_ID]         = $options[:account_id]
        post[:REBILL_ID]          = rebill_id
        post[:TRANS_TYPE]         = 'GET'
        post[:TAMPER_PROOF_SEAL]  = calc_rebill_tps(post)
	post[:REBILL]	 	  = '1'
        commit('nil', post)
      end

      # Update a recurring payment's details.
      #
      # This transaction updates an existing recurring billing
      #
      # ==== Parameters
      #
      # * <tt>rebill_id</tt> -- A string containing the rebill_id of the recurring billing that is already active (REQUIRED)
      # * <tt>options</tt> -- A hash of parameters.
      #
      # ==== Options
      # 
      # * <tt>:rebill</tt> -- A hash containing information about adding a recurring payment to the purchase. The 5 optional hash parameters are below.
      #
      # * <tt>:rebill_amount</tt> -- A string containing the new rebilling amount.
      # * <tt>:rebill_next_date</tt> -- A string containing the new rebilling next date.
      # * <tt>:rebill_expression</tt> -- A string containing the new rebilling expression.
      # * <tt>:rebill_cycles</tt> -- A string containing the new rebilling cycles.
      # * <tt>:rebill_next_amount</tt> -- A string containing the next rebilling amount to charge the customer. This ONLY affects the next scheduled charge; all other rebillings will continue at the regular (rebill_amount) amount.
      # Take a look above at the recurring_payment method for similar examples on how to use.
      def update_rebilling(rebill_id, options = {})
	post = {}
	requires!(rebill_id)
	requires!(options, :rebill)
	$options[:view_rebilling] = '1'
 	post[:ACCOUNT_ID]         = $options[:account_id]	
	post[:REBILL_ID]          = rebill_id
	post[:TRANS_TYPE]         = 'SET'
	post[:TAMPER_PROOF_SEAL]  = calc_rebill_tps(post)
        post[:REB_AMOUNT]         = options[:rebill][:rebill_amount]
        post[:NEXT_DATE]          = options[:rebill][:rebill_next_date]
        post[:REB_EXPR]           = options[:rebill][:rebill_expression]
        post[:REB_CYCLES]     	  = options[:rebill][:rebill_cycles]
	post[:NEXT_AMOUNT]        = options[:rebill][:rebill_next_amount]
        post[:REBILL]             = '1'
	commit('nil', post)	
      end

      # Cancel a recurring payment.
      #
      # This transaction cancels an existing recurring billing.
      #
      # ==== Parameters
      #
      # * <tt>rebill_id</tt> -- A string containing the rebill_id of the recurring billing that is already active (REQUIRED)
      def cancel_rebilling(rebill_id)
	post = {}
        requires!(rebill_id)
        post[:ACCOUNT_ID]        = $options[:account_id]
        post[:REBILL_ID]         = rebill_id
        post[:TRANS_TYPE]        = 'SET'
	post[:STATUS]            = 'stopped'
        post[:TAMPER_PROOF_SEAL] = calc_rebill_tps(post)
	post[:REBILL]		 = '1'
        commit('nil', post)
      end

      private
      
      def commit(money, fields)
        fields[:AMOUNT] = amount(money) unless (fields[:TRANSACTION_TYPE] == 'VOID' or fields[:REBILL] == '1')
	response = post_data(fields)
	message = get_message(response)
	response['AVS']  = (response['AVS'] = "_")  ? nil : response['AVS']
	response['CVV2'] = (response['CVV2'] = "_") ? nil : response['CVV2']
	Response.new(success?(), message, response,
          :test 	 => $options[:transaction_mode],
          :authorization => response['RRNO'],
          :avs_result    => response['AVS'],
          :cvv_result    => response['CVV2']
	)
      end

      def success?()
        (($result == APPROVED and !($trans_message =~ /DUPLICATE/)) or 
          $rebill_result != '') 
      end

      def error?()
	$result == ERROR
      end

      def declined?()
	$result == DECLINED
      end

      def add_invoice(post, options)
	post[:ORDER_ID]	  = options[:order_id] if options.has_key? :order_id
        post[:INVOICE_ID] = options[:invoice] if options.has_key? :invoice
        post[:COMMENT]    = options[:description] if options.has_key? :description
      end

      def add_creditcard(post, creditcard)
	post[:PAYMENT_TYPE] = 'CREDIT'
        post[:CC_NUM]       = creditcard.number
        post[:CVCVV2]       = creditcard.verification_value if 
                              creditcard.verification_value?
        post[:CC_EXPIRES]   = expdate(creditcard)
        post[:NAME1]        = creditcard.first_name
        post[:NAME2]        = creditcard.last_name
      end

      def add_check(post, check)
	post[:PAYMENT_TYPE]     = 'ACH'
	post[:ACH_ROUTING]      = check.routing_number
	post[:ACH_ACCOUNT]      = check.account_number
	post[:ACH_ACCOUNT_TYPE] = check.account_type
	post[:NAME1]            = check.first_name
	post[:NAME2]            = check.last_name 
      end

      def add_customer_data(post, options)
          post[:EMAIL] = options[:email] if options.has_key? :email
	  post[:CUSTOM_ID] = options[:customer] if options.has_key? :customer
      end
      
      def add_address(post, options)
        if address = options[:address] || options[:billing_address]
	  post[:NAME]	      = address[:name]
          post[:ADDR1]        = address[:address1]
	  post[:ADDR2]        = address[:address2]
          post[:COMPANY_NAME] = address[:company]
          post[:PHONE]        = address[:phone]
          post[:CITY]         = address[:city]
	  post[:STATE]        = address[:state].blank?  ? 
	                        'n/a' : address[:state]
          post[:ZIPCODE]      = address[:zip]
          post[:COUNTRY]      = address[:country]
        end
      end

      def post_data(post)
        post[:MERCHANT]  = $options[:account_id]
        post[:REBILL] == '1' ? url = URI.parse(self.rebilling_url) : url = URI.parse(self.live_url) 
        http             = Net::HTTP.new(url.host, url.port)
        http.use_ssl     = true
	http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http.start do |http|
          request        = Net::HTTP::Post.new(url.path)
          request.set_form_data(post)
          response       = http.request(request)
          if post[:REBILL] != '1'
            headers      = response.header["Location"]
            headerString = URI.parse(headers)
            response     = CGI.parse(headerString.query)
          else
            body         = response.body
            response     = CGI.parse(body)
          end
	  $result = response['Result'].to_s()
	  $rebill_result = response['rebill_id'].to_s()
	  $trans_message = response['MESSAGE'].to_s()
	  return response
        end
      end

      def get_message(response)
	return "Duplicate transaction" if response['MESSAGE'].to_s() =~ 
        /DUPLICATE/
	return "Security error. Please verify that the correct BluePay 
	Account ID and Secret Key were used" if response['MESSAGE'].to_s() =~ 
        /SECURITY ERROR/
        return "Rebill ID:" << response['rebill_id'].to_s() <<
               "\nCreation Date:" << response['creation_date'].to_s() <<
               "\nLast Date:" << response['last_date'].to_s() <<
               "\nNext Amount:" << response['next_amount'].to_s() <<
               "\nNext Date:" << response['next_date'].to_s() <<
               "\nRebill Expression:" << response['sched_expr'].to_s() <<
               "\nCycles Remaining:" << response['cycles_remain'].to_s() <<
               "\nStatus:" << response['status'].to_s() if 
               $options[:view_rebilling] == '1'
	return "Rebill ID:" << response['rebill_id'].to_s() << 
        " has been stopped" if response['status'].to_s() =~ /stopped/
	return response['MESSAGE'].to_s()
      end

      def expdate(creditcard)
        year  = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)

        "#{month}#{year[-2..-1]}"
      end

      def calc_tps(amount, post)
         digest = Digest::MD5.hexdigest($options[:secret_key] + 
         $options[:account_id] + post[:TRANSACTION_TYPE] + 
         amount.to_s() + post[:REBILLING].to_s() + 
         post[:REB_FIRST_DATE].to_s() + post[:REB_EXPR].to_s() + 
         post[:REB_CYCLES].to_s() + post[:REB_AMOUNT].to_s() + 
         post[:RRNO].to_s() + post[:MODE])
	return digest
      end


      def calc_rebill_tps(post)
        digest = Digest::MD5.hexdigest($options[:secret_key] + 
        $options[:account_id] + post[:TRANS_TYPE] + post[:REBILL_ID])
        return digest
      end

    end
  end
end
