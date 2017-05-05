require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class FirstGivingGateway < Gateway
      self.test_url = 'http://usapisandbox.fgdev.net'
      self.live_url = 'https://api.firstgiving.com'

      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = 'http://www.firstgiving.com/'
      self.default_currency = 'USD'
      self.display_name = 'FirstGiving'

      def initialize(options = {})
        requires!(options, :application_key, :security_token, :charity_id)
        super
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, options)
        add_customer_data(post, options)
        add_donation_data(post, money, options)
        commit('/donation/creditcard', post)
      end

      def refund(money, identifier, options = {})
        get = {}
        get[:transactionId] = identifier
        get[:tranType]     = 'REFUNDREQUEST'
        commit("/transaction/refundrequest?" + encode(get))
      end

      private

      def add_donation_data(post, money, options)
        post[:amount] = amount(money)
        post[:charityId] = @options[:charity_id]
        post[:description] = (options[:description] || "Purchase")
        post[:currencyCode] = (options[:currency] || currency(money))
      end

      def add_customer_data(post, options)
        post[:billToEmail] = (options[:email] || "activemerchant@example.com")
        post[:remoteAddr]  = (options[:ip] || "127.0.0.1")
      end

      def add_address(post, options)
        if(billing_address = (options[:billing_address] || options[:address]))
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
        post[:ccType]              = creditcard_brand(creditcard.brand)
        post[:ccExpDateMonth]      = creditcard.month
        post[:ccExpDateYear]       = creditcard.year
        post[:ccCardValidationNum] = creditcard.verification_value
      end

      def parse(body)
        response = {}

        xml = Nokogiri::XML(body)
        element = xml.xpath("//firstGivingDonationApi/firstGivingResponse").first

        element.attributes.each do |name, attribute|
          response[name] = attribute.content
        end
        element.children.each do |child|
          next if child.text?
          response[child.name] = child.text
        end

        response
      end

      def commit(action, post=nil)
        url = (test? ? self.test_url : self.live_url) + action

        begin
          if post
            response = parse(ssl_post(url, post_data(post), headers))
          else
            response = parse(ssl_get(url, headers))
          end
        rescue ResponseError => e
          response = parse(e.response.body)
        end

        Response.new(
          (response["acknowledgement"] == "Success"),
          (response["friendlyErrorMessage"] || response["verboseErrorMessage"] || response["acknowledgement"]),
          response,
          authorization: response["transactionId"],
          test: test?,
        )
      end

      def post_data(post)
        post.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end

      def encode(hash)
        hash.collect{|(k,v)| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}"}.join('&')
      end

      def creditcard_brand(brand)
        case brand
        when "visa" then "VI"
        when "master" then "MC"
        when "discover" then "DI"
        when "american_express" then "AX"
        else
          raise "Unhandled credit card brand #{brand}"
        end
      end

      def headers
        {
          "User-Agent"        => "ActiveMerchantBindings/#{ActiveMerchant::VERSION}",
          "JG_APPLICATIONKEY" => "#{@options[:application_key]}",
          "JG_SECURITYTOKEN"  => "#{@options[:security_token]}"
        }
      end
    end
  end
end

