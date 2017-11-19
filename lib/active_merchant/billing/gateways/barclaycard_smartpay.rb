module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BarclaycardSmartpayGateway < Gateway
      self.test_url = 'https://pal-test.barclaycardsmartpay.com/pal/servlet'
      self.live_url = 'https://pal-live.barclaycardsmartpay.com/pal/servlet'

      self.supported_countries = ['AL', 'AD', 'AM', 'AT', 'AZ', 'BY', 'BE', 'BA', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR', 'GE', 'DE', 'GR', 'HU', 'IS', 'IE', 'IT', 'KZ', 'LV', 'LI', 'LT', 'LU', 'MK', 'MT', 'MD', 'MC', 'ME', 'NL', 'NO', 'PL', 'PT', 'RO', 'RU', 'SM', 'RS', 'SK', 'SI', 'ES', 'SE', 'CH', 'TR', 'UA', 'GB', 'VA']
      self.default_currency = 'EUR'
      self.currencies_with_three_decimal_places = %w(BHD KWD OMR RSD TND)
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
        post[:billingAddress] = billing_address_hash(options) if options[:billing_address]
        post[:deliveryAddress] = shipping_address_hash(options) if options[:shipping_address]
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

      def credit(money, creditcard, options = {})
        post = payment_request(money, options)
        post[:amount] = amount_hash(money, options[:currency])
        post[:card] = credit_card_hash(creditcard)
        post[:dateOfBirth] = options[:date_of_birth] if options[:date_of_birth]
        post[:entityType]  = options[:entity_type] if options[:entity_type]
        post[:nationality] = options[:nationality] if options[:nationality]
        post[:shopperName] = options[:shopper_name] if options[:shopper_name]

        commit('refundWithData', post)
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

      # Smartpay may return AVS codes not covered by standard AVSResult codes.
      # Smartpay's descriptions noted below.
      AVS_MAPPING = {
        '0'  => 'R',  # Unknown
        '1'  => 'A',	# Address matches, postal code doesn't
        '2'  => 'N',	# Neither postal code nor address match
        '3'  => 'R',	# AVS unavailable
        '4'  => 'E',	# AVS not supported for this card type
        '5'  => 'U',	# No AVS data provided
        '6'  => 'Z',	# Postal code matches, address doesn't match
        '7'  => 'D',	# Both postal code and address match
        '8'  => 'U',	# Address not checked, postal code unknown
        '9'  => 'B',	# Address matches, postal code unknown
        '10' => 'N',	# Address doesn't match, postal code unknown
        '11' => 'U',	# Postal code not checked, address unknown
        '12' => 'B',	# Address matches, postal code not checked
        '13' => 'U',	# Address doesn't match, postal code not checked
        '14' => 'P',	# Postal code matches, address unknown
        '15' => 'P',	# Postal code matches, address not checked
        '16' => 'N',	# Postal code doesn't match, address unknown
        '17' => 'U',  # Postal code doesn't match, address not checked
        '18' => 'I'	  # Neither postal code nor address were checked
      }

      def commit(action, post)
        request = post_data(flatten_hash(post))
        raw_response = ssl_post(build_url(action), request, headers)
        response = parse(raw_response)

        Response.new(
          success_from(response),
          message_from(response),
          response,
          test: test?,
          avs_result: AVSResult.new(:code => parse_avs_code(response)),
          authorization: response['recurringDetailReference'] || authorization_from(post, response)
        )

      rescue ResponseError => e
        case e.response.code
        when '401'
          return Response.new(false, 'Invalid credentials', {}, :test => test?)
        when '403'
          return Response.new(false, 'Not allowed', {}, :test => test?)
        when '422'
          return Response.new(false, 'Unprocessable Entity', {}, :test => test?)
        when '500'
          if e.response.body.split(' ')[0] == 'validation'
            return Response.new(false, e.response.body.split(' ', 3)[2], {}, :test => test?)
          end
        end
        raise
      end

      def authorization_from(parameters, response)
        authorization = [parameters[:originalReference], response['pspReference']].compact

        return nil if authorization.empty?
        return authorization.join("#")
      end

      def parse_avs_code(response)
        AVS_MAPPING[response["avsResult"][0..1].strip] if response["avsResult"]
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
          'Authorization' => 'Basic ' + Base64.strict_encode64("ws@Company.#{@options[:company]}:#{@options[:password]}").strip
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
        return true if response['resultCode'] == 'Received'
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

      def billing_address_hash(options)
        address = options[:address] || options[:billing_address] if options[:address] || options[:billing_address]
        street = options[:street] || parse_street(address)
        house = options[:house_number] || parse_house_number(address)

        create_address_hash(address, house, street)
      end

      def shipping_address_hash(options)
        address = options[:shipping_address]
        street = options[:shipping_street] || parse_street(address)
        house = options[:shipping_house_number] || parse_house_number(address)

        create_address_hash(address, house, street)
      end

      def parse_street(address)
        address_to_parse = "#{address[:address1]} #{address[:address2]}"
        street = address[:street] || address_to_parse.split(/\s+/).keep_if { |x| x !~ /\d/ }.join(' ')
        street.empty? ? "Not Provided" : street
      end

      def parse_house_number(address)
        address_to_parse = "#{address[:address1]} #{address[:address2]}"
        house = address[:houseNumberOrName] || address_to_parse.split(/\s+/).keep_if { |x| x =~ /\d/ }.join(' ')
        house.empty? ? "Not Provided" : house
      end

      def create_address_hash(address, house, street)
        hash = {}
        hash[:houseNumberOrName] = house
        hash[:street]            = street
        hash[:city]              = address[:city] if address[:city]
        hash[:stateOrProvince]   = address[:state] if address[:state]
        hash[:postalCode]        = address[:zip] if address[:zip]
        hash[:country]           = address[:country] if address[:country]
        hash
      end

      def amount_hash(money, currency)
        currency = currency || currency(money)
        hash = {}
        hash[:currency] = currency
        hash[:value]    = localized_amount(money, currency) if money
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
        hash[:originalReference]  = psp_reference_from(reference)
        hash.keep_if { |_, v| v }
      end

      def psp_reference_from(authorization)
        authorization.nil? ? nil : authorization.split("#").first
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
