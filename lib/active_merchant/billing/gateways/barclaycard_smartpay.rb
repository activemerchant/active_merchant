module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BarclaycardSmartpayGateway < Gateway
      self.test_url = 'https://pal-test.barclaycardsmartpay.com/pal/servlet'
      self.live_url = 'https://pal-live.barclaycardsmartpay.com/pal/servlet'

      self.supported_countries = ['AR', 'AT', 'BE', 'BR', 'CA', 'CH', 'CL', 'CN', 'CO', 'DE', 'DK', 'EE', 'ES', 'FI', 'FR', 'GB', 'HK', 'ID', 'IE', 'IL', 'IN', 'IT', 'JP', 'KR', 'LU', 'MX', 'MY', 'NL', 'NO', 'PA', 'PE', 'PH', 'PL', 'PT', 'RU', 'SE', 'SG', 'TH', 'TR', 'TW', 'US', 'VN', 'ZA']
      self.default_currency = 'EUR'
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb, :dankort, :maestro]

      self.homepage_url = 'https://www.barclaycardsmartpay.com/'
      self.display_name = 'Barclaycard Smartpay'

      def initialize(options = {})
        requires!(options, :company, :merchant, :password)
        super
      end

      def purchase(money, creditcard, options = {})
        requires!(options, :order_id)

        MultiResponse.run do |r|
          r.process { authorize(money, creditcard, options) }
          r.process { capture(money, r.authorization, options) }
        end
      end

      def authorize(money, creditcard, options = {})
        requires!(options, :order_id)

        post = payment_request(money, options)
        post[:amount] = amount_hash(money, options[:currency])
        post[:card] = credit_card_hash(creditcard)

        if address = (options[:billing_address] || options[:address])
          post[:billingAddress] = address_hash(address)
        end

        if options[:shipping_address]
          post[:deliveryAddress] = address_hash(options[:shipping_address])
        end

        commit('authorise', post)
      end

      def capture(money, authorization, options = {})
        requires!(options, :order_id)

        post = modification_request(authorization, options)
        post[:modificationAmount] = amount_hash(money, options[:currency])

        commit('capture', post)
      end

      def refund(money, authorization, options = {})
        requires!(options, :order_id)

        post = modification_request(authorization, options)
        post[:modificationAmount] = amount_hash(money, options[:currency])

        commit('refund', post)
      end

      def void(identification, options = {})
        requires!(options, :order_id)

        post = modification_request(identification, options)

        commit('cancel', post)
      end

      def verify(creditcard, options = {})
        authorize(0, creditcard, options)
      end

      def store(creditcard, options = {})
        # ??? require :email and :customer, :order_id?

        post = store_request(options)
        post[:card] = credit_card_hash(creditcard)
        post[:recurring] = {:contract => 'RECURRING'}

        commit('store', post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r(((?:\r\n)?Authorization: Basic )[^\r\n]+(\r\n)?), '\1[FILTERED]').
          gsub(%r((card.number=)\d+), '\1[FILTERED]').
          gsub(%r((card.cvc=)\d+), '\1[FILTERED]')
      end

      private

      def commit(action, post)
        request = post_data(flatten_hash(post))
        raw_response = ssl_post(build_url(action), request, headers)
        response = parse(raw_response)

        Response.new(
          success_from(response),
          message_from(response),
          response,
          test: test?,
          authorization: response['recurringDetailReference'] || response['pspReference']
        )

      rescue ResponseError => e
        case e.response.code
        when '401'
          return Response.new(false, 'Invalid credentials', {}, :test => test?)
        when '422'
          return Response.new(false, 'Unprocessable Entity', {}, :test => test?)
        when '500'
          if e.response.body.split(' ')[0] == 'validation'
            return Response.new(false, e.response.body.split(' ', 3)[2], {}, :test => test?)
          end
        end
        raise
      end

      def flatten_hash(hash, prefix = nil)
        flat_hash = {}
        hash.each_pair do |key, val|
          conc_key = prefix.nil? ? key : "#{prefix}.#{key}"
          if val.is_a?(Hash)
            flat_hash.merge!(flatten_hash(val, conc_key))
          else
            flat_hash[conc_key] = val
          end
        end
        flat_hash
      end

      def headers
        {
          'Content-Type' => 'application/x-www-form-urlencoded; charset=utf-8',
          'Authorization' => 'Basic ' + Base64.encode64("ws@Company.#{@options[:company]}:#{@options[:password]}").strip
        }
      end

      def parse(response)
        Hash[
          response.split('&').map do |x|
            key, val = x.split('=', 2)
            [key.split('.').last, CGI.unescape(val)]
          end
        ]
      end

      def post_data(data)
        data.map do |key, val|
          "#{key}=#{CGI.escape(val.to_s)}"
        end.reduce do |x, y|
          "#{x}&#{y}"
        end
      end

      def message_from(response)
        return response['resultCode'] if response.has_key?('resultCode') # Payment request
        return response['response'] if response['response'] # Modification request
        return response['result'] if response.has_key?('result') # Store/Recurring request
        'Failure' # Negative fallback in case of error
      end

      def success_from(response)
        return true if response.has_key?('authCode')
        return true if response['result'] == 'Success'
        successful_responses = %w([capture-received] [cancel-received] [refund-received])
        successful_responses.include?(response['response'])
      end

      def build_url(action)
        case action
        when 'store'
          "#{test? ? self.test_url : self.live_url}/Recurring/v12/storeToken"
        else
          "#{test? ? self.test_url : self.live_url}/Payment/v12/#{action}"
        end
      end

      def address_hash(address)
        full_address = "#{address[:address1]} #{address[:address2]}" if address

        hash = {}
        hash[:city]              = address[:city] if address[:city]
        hash[:street]            = full_address.split(/\s+/).keep_if { |x| x !~ /\d/ }.join(' ')
        hash[:houseNumberOrName] = full_address.split(/\s+/).keep_if { |x| x =~ /\d/ }.join(' ')
        hash[:postalCode]        = address[:zip] if address[:zip]
        hash[:stateOrProvince]   = address[:state] if address[:state]
        hash[:country]           = address[:country] if address[:country]
        hash
      end

      def amount_hash(money, currency)
        hash = {}
        hash[:currency] = currency || currency(money)
        hash[:value]    = amount(money) if money
        hash
      end

      def credit_card_hash(creditcard)
        hash = {}
        hash[:cvc]         = creditcard.verification_value if creditcard.verification_value
        hash[:expiryMonth] = format(creditcard.month, :two_digits) if creditcard.month
        hash[:expiryYear]  = format(creditcard.year, :four_digits) if creditcard.year
        hash[:holderName]  = creditcard.name if creditcard.name
        hash[:number]      = creditcard.number if creditcard.number
        hash
      end

      def modification_request(reference, options)
        hash = {}
        hash[:merchantAccount]    = @options[:merchant]
        hash[:originalReference]  = reference if reference
        hash.keep_if { |_, v| v }
      end

      def payment_request(money, options)
        hash = {}
        hash[:merchantAccount]  = @options[:merchant]
        hash[:reference]        = options[:order_id] if options[:order_id]
        hash[:shopperEmail]     = options[:email] if options[:email]
        hash[:shopperIP]        = options[:ip] if options[:ip]
        hash[:shopperReference] = options[:customer] if options[:customer]
        hash.keep_if { |_, v| v }
      end

      def store_request(options)
        hash = {}
        hash[:merchantAccount]  = @options[:merchant]
        hash[:shopperEmail]     = options[:email] if options[:email]
        hash[:shopperReference] = options[:customer] if options[:customer]
        hash.keep_if { |_, v| v }
      end
    end
  end
end
