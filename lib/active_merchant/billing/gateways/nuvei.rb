# coding: utf-8
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class NuveiGateway < Gateway
      self.test_url = 'https://ppp-test.safecharge.com/ppp/api/v1/'
      self.live_url = 'https://secure.safecharge.com/ppp/api/v1/'

      # TODO: Is there any limitation here with Nuvei?
      self.supported_countries = %w(AT AU BE BG BR CH CY CZ DE DK EE ES FI FR GB GI GR HK HU IE IS IT LI LT LU LV MC MT MX NL NO PL PT RO SE SG SK SI US)
      self.default_currency = 'USD'
      
      # TODO: Is there any limitation here with Nuvei?
      self.currencies_without_fractions = %w(CVE DJF GNF IDR JPY KMF KRW PYG RWF UGX VND VUV XAF XOF XPF)

      # TODO: What should this value be?
      self.currencies_with_three_decimal_places = %w(BHD IQD JOD KWD LYD OMR TND)

      # TODO: Is there any limitation here with Nuvei?
      self.supported_cardtypes = %i[visa master american_express diners_club jcb dankort maestro discover elo naranja cabal unionpay]

      self.homepage_url = 'https://www.nuvei.com/'
      self.display_name = 'Nuvei'

      def initialize(options = {})
        requires!(options, :merchant_id, :merchant_site_id, :secret)
        @merchant_id, @merchant_site_id, @secret = options.values_at(:merchant_id, :merchant_site_id, :secret)
        super
      end

      def purchase(money, payment, options = {})
        post = init_post
        add_session(post)
        add_payment(post, money, payment, options)
        add_device_details(post, options)
        add_billing_address(post, options)

        commit('payment', post, options)
      end

      def authorize(money, payment, options = {})
        post = init_post
        add_session(post)
        add_payment(post, money, payment, options)
        add_device_details(post, options)

        commit('initPayment', post, options)
      end

      def add_session(post)
        session = open_session
        post[:sessionToken] = session['sessionToken']
      end

      def add_device_details(post, options)
        post[:deviceDetails] = {
          :ipAddress => options[:ip]
        }
      end

      def add_billing_address(post, options)
        post[:billingAddress] = {
          :email => options[:email],
          # Country must be ISO 3166-1-alpha-2 code.
          # See: www.iso.org/iso/country_codes/iso_3166_code_lists/english_country_names_and_code_elements.htm
          :country => options.dig(:billing_address, :country)
        }
      end
      
      def capture(money, authorization, options = {})
        post = init_post(options)

        # Example response:
        # {
        #   "sessionToken" => "",
        #   "merchantId" => "${mId}",
        #   "merchantSiteId" => "${mSiteId}",
        #   "clientRequestId" => "${clientRequestId}",
        #   "amount" => "${amount}",
        #   "currency" => "${currency}",
        #   "userTokenId" => "230811147",
        #   "clientUniqueId" => "12345",
        #   "paymentOption" => {
	#     "card" => {
	#       "cardNumber" => "4111111111111111",
	#       "cardHolderName" => "John Smith",
	#       "expirationMonth" => "12",
	#       "expirationYear" => "2022",
	#       "CVV" => "217"
	#     }
        #   },
        #   "deviceDetails" => {
	#     "ipAddress" => "127.0.0.1"
        #   },
        #   "billingAddress" => {
	#     "email" => "john.smith@email.com",
	#     "country" => "US"
        #   },
        #   "timeStamp" => "${timeStamp}",
        #   "checksum" => "${hash}"
        # }

        commit('capture', post, options)
      end

      def refund(money, authorization, options = {})
        post = init_post(options)
        commit('refund', post, options)
      end
      
      def credit(money, payment, options = {})
        action = 'refundWithData'
        post = init_post(options)
        commit(action, post, options)
      end

      def void(authorization, options = {})
        post = init_post(options)
        commit(endpoint, post, options)
      end

      def verify(credit_card, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(0, credit_card, options) }
          options[:idempotency_key] = nil
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      private

      # TODO: What is this for Nuvei?
      AVS_MAPPING = {
        '0'  => 'R',  # Unknown
        '1'  => 'A',  # Address matches, postal code doesn't
        '2'  => 'N',  # Neither postal code nor address match
        '3'  => 'R',  # AVS unavailable
        '4'  => 'E',  # AVS not supported for this card type
        '5'  => 'U',  # No AVS data provided
        '6'  => 'Z',  # Postal code matches, address doesn't match
        '7'  => 'D',  # Both postal code and address match
        '8'  => 'U',  # Address not checked, postal code unknown
        '9'  => 'B',  # Address matches, postal code unknown
        '10' => 'N',  # Address doesn't match, postal code unknown
        '11' => 'U',  # Postal code not checked, address unknown
        '12' => 'B',  # Address matches, postal code not checked
        '13' => 'U',  # Address doesn't match, postal code not checked
        '14' => 'P',  # Postal code matches, address unknown
        '15' => 'P',  # Postal code matches, address not checked
        '16' => 'N',  # Postal code doesn't match, address unknown
        '17' => 'U',  # Postal code doesn't match, address not checked
        '18' => 'I',  # Neither postal code nor address were checked
        '19' => 'L',  # Name and postal code matches.
        '20' => 'V',  # Name, address and postal code matches.
        '21' => 'O',  # Name and address matches.
        '22' => 'K',  # Name matches.
        '23' => 'F',  # Postal code matches, name doesn't match.
        '24' => 'H',  # Both postal code and address matches, name doesn't match.
        '25' => 'T',  # Address matches, name doesn't match.
        '26' => 'N'   # Neither postal code, address nor name matches.
      }

      # TODO: What is this for Nuvei?
      CVC_MAPPING = {
        '0' => 'P', # Unknown
        '1' => 'M', # Matches
        '2' => 'N', # Does not match
        '3' => 'P', # Not checked
        '4' => 'S', # No CVC/CVV provided, but was required
        '5' => 'U', # Issuer not certifed by CVC/CVV
        '6' => 'P'  # No CVC/CVV provided
      }

      def open_session
        timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
        checksum = get_session_checksum(timestamp)
        parameters = {
          :merchantId => @merchant_id,
          :merchantSiteId => @merchant_site_id,
          :timeStamp => timestamp,
          :checksum => checksum
        }
        
        begin
          raw_response = ssl_post(url('getSessionToken'), post_data(parameters), request_headers(options))
          response = parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response = parse(raw_response)
        end
      end

      def failed_session_creation()
        Response.new(
          success,
          message_from(success, response),
          response,
          authorization: authorization_from(success, action, response),
          test: test?,
          avs_result: AVSResult.new(code: avs_code_from(response)),
          cvv_result: CVVResult.new(cvv_result_from(response))
        )
      end

      def get_payment_checksum (client_request_id, amount, currency, timestamp)
        base = @merchant_id + @merchant_site_id + client_request_id + amount.to_s + currency + timestamp + @secret
        checksum = Digest::SHA256.hexdigest base
        checksum
      end
      
      def get_session_checksum (timestamp)
        base = @merchant_id + @merchant_site_id + timestamp + @secret
        checksum = Digest::SHA256.hexdigest base
        checksum
      end

      def add_payment (post, money, payment, options)
        timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
        post[:clientRequestId] = options[:order_id].to_s
        post[:timeStamp] = timestamp
        # TODO: Is this correct?
        post[:amount] = money
        # TODO: Is this correct?
        post[:currency] = options[:currency] || self.default_currency
        post[:paymentOption] = {
          :card => {
            :cardNumber => payment.number,
            :cardHolderName => payment.name,
            :expirationMonth => format(payment.month, :two_digits),
            :expirationYear => format(payment.year, :four_digits_year),
            :CVV => payment.verification_value,
          }
        }
        post[:checksum] = get_payment_checksum(post[:clientRequestId], post[:amount], post[:currency], timestamp)
      end
      
      def add_merchant_options(post)
        post[:merchantId] = @merchant_id
        post[:merchantSiteId] = @merchant_site_id
      end

      def parse(body)
        return {} if body.blank?
        JSON.parse(body)
      end

      def commit(action, parameters, options)
        begin
          raw_response = ssl_post(url(action), post_data(parameters), request_headers(options))
          response = parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response = parse(raw_response)
        end

        success = success_from(action, response, options)
        Response.new(
          success,
          message_from(success, response),
          response,
          authorization: authorization_from(success, action, response),
          test: test?,
          avs_result: AVSResult.new(code: avs_code_from(response)),
          cvv_result: CVVResult.new(cvv_result_from(response))
        )
      end
      
      def avs_code_from(response)
        AVS_MAPPING[response['paymentOption']['card']['avsCode']] if response.dig('paymentOption', 'card', 'avsCode')
      end

      def cvv_result_from(response)
        AVS_MAPPING[response['paymentOption']['card']['cvv2Reply']] if response.dig('paymentOption', 'card', 'cvv2Reply')
      end

      def url(action)
        if test?
          "#{test_url}#{action}.do"
        else
          "#{live_url}#{action}.do"
        end
      end

      def basic_auth
        Base64.strict_encode64("#{@username}:#{@password}")
      end

      def request_headers(options)
        headers = {
          'Content-Type' => 'application/json',
          'Authorization' => "Basic #{basic_auth}"
        }
        headers['Idempotency-Key'] = options[:idempotency_key] if options[:idempotency_key]
        headers
      end

      def success_from(action, response, options)
        case action.to_s
        when 'initPayment'
          response['status'] == "SUCCESS" and response['transactionStatus'] == "APPROVED"
        when 'payment'
          response['status'] == "SUCCESS" and response['transactionStatus'] == "APPROVED"
        else
          false
        end
        
      end

      def message_from(success, response)
        if success
          'Succeeded'
        elsif !response['reason'].empty?
          response['reason']
        elsif !response['gwErrorReason'].empty?
          response['gwErrorReason']
        else
          'Failed'
        end
      end

      def authorize_message_from(response)
        #TODO: update for nuvei
        if response['refusalReason'] && response['additionalData'] && response['additionalData']['refusalReasonRaw']
          "#{response['refusalReason']} | #{response['additionalData']['refusalReasonRaw']}"
        else
          response['refusalReason'] || response['resultCode'] || response['message'] || response['result']
        end
      end

      def authorization_from(success, action, response)
        # Successful ayment requests give us an authCode back.
        # For all other requests, we will just use the internalRequestId that Nuvei provides
        
        if !success
          nil
        elsif action == 'payment' and response['status'] == 'SUCCESS'
          response['authCode'].to_s
        else 
          response["internalRequestId"].to_s
        end
      end

      def init_post(options = {})
        post = {}
        add_merchant_options(post)
        post
      end

      def post_data(parameters = {})
        JSON.generate(parameters)
      end

    end
  end
end
