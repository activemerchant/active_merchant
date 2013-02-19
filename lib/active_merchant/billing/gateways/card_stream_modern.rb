require 'pry'
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CardStreamModernGateway < Gateway
      self.test_url = self.live_url = 'https://gateway.cardstream.com/direct/'
      self.money_format = :cents
      self.default_currency = 'GBP'
      self.supported_countries = ['GB']
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club, :discover, :jcb, :maestro, :solo, :switch]
      self.homepage_url = 'http://www.cardstream.com/'
      self.display_name = 'CardStream'

      def initialize(options = {})
        requires!(options, :login)
        super
      end

      def authorize(money, creditcard, options = {})
        post = {}
        add_amount(post, money, options)
        add_invoice(post, creditcard, money, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)

        commit('PREAUTH', money, post)
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_amount(post, money, options)
        add_invoice(post, creditcard, money, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)
        commit('SALE', money, post)
      end

      def capture(money, authorization, options = {})
        post = {}
        add_pair(post, :xref, authorization)
        add_amount(post, money, options)
        commit('SALE', money, post)
      end

      def void(money, authorization, options = {})
        post = {}
        add_pair(post, :xref, authorization)
        add_amount(post, money, options)
        commit('REFUND', money, post)
      end

      private

      def add_amount(post, money, options)
        add_pair(post, :amount, amount(money), :required => true)
        add_pair(post, :currencyCode, options[:currency] || self.default_currency)
      end

      def add_customer_data(post, options)
        address = options[:billing_address] || options[:address]
        add_pair(post, :customerPostCode, address[:zip])
        add_pair(post, :customerEmail, options[:email])
        add_pair(post, :customerPhone, options[:phone])
      end

      def add_address(post, creditcard, options)
        address = options[:billing_address] || options[:address]

        return if address.nil?

        add_pair(post, :customerAddress, address[:address1] + " " + (address[:address2].nil? ? "" : address[:address2]) ) 
        add_pair(post, :customerPostCode, address[:zip])
      end

      def add_invoice(post, credit_card, money, options)
        add_pair(post, :transactionUnique, options[:order_id], :required => true)
        add_pair(post, :orderRef, options[:description] || options[:order_id], :required => true)
        if [ 'american_express', 'diners_club' ].include?(card_brand(credit_card).to_s)
          add_pair(post, :item1Quantity,  1)
          add_pair(post, :item1Description,  (options[:description] || options[:order_id]).slice(0, 15))
          add_pair(post, :item1GrossValue, amount(money))
        end
      end

      def add_creditcard(post, credit_card)
        add_pair(post, :customerName, credit_card.name, :required => true)
        add_pair(post, :cardNumber, credit_card.number, :required => true)

        add_pair(post, :cardExpiryMonth, format(credit_card.month, :two_digits), :required => true)
        add_pair(post, :cardExpiryYear, format(credit_card.year, :two_digits), :required => true)

        if requires_start_date_or_issue_number?(credit_card)
          add_pair(post, :cardStartMonth, format(credit_card.start_month, :two_digits))
          add_pair(post, :cardStartYear, format(credit_card.start_year, :two_digits))

          add_pair(post, :cardIssueNumber, credit_card.issue_number)
        end

        add_pair(post, :cardCVV, credit_card.verification_value)
      end

      def parse(body)
        result = {}
        decoded = URI::decode_www_form(body)
        decoded.each do |pair|
          result[pair[0].to_sym] = pair[1]
        end
        result
      end

      def commit(action, money, parameters)
        response = parse( ssl_post(self.live_url, post_data(action, parameters)) )
        # binding.pry
        Response.new(response[:responseCode] == "0",
          response[:responseCode] == "0" ? "APPROVED" : response[:responseMessage], 
          response,
          :test => test?,
          :authorization => response[:xref],
          :avs_result => {
            :street_match => response[:addressCheck],
            :postal_match => response[:postcodeCheck],
          },
          :cvv_result => response[:cv2Check]
        )
      end

      def post_data(action, parameters = {})
        parameters.update(
          :merchantID => @options[:login],
          :action => action,
          :type => '1', #Ecommerce
          :countryCode => self.supported_countries[0]
        )
        parameters.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end

      def add_pair(post, key, value, options = {})
        post[key] = value if !value.blank? || options[:required]
      end
    end
  end
end

