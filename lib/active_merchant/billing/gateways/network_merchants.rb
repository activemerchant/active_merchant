module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class NetworkMerchantsGateway < Gateway
      self.live_url = self.test_url = 'https://secure.networkmerchants.com/api/transact.php'

      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://www.nmi.com/'
      self.display_name = 'Network Merchants (NMI)'

      self.money_format = :dollars
      self.default_currency = 'USD'

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def authorize(money, creditcard_or_vault_id, options = {})
        post = build_auth_post(money, creditcard_or_vault_id, options)
        commit('auth', post)
      end

      def purchase(money, creditcard_or_vault_id, options = {})
        post = build_purchase_post(money, creditcard_or_vault_id, options)
        commit('sale', post)
      end

      def capture(money, authorization, options = {})
        post = build_capture_post(money, authorization, options)
        commit('capture', post)
      end

      def void(authorization, options = {})
        post = build_void_post(authorization, options)
        commit('void', post)
      end

      def refund(money, authorization, options = {})
        post = build_refund_post(money, authorization, options)
        commit('refund', post)
      end

      def store(creditcard, options = {})
        post = build_store_post(creditcard, options)
        commit_vault('add_customer', post)
      end

      def unstore(customer_vault_id, options = {})
        post = build_unstore_post(customer_vault_id, options)
        commit_vault('delete_customer', post)
      end

      private

      def build_auth_post(money, creditcard_or_vault_id, options)
        post = {}
        add_order(post, options)
        add_address(post, options)
        add_shipping_address(post, options)
        add_payment_method(post, creditcard_or_vault_id, options)
        add_amount(post, money, options)
        post
      end

      def build_purchase_post(money, creditcard, options)
        build_auth_post(money, creditcard, options)
      end

      def build_capture_post(money, authorization, options)
        post = {}
        post[:transactionid] = authorization
        add_amount(post, money, options)
        post
      end

      def build_void_post(authorization, options)
        post = {}
        post[:transactionid] = authorization
        post
      end

      def build_refund_post(money, authorization, options)
        post = {}
        post[:transactionid] = authorization
        add_amount(post, money, options)
        post
      end

      def build_store_post(creditcard_or_check, options)
        post = {}
        add_address(post, options)
        add_shipping_address(post, options)
        add_payment_method(post, creditcard_or_check, options)
        post
      end

      def build_unstore_post(customer_vault_id, options)
        post = {}
        post['customer_vault_id'] = customer_vault_id
        post
      end

      def add_order(post, options)
        post[:orderid] = options[:order_id]
        post[:orderdescription] = options[:description]
      end

      def add_address(post, options)
        post[:email] = options[:email]
        post[:ipaddress] = options[:ip]

        address = options[:billing_address] || options[:address] || {}
        post[:address1] = address[:address1]
        post[:address2] = address[:address2]
        post[:city] = address[:city]
        post[:state] = address[:state].blank? ? 'n/a' : address[:state]
        post[:zip] = address[:zip]
        post[:country] = address[:country]
        post[:phone] = address[:phone]
      end

      def add_shipping_address(post, options)
        shipping_address = options[:shipping_address] || {}
        post[:shipping_address1] = shipping_address[:address1]
        post[:shipping_address2] = shipping_address[:address2]
        post[:shipping_city] = shipping_address[:city]
        post[:shipping_state] = shipping_address[:state]
        post[:shipping_zip] = shipping_address[:zip]
        post[:shipping_country] = shipping_address[:country]
      end

      def add_swipe_data(post, creditcard, options)
        # unencrypted tracks
        if creditcard.respond_to?(:track_data) && creditcard.track_data.present?
          post[:track_1] = creditcard.track_data
        else
          post[:track_1] = options[:track_1]
          post[:track_2] = options[:track_2]
          post[:track_3] = options[:track_3]
        end

        # encrypted tracks
        post[:magnesafe_track_1] = options[:magnesafe_track_1]
        post[:magnesafe_track_2] = options[:magnesafe_track_2]
        post[:magnesafe_track_3] = options[:magnesafe_track_3]
        post[:magnesafe_magneprint] = options[:magnesafe_magneprint]
        post[:magnesafe_ksn] = options[:magnesafe_ksn]
        post[:magnesafe_magneprint_status] = options[:magnesafe_magneprint_status]
      end

      def add_payment_method(post, payment_source, options)
        post[:processor_id] = options[:processor_id]
        post[:customer_vault] = 'add_customer' if options[:store]

        add_swipe_data(post, payment_source, options)

        if payment_source.is_a?(Check)
          check = payment_source
          post[:firstname] = check.first_name
          post[:lastname] = check.last_name
          post[:checkname] = check.name
          post[:checkaba] = check.routing_number
          post[:checkaccount] = check.account_number
          post[:account_type] = check.account_type
          post[:account_holder_type] = check.account_holder_type
          post[:payment] = 'check'
        elsif payment_source.respond_to?(:number)
          creditcard = payment_source
          post[:firstname] = creditcard.first_name
          post[:lastname] = creditcard.last_name
          post[:ccnumber] = creditcard.number
          post[:ccexp] = format(creditcard.month, :two_digits) + format(creditcard.year, :two_digits)
          post[:cvv] = creditcard.verification_value
          post[:payment] = 'creditcard'
        else
          post[:customer_vault_id] = payment_source
        end
      end

      def add_login(post)
        post[:username] = @options[:login]
        post[:password] = @options[:password]
      end

      def add_amount(post, money, options)
        post[:currency] = options[:currency] || currency(money)
        post[:amount] = amount(money)
      end

      def commit_vault(action, parameters)
        commit(nil, parameters.merge(:customer_vault => action))
      end

      def commit(action, parameters)
        raw = parse(ssl_post(self.live_url, build_request(action, parameters)))

        success = (raw['response'] == ResponseCodes::APPROVED)

        authorization = authorization_from(success, parameters, raw)

        Response.new(success, raw['responsetext'], raw,
          :test => test?,
          :authorization => authorization,
          :avs_result => { :code => raw['avsresponse']},
          :cvv_result => raw['cvvresponse']
        )
      end

      def build_request(action, parameters)
        parameters[:type] = action if action
        add_login(parameters)
        parameters.to_query
      end

      def authorization_from(success, parameters, response)
        return nil unless success

        authorization = response['transactionid']
        if(parameters[:customer_vault] && (authorization.nil? || authorization.empty?))
          authorization = response['customer_vault_id']
        end

        authorization
      end

      class ResponseCodes
        APPROVED = '1'
        DENIED = '2'
        ERROR = '3'
      end

      def parse(raw_response)
        rsp = CGI.parse(raw_response)
        rsp.keys.each { |k| rsp[k] = rsp[k].first } # flatten out the values
        rsp
      end
    end
  end
end

