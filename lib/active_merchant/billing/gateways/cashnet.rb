module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CashnetGateway < Gateway
      
      self.live_url      = 'https://commerce.cashnet.com/'

      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]
      self.homepage_url        = 'http://www.higherone.com/'
      self.display_name        = 'Cashnet'
      self.money_format        = :dollars

      # Creates a new CashnetGateway
      #
      # ==== Options
      #
      # * <tt>:gateway_merchant_name</tt> -- The Gateway Merchant Name (REQUIRED)
      # * <tt>:station</tt> -- Station (REQUIRED)
      # * <tt>:operator</tt> -- Operator (REQUIRED)
      # * <tt>:password</tt> -- Password (REQUIRED)
      # * <tt>:credit_card_payment_code </tt> -- Credit Card Payment Code  (REQUIRED)
      # * <tt>:customer_code</tt> -- Customer Code (REQUIRED)
      # * <tt>:item_code</tt> -- Item code (REQUIRED)
      # * <tt>:site_name</tt> -- Site name (REQUIRED)
      # * <tt>:test</tt> -- set to true for TEST mode or false for LIVE mode
      def initialize(options = {})
        requires!(options, :gateway_merchant_name, :station, :operator,
          :password, :credit_card_payment_code, :customer_code, :item_code, :site_name)
        super
      end

      def purchase(money, payment_object, fields = {})
        post = {}
        add_creditcard(post, payment_object)
        add_invoice(post, options)
        add_address(post, options)
        add_customer_data(post, options)
        commit('SALE', money, post)
      end

      def refund(money, identification, fields = {})
        fields[:origtx]  = identification
        commit('REFUND', money, fields)
      end

      private

      def commit(action, money, fields)
        fields[:amount] = amount(money) 
        url = live_url + self.options[:gateway_merchant_name]
        parse(ssl_post(url, post_data(action, fields)))
      end

      def post_data(action, parameters = {})
        post = {}
        post[:command]        = action
        post[:merchant]       = self.options[:merchant]
        post[:operator]       = self.options[:operator]
        post[:station]        = self.options[:station]
        post[:password]       = self.options[:password]
        post.merge(parameters).collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end

      def add_creditcard(post, creditcard)
        post[:cardno]          = creditcard.number
        post[:cid]             = creditcard.verification_value
        post[:expdate]         = expdate(creditcard)
        post[:card_name_g]     = creditcard.name
      end

      def add_invoice(post, options)
        post[:order_number]    = options[:order_id]
        post[:itemcode]        = self.options[:itemcode]
      end

      def add_address(post, options)
        if address = (options[:shipping_address] || options[:billing_address] || options[:address])
          post[:addr_g]       = address[:address1]
          post[:city_g]       = address[:city]
          post[:state_g]      = address[:state]
          post[:zip_g]        = address[:zip]
        end
      end

      def add_customer_data(post, options)
        post[:email_g]  = options[:email]
        post[:custcode] = self.options[:customer_code]
      end

      def expdate(creditcard)
        year  = format(creditcard.year, :two_digits)
        month = format(creditcard.month, :two_digits)

        "#{month}#{year}"
      end

      def parse(body)
        response_data = body.match(/<cashnet>(.*)<\/cashnet>/)[1]
        response_fields = Hash[CGI::parse(response_data).map{|k,v| [k.to_sym,v.first]}]

        # normalize message
        message = message_from(response_fields)
        success = response_fields[:result] == '0'
        authorization = response_fields[:result] == '0' ? response_fields[:txno] : ''
        Response.new(success, message, response_fields,
          :test          => test?,
          :authorization => authorization
        )
      end

      def message_from(response_fields)
        message = response_fields[:respmessage]
        message
      end

    end
  end
end