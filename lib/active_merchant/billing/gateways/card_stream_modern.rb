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
        requires!(options, :login, :password)
        super
      end

      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)

        commit('PREAUTH', money, post)
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)

        commit('SALE', money, post)
      end

      def capture(money, authorization, options = {})
        commit('SALE', money, post)
      end

      def void(authorization, options = {})
        commit('REFUND', post)
      end

      private

      def add_customer_data(post, options)
        add_pair(post, :customerPostCode, options[:])
        add_pair(post, :customerEmail, options[:email])
        add_pair(post, :customerPhone, options[:phone])
      end

      def add_address(post, creditcard, options)
        add_pair(post, :customerAddress, options[:])
      end

      def add_invoice(post, options)
        add_pair(post, :transactionUnique, options[:order_id], :required => true)
        add_pair(post, :orderRef, options[:description] || options[:order_id], :required => true)

        if [ 'american_express', 'diners_club' ].include?(card_brand(credit_card).to_s)
          add_pair(post, :item1Quantity,  1)
          add_pair(post, :item1Description,  (options[:description] || options[:order_id]).slice(0, 15))
          add_pair(post, :item1GrossValue, amount(money))
        end
      end

      def add_creditcard(post, creditcard)
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
      end

      def commit(action, money, parameters)
        response = parse( ssl_post(url_for(action), post_data(action, parameters)) )

        Response.new(response["responseCode"] == 0, message_from(response), response,
          :test => test?,
          :authorization => response["xref"],
          :avs_result => {
            :street_match => response["addressCheck"],
            :postal_match => response["postcodeCheck"],
          },
          :cvv_result => response["cv2Check"]
        )
      end

      def message_from(response)
        response[:responseMessage]
      end

      def post_data(action, parameters = {})
        parameters.update(
          :merchantID => @options[:login],
          :action => action,
          :type => '1', #Ecommerce
          :currencyCode => self.default_currency,
          :countryCode => self.supported_countries[0]
        )
      end
    end
  end
end

