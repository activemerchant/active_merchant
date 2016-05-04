require 'digest/md5'
require 'rexml/document'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MerchantWarriorGateway < Gateway
      TOKEN_TEST_URL = 'https://base.merchantwarrior.com/token/'
      TOKEN_LIVE_URL = 'https://api.merchantwarrior.com/token/'

      POST_TEST_URL = 'https://base.merchantwarrior.com/post/'
      POST_LIVE_URL = 'https://api.merchantwarrior.com/post/'

      self.supported_countries = ['AU']
      self.supported_cardtypes = [:visa, :master, :american_express,
                                  :diners_club, :discover, :jcb]
      self.homepage_url = 'https://www.merchantwarrior.com/'
      self.display_name = 'Merchant Warrior'

      self.money_format = :dollars
      self.default_currency = 'AUD'

      def initialize(options = {})
        requires!(options, :merchant_uuid, :api_key, :api_passphrase)
        super
      end

      def authorize(money, payment_method, options = {})
        post = {}
        add_amount(post, money, options)
        add_order_id(post, options)
        add_address(post, options)
        add_payment_method(post, payment_method)
        commit('processAuth', post)
      end

      def purchase(money, payment_method, options = {})
        post = {}
        add_amount(post, money, options)
        add_order_id(post, options)
        add_address(post, options)
        add_payment_method(post, payment_method)
        commit('processCard', post)
      end

      def capture(money, identification, options = {})
        post = {}
        add_amount(post, money, options)
        add_transaction(post, identification)
        post.merge!('captureAmount' => amount(money))
        commit('processCapture', post)
      end

      def refund(money, identification, options = {})
        post = {}
        add_amount(post, money, options)
        add_transaction(post, identification)
        post['refundAmount'] = amount(money)
        commit('refundCard', post)
      end

      def store(creditcard, options = {})
        post = {
          'cardName' => scrub_name(creditcard.name),
          'cardNumber' => creditcard.number,
          'cardExpiryMonth' => format(creditcard.month, :two_digits),
          'cardExpiryYear'  => format(creditcard.year, :two_digits)
        }
        commit('addCard', post)
      end

      private

      def add_transaction(post, identification)
        post['transactionID'] = identification
      end

      def add_address(post, options)
        return unless(address = (options[:billing_address] || options[:address]))

        post['customerName'] = scrub_name(address[:name])
        post['customerCountry'] = address[:country]
        post['customerState'] = address[:state]
        post['customerCity'] = address[:city]
        post['customerAddress'] = address[:address1]
        post['customerPostCode'] = address[:zip]
		post['customerIP'] = address[:ip]
		post['customerPhone'] = address[:phone]
		post['customerEmail'] = address[:email]
      end

      def add_order_id(post, options)
        post['transactionProduct'] = truncate(options[:order_id], 34) || SecureRandom.hex(15)
      end

      def add_payment_method(post, payment_method)
        if payment_method.respond_to?(:number)
          add_creditcard(post, payment_method)
        else
          add_token(post, payment_method)
        end
      end

      def add_token(post, token)
        post['cardID'] = token
      end

      def add_creditcard(post, creditcard)
        post['paymentCardNumber'] = creditcard.number
        post['paymentCardName'] = scrub_name(creditcard.name)
        post['paymentCardExpiry'] = creditcard.expiry_date.expiration.strftime("%m%y")
        post['paymentCardCSC'] = creditcard.verification_value if creditcard.verification_value?
      end

      def scrub_name(name)
        name.gsub(/[^a-zA-Z\. -]/, '')
      end

      def add_amount(post, money, options)
        currency = (options[:currency] || currency(money))

        post['transactionAmount'] = amount(money)
        post['transactionCurrency'] = currency
        post['hash'] = verification_hash(amount(money), currency)
      end

      def verification_hash(money, currency)
        Digest::MD5.hexdigest(
          (
            @options[:api_passphrase].to_s +
            @options[:merchant_uuid].to_s +
            money.to_s +
            currency
          ).downcase
        )
      end

      def parse(body)
        xml = REXML::Document.new(body)

        response = {}
        xml.root.elements.to_a.each do |node|
          parse_element(response, node)
        end
        response
      end

      def parse_element(response, node)
        if node.has_elements?
          node.elements.each{|element| parse_element(response, element)}
        else
          response[node.name.underscore.to_sym] = node.text
        end
      end

      def commit(action, post)
        add_auth(action, post)

        response = parse(ssl_post(url_for(action, post), post_data(post)))

        Response.new(
          success?(response),
          response[:response_message],
          response,
          :test => test?,
          :authorization => (response[:card_id] || response[:transaction_id])
        )
      end

      def add_auth(action, post)
        post['merchantUUID'] = @options[:merchant_uuid]
        post['apiKey'] = @options[:api_key]
        unless token?(post)
          post['method'] = action
        end
      end

      def url_for(action, post)
        if token?(post)
          [(test? ? TOKEN_TEST_URL : TOKEN_LIVE_URL), action].join("/")
        else
          (test? ? POST_TEST_URL : POST_LIVE_URL)
        end
      end

      def token?(post)
        (post["cardID"] || post["cardName"])
      end

      def success?(response)
        (response[:response_code] == '0')
      end

      def post_data(post)
        post.collect{|k,v| "#{k}=#{CGI.escape(v.to_s)}" }.join("&")
      end
    end
  end
end
