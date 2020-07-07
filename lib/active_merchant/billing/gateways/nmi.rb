module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class NmiGateway < Gateway
      include Empty

      DUP_WINDOW_DEPRECATION_MESSAGE = 'The class-level duplicate_window variable is deprecated. Please use the :dup_seconds transaction option instead.'

      self.test_url = self.live_url = 'https://secure.nmi.com/api/transact.php'
      self.default_currency = 'USD'
      self.money_format = :dollars
      self.supported_countries = ['US']
      self.supported_cardtypes = %i[visa master american_express discover]
      self.homepage_url = 'http://nmi.com/'
      self.display_name = 'NMI'

      def self.duplicate_window=(seconds)
        ActiveMerchant.deprecated(DUP_WINDOW_DEPRECATION_MESSAGE)
        @dup_seconds = seconds
      end

      def self.duplicate_window
        instance_variable_defined?(:@dup_seconds) ? @dup_seconds : nil
      end

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def purchase(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method, options)
        add_stored_credential(post, options)
        add_customer_data(post, options)
        add_vendor_data(post, options)
        add_merchant_defined_fields(post, options)
        add_level3_fields(post, options)

        commit('sale', post)
      end

      def authorize(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method, options)
        add_stored_credential(post, options)
        add_customer_data(post, options)
        add_vendor_data(post, options)
        add_merchant_defined_fields(post, options)
        add_level3_fields(post, options)

        commit('auth', post)
      end

      def capture(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        add_reference(post, authorization)
        add_merchant_defined_fields(post, options)

        commit('capture', post)
      end

      def void(authorization, options={})
        post = {}
        add_reference(post, authorization)
        add_payment_type(post, authorization)

        commit('void', post)
      end

      def refund(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        add_reference(post, authorization)
        add_payment_type(post, authorization)

        commit('refund', post)
      end

      def credit(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method, options)
        add_customer_data(post, options)
        add_vendor_data(post, options)
        add_level3_fields(post, options)

        commit('credit', post)
      end

      def verify(payment_method, options={})
        post = {}
        add_payment_method(post, payment_method, options)
        add_customer_data(post, options)
        add_vendor_data(post, options)
        add_merchant_defined_fields(post, options)
        add_level3_fields(post, options)

        commit('validate', post)
      end

      def store(payment_method, options = {})
        post = {}
        add_invoice(post, nil, options)
        add_payment_method(post, payment_method, options)
        add_customer_data(post, options)
        add_vendor_data(post, options)
        add_merchant_defined_fields(post, options)

        commit('add_customer', post)
      end

      def verify_credentials
        response = void('0')
        response.message != 'Authentication Failed'
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((password=)[^&\n]*), '\1[FILTERED]').
          gsub(%r((ccnumber=)\d+), '\1[FILTERED]').
          gsub(%r((cvv=)\d+), '\1[FILTERED]').
          gsub(%r((checkaba=)\d+), '\1[FILTERED]').
          gsub(%r((checkaccount=)\d+), '\1[FILTERED]').
          gsub(%r((cryptogram=)[^&]+(&?)), '\1[FILTERED]\2')
      end

      def supports_network_tokenization?
        true
      end

      private

      def add_level3_fields(post, options)
        add_fields_to_post_if_present(post, options, %i[tax shipping ponumber])
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:orderid] = options[:order_id]
        post[:orderdescription] = options[:description]
        post[:currency] = options[:currency] || currency(money)
        post[:billing_method] = 'recurring' if options[:recurring]
        if (dup_seconds = (options[:dup_seconds] || self.class.duplicate_window))
          post[:dup_seconds] = dup_seconds
        end
      end

      def add_payment_method(post, payment_method, options)
        if payment_method.is_a?(String)
          customer_vault_id, = split_authorization(payment_method)
          post[:customer_vault_id] = customer_vault_id
        elsif payment_method.is_a?(NetworkTokenizationCreditCard)
          post[:ccnumber] = payment_method.number
          post[:ccexp] = exp_date(payment_method)
          post[:token_cryptogram] = payment_method.payment_cryptogram
        elsif card_brand(payment_method) == 'check'
          post[:payment] = 'check'
          post[:firstname] = payment_method.first_name
          post[:lastname] = payment_method.last_name
          post[:checkname] = payment_method.name
          post[:checkaba] = payment_method.routing_number
          post[:checkaccount] = payment_method.account_number
          post[:account_holder_type] = payment_method.account_holder_type
          post[:account_type] = payment_method.account_type
          post[:sec_code] = options[:sec_code] || 'WEB'
        else
          post[:payment] = 'creditcard'
          post[:firstname] = payment_method.first_name
          post[:lastname] = payment_method.last_name
          post[:ccnumber] = payment_method.number
          post[:cvv] = payment_method.verification_value unless empty?(payment_method.verification_value)
          post[:ccexp] = exp_date(payment_method)
        end
      end

      def add_stored_credential(post, options)
        return unless (stored_credential = options[:stored_credential])

        if stored_credential[:initiator] == 'cardholder'
          post[:initiated_by] = 'customer'
        else
          post[:initiated_by] = 'merchant'
        end

        # :reason_type, when provided, overrides anything previously set in
        # post[:billing_method] (see `add_invoice` and the :recurring) option
        case stored_credential[:reason_type]
        when 'recurring'
          post[:billing_method] = 'recurring'
        when 'installment'
          post[:billing_method] = 'installment'
        when 'unscheduled'
          post.delete(:billing_method)
        end

        if stored_credential[:initial_transaction]
          post[:stored_credential_indicator] = 'stored'
        else
          post[:stored_credential_indicator] = 'used'
          post[:initial_transaction_id] = stored_credential[:network_transaction_id]
        end
      end

      def add_customer_data(post, options)
        post[:email] = options[:email]
        post[:ipaddress] = options[:ip]
        post[:customer_id] = options[:customer_id] || options[:customer]

        if (billing_address = options[:billing_address] || options[:address])
          post[:company] = billing_address[:company]
          post[:address1] = billing_address[:address1]
          post[:address2] = billing_address[:address2]
          post[:city] = billing_address[:city]
          post[:state] = billing_address[:state]
          post[:country] = billing_address[:country]
          post[:zip] = billing_address[:zip]
          post[:phone] = billing_address[:phone]
        end

        if (shipping_address = options[:shipping_address])
          post[:shipping_company] = shipping_address[:company]
          post[:shipping_address1] = shipping_address[:address1]
          post[:shipping_address2] = shipping_address[:address2]
          post[:shipping_city] = shipping_address[:city]
          post[:shipping_state] = shipping_address[:state]
          post[:shipping_country] = shipping_address[:country]
          post[:shipping_zip] = shipping_address[:zip]
          post[:shipping_phone] = shipping_address[:phone]
        end
      end

      def add_vendor_data(post, options)
        post[:vendor_id] = options[:vendor_id] if options[:vendor_id]
        post[:processor_id] = options[:processor_id] if options[:processor_id]
      end

      def add_merchant_defined_fields(post, options)
        (1..20).each do |each|
          key = "merchant_defined_field_#{each}".to_sym
          post[key] = options[key] if options[key]
        end
      end

      def add_reference(post, authorization)
        transaction_id, = split_authorization(authorization)
        post[:transactionid] = transaction_id
      end

      def add_payment_type(post, authorization)
        _, payment_type = split_authorization(authorization)
        post[:payment] = payment_type if payment_type
      end

      def exp_date(payment_method)
        "#{format(payment_method.month, :two_digits)}#{format(payment_method.year, :two_digits)}"
      end

      def commit(action, params)
        params[action == 'add_customer' ? :customer_vault : :type] = action
        params[:username] = @options[:login]
        params[:password] = @options[:password]

        raw_response = ssl_post(url, post_data(action, params), headers)
        response = parse(raw_response)
        succeeded = success_from(response)

        Response.new(
          succeeded,
          message_from(succeeded, response),
          response,
          authorization: authorization_from(response, params[:payment], action),
          avs_result: AVSResult.new(code: response[:avsresponse]),
          cvv_result: CVVResult.new(response[:cvvresponse]),
          test: test?
        )
      end

      def authorization_from(response, payment_type, action)
        authorization = (action == 'add_customer' ? response[:customer_vault_id] : response[:transactionid])
        [authorization, payment_type].join('#')
      end

      def split_authorization(authorization)
        authorization.split('#')
      end

      def headers
        { 'Content-Type' => 'application/x-www-form-urlencoded;charset=UTF-8' }
      end

      def post_data(action, params)
        params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
      end

      def url
        test? ? test_url : live_url
      end

      def parse(body)
        Hash[CGI::parse(body).map { |k, v| [k.intern, v.first] }]
      end

      def success_from(response)
        response[:response] == '1'
      end

      def message_from(succeeded, response)
        if succeeded
          'Succeeded'
        else
          response[:responsetext]
        end
      end
    end
  end
end
