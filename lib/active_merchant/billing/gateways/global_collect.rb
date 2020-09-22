module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class GlobalCollectGateway < Gateway
      self.display_name = 'GlobalCollect'
      self.homepage_url = 'http://www.globalcollect.com/'

      self.test_url = 'https://eu.sandbox.api-ingenico.com'
      self.live_url = 'https://api.globalcollect.com'

      self.supported_countries = %w[AD AE AG AI AL AM AO AR AS AT AU AW AX AZ BA BB BD BE BF BG BH BI BJ BL BM BN BO BQ BR BS BT BW BY BZ CA CC CD CF CH CI CK CL CM CN CO CR CU CV CW CX CY CZ DE DJ DK DM DO DZ EC EE EG ER ES ET FI FJ FK FM FO FR GA GB GD GE GF GH GI GL GM GN GP GQ GR GS GT GU GW GY HK HN HR HT HU ID IE IL IM IN IS IT JM JO JP KE KG KH KI KM KN KR KW KY KZ LA LB LC LI LK LR LS LT LU LV MA MC MD ME MF MG MH MK MM MN MO MP MQ MR MS MT MU MV MW MX MY MZ NA NC NE NG NI NL NO NP NR NU NZ OM PA PE PF PG PH PL PN PS PT PW QA RE RO RS RU RW SA SB SC SE SG SH SI SJ SK SL SM SN SR ST SV SZ TC TD TG TH TJ TL TM TN TO TR TT TV TW TZ UA UG US UY UZ VC VE VG VI VN WF WS ZA ZM ZW]
      self.default_currency = 'USD'
      self.money_format = :cents
      self.supported_cardtypes = %i[visa master american_express discover naranja cabal]

      def initialize(options={})
        requires!(options, :merchant_id, :api_key_id, :secret_api_key)
        super
      end

      def purchase(money, payment, options={})
        MultiResponse.run do |r|
          r.process { authorize(money, payment, options) }
          r.process { capture(money, r.authorization, options) } if should_request_capture?(r, options[:requires_approval])
        end
      end

      def authorize(money, payment, options={})
        post = nestable_hash
        add_order(post, money, options)
        add_payment(post, payment, options)
        add_customer_data(post, options, payment)
        add_address(post, payment, options)
        add_creator_info(post, options)
        add_fraud_fields(post, options)
        commit(:authorize, post)
      end

      def capture(money, authorization, options={})
        post = nestable_hash
        add_order(post, money, options, capture: true)
        add_customer_data(post, options)
        add_creator_info(post, options)
        commit(:capture, post, authorization)
      end

      def refund(money, authorization, options={})
        post = nestable_hash
        add_amount(post, money, options)
        add_refund_customer_data(post, options)
        add_creator_info(post, options)
        commit(:refund, post, authorization)
      end

      def void(authorization, options={})
        post = nestable_hash
        add_creator_info(post, options)
        commit(:void, post, authorization)
      end

      def verify(payment, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, payment, options) }
          r.process { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: )[^\\]*)i, '\1[FILTERED]').
          gsub(%r(("cardNumber\\+":\\+")\d+), '\1[FILTERED]').
          gsub(%r(("cvv\\+":\\+")\d+), '\1[FILTERED]')
      end

      private

      BRAND_MAP = {
        'visa' => '1',
        'american_express' => '2',
        'master' => '3',
        'discover' => '128',
        'jcb' => '125',
        'diners_club' => '132'
      }

      def add_order(post, money, options, capture: false)
        if capture
          post['amount'] = amount(money)
        else
          add_amount(post['order'], money, options)
        end
        post['order']['references'] = {
          'merchantReference' => options[:order_id],
          'descriptor' => options[:description] # Max 256 chars
        }
        post['order']['references']['invoiceData'] = {
          'invoiceNumber' => options[:invoice]
        }
        add_airline_data(post, options) if options[:airline_data]
        add_number_of_installments(post, options) if options[:number_of_installments]
      end

      def add_airline_data(post, options)
        airline_data = {}

        flight_date = options[:airline_data][:flight_date]
        passenger_name = options[:airline_data][:passenger_name]
        code = options[:airline_data][:code]
        name = options[:airline_data][:name]

        airline_data['flightDate'] = flight_date if flight_date
        airline_data['passengerName'] = passenger_name if passenger_name
        airline_data['code'] = code if code
        airline_data['name'] = name if name

        flight_legs = []
        options[:airline_data][:flight_legs]&.each do |fl|
          leg = {}
          leg['arrivalAirport'] = fl[:arrival_airport] if fl[:arrival_airport]
          leg['originAirport'] = fl[:origin_airport] if fl[:origin_airport]
          leg['date'] = fl[:date] if fl[:date]
          leg['number'] = fl[:number] if fl[:number]
          leg['carrierCode'] = fl[:carrier_code] if fl[:carrier_code]
          leg['airlineClass'] = fl[:carrier_code] if fl[:airline_class]
          flight_legs << leg
        end
        airline_data['flightLegs'] = flight_legs
        post['order']['additionalInput']['airlineData'] = airline_data
      end

      def add_creator_info(post, options)
        post['sdkIdentifier'] = options[:sdk_identifier] if options[:sdk_identifier]
        post['sdkCreator'] = options[:sdk_creator] if options[:sdk_creator]
        post['integrator'] = options[:integrator] if options[:integrator]
        post['shoppingCartExtension'] = {}
        post['shoppingCartExtension']['creator'] = options[:creator] if options[:creator]
        post['shoppingCartExtension']['name'] = options[:name] if options[:name]
        post['shoppingCartExtension']['version'] = options[:version] if options[:version]
        post['shoppingCartExtension']['extensionID'] = options[:extension_ID] if options[:extension_ID]
      end

      def add_amount(post, money, options={})
        post['amountOfMoney'] = {
          'amount' => amount(money),
          'currencyCode' => options[:currency] || currency(money)
        }
      end

      def add_payment(post, payment, options)
        year  = format(payment.year, :two_digits)
        month = format(payment.month, :two_digits)
        expirydate = "#{month}#{year}"
        pre_authorization = options[:pre_authorization] ? 'PRE_AUTHORIZATION' : 'FINAL_AUTHORIZATION'

        post['cardPaymentMethodSpecificInput'] = {
          'paymentProductId' => BRAND_MAP[payment.brand],
          'skipAuthentication' => 'true', # refers to 3DSecure
          'skipFraudService' => 'true',
          'authorizationMode' => pre_authorization
        }
        post['cardPaymentMethodSpecificInput']['requiresApproval'] = options[:requires_approval] unless options[:requires_approval].nil?

        post['cardPaymentMethodSpecificInput']['card'] = {
          'cvv' => payment.verification_value,
          'cardNumber' => payment.number,
          'expiryDate' => expirydate,
          'cardholderName' => payment.name
        }
      end

      def add_customer_data(post, options, payment = nil)
        if payment
          post['order']['customer']['personalInformation']['name']['firstName'] = payment.first_name[0..14] if payment.first_name
          post['order']['customer']['personalInformation']['name']['surname'] = payment.last_name[0..69] if payment.last_name
        end
        post['order']['customer']['merchantCustomerId'] = options[:customer] if options[:customer]
        post['order']['customer']['companyInformation']['name'] = options[:company] if options[:company]
        post['order']['customer']['contactDetails']['emailAddress'] = options[:email] if options[:email]
        if address = options[:billing_address] || options[:address]
          post['order']['customer']['contactDetails']['phoneNumber'] = address[:phone] if address[:phone]
        end
      end

      def add_refund_customer_data(post, options)
        if address = options[:billing_address] || options[:address]
          post['customer']['address'] = {
            'countryCode' => address[:country]
          }
          post['customer']['contactDetails']['emailAddress'] = options[:email] if options[:email]
          if address = options[:billing_address] || options[:address]
            post['customer']['contactDetails']['phoneNumber'] = address[:phone] if address[:phone]
          end
        end
      end

      def add_address(post, creditcard, options)
        shipping_address = options[:shipping_address]
        if billing_address = options[:billing_address] || options[:address]
          post['order']['customer']['billingAddress'] = {
            'street' => billing_address[:address1],
            'additionalInfo' => billing_address[:address2],
            'zip' => billing_address[:zip],
            'city' => billing_address[:city],
            'state' => billing_address[:state],
            'countryCode' => billing_address[:country]
          }
        end
        if shipping_address
          post['order']['customer']['shippingAddress'] = {
            'street' => shipping_address[:address1],
            'additionalInfo' => shipping_address[:address2],
            'zip' => shipping_address[:zip],
            'city' => shipping_address[:city],
            'state' => shipping_address[:state],
            'countryCode' => shipping_address[:country]
          }
          post['order']['customer']['shippingAddress']['name'] = {
            'firstName' => shipping_address[:firstname],
            'surname' => shipping_address[:lastname]
          }
        end
      end

      def add_fraud_fields(post, options)
        fraud_fields = {}
        fraud_fields.merge!(options[:fraud_fields]) if options[:fraud_fields]
        fraud_fields[:customerIpAddress] = options[:ip] if options[:ip]

        post['fraudFields'] = fraud_fields unless fraud_fields.empty?
      end

      def add_number_of_installments(post, options)
        post['order']['additionalInput']['numberOfInstallments'] = options[:number_of_installments] if options[:number_of_installments]
      end

      def parse(body)
        JSON.parse(body)
      end

      def url(action, authorization)
        (test? ? test_url : live_url) + uri(action, authorization)
      end

      def uri(action, authorization)
        uri = "/v1/#{@options[:merchant_id]}/"
        case action
        when :authorize
          uri + 'payments'
        when :capture
          uri + "payments/#{authorization}/approve"
        when :refund
          uri + "payments/#{authorization}/refund"
        when :void
          uri + "payments/#{authorization}/cancel"
        end
      end

      def commit(action, post, authorization = nil)
        begin
          raw_response = ssl_post(url(action, authorization), post.to_json, headers(action, post, authorization))
          response = parse(raw_response)
        rescue ResponseError => e
          response = parse(e.response.body) if e.response.code.to_i >= 400
        rescue JSON::ParserError
          response = json_error(raw_response)
        end

        succeeded = success_from(response)
        Response.new(
          succeeded,
          message_from(succeeded, response),
          response,
          authorization: authorization_from(succeeded, response),
          error_code: error_code_from(succeeded, response),
          test: test?
        )
      end

      def json_error(raw_response)
        {
          'error_message' => 'Invalid response received from the Ingenico ePayments (formerly GlobalCollect) API.  Please contact Ingenico ePayments if you continue to receive this message.' \
            "  (The raw response returned by the API was #{raw_response.inspect})",
          'status' => 'REJECTED'
        }
      end

      def headers(action, post, authorization = nil)
        {
          'Content-Type' => content_type,
          'Authorization' => auth_digest(action, post, authorization),
          'Date' => date
        }
      end

      def auth_digest(action, post, authorization = nil)
        data = <<~EOS
          POST
          #{content_type}
          #{date}
          #{uri(action, authorization)}
        EOS
        digest = OpenSSL::Digest.new('sha256')
        key = @options[:secret_api_key]
        "GCS v1HMAC:#{@options[:api_key_id]}:#{Base64.strict_encode64(OpenSSL::HMAC.digest(digest, key, data))}"
      end

      def date
        @date ||= Time.now.strftime('%a, %d %b %Y %H:%M:%S %Z') # Must be same in digest and HTTP header
      end

      def content_type
        'application/json'
      end

      def success_from(response)
        !response['errorId'] && response['status'] != 'REJECTED'
      end

      def message_from(succeeded, response)
        return 'Succeeded' if succeeded

        if errors = response['errors']
          errors.first.try(:[], 'message')
        elsif response['error_message']
          response['error_message']
        elsif response['status']
          'Status: ' + response['status']
        else
          'No message available'
        end
      end

      def authorization_from(succeeded, response)
        if succeeded
          response['id'] || response['payment']['id'] || response['paymentResult']['payment']['id']
        elsif response['errorId']
          response['errorId']
        else
          'GATEWAY ERROR'
        end
      end

      def error_code_from(succeeded, response)
        return if succeeded

        if errors = response['errors']
          errors.first.try(:[], 'code')
        elsif status = response.try(:[], 'statusOutput').try(:[], 'statusCode')
          status.to_s
        else
          'No error code available'
        end
      end

      def nestable_hash
        Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }
      end

      # Capture hasn't already been requested,
      # and
      # `requires_approval` is not false
      def should_request_capture?(response, requires_approval)
        !capture_requested?(response) && requires_approval != false
      end

      def capture_requested?(response)
        response.params.try(:[], 'payment').try(:[], 'status') == 'CAPTURE_REQUESTED'
      end
    end
  end
end
