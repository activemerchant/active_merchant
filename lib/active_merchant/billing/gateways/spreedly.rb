module ActiveMerchant #:nodoc:
  module Billing
    # :doc:
    # Spreedly Gateway integration via version 4 of the Spreedly API, utilizing Spreedly's Payments API.
    #
    # Excerpt from 'Using Spreedly's Payments API: (http:http://spreedly.com/manual/integration-reference/payments-api)
    #
    # 1. Customer picks a plan on your site
    # 2. Your site creates an invoice via the API
    # 3. Your site uses the invoice to show the customer what they will be charged
    # 4. Your site collects payment details from the customer
    # 5. Your site pays the invoice using the customer's payment details
    #
    # The hosting commerce solution is responsible for steps 1 to 4. The Spreedly ActiveMerchant implementation
    # takes care about Step 5, which is the actual transmitting of the invoice and payment of it. 
    # There is no need to implement authorize, since there is no real authorization for the Spreedly API. Same counts
    # for capture. Capture is done automatically by Spreedly depending on the subscription plan the user has chosen.
    #
    # Please consider updating the fixtures, if you want to run the remote tests.
    class SpreedlyGateway < Gateway
      class_attribute :api_version

      self.test_url = 'https://spreedly.com'
      self.live_url = 'https://spreedly.com'
      self.api_version = 'v4'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US', 'DE', 'KW', 'LV', 'LB', 'LT', 'LU', 'AD', 'JO', 
        'ML', 'MV', 'MT', 'MR', 'MX', 'AU', 'AT', 'BD', 'BE', 'MC', 'NE', 'NZ', 'BG', 'CA',
        'BN', 'CZ', 'PL', 'NO', 'CY', 'OM', 'PT', 'EE', 'FI', 'RO', 'DK', 'QA', 'SA', 'SM',
        'EG', 'SK', 'SI', 'SG', 'FR', 'ZA', 'GR', 'LK', 'GI', 'SE', 'VA', 'HK', 'TT', 'TR',
        'UK', 'IN', 'IR', 'HU', 'CH', 'AE', 'IS', 'ID', 'UM', 'IT', 'IL', 'VN']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.spreedly.com/'

      # The name of the gateway
      self.display_name = 'Spreedly'

      def initialize(options = {})
        requires!(options, :api_key, :short_site_name)
        super
      end

      def authorize(money, creditcard, options = {})
        true
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)

        commit('subscribe', money, post)
      end

      def capture(money, authorization, options = {})
        true
      end

      private

      def add_invoice(post, options)
        if options["invoice"]
          post[:invoice_token] = options["invoice"]["token"]
        end
      end

      def add_creditcard(post, creditcard)
        post[:credit_card] = creditcard
      end

      def commit(action, money, parameters)
        response = nil

        if action == 'subscribe'
          payment = create_payment(parameters[:credit_card])
          url = "#{live_url}/api/#{api_version}/#{@options[:short_site_name]}/invoices/#{parameters[:invoice_token]}/pay.xml"
          options = {
            headers: {
              'Content-Type' => 'application/xml'
            },
            basic_auth: {
              username: @options[:api_key],
              password: 'X'
            },
            body: payment[:payment].to_xml(root: 'payment')
          }

          response = HTTParty.put url, options
        end

        response
      end

      def create_payment(credit_card)
        payment = {}
        payment[:account_type] = 'credit-card'
        payment[:credit_card] = {
          number: credit_card.number,
          card_type: credit_card.brand,
          verification_value: credit_card.verification_value,
          month: credit_card.month,
          year: credit_card.year,
          first_name: credit_card.first_name,
          last_name: credit_card.last_name
        }
        { payment: payment }
      end
    end
  end
end

