module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class NmiVaultGateway < Gateway
      self.test_url = self.live_url = 'https://secure.nmi.com/api/transact.php'
      self.homepage_url = 'http://nmi.com/'
      self.display_name = 'NMI (Customer Vault)'
      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      # https://pcisecure.diamondmindschools.com/merchants/resources/integration/integration_portal.php#appendix_3
      DECLINED_CODES = [200, 201, 202, 203, 204, 220, 221, 222, 223, 224, 225, 240, 250]
      FRAUD_CODES = [251, 252, 253]

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def authorize(money, customer_id, options = {})
        post = {:customer_vault_id => customer_id}
        add_currency_code(post, money, options)
        add_invoice(post, options)

        commit('auth', money, post)
      end

      def purchase(money, customer_id, options = {})
        post = {:customer_vault_id => customer_id}
        add_currency_code(post, money, options)
        add_invoice(post, options)

        commit('sale', money, post)
      end

      def capture(money, authorization, options = {})
        post = {:transactionid => authorization}
        if options.has_key? :order_id
          post[:orderid] = options[:order_id]
        end
        commit('capture', money, post)
      end

      def void(authorization, options = {})
        post = {:transactionid => authorization}
        commit('void', nil, post)
      end

      def refund(money, identification, options = {})
        post = {:transactionid => identification}
        commit('refund', money, post)
      end

      def store(creditcard, options = {})
        post = {:customer_vault_id => generate_unique_id()}
        add_currency_code(post, nil, options)
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)

        commit('add', nil, post)
      end

      def update(customer_id, creditcard, options = {})
        post = {:customer_vault_id => customer_id}
        add_currency_code(post, nil, options)
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)

        commit('update', nil, post)
      end

      def unstore(customer_id, options = {})
        post = {:customer_vault_id => customer_id}

        commit('delete', nil, post)
      end

      private

      def add_customer_data(post, options)
        if options.has_key? :email
          post[:email] = options[:email]
        end

        if options.has_key? :customer
          post[:billing_id] = options[:customer] if Float(options[:customer]) rescue nil
        end
      end

      def add_address(post, creditcard, options)
        if address = options[:billing_address] || options[:address]
          post[:company]  = address[:company].to_s
          post[:address1] = address[:address1].to_s
          post[:address2] = address[:address2].to_s
          post[:city]     = address[:city].to_s
          post[:state]    = address[:state].to_s
          post[:country]  = address[:country].to_s
          post[:zip]      = address[:zip].to_s
          post[:phone]    = address[:phone].to_s
        end

        if address = options[:shipping_address]
          post[:shipping_firstname] = address[:first_name].to_s
          post[:shipping_lastname]  = address[:last_name].to_s
          post[:shipping_company]   = address[:company].to_s
          post[:shipping_address1]  = address[:address1].to_s
          post[:shipping_address2]  = address[:address2].to_s
          post[:shipping_city]      = address[:city].to_s
          post[:shipping_state]     = address[:state].to_s
          post[:shipping_zip]       = address[:zip].to_s
          post[:shipping_country]   = address[:country].to_s
          post[:shipping_phone]     = address[:phone].to_s
        end
      end

      def add_currency_code(post, money, options)
        post[:currency] = options[:currency] || currency(money)
      end

      def add_invoice(post, options)
        post[:orderid] = options[:order_id]
        post[:order_description] = options[:description]
      end

      def add_creditcard(post, creditcard)
        post[:ccnumber]   = creditcard.number
        post[:ccexp]      = expdate(creditcard)
        post[:first_name] = creditcard.first_name
        post[:last_name]  = creditcard.last_name
        post[:payment]    = 'creditcard'
      end

      def expdate(creditcard)
        year  = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)

        "#{month}#{year[-2..-1]}"
      end

      def parse(body)
      end

      def commit(action, money, parameters)
        customer_action = ['add', 'update', 'delete'].include? action
        unless customer_action or 'void' == action
          parameters[:amount] = amount(money)
        end

        url = test? ? self.test_url : self.live_url
        body = post_data(action, parameters)
        data = ssl_post url, body

        response = {}
        CGI.parse(data).each do |key, value|
          if value.length == 1
            value = value[0]
          end
          response[key.to_sym] = value
        end
        response[:action] = action

        message = message_from(response)

        Response.new(response[:response_code] == '100', message, response,
          :test => test?,
          :authorization => customer_action ? response[:customer_vault_id] : response[:transactionid],
          :avs_result => { :code => response[:avsresponse] },
          :cvv_result => response[:cvvresponse]
        )
      end

      def message_from(response)
        # Remove the REFID from the message text for the Response.message attr.
        # it will still be available via Reponse.params['responsetext'].
        response[:responsetext].gsub(/ REFID:\d+$/, '')
      end

      def post_data(action, parameters = {})
        post = {}

        if ['add', 'update', 'delete'].include? action
          post[:customer_vault] = "#{action}_customer"
        else
          post[:type] = action
        end

        if test?
          post[:username] = 'demo'
          post[:password] = 'password'
        else
          post[:username] = @options[:login]
          post[:password] = @options[:password]
        end

        request = post.merge(parameters).collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
        request
      end
    end
  end
end

