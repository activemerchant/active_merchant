require "square"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SquareGateway < Gateway
      self.test_url = "https://connect.squareupsandbox.com/v2"
      self.live_url = "https://connect.squareup.com/v2"

      self.supported_countries = %w[US CA GB AU JP]
      self.default_currency = "USD"
      self.supported_cardtypes = %i[visa master american_express discover jcb union_pay]
      self.money_format = :cents

      self.homepage_url = "https://squareup.com/"
      self.display_name = "Square Payments Gateway"

      CVC_CODE_TRANSLATOR = {
        "CVV_ACCEPTED" => "M",
        "CVV_REJECTED" => "N",
        "CVV_NOT_CHECKED" => "P"
      }.freeze

      AVS_CODE_TRANSLATOR = {
        "AVS_ACCEPTED" => "P", # 'P' => 'Postal code matches, but street address not verified.'
        "AVS_REJECTED" => "N", # 'N' => 'Street address and postal code do not match.'
        "AVS_NOT_CHECKED" => "I" # 'I' => 'Address not verified.'
      }.freeze

      STANDARD_ERROR_CODE_MAPPING = {
        "BAD_EXPIRATION" => STANDARD_ERROR_CODE[:invalid_expiry_date],
        "INVALID_ACCOUNT" => STANDARD_ERROR_CODE[:config_error],
        "CARDHOLDER_INSUFFICIENT_PERMISSIONS" => STANDARD_ERROR_CODE[:card_declined],
        "INSUFFICIENT_PERMISSIONS" => STANDARD_ERROR_CODE[:config_error],
        "INSUFFICIENT_FUNDS" => STANDARD_ERROR_CODE[:card_declined],
        "INVALID_LOCATION" => STANDARD_ERROR_CODE[:processing_error],
        "TRANSACTION_LIMIT" => STANDARD_ERROR_CODE[:card_declined],
        "CARD_EXPIRED" => STANDARD_ERROR_CODE[:expired_card],
        "CVV_FAILURE" => STANDARD_ERROR_CODE[:incorrect_cvc],
        "ADDRESS_VERIFICATION_FAILURE" => STANDARD_ERROR_CODE[:incorrect_address],
        "VOICE_FAILURE" => STANDARD_ERROR_CODE[:card_declined],
        "PAN_FAILURE" => STANDARD_ERROR_CODE[:incorrect_number],
        "EXPIRATION_FAILURE" => STANDARD_ERROR_CODE[:invalid_expiry_date],
        "INVALID_EXPIRATION" => STANDARD_ERROR_CODE[:invalid_expiry_date],
        "CARD_NOT_SUPPORTED" => STANDARD_ERROR_CODE[:processing_error],
        "INVALID_PIN" => STANDARD_ERROR_CODE[:incorrect_pin],
        "INVALID_POSTAL_CODE" => STANDARD_ERROR_CODE[:incorrect_zip],
        "CHIP_INSERTION_REQUIRED" => STANDARD_ERROR_CODE[:processing_error],
        "ALLOWABLE_PIN_TRIES_EXCEEDED" => STANDARD_ERROR_CODE[:card_declined],
        "MANUALLY_ENTERED_PAYMENT_NOT_SUPPORTED" => STANDARD_ERROR_CODE[:unsupported_feature],
        "PAYMENT_LIMIT_EXCEEDED" => STANDARD_ERROR_CODE[:processing_error],
        "GENERIC_DECLINE" => STANDARD_ERROR_CODE[:card_declined],
        "INVALID_FEES" => STANDARD_ERROR_CODE[:config_error],
        "GIFT_CARD_AVAILABLE_AMOUNT" => STANDARD_ERROR_CODE[:card_declined],
        "BAD_REQUEST" => STANDARD_ERROR_CODE[:processing_error]
      }.freeze

      def initialize(options = {})
        requires!(options, :access_token)
        @access_token = options[:access_token]
        @location_id = options[:location_id]
        super
      end

      def square_client
        @square_client ||= Square::Client.new(
          access_token: @access_token,
          environment: test? ? "sandbox" : "production"
        )
      end

      def purchase(money, payment, options = {})
        post = create_post_for_purchase(money, payment, options)

        add_descriptor(post, options)
        post[:autocomplete] = true

        commit(:payments, :create_payment, { body: post })
      end

      def refund(money, identification, options = {})
        post = { payment_id: identification }

        add_idempotency_key(post, options)
        add_amount(post, money, options)

        post[:reason] = options[:reason] if options[:reason]

        commit(:refunds, :refund_payment, { body: post })
      end

      def store(payment, options = {})
        MultiResponse.run(:first) do |r|
          post = {}

          if !(options[:customer_id])
            add_customer(post, options)
            add_address(post, options, :address)

            r.process { commit(:customers, :create_customer, { body: post }) }
            return r unless r.responses.last.params["customer"]

            options[:customer_id] = r.responses.last.params["customer"]["id"]
          end

          add_address(post, options, :billing_address)

          r.process do
            commit(:customers, :create_customer_card, {
                     customer_id: options[:customer_id],
                     body: {
                       card_nonce: payment,
                       billing_address: post[:billing_address],
                       cardholder_name: options[:cardholder_name]
                     }
                   })
          end
        end
      end

      def delete_customer(identification)
        commit(:customers, :delete_customer, customer_id: identification)
      end

      def delete_customer_card(customer_id, card_id)
        commit(:customers, :delete_customer_card, { customer_id: customer_id, card_id: card_id })
      end
      alias unstore delete_customer_card

      def update_customer(identification, options = {})
        post = {}

        add_customer(post, options)
        add_address(post, options, :address)

        commit(:customers, :update_customer, { customer_id: identification, body: post })
      end

      private

      def add_customer(post, options)
        post[:given_name] = options[:given_name] || options[:billing_address][:name].split(" ")[0]
        post[:family_name] = options[:family_name] || options[:billing_address][:name].split(" ")[1]
        post[:company_name] = options[:company_name] if options[:company_name]
        post[:phone_number] = options[:phone_number] || options[:billing_address][:phone]
        post[:email_address] = options[:email] if options[:email]
        post[:note] = options[:description] if options[:description]
        post[:reference_id] = options[:reference_id] if options[:reference_id]
      end

      def add_address(post, options, addr_key = :billing_address)
        if address = options[addr_key] || options[:address] || options[:billing_address]
          add_address_for(post, address, addr_key)
        end
      end

      def add_address_for(post, address, addr_key)
        addr_key = addr_key.to_sym
        post[addr_key] ||= {} # Or-Equals in case they passed in using Square's key format
        if address[:name]
          post[addr_key][:first_name] = address[:name].split(" ")[0]
          post[addr_key][:last_name] = address[:name].split(" ")[1] if address[:name].split(" ")[1]
        end
        post[addr_key][:address_line_1] = address[:address1] if address[:address1]
        post[addr_key][:address_line_2] = address[:address2] if address[:address2]
        post[addr_key][:address_line_3] = address[:address3] if address[:address3]

        post[addr_key][:locality] = address[:city] if address[:city]
        post[addr_key][:sublocality] = address[:sublocality] if address[:sublocality]
        post[addr_key][:sublocality_2] = address[:sublocality_2] if address[:sublocality_2]
        post[addr_key][:sublocality_3] = address[:sublocality_3] if address[:sublocality_3]

        post[addr_key][:administrative_district_level_1] = address[:state] if address[:state]
        if address[:administrative_district_level_2] # In the US, this is the county.
          post[addr_key][:administrative_district_level_2] = address[:administrative_district_level_2]
        end
        post[addr_key][:postal_code] = address[:zip] if address[:zip]
        post[addr_key][:country] = address[:country] if address[:country]
      end

      def add_idempotency_key(post, options)
        post[:idempotency_key] = options[:order_id] || generate_unique_id
      end

      def add_amount(post, money, options)
        currency = options[:currency] || currency(money)
        post[:amount_money] = {
          amount: localized_amount(money, currency).to_i,
          currency: currency.upcase
        }
      end

      def add_descriptor(post, options)
        return unless options[:descriptor]

        post[:statement_description_identifier] = options[:descriptor]
      end

      def create_post_for_purchase(money, payment, options)
        post = {}

        post[:source_id] = payment
        post[:customer_id] = options[:customer] if options[:customer].present?
        post[:note] = options[:description] if options[:description]
        post[:location_id] = @location_id if @location_id

        add_idempotency_key(post, options)
        add_amount(post, money, options)

        post
      end

      def sdk_request(api_name, method, params = {})
        raw_response = square_client.send(api_name).send(method, **params)
        log(raw_response)

        parse(raw_response)
      end

      def commit(api_name, method, params = {})
        response = sdk_request(api_name, method, params)
        success = success_from(response)

        card = card_from_response(response)

        avs_code = AVS_CODE_TRANSLATOR[card["avs_status"]]
        cvc_code = CVC_CODE_TRANSLATOR[card["cvv_status"]]

        Response.new(
          success,
          message_from(success, response),
          response,
          authorization: authorization_from(success, method, response),
          avs_result: success ? AVSResult.new(code: avs_code) : nil,
          cvv_result: success ? CVVResult.new(cvc_code) : nil,
          error_code: success ? nil : error_code_from(response),
          test: test?
        )
      end

      def card_from_response(response)
        return {} unless response["payment"]

        response["payment"]["card_details"] || {}
      end

      def success_from(response)
        !response.key?("errors")
      end

      def message_from(success, response)
        success ? "Transaction approved" : response["errors"][0]["detail"]
      end

      def authorization_from(success, method, response)
        return nil unless success

        case method
        when :create_customer, :update_customer
          response["customer"]["id"]
        when :create_customer_card
          response["card"]["id"]
        when :create_payment
          response["payment"]["id"]
        when :refund_payment
          response["refund"]["id"]
        when :delete_customer, :delete_customer_card
          {}
        end
      end

      def error_code_from(response)
        return nil unless response["errors"]

        code = response["errors"][0]["code"]
        STANDARD_ERROR_CODE_MAPPING[code] || STANDARD_ERROR_CODE[:processing_error]
      end

      def parse(raw_response)
        raw_response.body.to_h.with_indifferent_access
      end

      def log(raw_response)
        return unless wiredump_device

        scrubbed_response = scrub(raw_response.to_yaml)

        wiredump_device.write(scrubbed_response)
      end

      def scrub(transcript)
        transcript
          .gsub(%r((Authorization: Bearer )\w+), '\1[FILTERED]')
          .gsub(%r(("card_nonce\\?":\\?")[^"]*)i, '\1[FILTERED]')
          .gsub(%r(("number\\?":\\?")[^"]*)i, '\1[FILTERED]')
          .gsub(%r(("verification_value\\?":\\?")[^"]*)i, '\1[FILTERED]')
      end
    end
  end
end
