module ActiveMerchant #:nodoc:
  module Billing #:nodoc:

    # For more information on the flo2cash visit {Flo2Cash}[https://flo2cash.com/nz]
    #
    # ==== Automated Recurring Billing (ARB)
    #
    # Before using the Recurring Payments service, you first need to make sure
    # that you have at least one of the Recurring Payments channel enabled for
    # your account
    #
    # Recurring Payments supports two different types of recurring payments
    # * `Recurring Card Payments` which allow you to set up customer on
    # recurring payments with their credit cards.
    # * `Recurring Direct Debits` which allow you to set up customers on
    # recurring payments with their bank account numbers.
    #
    class Flo2cashRestGateway < Gateway
      self.test_url = 'https://sandbox.flo2cash.com/api'
      self.live_url = 'https://secure.flo2cash.co.nz/api'

      self.supported_countries = ['NZ']
      self.default_currency = 'NZD'
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club]

      self.homepage_url = 'http://www.flo2cash.co.nz/'
      self.display_name = 'Flo2Cash'

      # Errors Codes from flo2Cash
      #
      #   05  Declined – Bank declined
      #   10  Declined – Bank error
      #   51  Declined – Insufficient funds
      #   54  Declined – Expired card
      #   68  Failed – No reply from bank
      #
      STANDARD_ERROR_CODE_MAPPING = {
        '05' => STANDARD_ERROR_CODE[:processing_error],
        '10' => STANDARD_ERROR_CODE[:processing_error],
        '51' => STANDARD_ERROR_CODE[:card_declined],
        '54' => STANDARD_ERROR_CODE[:expired_card],
        '68' => STANDARD_ERROR_CODE[:processing_error],
      }

      BRAND_MAP = {
        "visa" => "VISA",
        "master" => "MC",
        "american_express" => "AMEX",
        "diners_club" => "DINERS"
      }

      CLIENT_ERROR_REGEX = /^4\d\d/

      # The following are the response statuses from flo2cash to each endpoint
      #
      # If a transaction results in a decline due to reasons like card expired
      # or insufficient funds, the transaction will be marked as Failed
      #
      # PAYMENT_STATUSES = %w(successful declined blocked failed unknown)
      # CARD_PLAN_STATUSES = %w(active suspended ended cancelled)
      # DIRECT_DEBIT_PLAN_STATUSES = %w(pending-approval active suspended ended cancelled)
      # DIRECT_DEBIT_STATUSES = %w(scheduled processing successful dishonoured failed)

      SUCCESS_STATUSES = %w(successful scheduled processing active cancelled pending-approval)

      ACTION_URL_MAP = {
        store: 'cardtokens',
        purchase: 'payments',
        refund: "payments/%{payment_id}/refunds",
        create_card_plan: 'cardplans',
        create_direct_debit_plan: "directdebitplans",
        update_card_plan: "cardplans/%{plan_id}/status",
        update_direct_debit_plan: "directdebitplans/%{plan_id}/status",
        retrieve_card_plan: "cardplans/%{plan_id}",
        retrieve_card_payment: "payments/%{payment_id}",
        retrieve_direct_debit_plan: "directdebitplans/%{plan_id}",
      }

      # Creates a new Flo2cachRest gateway
      #
      # The gateway requires a +merchant_id+ and a +api_key+ key be passed in
      # the +options+ hash.
      #
      # ==== Options
      #
      # * <tt>:merchant_id</tt> -- The Flo2Cash Merchant ID (REQUIRED)
      # * <tt>:api_key</tt> -- The Flo2Cash API key (REQUIRED)
      #
      def initialize(options = {})
        requires!(options, :merchant_id, :api_key)
        @merchant_id = options[:merchant_id]
        @api_key = options[:api_key]

        super
      end

      # Process Payment
      #
      def purchase(money, payment_method, options={})
        post = {}
        add_type(post, 'purchase')
        add_channel(post, options)
        add_particular(post, options)
        add_invoice(post, money, options)
        add_customer_resume(post, options)
        add_references(post, options)
        add_device_info(post, options)
        add_geolocation(post, options)

        token = if payment_method.is_a?(String)
            payment_method
          else
            store(payment_method, options).authorization
          end
        add_payment_method(post, options, token)

        commit(:post, :purchase, post, options)
      end

      # Store the card and returns card token
      #
      def store(card, options)
        post = {}
        add_merchant(post, options)
        add_unique_reference(post, options)
        add_card_data(post, card)

        commit(:post, :store, post, options)
      end

      # Refund a Card Payment
      #
      def refund(money, payment_id, options={})
        post = { payment_id: payment_id }
        add_amount(post, money)
        add_references(post, options)
        add_customer_resume(post, options)
        add_device_info(post, options)
        add_geolocation(post, options)

        commit(:post, :refund, post, options)
      end

      # Create a new Card Plan
      #
      # These are self managed plans, where a plan is created for a customer
      # with frequency and amount. Flo2Cash manages charging and retries at
      # defined intervals
      #
      # ==== Parameters
      #
      # * <tt>token</tt> -- Card token
      # * <tt>options</tt> -- hash of options
      #
      # ==== Options
      #
      # * <tt>:start_date</tt> is a string that tells the gateway when to start the rebill. (REQUIRED)
      # * <tt>:type</tt> recurring | instalment (REQUIRED)
      # * <tt>:amount</tt> Amount to rebill (REQUIRED)
      # * <tt>:total_amount</tt> Amount to rebill (REQUIRED if type is instalment)
      # + recurring, customer agrees to pay a fixed amount every defined frequency
      # + instalment, divide the total amount you want to charge your customer into equal instalments.
      # * <tt>frequency</tt>: one of { daily | weekly | fortnightly | 4-weekly | 8-weekly | 12-weekly |
      # monthly | 2-monthly | 3-monthly | 6-monthly | 12-monthly }
      # * <tt>:instalment_fail_option</tt> one of { none | add-to-next | add-to-last | add-at-end }
      # * <tt>:paymentMethod</tt> A hash containeing the payment <tt>:type</tt> of the payment method and
      # the <tt>:token</tt> or <tt>:iframe</tt> values depending of <tt>:type</tt>
      # * <tt>:payer</tt> A hash containing customer information where <tt>:email</tt> is required
      #
      def create_card_plan(token, options)
        post = {}
        post[:startDate] = options[:start_date] || Date.today.at_beginning_of_month.next_month
        add_type(post, options[:type] || 'recurring')
        add_payment_method(post, options, token)
        add_frequency(post, options)
        add_customer_data(post, options)
        add_address(post, options[:address])
        add_invoice(post, options[:amount], options)
        add_references(post, options)
        add_merchant(post, options)
        add_initial_payment(post, options) unless options[:skip_initial_payment]
        add_retry_preferences(post, options)

        commit(:post, :create_card_plan, post, options)
      end

      alias_method :recurring, :create_card_plan

      # Create a new Direct Debit Plan
      #
      # recurring payments with their bank account numbers
      #
      # ==== Parameters
      #
      # * <tt>token</tt> -- Card token
      # * <tt>options</tt> -- hash of options
      #
      # ==== Options
      #
      # * <tt>:start_date</tt> is a string that tells the gateway when to start the rebill. (REQUIRED)
      # * <tt>:type</tt> recurring | instalment | per-invoice (REQUIRED)
      # * <tt>:amount</tt> Amount to rebill (REQUIRED)
      # * <tt>:total_amount</tt> Amount to rebill (REQUIRED if type is instalment)
      # * <tt>initial_date</tt> -- Initial payment date
      # * <tt>intital_amount</tt> -- Amount to bill
      # * <tt>frequency</tt>: one of { daily | weekly | fortnightly | 4-weekly | 8-weekly | 12-weekly |
      # monthly | 2-monthly | 3-monthly | 6-monthly | 12-monthly } (NOT REQUIRED WHEN type per-invoice)
      # * <tt>:signup_type</tt> one of { ivr | paper } (REQUIRED)
      # * <tt>:payer</tt> A hash containing customer information where <tt>:email</tt> is required
      # * <tt>bank_name</tt> -- Bank Name (REQUIRED) (< 50 chars)
      # * <tt>account_name</tt> -- Account Holder name (REQUIRED) (< 20 chars)
      # * <tt>account_number</tt> -- valid account number for merchants country
      #
      def create_direct_debit_plan(options)
        post = {}
        post[:startDate] = options[:start_date] || Date.today.at_beginning_of_month.next_month
        post[:signupType] = options[:signup_type] || 'paper'

        add_type(post, options[:type] || 'recurring') # recurring | instalment | per-invoice
        add_frequency(post, options)
        add_invoice(post, options[:amount], options)
        add_debit_card_references(post, options)
        add_merchant(post, options)
        add_initial_payment(post, options) unless options[:skip_initial_payment]
        add_retry_preferences(post, options)
        add_customer_data(post, options)
        add_address(post, options[:address])
        add_bank_details(post, options)

        commit(:post, :create_direct_debit_plan, post, options)
      end

      alias_method :recurring_debit, :create_card_plan

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(/(Authorization: Basic )\w+/, '\1[FILTERED]').
          gsub(/(merchant\\?\\?\\?":{\\?\\?\\?"id\\?\\?\\?":)(\d+)/, '\1[FILTERED]').
          gsub(/(card\\?\\?\\?":{\\?\\?\\?"number\\?\\?\\?":\\?\\?\\?")(\d+)/, '\1[FILTERED]')
      end

      # Returns a Payment resource
      #
      def retrieve_card_plan(plan_id, options={})
        commit(:get, :retrieve_card_plan, { plan_id: plan_id }, options)
      end

      # Returns a Payment resource
      #
      def retrieve_card_payment(payment_id, options={})
        commit(:get, :retrieve_card_payment, { payment_id: payment_id }, options)
      end

      # Returns a Direct Debit Plan
      #
      def retrieve_direct_debit_plan(plan_id, options={})
        commit(:get, :retrieve_direct_debit_plan, { plan_id: plan_id }, options)
      end

      # Update status of a Card Plan +plan_id+ if possible
      #
      # ==== Parameters
      #
      # * <tt>plan_id</tt> -- The identifier of Card Plan to change.
      # * <tt>status</tt> -- can be "active | cancelled | suspended"
      #   + Cancelled can only be applied to active/suspended plans
      #   + Active can only be applied to suspended plans
      #   + Suspended can only be applied to active plans
      #
      def update_card_plan(plan_id, status, options={})
        params = { plan_id: plan_id, status: status }
        commit(:put, :update_card_plan, params, options)
      end

      # Update status of Direct Debit Plan +plan_id+ if possible
      #
      # ==== Parameters
      #
      # * <tt>plan_id</tt> -- The identifier of Direct Debit Plan to change.
      # * <tt>status</tt> -- can be "cancelled | active | suspended"
      #   + Cancelled can only be applied to active/suspended plans
      #   + Active can only be applied to suspended plans
      #   + Suspended can only be applied to active plans
      #
      def update_direct_debit_plan(plan_id, status, options={})
        params = { plan_id: plan_id, status: status }
        commit(:put, :update_direct_debit_plan, params, options)
      end

      private

      def commit(verb, action, params, options={})
        begin
          raw_response = ssl_request(verb, url(action, params), post_data(verb, params), headers(options))

          response = parse(raw_response)
          succeeded = success_from(response)
        rescue ActiveMerchant::ResponseError => e
          raise if e.response.code !~ CLIENT_ERROR_REGEX

          response = parse(e.response.body)
          succeeded = false
        end

        Response.new(
          succeeded,
          message_from(succeeded, response),
          response,
          authorization: authorization_from(action, response),
          error_code: error_code_from(succeeded, response),
          test: test?
        )
      end

      def headers(options={})
        {
          'Content-Type' => 'application/json',
          'Authorization' => "Basic #{options[:api_key] || @api_key}"
        }
      end

      def parse(body)
        JSON.parse(body)
      end

      def success_from(response)
        !response.key?('status') || SUCCESS_STATUSES.include?(response['status'])
      end

      def message_from(succeeded, response)
        if succeeded
          'Succeeded'
        else
          response.dig('response', 'message').presence || error_code_from(false, response)
        end
      end

      def add_customer_resume(post, options)
        post[:initiatedBy] = options[:initiated_by]
        post[:receiptRecipient] = options[:email]
      end

      def add_customer_data(post, options)
        post[:payer] = {
          companyName: options[:company_name],
          title: options[:title],
          firstNames: options[:first_name],
          lastName: options[:last_name],
          dateOfBirth: options[:dob],
          telephoneHome: options[:home_phone],
          telephoneWork: options[:work_phone],
          telephoneMobile: options[:mob_phone],
          fax: options[:fax],
          email: options[:email]
        }
      end

      def add_device_info(post, options)
        post[:device] = {
          id: options[:device_id],
          description: options[:device_description]
        }
      end

      def add_address(post, options)
        post[:payer].merge({
          address1: options.try(:[], :address1),
          address2: options.try(:[], :address2),
          address3: options.try(:[], :address3),
          suburb: options.try(:[], :suburb),
          city: options.try(:[], :city),
          state: options.try(:[], :state),
          postcode: options.try(:[], :postcode),
          country: options.try(:[], :country)
        })
      end

      # Add Bank details to +post+ hash
      #
      # ==== Options
      # * <tt>bank_name</tt> -- Bank Name (REQUIRED) (< 50 chars)
      # * <tt>account_name</tt> -- Account Holder name (REQUIRED) (< 20 chars)
      # * <tt>account_number</tt> -- valid account number form merchants country
      #
      def add_bank_details(post, options)
        post[:bankDetails] = {
          name: options[:bank_name],
          branchAddress1: options[:bank_address1],
          branchAddress2: options[:bank_address2],
          account: {
            name: options[:account_name],
            number: options[:account_number]
          }
        }
      end

      # Add channel
      #
      # ==== Options
      #
      # * <tt>channel</tt> -- One of { web | vt | api | batch | recurring | ivr | mobile }
      #
      def add_channel(post, options)
        post[:channel] = options[:channel] || 'web'
      end

      # Add initial payment
      #
      # ==== Options
      #
      # * <tt>initial_date</tt> -- Initial payment date
      # * <tt>intital_amount</tt> -- Amount to bill
      #
      def add_initial_payment(post, options)
        post[:initialPayment] = {
          'date' => options[:initial_date] || options[:start_date] || Date.today.at_beginning_of_month.next_month,
          'amount' => amount(options[:initial_amount]) || amount(options[:amount])
        }
      end

      #
      # instalmentFailOption
      # "none | add-to-next | add-to-last | add-at-end"
      #
      def add_invoice(post, money, options)
        add_amount(post, money)
        post[:currency] = options[:currency] || currency(money)
        if options.has_key?('total_amount')
          post[:totalAmount] = options[:total_amount]
          post[:instalmentFailOption] = options[:instalment_fail_option] || 'none'
        end
      end

      def add_amount(post, money)
        post[:amount] = amount(money)
      end

      # Add frequency
      #
      # ==== Options
      #
      # * <tt>frequency</tt>: one of { daily | weekly | fortnightly | 4-weekly | 8-weekly | 12-weekly |
      # monthly | 2-monthly | 3-monthly | 6-monthly | 12-monthly }
      #
      def add_frequency(post, options)
        post[:frequency] = options[:frequency]
      end

      def add_merchant(post, options)
        post[:merchant]  = {
          'id' => options[:merchant_id] || @merchant_id
        }
      end

      # Add payment method
      #
      # ==== Options
      #
      # * <tt>payment_method_type</tt>: token | iframe | card
      # * <tt>token</tt>: token | iframe | card
      #
      def add_payment_method(post, options, value)
        if options[:payment_method_type] == 'iframe'
          post[:paymentMethod] = {
            type: options[:payment_method_type],
            iframe: { 'value' => value }
          }

        else
          post[:paymentMethod] = {
            type: options[:payment_method_type] || 'token',
            token: { 'value' => value }
          }
        end
      end

      def add_references(post, options)
        post[:reference1] = options[:reference_1]
        post[:reference2] = options[:reference_2]
      end

      def add_particular(post, options)
        post[:particulars] = options[:particulars]
      end

      def add_debit_card_references(post, options)
        post[:statementReference1] = options[:statement_reference_1]
        post[:statementReference2] = options[:statement_reference_2]
        post[:merchantReference1] = options[:merchant_reference_1]
        post[:merchantReference2] = options[:merchant_reference_2]
        post[:merchantReference3] = options[:merchant_reference_3]
      end

      # For Recurring Plans Flo2Cash manages charging and retries on defined
      # intervals
      #
      # For a tokenised card, merchant can upload a batch of payments with retry
      # information in the batch file. Flo2Cash will retry at the specified
      # intervals
      #
      # ==== Parameters
      #
      # * <tt>options</tt> -- A hash of Options
      #
      # ==== Options
      #
      # * <tt>retry_perform</tt> -- true | false
      # * <tt>retry_frequency_in_days</tt> Number of days in between attempts
      # * <tt>retry_max_attempts</tt> Number of attempts (max value 7)
      #
      # Based on the chosen parameters, retires are attempted every calendar day,
      # irrespective of the weekend or a public holiday.
      #
      def add_retry_preferences(post, options)
        post[:retryPreferences] = {
          'perform' => options[:retry_perform] || false,
          'frequencyInDays' => options[:retry_frequency_in_days] || 1,
          'maxAttempts' => options[:retry_max_attempts] || 7
        }
      end

      def add_type(post, type_option)
        post[:type] = type_option
      end

      def add_unique_reference(post, options)
        post[:uniqueReference] = options[:unique_reference]
      end

      # paymentMethod[type] options: iframe | card
      #
      def add_card_data(post, card)
        post[:paymentMethod] = {
          type: 'card', # iframe | card
          card: {
            number: card.number,
            expiryDate: expdate(card),
            nameOnCard: card.name
          }
        }
      end

      def add_geolocation(post, options)
        post[:geolocation] = {
          latitude: options[:latitude],
          longitude: options[:longitude]
        }
      end

      def authorization_from(action, response)
        case action
        when :store
          response['token']
        when :payment, :purchase
          response['number']
        else
          response['id']
        end
      end

      def post_data(verb, params)
        return nil if verb == :get || params.nil?

        params.to_json
      end

      def error_code_from(succeeded, response)
        unless succeeded
          response['messages'].try(:join, '; ').presence ||
            parse_error(response['response']).presence ||
            'Unable to read error message'
        end
      end

      def parse_error(response={})
        STANDARD_ERROR_CODE_MAPPING[response['providerResponse']].presence ||
          response['message']
      end

      def expdate(card)
        "#{format(card.month, :two_digits)}#{format(card.year, :two_digits)}"
      end

      def url(action, params)
        arguments = ACTION_URL_MAP[action].scan(/.*%{(.*)}.*/).flatten.map(&:to_sym)

        path = arguments.empty? ? ACTION_URL_MAP[action] : ACTION_URL_MAP[action] % params.slice(*arguments)

        (test? ? test_url : live_url) + '/' + path
      end
    end
  end
end
