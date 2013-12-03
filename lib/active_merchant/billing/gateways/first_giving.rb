require 'rexml/document'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class FirstGivingGateway < Gateway

      class FirstGivingPostData < PostData
        # Fields that will be sent even if they are blank
        self.required_fields = [ :action, :amount ]
      end

      self.test_url = 'http://usapisandbox.fgdev.net'
      self.live_url = 'https://api.firstgiving.com'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.firstgiving.com/'

      # The default currency
      self.default_currency = 'USD'

      # The name of the gateway
      self.display_name = 'First Giving'

      module Actions
        DONATION_CREDITCARD = '/donation/creditcard'
        DONATION_VERIFY     = '/verify'
      end

      def initialize(options = {})
        requires!(options, :application_key, :security_token)
        super(options)
      end

      def purchase(money, creditcard, options = {})
        post = FirstGivingPostData.new
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, options)
        add_customer_data(post, options)
        add_donation_data(post, money, options)
        commit(Actions::DONATION_CREDITCARD, money, post)
      end

      def authorize(money, creditcard, options = {})
        raise NotImplementedError
      end

      def capture(money, authorization, options = {})
        raise NotImplementedError
      end

      private

      def add_donation_data(post, money, options)
        post[:amount] = amount(money)
        post[:charityId] = options[:charity_id]
        post[:description] = options[:description]
        post[:currencyCode] = options[:currency]
      end

      def add_customer_data(post, options)
        post[:billToEmail] = options[:email]
        post[:remoteAddr]  = options[:ip]
      end

      def add_address(post, options)
        if billing_address = options[:billing_address] || options[:address]
          post[:billToAddressLine1]  = billing_address[:address1]
          post[:billToCity]          = billing_address[:city]
          post[:billToState]         = billing_address[:state]
          post[:billToZip]           = billing_address[:zip]
          post[:billToCountry]       = billing_address[:country]
        end
      end

      def add_invoice(post, options)
        post[:orderId] = options[:order_id]
      end

      def add_creditcard(post, creditcard)
        post[:billToFirstName]     = creditcard.first_name
        post[:billToLastName]      = creditcard.last_name
        post[:ccNumber]            = creditcard.number
        post[:ccType]              = creditcard_type(creditcard.brand)
        post[:ccExpDateMonth]      = creditcard.month
        post[:ccExpDateYear]       = creditcard.year
        post[:ccCardValidationNum] = creditcard.verification_value
      end

      def parse(body)
        response = {
          :message  => "Global Error Receipt",
          :complete => false,
          :response => "CAPTURED"
        }
        xml = REXML::Document.new(body)

        fg_response = xml.elements['firstGivingDonationApi/firstGivingResponse']

        if fg_response.attributes['acknowledgement'] == "Failed"
          response[:response] = 'ERROR'
          response[:message]  = fg_response.attributes['friendlyErrorMessage']
        else
          response[:authorization] = fg_response.elements['transactionId'].first.value
          response[:complete]      = true
          response[:message]       = 'Success'
        end

        response
      end

      def commit(action, money, post)
        begin
          url = test? ? self.test_url : self.live_url
          url += action
          response = parse( ssl_post(url, post_data(post, money), headers) )
        rescue ResponseError => e
          response = parse(e.response.body)
        end

        Response.new(response[:response] == 'CAPTURED', response[:message], response,
                 :test => test?,
                 :authorization => response[:authorization])

      end

      def post_data(post, money)
        return post.to_post_data
      end

      def creditcard_type(brand)
        case brand
        when "visa" then "VI"
        when "master" then "MC"
        when "discover" then "DI"
        when "american_express" then "AX"
        else
          raise Exception
        end
      end

      def headers
        {
          "Content-Type"      => "application/json",
          "User-Agent"        => "FirstGiving Ruby SDK",
          "JG_APPLICATIONKEY" => "#{@options[:application_key]}",
          "JG_SECURITYTOKEN"  => "#{@options[:security_token]}"
        }
      end

    end
  end
end

