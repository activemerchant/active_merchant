module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class NmiGateway < Gateway
      include Empty

      DUP_WINDOW_DEPRECATION_MESSAGE = "The class-level duplicate_window variable is deprecated. Please use the :dup_seconds transaction option instead."

      self.test_url = self.live_url = 'https://secure.networkmerchants.com/api/transact.php'
      self.default_currency = 'USD'
      self.money_format = :dollars
      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
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
        if options.has_key?(:security_key)
          requires!(options, :security_key)
        else
          requires!(options, :login, :password)
        end
        super
      end

      def purchase(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method, options)
        add_customer_data(post, options)
        add_merchant_defined_fields(post, options)
        add_level3_fields(post, options)
        add_three_d_secure(post, options)

        commit("sale", post)
      end

      def authorize(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method, options)
        add_customer_data(post, options)
        add_merchant_defined_fields(post, options)
        add_level3_fields(post, options)
        add_three_d_secure(post, options)
        commit('auth', post)
      end

      def capture(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        add_reference(post, authorization)
        add_merchant_defined_fields(post, options)

        commit("capture", post)
      end

      def void(authorization, options={})
        post = {}
        add_reference(post, authorization)
        add_payment_type(post, authorization)

        commit("void", post)
      end

      def refund(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        add_reference(post, authorization)
        add_payment_type(post, authorization)

        commit("refund", post)
      end

      def credit(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method, options)
        add_customer_data(post, options)

        commit("credit", post)
      end

      def verify(payment_method, options={})
        post = {}
        add_payment_method(post, payment_method, options)
        add_customer_data(post, options)
        add_merchant_defined_fields(post, options)

        commit("validate", post)
      end

      def store(payment_method, options = {})
        post = {}
        add_invoice(post, nil, options)
        add_payment_method(post, payment_method, options)
        add_customer_data(post, options)
        add_merchant_defined_fields(post, options)

        commit("add_customer", post)
      end

      def verify_credentials
        response = void("0")
        response.message != "Authentication Failed"
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((password=)[^&\n]*), '\1[FILTERED]').
          gsub(%r((security_key=)[^&\n]*), '\1[FILTERED]').
          gsub(%r((ccnumber=)\d+), '\1[FILTERED]').
          gsub(%r((cvv=)\d+), '\1[FILTERED]').
          gsub(%r((checkaba=)\d+), '\1[FILTERED]').
          gsub(%r((checkaccount=)\d+), '\1[FILTERED]')
      end

      private

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:orderid] = options[:order_id]
        post[:orderdescription] = options[:description]
        post[:currency] = options[:currency] || currency(money)
        post[:billing_method] = "recurring" if options[:recurring]
        if (dup_seconds = (options[:dup_seconds] || self.class.duplicate_window))
          post[:dup_seconds] = dup_seconds
        end
      end

      def add_payment_method(post, payment_method, options)
        if(payment_method.is_a?(String))
          post[:customer_vault_id] = payment_method
        elsif(card_brand(payment_method) == 'check')
          post[:payment] = 'check'
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
          # should only send :initial_transaction_id if it is a MIT
          post[:initial_transaction_id] = stored_credential[:network_transaction_id] if post[:initiated_by] == 'merchant'
        end
      end

      def add_customer_data(post, options)
        post[:email] = options[:email]
        post[:ipaddress] = options[:ip]
        post[:customer_id] = options[:customer_id] || options[:customer]

        if(billing_address = options[:billing_address] || options[:address])
          post[:company] = billing_address[:company]
          post[:address1] = billing_address[:address1]
          post[:address2] = billing_address[:address2]
          post[:city] = billing_address[:city]
          post[:state] = billing_address[:state]
          post[:country] = billing_address[:country]
          post[:zip]    = billing_address[:zip]
          post[:phone] = billing_address[:phone]
        end

        if(shipping_address = options[:shipping_address])
          post[:shipping_company] = shipping_address[:company]
          post[:shipping_address1] = shipping_address[:address1]
          post[:shipping_address2] = shipping_address[:address2]
          post[:shipping_city] = shipping_address[:city]
          post[:shipping_state] = shipping_address[:state]
          post[:shipping_country] = shipping_address[:country]
          post[:shipping_zip]    = shipping_address[:zip]
          post[:shipping_phone] = shipping_address[:phone]
        end

        if (descriptor = options[:descriptors])
          post[:descriptor] = descriptor[:descriptor]
          post[:descriptor_phone] = descriptor[:descriptor_phone]
          post[:descriptor_address] = descriptor[:descriptor_address]
          post[:descriptor_city] = descriptor[:descriptor_city]
          post[:descriptor_state] = descriptor[:descriptor_state]
          post[:descriptor_postal] = descriptor[:descriptor_postal]
          post[:descriptor_country] = descriptor[:descriptor_country]
          post[:descriptor_mcc] = descriptor[:descriptor_mcc]
          post[:descriptor_merchant_id] = descriptor[:descriptor_merchant_id]
          post[:descriptor_url] = descriptor[:descriptor_url]
        end
      end

      def add_merchant_defined_fields(post, options)
        (1..20).each do |each|
          key = "merchant_defined_field_#{each}".to_sym
          post[key] = options[key] if options[key]
        end
      end

      def add_three_d_secure(post, options)
        three_d_secure = options[:three_d_secure]
        return unless three_d_secure

        post[:cardholder_auth] = cardholder_auth(three_d_secure[:authentication_response_status])
        post[:cavv] = three_d_secure[:cavv]
        post[:xid] = three_d_secure[:xid]
        post[:three_ds_version] = three_d_secure[:version]
        post[:directory_server_id] = three_d_secure[:ds_transaction_id]
      end

      def cardholder_auth(trans_status)
        return nil if trans_status.nil?

        trans_status == 'Y' ? 'verified' : 'attempted'
      end

      def add_reference(post, authorization)
        transaction_id, _ = split_authorization(authorization)
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
        params[:username] = @options[:login] unless @options[:login].nil?
        params[:password] = @options[:password] unless @options[:password].nil?
        params[:security_key] = @options[:security_key] unless @options[:security_key].nil?
        raw_response = ssl_post(url, post_data(action, params), headers)
        response = parse(raw_response)
        succeeded = success_from(response)

        Response.new(
          succeeded,
          message_from(succeeded, response),
          response,
          authorization: authorization_from(response, params[:payment]),
          avs_result: AVSResult.new(code: response[:avsresponse]),
          cvv_result: CVVResult.new(response[:cvvresponse]),
          test: test?
        )
      end

      def authorization_from(response, payment_type)
        [ response[:transactionid], payment_type ].join("#")
      end

      def split_authorization(authorization)
        authorization.split("#")
      end

      def headers
        headers = { 'Content-Type' => 'application/x-www-form-urlencoded;charset=UTF-8' }
        headers
      end

      def post_data(action, params)
        params.map {|k, v| "#{k}=#{CGI.escape(v.to_s)}"}.join('&')
      end

      def url
        test? ? test_url : live_url
      end

      def parse(body)
        Hash[CGI::parse(body).map { |k,v| [k.intern, v.first] }]
      end

      def success_from(response)
        response[:response] == "1"
      end

      def message_from(succeeded, response)
        if succeeded
          "Succeeded"
        else
          response[:responsetext]
        end
      end

    end
  end
end
