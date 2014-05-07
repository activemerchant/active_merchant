require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BluePayGateway < Gateway
      class_attribute :rebilling_url, :ignore_http_status

      self.live_url      = 'https://secure.bluepay.com/interfaces/bp20post'
      self.rebilling_url = 'https://secure.bluepay.com/interfaces/bp20rebadmin'

      self.ignore_http_status = true

      CARD_CODE_ERRORS = %w( N S )
      AVS_ERRORS = %w( A E N R W Z )
      AVS_REASON_CODES = %w(27 45)

      FIELD_MAP = {
        'TRANS_ID' => :transaction_id,
        'STATUS' => :response_code,
        'AVS' => :avs_result_code,
        'CVV2'=> :card_code,
        'AUTH_CODE' => :authorization,
        'MESSAGE' => :message,
        'REBID' => :rebid,
        'TRANS_TYPE' => :trans_type,
        'PAYMENT_ACCOUNT_MASK' => :acct_mask,
        'CARD_TYPE' => :card_type,
      }

      REBILL_FIELD_MAP = {
        'REBILL_ID' => :rebill_id,
        'ACCOUNT_ID'=> :account_id,
        'USER_ID' => :user_id,
        'TEMPLATE_ID' => :template_id,
        'STATUS' => :status,
        'CREATION_DATE' => :creation_date,
        'NEXT_DATE' => :next_date,
        'LAST_DATE' => :last_date,
        'SCHED_EXPR' => :schedule,
        'CYCLES_REMAIN' => :cycles_remain,
        'REB_AMOUNT' => :rebill_amount,
        'NEXT_AMOUNT' => :next_amount,
        'USUAL_DATE' => :undoc_usual_date, # Not found in the bp20rebadmin API doc.
      }

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
        add_payment_method(post, payment_object)
        add_invoice(post, options)
        add_address(post, options)
        add_customer_data(post, options)
        add_rebill(post, options) if options[:rebill]
        add_duplicate_override(post, options)
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
        add_payment_method(post, payment_object)
        add_invoice(post, options)
        add_address(post, options)
        add_customer_data(post, options)
        add_rebill(post, options) if options[:rebill]
        add_duplicate_override(post, options)
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
      def refund(money, identification, options = {})
        if(identification && !identification.kind_of?(String))
          deprecated "refund should only be used to refund a referenced transaction"
          return credit(money, identification, options)
        end

        post = {}
        post[:PAYMENT_ACCOUNT] = ''
        post[:MASTER_ID]  = identification
        post[:TRANS_TYPE] = 'REFUND'
        post[:NAME1] = (options[:first_name] ? options[:first_name] : "")
        post[:NAME2] = options[:last_name] if options[:last_name]
        post[:ZIP] = options[:zip] if options[:zip]
        add_invoice(post, options)
        add_address(post, options)
        add_customer_data(post, options)
        commit('CREDIT', money, post)
      end

      def credit(money, payment_object, options = {})
        if(payment_object && payment_object.kind_of?(String))
          deprecated "credit should only be used to credit a payment method"
          return refund(money, payment_object, options)
        end

        post = {}
        post[:PAYMENT_ACCOUNT] = ''
        add_payment_method(post, payment_object)
        post[:TRANS_TYPE] = 'CREDIT'

        post[:NAME1] = (options[:first_name] ? options[:first_name] : "")
        post[:NAME2] = options[:last_name] if options[:last_name]
        post[:ZIP] = options[:zip] if options[:zip]
        add_invoice(post, options)
        add_address(post, options)
        add_customer_data(post, options)
        commit('CREDIT', money, post)
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
        deprecated RECURRING_DEPRECATION_MESSAGE

        requires!(options, :rebill_start_date, :rebill_expression)
        options[:rebill] = true
        if money
          purchase(money, payment_object, options)
        else
          authorize(money, payment_object, options)
        end
      end

      # View a recurring payment
      #
      # This will pull data associated with a current recurring billing
      #
      # ==== Parameters
      #
      # * <tt>rebill_id</tt> -- A string containing the rebill_id of the recurring billing that is already active (REQUIRED)
      def status_recurring(rebill_id)
        deprecated RECURRING_DEPRECATION_MESSAGE

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
        deprecated RECURRING_DEPRECATION_MESSAGE

        post = {}
        requires!(options, :rebill_id)
        post[:REBILL_ID]          = options[:rebill_id]
        post[:TRANS_TYPE]         = 'SET'
        post[:REB_AMOUNT]         = amount(options[:rebill_amount]) if options[:rebill_amount]
        post[:NEXT_DATE]          = options[:rebill_next_date]
        post[:REB_EXPR]           = options[:rebill_expression]
        post[:REB_CYCLES]         = options[:rebill_cycles]
        post[:NEXT_AMOUNT]        = options[:rebill_next_amount]
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
        deprecated RECURRING_DEPRECATION_MESSAGE

        post = {}
        requires!(rebill_id)
        post[:REBILL_ID]         = rebill_id
        post[:TRANS_TYPE]        = 'SET'
        post[:STATUS]            = 'stopped'
        commit('rebill', 'nil', post)
      end

      private

      def commit(action, money, fields)
        fields[:AMOUNT] = amount(money) unless(fields[:TRANS_TYPE] == 'VOID' || action == 'rebill')
        fields[:MODE] = (test? ? 'TEST' : 'LIVE')
        fields[:ACCOUNT_ID] = @options[:login]

        if action == 'rebill'
          url = rebilling_url
          fields[:TAMPER_PROOF_SEAL] = calc_rebill_tps(fields)
        else
          url = live_url
          fields[:TAMPER_PROOF_SEAL] = calc_tps(amount(money), fields)
        end
        parse(ssl_post(url, post_data(action, fields)))
      end

      def parse_recurring(response_fields, opts={}) # expected status?
        parsed = {}
        response_fields.each do |k,v|
          mapped_key = REBILL_FIELD_MAP.include?(k) ? REBILL_FIELD_MAP[k] : k
          parsed[mapped_key] = v
        end

        success = parsed[:status] != 'error'
        message = parsed[:status]

        Response.new(success, message, parsed,
          :test          => test?,
          :authorization => parsed[:rebill_id])
      end

      def parse(body)
        # The bp20api has max one value per form field.
        response_fields = Hash[CGI::parse(body).map{|k,v| [k.upcase,v.first]}]

        if response_fields.include? "REBILL_ID"
          return parse_recurring(response_fields)
        end

        parsed = {}
        response_fields.each do |k,v|
          mapped_key = FIELD_MAP.include?(k) ? FIELD_MAP[k] : k
          parsed[mapped_key] = v
        end

        # normalize message
        message = message_from(parsed)
        success = parsed[:response_code] == '1'
        Response.new(success, message, parsed,
          :test          => test?,
          :authorization => (parsed[:rebid] && parsed[:rebid] != '' ? parsed[:rebid] : parsed[:transaction_id]),
          :avs_result    => { :code => parsed[:avs_result_code] },
          :cvv_result    => parsed[:card_code]
        )
      end

      def message_from(parsed)
        message = parsed[:message]
        if(parsed[:response_code].to_i == 2)
          if CARD_CODE_ERRORS.include?(parsed[:card_code])
            message = CVVResult.messages[parsed[:card_code]]
          elsif AVS_ERRORS.include?(parsed[:avs_result_code])
            message = AVSResult.messages[ parsed[:avs_result_code] ]
          else
            message = message.chomp('.')
          end
        elsif message == "Missing ACCOUNT_ID"
          message = "The merchant login ID or password is invalid"
        elsif message =~ /Approved/
          message = "This transaction has been approved"
        elsif message =~  /Expired/
          message =  "The credit card has expired"
        end
        message
      end

      def add_invoice(post, options)
        post[:ORDER_ID]    = options[:order_id]
        post[:INVOICE_ID]  = options[:invoice]
        post[:invoice_num] = options[:order_id]
        post[:MEMO]        = options[:description]
        post[:description] = options[:description]
      end

      def add_payment_method(post, payment_object)
        post[:MASTER_ID] = ''
        case payment_object
        when String
          post[:MASTER_ID] = payment_object
        when Check
          add_check(post, payment_object)
        else
          add_creditcard(post, payment_object)
        end
      end

      def add_creditcard(post, creditcard)
        post[:PAYMENT_TYPE]    = 'CREDIT'
        post[:PAYMENT_ACCOUNT] = creditcard.number
        post[:CARD_CVV2]       = creditcard.verification_value
        post[:CARD_EXPIRE]     = expdate(creditcard)
        post[:NAME1]           = creditcard.first_name
        post[:NAME2]           = creditcard.last_name
      end

      CHECK_ACCOUNT_TYPES = {
        "checking" => "C",
        "savings" => "S"
      }

      def add_check(post, check)
        post[:PAYMENT_TYPE]     = 'ACH'
        post[:PAYMENT_ACCOUNT]  = [CHECK_ACCOUNT_TYPES[check.account_type], check.routing_number, check.account_number].join(":")
        post[:NAME1]            = check.first_name
        post[:NAME2]            = check.last_name
      end

      def add_customer_data(post, options)
          post[:EMAIL]     = options[:email]
          post[:CUSTOM_ID] = options[:customer]
      end

      def add_duplicate_override(post, options)
        post[:DUPLICATE_OVERRIDE] = options[:duplicate_override]
      end

      def add_address(post, options)
        if address = (options[:shipping_address] || options[:billing_address] || options[:address])
          post[:ADDR1]        = address[:address1]
          post[:ADDR2]        = address[:address2]
          post[:COMPANY_NAME] = address[:company]
          post[:PHONE]        = address[:phone]
          post[:CITY]         = address[:city]
          post[:STATE]        = (address[:state].blank? ? 'n/a' : address[:state])
          post[:ZIP]          = address[:zip]
          post[:COUNTRY]      = address[:country]
        end
      end

      def add_rebill(post, options)
        post[:DO_REBILL]       = '1'
        post[:REB_AMOUNT]      = amount(options[:rebill_amount])
        post[:REB_FIRST_DATE]  = options[:rebill_start_date]
        post[:REB_EXPR]        = options[:rebill_expression]
        post[:REB_CYCLES]      = options[:rebill_cycles]
      end

      def post_data(action, parameters = {})
        post = {}
        post[:version]        = '1'
        post[:login]          = ''
        post[:tran_key]       = ''
        post[:relay_response] = "FALSE"
        post[:type]           = action
        post[:delim_data]     = "TRUE"
        post[:delim_char]     = ","
        post[:encap_char]     = "$"
        post[:card_num]       = '4111111111111111'
        post[:exp_date]       = '1212'
        post[:solution_ID]    = application_id if(application_id && application_id != "ActiveMerchant")
        post.merge(parameters).collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end

      def expdate(creditcard)
        year  = format(creditcard.year, :two_digits)
        month = format(creditcard.month, :two_digits)

        "#{month}#{year}"
      end

      def calc_tps(amount, post)
        post[:NAME1] ||= ''
        Digest::MD5.hexdigest(
          [
            @options[:password],
            @options[:login],
            post[:TRANS_TYPE],
            amount,
            post[:MASTER_ID],
            post[:NAME1],
            post[:PAYMENT_ACCOUNT]
          ].join("")
        )
      end

      def calc_rebill_tps(post)
        Digest::MD5.hexdigest(
          [
            @options[:password],
            @options[:login],
            post[:TRANS_TYPE],
            post[:REBILL_ID]
          ].join("")
        )
      end

      def handle_response(response)
        if ignore_http_status || (200...300).include?(response.code.to_i)
          return response.body
        end
        raise ResponseError.new(response)
      end
    end
  end
end
