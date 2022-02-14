module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class GlobalCollectGateway < Gateway
      class_attribute :preproduction_url

      self.display_name = 'GlobalCollect'
      self.homepage_url = 'http://www.globalcollect.com/'

      self.test_url = 'https://eu.sandbox.api-ingenico.com'
      self.preproduction_url = 'https://world.preprod.api-ingenico.com'
      self.live_url = 'https://world.api-ingenico.com'

      self.supported_countries = %w[AD AE AG AI AL AM AO AR AS AT AU AW AX AZ BA BB BD BE BF BG BH BI BJ BL BM BN BO BQ BR BS BT BW BY BZ CA CC CD CF CH CI CK CL CM CN CO CR CU CV CW CX CY CZ DE DJ DK DM DO DZ EC EE EG ER ES ET FI FJ FK FM FO FR GA GB GD GE GF GH GI GL GM GN GP GQ GR GS GT GU GW GY HK HN HR HT HU ID IE IL IM IN IS IT JM JO JP KE KG KH KI KM KN KR KW KY KZ LA LB LC LI LK LR LS LT LU LV MA MC MD ME MF MG MH MK MM MN MO MP MQ MR MS MT MU MV MW MX MY MZ NA NC NE NG NI NL NO NP NR NU NZ OM PA PE PF PG PH PL PN PS PT PW QA RE RO RS RU RW SA SB SC SE SG SH SI SJ SK SL SM SN SR ST SV SZ TC TD TG TH TJ TL TM TN TO TR TT TV TW TZ UA UG US UY UZ VC VE VG VI VN WF WS ZA ZM ZW]
      self.default_currency = 'USD'
      self.money_format = :cents
      self.supported_cardtypes = %i[visa master american_express discover naranja cabal]

      def initialize(options = {})
        requires!(options, :merchant_id, :api_key_id, :secret_api_key)
        super
      end

      def purchase(money, payment, options = {})
        MultiResponse.run do |r|
          r.process { authorize(money, payment, options) }
          r.process { capture(money, r.authorization, options) } if should_request_capture?(r, options[:requires_approval])
        end
      end

      def authorize(money, payment, options = {})
        post = nestable_hash
        add_order(post, money, options)
        add_payment(post, payment, options)
        add_customer_data(post, options, payment)
        add_address(post, payment, options)
        add_creator_info(post, options)
        add_fraud_fields(post, options)
        add_external_cardholder_authentication_data(post, options)
        commit(:authorize, post, options: options)
      end

      def capture(money, authorization, options = {})
        post = nestable_hash
        add_order(post, money, options, capture: true)
        add_customer_data(post, options)
        add_creator_info(post, options)
        commit(:capture, post, authorization: authorization)
      end

      def refund(money, authorization, options = {})
        post = nestable_hash
        add_amount(post, money, options)
        add_refund_customer_data(post, options)
        add_creator_info(post, options)
        commit(:refund, post, authorization: authorization)
      end

      def void(authorization, options = {})
        post = nestable_hash
        add_creator_info(post, options)
        commit(:void, post, authorization: authorization)
      end

      def verify(payment, options = {})
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
        'diners_club' => '132',
        'cabal' => '135',
        'naranja' => '136'
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
        add_airline_data(post, options)
        add_lodging_data(post, options)
        add_number_of_installments(post, options) if options[:number_of_installments]
      end

      def add_airline_data(post, options)
        return unless airline_options = options[:airline_data]

        airline_data = {}

        airline_data['flightDate'] = airline_options[:flight_date] if airline_options[:flight_date]
        airline_data['passengerName'] = airline_options[:passenger_name] if airline_options[:passenger_name]
        airline_data['code'] = airline_options[:code] if airline_options[:code]
        airline_data['name'] = airline_options[:name] if airline_options[:name]
        airline_data['invoiceNumber'] = options[:airline_data][:invoice_number] if options[:airline_data][:invoice_number]
        airline_data['isETicket'] = options[:airline_data][:is_eticket] if options[:airline_data][:is_eticket]
        airline_data['isRestrictedTicket'] = options[:airline_data][:is_restricted_ticket] if options[:airline_data][:is_restricted_ticket]
        airline_data['isThirdParty'] = options[:airline_data][:is_third_party] if options[:airline_data][:is_third_party]
        airline_data['issueDate'] = options[:airline_data][:issue_date] if options[:airline_data][:issue_date]
        airline_data['merchantCustomerId'] = options[:airline_data][:merchant_customer_id] if options[:airline_data][:merchant_customer_id]
        airline_data['flightLegs'] = add_flight_legs(airline_options)
        airline_data['passengers'] = add_passengers(airline_options)

        post['order']['additionalInput']['airlineData'] = airline_data
      end

      def add_flight_legs(airline_options)
        flight_legs = []
        airline_options[:flight_legs]&.each do |fl|
          leg = {}
          leg['airlineClass'] = fl[:airline_class] if fl[:airline_class]
          leg['arrivalAirport'] = fl[:arrival_airport] if fl[:arrival_airport]
          leg['arrivalTime'] = fl[:arrival_time] if fl[:arrival_time]
          leg['carrierCode'] = fl[:carrier_code] if fl[:carrier_code]
          leg['conjunctionTicket'] = fl[:conjunction_ticket] if fl[:conjunction_ticket]
          leg['couponNumber'] = fl[:coupon_number] if fl[:coupon_number]
          leg['date'] = fl[:date] if fl[:date]
          leg['departureTime'] = fl[:departure_time] if fl[:departure_time]
          leg['endorsementOrRestriction'] = fl[:endorsement_or_restriction] if fl[:endorsement_or_restriction]
          leg['exchangeTicket'] = fl[:exchange_ticket] if fl[:exchange_ticket]
          leg['fare'] = fl[:fare] if fl[:fare]
          leg['fareBasis'] = fl[:fare_basis] if fl[:fare_basis]
          leg['fee'] = fl[:fee] if fl[:fee]
          leg['flightNumber'] = fl[:flight_number] if fl[:flight_number]
          leg['number'] = fl[:number] if fl[:number]
          leg['originAirport'] = fl[:origin_airport] if fl[:origin_airport]
          leg['passengerClass'] = fl[:passenger_class] if fl[:passenger_class]
          leg['stopoverCode'] = fl[:stopover_code] if fl[:stopover_code]
          leg['taxes'] = fl[:taxes] if fl[:taxes]
          flight_legs << leg
        end
        flight_legs
      end

      def add_passengers(airline_options)
        passengers = []
        airline_options[:passengers]&.each do |flyer|
          passenger = {}
          passenger['firstName'] = flyer[:first_name] if flyer[:first_name]
          passenger['surname'] = flyer[:surname] if flyer[:surname]
          passenger['surnamePrefix'] = flyer[:surname_prefix] if flyer[:surname_prefix]
          passenger['title'] = flyer[:title] if flyer[:title]
          passengers << passenger
        end
        passengers
      end

      def add_lodging_data(post, options)
        return unless lodging_options = options[:lodging_data]

        lodging_data = {}

        lodging_data['charges'] = add_charges(lodging_options)
        lodging_data['checkInDate'] = lodging_options[:check_in_date] if lodging_options[:check_in_date]
        lodging_data['checkOutDate'] = lodging_options[:check_out_date] if lodging_options[:check_out_date]
        lodging_data['folioNumber'] = lodging_options[:folio_number] if lodging_options[:folio_number]
        lodging_data['isConfirmedReservation'] = lodging_options[:is_confirmed_reservation] if lodging_options[:is_confirmed_reservation]
        lodging_data['isFacilityFireSafetyConform'] = lodging_options[:is_facility_fire_safety_conform] if lodging_options[:is_facility_fire_safety_conform]
        lodging_data['isNoShow'] = lodging_options[:is_no_show] if lodging_options[:is_no_show]
        lodging_data['isPreferenceSmokingRoom'] = lodging_options[:is_preference_smoking_room] if lodging_options[:is_preference_smoking_room]
        lodging_data['numberOfAdults'] = lodging_options[:number_of_adults] if lodging_options[:number_of_adults]
        lodging_data['numberOfNights'] = lodging_options[:number_of_nights] if lodging_options[:number_of_nights]
        lodging_data['numberOfRooms'] = lodging_options[:number_of_rooms] if lodging_options[:number_of_rooms]
        lodging_data['programCode'] = lodging_options[:program_code] if lodging_options[:program_code]
        lodging_data['propertyCustomerServicePhoneNumber'] = lodging_options[:property_customer_service_phone_number] if lodging_options[:property_customer_service_phone_number]
        lodging_data['propertyPhoneNumber'] = lodging_options[:property_phone_number] if lodging_options[:property_phone_number]
        lodging_data['renterName'] = lodging_options[:renter_name] if lodging_options[:renter_name]
        lodging_data['rooms'] = add_rooms(lodging_options)

        post['order']['additionalInput']['lodgingData'] = lodging_data
      end

      def add_charges(lodging_options)
        charges = []
        lodging_options[:charges]&.each do |item|
          charge = {}
          charge['chargeAmount'] = item[:charge_amount] if item[:charge_amount]
          charge['chargeAmountCurrencyCode'] = item[:charge_amount_currency_code] if item[:charge_amount_currency_code]
          charge['chargeType'] = item[:charge_type] if item[:charge_type]
          charges << charge
        end
        charges
      end

      def add_rooms(lodging_options)
        rooms = []
        lodging_options[:rooms]&.each do |item|
          room = {}
          room['dailyRoomRate'] = item[:daily_room_rate] if item[:daily_room_rate]
          room['dailyRoomRateCurrencyCode'] = item[:daily_room_rate_currency_code] if item[:daily_room_rate_currency_code]
          room['dailyRoomTaxAmount'] = item[:daily_room_tax_amount] if item[:daily_room_tax_amount]
          room['dailyRoomTaxAmountCurrencyCode'] = item[:daily_room_tax_amount_currency_code] if item[:daily_room_tax_amount_currency_code]
          room['numberOfNightsAtRoomRate'] = item[:number_of_nights_at_room_rate] if item[:number_of_nights_at_room_rate]
          room['roomLocation'] = item[:room_location] if item[:room_location]
          room['roomNumber'] = item[:room_number] if item[:room_number]
          room['typeOfBed'] = item[:type_of_bed] if item[:type_of_bed]
          room['typeOfRoom'] = item[:type_of_room] if item[:type_of_room]
          rooms << room
        end
        rooms
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

      def add_amount(post, money, options = {})
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
            'street' => truncate(billing_address[:address1], 50),
            'additionalInfo' => truncate(billing_address[:address2], 50),
            'zip' => billing_address[:zip],
            'city' => billing_address[:city],
            'state' => truncate(billing_address[:state], 35),
            'countryCode' => billing_address[:country]
          }
        end
        if shipping_address
          post['order']['customer']['shippingAddress'] = {
            'street' => truncate(shipping_address[:address1], 50),
            'additionalInfo' => truncate(shipping_address[:address2], 50),
            'zip' => shipping_address[:zip],
            'city' => shipping_address[:city],
            'state' => truncate(shipping_address[:state], 35),
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

      def add_external_cardholder_authentication_data(post, options)
        return unless threeds_2_options = options[:three_d_secure]

        authentication_data = {}
        authentication_data[:acsTransactionId] = threeds_2_options[:acs_transaction_id] if threeds_2_options[:acs_transaction_id]
        authentication_data[:cavv] = threeds_2_options[:cavv] if threeds_2_options[:cavv]
        authentication_data[:cavvAlgorithm] = threeds_2_options[:cavv_algorithm] if threeds_2_options[:cavv_algorithm]
        authentication_data[:directoryServerTransactionId] = threeds_2_options[:ds_transaction_id] if threeds_2_options[:ds_transaction_id]
        authentication_data[:eci] = threeds_2_options[:eci] if threeds_2_options[:eci]
        authentication_data[:threeDSecureVersion] = threeds_2_options[:version] if threeds_2_options[:version]
        authentication_data[:validationResult] = threeds_2_options[:authentication_response_status] if threeds_2_options[:authentication_response_status]
        authentication_data[:xid] = threeds_2_options[:xid] if threeds_2_options[:xid]

        post['cardPaymentMethodSpecificInput'] ||= {}
        post['cardPaymentMethodSpecificInput']['threeDSecure'] ||= {}
        post['cardPaymentMethodSpecificInput']['threeDSecure']['externalCardholderAuthenticationData'] = authentication_data unless authentication_data.empty?
      end

      def add_number_of_installments(post, options)
        post['order']['additionalInput']['numberOfInstallments'] = options[:number_of_installments] if options[:number_of_installments]
      end

      def parse(body)
        JSON.parse(body)
      end

      def url(action, authorization)
        return preproduction_url + uri(action, authorization) if @options[:url_override].to_s == 'preproduction'

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

      def idempotency_key_for_signature(options)
        "x-gcs-idempotence-key:#{options[:idempotency_key]}" if options[:idempotency_key]
      end

      def commit(action, post, authorization: nil, options: {})
        begin
          raw_response = ssl_post(url(action, authorization), post.to_json, headers(action, post, authorization, options))
          response = parse(raw_response)
        rescue ResponseError => e
          response = parse(e.response.body) if e.response.code.to_i >= 400
        rescue JSON::ParserError
          response = json_error(raw_response)
        end

        succeeded = success_from(action, response)
        Response.new(
          succeeded,
          message_from(succeeded, response),
          response,
          authorization: authorization_from(response),
          error_code: error_code_from(succeeded, response),
          test: test?
        )
      end

      def json_error(raw_response)
        {
          'error_message' => 'Invalid response received from the Ingenico ePayments (formerly GlobalCollect) API.  Please contact Ingenico ePayments if you continue to receive this message.' \
            "  (The raw response returned by the API was #{raw_response.inspect})"
        }
      end

      def headers(action, post, authorization = nil, options = {})
        headers = {
          'Content-Type' => content_type,
          'Authorization' => auth_digest(action, post, authorization, options),
          'Date' => date
        }

        headers['X-GCS-Idempotence-Key'] = options[:idempotency_key] if options[:idempotency_key]
        headers
      end

      def auth_digest(action, post, authorization = nil, options = {})
        data = <<~REQUEST
          POST
          #{content_type}
          #{date}
          #{idempotency_key_for_signature(options)}
          #{uri(action, authorization)}
        REQUEST
        data = data.each_line.reject { |line| line.strip == '' }.join
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

      def success_from(action, response)
        return false if response['errorId'] || response['error_message']

        case action
        when :authorize
          response.dig('payment', 'statusOutput', 'isAuthorized')
        when :capture
          capture_status = response.dig('status') || response.dig('payment', 'status')
          %w(CAPTURED CAPTURE_REQUESTED).include?(capture_status)
        when :void
          void_response_id =
            response.dig('cardPaymentMethodSpecificOutput', 'voidResponseId') || response.dig('mobilePaymentMethodSpecificOutput', 'voidResponseId')

          if %w(00 0 8 11).include?(void_response_id)
          else
            response.dig('payment', 'status') == 'CANCELLED'
          end
        when :refund
          refund_status = response.dig('status') || response.dig('payment', 'status')
          %w(REFUNDED REFUND_REQUESTED).include?(refund_status)
        else
          response['status'] != 'REJECTED'
        end
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

      def authorization_from(response)
        response.dig('id') || response.dig('payment', 'id') || response.dig('paymentResult', 'payment', 'id')
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
