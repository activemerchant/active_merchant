module ActiveMerchant # :nodoc:
  module Billing # :nodoc:
    class PaysafeGateway < Gateway
      version 'v1'

      self.test_url = 'https://api.test.paysafe.com'
      self.live_url = 'https://api.paysafe.com'

      self.supported_countries = %w(AL AT BE BA BG CA HR CY CZ DK EE FI FR DE GR HU IS IE IT LV LI LT LU MT ME NL MK NO PL PT RO RS SK SI ES SE CH TR GB US)
      self.supported_cardtypes = %i[visa master american_express discover]

      self.homepage_url = 'https://www.paysafe.com/'
      self.display_name = 'Paysafe'

      def initialize(options = {})
        requires!(options, :username, :password, :account_id)
        super
      end

      def purchase(money, payment, options = {})
        post = {}
        add_auth_purchase_params(post, money, payment, options)
        add_split_pay_details(post, options)
        post[:settleWithAuth] = true

        commit(:post, 'auths', post, options)
      end

      def authorize(money, payment, options = {})
        post = {}
        add_auth_purchase_params(post, money, payment, options)

        commit(:post, 'auths', post, options)
      end

      def capture(money, authorization, options = {})
        post = {}
        add_invoice(post, money, options)

        commit(:post, "auths/#{authorization}/settlements", post, options)
      end

      def refund(money, authorization, options = {})
        post = {}
        add_invoice(post, money, options)

        commit(:post, "settlements/#{authorization}/refunds", post, options)
      end

      def void(authorization, options = {})
        post = {}
        money = options[:amount]
        add_invoice(post, money, options)

        commit(:post, "auths/#{authorization}/voidauths", post, options)
      end

      def credit(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_customer_data(post, payment, options) unless payment.is_a?(String)
        add_merchant_details(post, options)
        add_billing_address(post, options)

        commit(:post, 'standalonecredits', post, options)
      end

      # This is a '$0 auth' done at a specific verification endpoint at the gateway
      def verify(payment, options = {})
        post = {}
        add_payment(post, payment)
        add_billing_address(post, options)
        add_customer_data(post, payment, options) unless payment.is_a?(String)

        commit(:post, 'verifications', post, options)
      end

      def store(payment, options = {})
        post = {}

        if options[:profile_id]
          post[:cardNum] = payment.number
          post[:cardExpiry] = {
            month: payment.month,
            year: payment.year
          }
          post[:accountId] = options[:account_id] if options[:account_id]
          post[:nickName] = options[:nickname] if options[:nickname]
          post[:holderName] = payment.name
          post[:billingAddressId] = options[:billing_address_id] if options[:billing_address_id]
          post[:defaultCardIndicator] = normalize(options[:default_card_indicator]) if options[:default_card_indicator]
        else
          add_payment(post, payment)
          add_address_for_vaulting(post, options)
          add_profile_data(post, payment, options)
          add_store_data(post, payment, options)
        end

        endpoint = options[:profile_id] ? "profiles/#{options[:profile_id]}/cards" : 'profiles'

        commit(:post, endpoint, post, options)
      end

      def unstore(pm_profile_id)
        commit(:delete, "profiles/#{get_id_from_store_auth(pm_profile_id)}", nil, nil)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )[a-zA-Z0-9:_]+), '\1[FILTERED]').
          gsub(%r(("cardNum\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r(("cvv\\?":\\?")\d+), '\1[FILTERED]')
      end

      private

      def add_auth_purchase_params(post, money, payment, options)
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_billing_address(post, options)
        add_merchant_details(post, options)
        add_customer_data(post, payment, options) unless payment.is_a?(String)
        add_three_d_secure(post, payment, options) if options[:three_d_secure]
        add_stored_credential(post, options) if options[:stored_credential]
        add_funding_transaction(post, options)
        add_airline_travel_details(post, options)
        add_cruiseline_travel_details(post, options)
      end

      # Customer data can be included in transactions where the payment method is a credit card
      # but should not be sent when the payment method is a token
      def add_customer_data(post, creditcard, options)
        post[:profile] = {}
        post[:profile][:firstName] = creditcard.first_name
        post[:profile][:lastName] = creditcard.last_name
        post[:profile][:email] = options[:email] if options[:email]
        post[:profile][:merchantCustomerId] = options[:customer_id] if options[:customer_id]
        post[:customerIp] = options[:ip] if options[:ip]
      end

      def add_billing_address(post, options)
        return unless address = options[:billing_address] || options[:address]

        post[:billingDetails] = {}
        post[:billingDetails][:street] = truncate(address[:address1], 50)
        post[:billingDetails][:street2] = truncate(address[:address2], 50)
        post[:billingDetails][:city] = truncate(address[:city], 40)
        post[:billingDetails][:state] = truncate(address[:state], 40)
        post[:billingDetails][:country] = address[:country]
        post[:billingDetails][:zip] = truncate(address[:zip], 10)
        post[:billingDetails][:phone] = truncate(address[:phone], 40)
      end

      # The add_address_for_vaulting method is applicable to the store method, as the APIs address
      # object is formatted differently from the standard transaction billing address
      def add_address_for_vaulting(post, options)
        return unless address = options[:billing_address] || options[:address]

        post[:card][:billingAddress] = {}
        post[:card][:billingAddress][:street] = truncate(address[:address1], 50)
        post[:card][:billingAddress][:street2] = truncate(address[:address2], 50)
        post[:card][:billingAddress][:city] = truncate(address[:city], 40)
        post[:card][:billingAddress][:zip] = truncate(address[:zip], 10)
        post[:card][:billingAddress][:country] = address[:country]
        post[:card][:billingAddress][:state] = truncate(address[:state], 40) if address[:state]
      end

      # This data is specific to creating a profile at the gateway's vault level
      def add_profile_data(post, payment, options)
        post[:firstName] = payment.first_name
        post[:lastName] = payment.last_name
        post[:dateOfBirth] = {}
        post[:dateOfBirth][:year] = options.dig(:date_of_birth, :year)
        post[:dateOfBirth][:month] = options.dig(:date_of_birth, :month)
        post[:dateOfBirth][:day] = options.dig(:date_of_birth, :day)
        post[:email] = options[:email] if options[:email]
        post[:ip] = options[:ip] if options[:ip]

        if options[:phone]
          post[:phone] = options[:phone]
        elsif address = options[:billing_address] || options[:address]
          post[:phone] = address[:phone] if address[:phone]
        end
      end

      def add_store_data(post, payment, options)
        post[:merchantCustomerId] = options[:customer_id] || SecureRandom.hex(12)
        post[:locale] = options[:locale] || 'en_US'
        post[:card][:holderName] = payment.name
      end

      # Paysafe expects minor units so we are not calling amount method on money parameter
      def add_invoice(post, money, options)
        post[:amount] = money
      end

      def add_payment(post, payment)
        if payment.is_a?(String)
          post[:card] = {}
          post[:card][:paymentToken] = get_pm_from_store_auth(payment)
        else
          post[:card] = { cardExpiry: {} }
          post[:card][:cardNum] = payment.number
          post[:card][:cardExpiry][:month] = payment.month
          post[:card][:cardExpiry][:year] = payment.year
          post[:card][:cvv] = payment.verification_value
        end
      end

      def add_merchant_details(post, options)
        return unless options[:merchant_descriptor]

        post[:merchantDescriptor] = {}
        post[:merchantDescriptor][:dynamicDescriptor] = options[:merchant_descriptor][:dynamic_descriptor] if options[:merchant_descriptor][:dynamic_descriptor]
        post[:merchantDescriptor][:phone] = options[:merchant_descriptor][:phone] if options[:merchant_descriptor][:phone]
      end

      def add_three_d_secure(post, payment, options)
        three_d_secure = options[:three_d_secure]

        post[:authentication] = {}
        post[:authentication][:eci] = three_d_secure[:eci]
        post[:authentication][:cavv] = three_d_secure[:cavv]
        post[:authentication][:xid] = three_d_secure[:xid] if three_d_secure[:xid]
        post[:authentication][:threeDSecureVersion] = three_d_secure[:version]
        post[:authentication][:directoryServerTransactionId] = three_d_secure[:ds_transaction_id] unless payment.is_a?(String) || !mastercard?(payment)
      end

      def add_cruiseline_travel_details(post, options)
        return unless cruiseline_data = options[:cruiseline_travel_details]

        post[:cruiselineTravelDetails] = {}
        post[:cruiselineTravelDetails][:cruiseShipName] = cruiseline_data[:cruise_ship_name] if cruiseline_data[:cruise_ship_name]
        post[:cruiselineTravelDetails][:passengerName] = cruiseline_data[:passenger_name] if cruiseline_data[:passenger_name]
        post[:cruiselineTravelDetails][:departureDate] = cruiseline_data[:departure_date] if cruiseline_data[:departure_date]
        post[:cruiselineTravelDetails][:returnDate] = cruiseline_data[:return_date] if cruiseline_data[:return_date]
        post[:cruiselineTravelDetails][:country] = cruiseline_data[:country] if cruiseline_data[:country]
        post[:cruiselineTravelDetails][:state] = cruiseline_data[:state] if cruiseline_data[:state]
        post[:cruiselineTravelDetails][:originCity] = cruiseline_data[:origin_city] if cruiseline_data[:origin_city]
        post[:cruiselineTravelDetails][:roomRate] = cruiseline_data[:room_rate] if cruiseline_data[:room_rate]
        post[:cruiselineTravelDetails][:travelPackageApplication] = cruiseline_data[:travel_package_application] if cruiseline_data[:travel_package_application]

        add_cruiseline_ticket_details(post, options)
        add_cruiseline_passenger_details(post, options)
        add_cruisline_trip_leg_details(post, options)
      end

      def add_cruiseline_ticket_details(post, options)
        return unless ticket = options[:cruiseline_travel_details][:ticket]

        post[:cruiselineTravelDetails][:ticket] = {}
        post[:cruiselineTravelDetails][:ticket][:ticketNumber] = ticket[:ticket_number] if ticket[:ticket_number]
        post[:cruiselineTravelDetails][:ticket][:isRestrictedTicket] = ticket[:is_restricted_ticket].to_s.present?
      end

      def add_cruiseline_passenger_details(post, options)
        return unless passengers = options[:cruiseline_travel_details][:passengers]

        passengers_hash = {}
        passengers.each.with_index(1) do |passenger, i|
          my_passenger = "passenger#{i}".to_sym
          details = add_passenger_details(my_passenger, passenger[1])

          passengers_hash[my_passenger] = details
        end
        post[:cruiselineTravelDetails][:passengers] = passengers_hash
      end

      def add_passenger_details(obj, passenger)
        details = {}

        details[:ticketNumber] = passenger[:ticket_number] if passenger[:ticket_number]
        details[:firstName] = passenger[:first_name] if passenger[:first_name]
        details[:lastName] = passenger[:last_name] if passenger[:last_name]
        details[:phoneNumber] = passenger[:phone_number] if passenger[:phone_number]
        details[:passengerCode] = passenger[:passenger_code] if passenger[:passenger_code]
        details[:gender] = passenger[:gender] if passenger[:gender]

        details
      end

      def add_cruisline_trip_leg_details(post, options)
        return unless trip_legs = options[:cruiseline_travel_details][:trip_legs]

        trip_legs_hash = {}
        trip_legs.each.with_index(1) do |leg, i|
          my_leg = "leg#{i}".to_sym
          details = add_cruiseline_leg_details(my_leg, leg[1])

          trip_legs_hash[my_leg] = details
        end
        post[:cruiselineTravelDetails][:tripLegs] = trip_legs_hash
      end

      def add_cruiseline_leg_details(obj, leg)
        details = {}

        details[:serviceClass] = leg[:service_class] if leg[:service_class]
        details[:departureCity] = leg[:departure_city] if leg[:departure_city]
        details[:destinationCity] = leg[:destination_city] if leg[:destination_city]
        details[:fare] = leg[:fare] if leg[:fare]
        details[:departureDate] = leg[:departure_date] if leg[:departure_date]

        details
      end

      def add_airline_travel_details(post, options)
        return unless airline_data = options[:airline_travel_details]

        post[:airlineTravelDetails] = {}
        post[:airlineTravelDetails][:passengerName] = airline_data[:passenger_name] if airline_data[:passenger_name]
        post[:airlineTravelDetails][:departureDate] = airline_data[:departure_date] if airline_data[:departure_date]
        post[:airlineTravelDetails][:origin] = airline_data[:origin] if airline_data[:origin]
        post[:airlineTravelDetails][:computerizedReservationSystem] = airline_data[:computerized_reservation_system] if airline_data[:computerized_reservation_system]
        post[:airlineTravelDetails][:customerReferenceNumber] = airline_data[:customer_reference_number] if airline_data[:customer_reference_number]

        add_airline_ticket_details(post, options)
        add_airline_travel_agency_details(post, options)
        add_airline_trip_legs(post, options)
      end

      def add_airline_ticket_details(post, options)
        return unless ticket = options[:airline_travel_details][:ticket]

        post[:airlineTravelDetails][:ticket] = {}
        post[:airlineTravelDetails][:ticket][:ticketNumber] = ticket[:ticket_number] if ticket[:ticket_number]
        post[:airlineTravelDetails][:ticket][:isRestrictedTicket] = ticket[:is_restricted_ticket].to_s.present?
        post[:airlineTravelDetails][:ticket][:cityOfTicketIssuing] = ticket[:city_of_ticket_issuing] if ticket[:city_of_ticket_issuing]
        post[:airlineTravelDetails][:ticket][:ticketDeliveryMethod] = ticket[:ticket_delivery_method] if ticket[:ticket_delivery_method]
        post[:airlineTravelDetails][:ticket][:ticketIssueDate] = ticket[:ticket_issue_date] if ticket[:ticket_issue_date]
        post[:airlineTravelDetails][:ticket][:numberOfPax] = ticket[:number_of_pax] if ticket[:number_of_pax]
      end

      def add_airline_travel_agency_details(post, options)
        return unless agency = options[:airline_travel_details][:travel_agency]

        post[:airlineTravelDetails][:travelAgency] = {}
        post[:airlineTravelDetails][:travelAgency][:name] = agency[:name] if agency[:name]
        post[:airlineTravelDetails][:travelAgency][:code] = agency[:code] if agency[:code]
      end

      def add_airline_trip_legs(post, options)
        return unless trip_legs = options[:airline_travel_details][:trip_legs]

        trip_legs_hash = {}
        trip_legs.each.with_index(1) do |leg, i|
          my_leg = "leg#{i}".to_sym
          details = add_airline_leg_details(my_leg, leg[1])

          trip_legs_hash[my_leg] = details
        end
        post[:airlineTravelDetails][:tripLegs] = trip_legs_hash
      end

      def add_airline_leg_details(obj, leg)
        details = {}
        add_flight_details(details, obj, leg)
        details[:serviceClass] = leg[:service_class] if leg[:service_class]
        details[:isStopOverAllowed] = leg[:is_stop_over_allowed].to_s.present?
        details[:destination] = leg[:destination] if leg[:destination]
        details[:fareBasis] = leg[:fare_basis] if leg[:fare_basis]
        details[:departureDate] = leg[:departure_date] if leg[:departure_date]

        details
      end

      def add_flight_details(details, obj, leg)
        details[:flight] = {}
        details[:flight][:carrierCode] = leg[:flight][:carrier_code] if leg[:flight][:carrier_code]
        details[:flight][:flightNumber] = leg[:flight][:flight_number] if leg[:flight][:flight_number]
      end

      def add_split_pay_details(post, options)
        return unless options[:split_pay]

        split_pay = []
        options[:split_pay].each do |pmnt|
          split = {}

          split[:linkedAccount] = pmnt[:linked_account]
          split[:amount] = pmnt[:amount].to_i if pmnt[:amount]
          split[:percent] = pmnt[:percent].to_i if pmnt[:percent]

          split_pay << split
        end
        post[:splitpay] = split_pay
      end

      def add_funding_transaction(post, options)
        return unless options[:funding_transaction]

        post[:fundingTransaction] = {}
        post[:fundingTransaction][:type] = options[:funding_transaction]
        post[:profile] ||= {}
        post[:profile][:merchantCustomerId] = options[:customer_id] || SecureRandom.hex(12)
      end

      def add_stored_credential(post, options)
        return unless options[:stored_credential]

        post[:storedCredential] = {}

        case options[:stored_credential][:initial_transaction]
        when true
          post[:storedCredential][:occurrence] = 'INITIAL'
        when false
          post[:storedCredential][:occurrence] = 'SUBSEQUENT'
        end

        case options[:stored_credential][:reason_type]
        when 'recurring', 'installment'
          post[:storedCredential][:type] = 'RECURRING'
        when 'unscheduled'
          if options[:stored_credential][:initiator] == 'merchant'
            post[:storedCredential][:type] = 'TOPUP'
          elsif options[:stored_credential][:initiator] == 'cardholder'
            post[:storedCredential][:type] = 'ADHOC'
          else
            return
          end
        end

        post[:storedCredential][:initialTransactionId] = options[:stored_credential][:network_transaction_id] if options[:stored_credential][:network_transaction_id]
        post[:storedCredential][:externalInitialTransactionId] = options[:external_initial_transaction_id] if options[:external_initial_transaction_id]
      end

      def mastercard?(payment)
        return false unless payment.respond_to?(:brand)

        payment.brand == 'master'
      end

      def parse(body)
        return {} if body.empty?

        JSON.parse(body)
      end

      def commit(method, action, parameters, options)
        url = url(action)
        raw_response = ssl_request(method, url, post_data(parameters, options), headers)
        response = parse(raw_response)
        success = success_from(response)

        Response.new(
          success,
          message_from(success, response),
          response,
          authorization: authorization_from(action, response),
          avs_result: AVSResult.new(code: response['avsResponse']),
          cvv_result: CVVResult.new(response['cvvVerification']),
          test: test?,
          error_code: success ? nil : error_code_from(response)
        )
      end

      def headers
        {
          'Content-Type' => 'application/json',
          'Authorization' => 'Basic ' + Base64.strict_encode64("#{@options[:username]}:#{@options[:password]}")
        }
      end

      def url(action, options = {})
        base_url = (test? ? test_url : live_url)

        if action.include? 'profiles'
          "#{base_url}/customervault/#{fetch_version}/#{action}"
        else
          "#{base_url}/cardpayments/#{fetch_version}/accounts/#{@options[:account_id]}/#{action}"
        end
      end

      def success_from(response)
        return false if response['status'] == 'FAILED' || response['error']

        true
      end

      def message_from(success, response)
        return response['status'] unless response['error']

        "Error(s)- code:#{response['error']['code']}, message:#{response['error']['message']}"
      end

      def authorization_from(action, response)
        if action == 'profiles'
          pm = response['cards']&.first&.dig('paymentToken')
          "#{pm}|#{response['id']}"
        else
          response['id']
        end
      end

      def get_pm_from_store_auth(authorization)
        authorization.split('|')[0]
      end

      def get_id_from_store_auth(authorization)
        authorization.split('|')[1]
      end

      def post_data(parameters = {}, options = {})
        return unless parameters.present?

        parameters[:merchantRefNum] = options[:merchant_ref_num] || options[:order_id] || SecureRandom.hex(16).to_s

        parameters.to_json
      end

      def error_code_from(response)
        return unless response['error']

        response['error']['code']
      end

      def handle_response(response)
        response.body
      end
    end
  end
end
