module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class NetbanxGateway < Gateway
      # Netbanx is the new REST based API for Optimal Payments / Paysafe
      self.test_url = 'https://api.test.netbanx.com/'
      self.live_url = 'https://api.netbanx.com/'

      self.supported_countries = ['CA', 'US', 'GB']
      self.default_currency = 'CAD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.money_format = :cents

      self.homepage_url = 'https://processing.paysafe.com/'
      self.display_name = 'Netbanx by PaySafe'

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        requires!(options, :account_number, :api_key)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_settle_with_auth(post)
        add_payment(post, payment)

        commit(:post, 'auths', post)
      end

      def authorize(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)

        commit(:post, 'auths', post)
      end

      def capture(money, authorization, options={})
        post = {}
        add_invoice(post, money, options)

        commit(:post, "auths/#{authorization}/settlements", post)
      end

      def refund(money, authorization, options={})
        post = {}
        add_invoice(post, money, options)

        commit(:post, "settlements/#{authorization}/refunds", post)
      end

      def void(authorization, options={})
        post = {}
        add_order_id(post, options)

        commit(:post, "auths/#{authorization}/voidauths", post)
      end

      def verify(credit_card, options={})
        post = {}
        add_payment(post, credit_card)
        add_order_id(post, options)

        commit(:post, 'verifications', post)
      end

      # note: when passing options[:customer] we only attempt to add the
      #       card to the profile_id passed as the options[:customer]
      def store(credit_card, options={})
        # locale can only be one of en_US, fr_CA, en_GB
        requires!(options, :locale)
        post = {}
        add_credit_card(post, credit_card, options)
        add_customer_data(post, options)

        commit(:post, 'customervault/v1/profiles', post)
      end

      def unstore(identification, options = {})
        customer_id, card_id = identification.split('|')

        if card_id.nil?
          # deleting the profile
          commit(:delete, "customervault/v1/profiles/#{CGI.escape(customer_id)}", nil)
        else
          # deleting the card from the profile
          commit(:delete, "customervault/v1/profiles/#{CGI.escape(customer_id)}/cards/#{CGI.escape(card_id)}", nil)
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r(("card\\?":{\\?"cardNum\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r(("cvv\\?":\\?")\d+), '\1[FILTERED]')
      end

      private

      def add_settle_with_auth(post)
        post[:settleWithAuth] = true
      end

      def add_customer_data(post, options)
        post[:merchantCustomerId] = (options[:merchant_customer_id] || SecureRandom.uuid)
        post[:locale] = options[:locale]
        # if options[:billing_address]
        #   post[:address]  = map_address(options[:billing_address])
        # end
      end

      def add_credit_card(post, credit_card, options = {})
        post[:card] ||= {}
        post[:card][:cardNum]    = credit_card.number
        post[:card][:holderName] = credit_card.name
        post[:card][:cvv]        = credit_card.verification_value
        post[:card][:cardExpiry] = expdate(credit_card)
        if options[:billing_address]
          post[:card][:billingAddress]  = map_address(options[:billing_address])
        end
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currencyCode] = options[:currency] if options[:currency]
        add_order_id(post, options)

        if options[:billing_address]
          post[:billingDetails]  = map_address(options[:billing_address])
        end

      end

      def add_payment(post, credit_card_or_reference, options = {})
        post[:card] ||= {}
        if credit_card_or_reference.is_a?(String)
          post[:card][:paymentToken] = credit_card_or_reference
        else
          post[:card][:cardNum]    = credit_card_or_reference.number
          post[:card][:cvv]        = credit_card_or_reference.verification_value
          post[:card][:cardExpiry] = expdate(credit_card_or_reference)
        end
      end

      def expdate(credit_card)
        year  = format(credit_card.year, :four_digits)
        month = format(credit_card.month, :two_digits)

        # returns a hash (necessary in the card JSON object)
        { :month => month, :year => year }
      end

      def add_order_id(post, options)
        post[:merchantRefNum] = (options[:order_id] || SecureRandom.uuid)
      end

      def map_address(address)
        return {} if address.nil?
        country = Country.find(address[:country]) if address[:country]
        mapped = {
          :street  => address[:address1],
          :city    => address[:city],
          :zip     => address[:zip],
        }
        mapped.merge!({:country => country.code(:alpha2).value}) unless country.blank?

        mapped
      end

      def parse(body)
        body.blank? ? {} : JSON.parse(body)
      end

      def commit(method, uri, parameters)
        params = parameters.to_json unless parameters.nil?
        response = begin
          parse(ssl_request(method, get_url(uri), params, headers))
        rescue ResponseError => e
          return Response.new(false, 'Invalid Login') if(e.response.code == '401')
          parse(e.response.body)
        end

        success = success_from(response)
        Response.new(
          success,
          message_from(success, response),
          response,
          :test => test?,
          :authorization => authorization_from(success, get_url(uri), method, response)
        )
      end

      def get_url(uri)
        url = (test? ? test_url : live_url)
        if uri =~ /^customervault/
          "#{url}#{uri}"
        else
          "#{url}cardpayments/v1/accounts/#{@options[:account_number]}/#{uri}"
        end
      end

      def success_from(response)
        response.blank? || !response.key?('error')
      end

      def message_from(success, response)
        success ? 'OK' : (response['error']['message'] || "Unknown error - please contact Netbanx-Paysafe")
      end

      def authorization_from(success, url, method, response)
        if success && response.present? && url.match(/cardpayments\/v1\/accounts\/.*\//)
          response['id']
        elsif method == :post && url.match(/customervault\/.*\//)
          # auth for tokenised customer vault is returned as
          # customer_profile_id|card_id|payment_method_token
          #
          # customer_profile_id is the uuid that identifies the customer
          # card_id is the uuid that identifies the card
          # payment_method_token is the token that needs to be used when
          #                      calling purchase with a token
          #
          # both id's are used to unstore, the payment token is only used for
          # purchase transactions
          [response['id'], response['cards'].first['id'], response['cards'].first['paymentToken']].join("|")
        end
      end

      # Builds the auth and U-A headers for the request
      def headers
        {
          'Accept'        => 'application/json',
          'Content-type'  => 'application/json',
          'Authorization' => "Basic #{Base64.strict_encode64(@options[:api_key].to_s).strip}",
          'User-Agent'    => "Netbanx-Paysafe v1.0/ActiveMerchant #{ActiveMerchant::VERSION}"
        }
      end
    end
  end
end
