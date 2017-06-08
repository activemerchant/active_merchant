module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SquareGateway < Gateway

      # test uses a 'sandbox' access token, same URL
      self.live_url = 'https://connect.squareup.com/v2/'

      self.money_format = :cents
      self.supported_countries = ['US', 'CA']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb, :maestro]

      self.homepage_url = 'https://squareup.com/developers'
      self.display_name = 'Square'

      # Map to Square's error codes:
      # https://docs.connect.squareup.com/api/connect/v2/#handlingerrors
      STANDARD_ERROR_CODE_MAPPING = {
        'INVALID_CARD' => STANDARD_ERROR_CODE[:invalid_number],
        'INVALID_EXPIRATION' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        'INVALID_EXPIRATION_DATE' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        'INVALID_EXPIRATION_YEAR' => STANDARD_ERROR_CODE[:invalid_expiry_date],

        # Something invalid in the card, e.g. verify declined when linking card to customer.
        'INVALID_CARD_DATA' => STANDARD_ERROR_CODE[:processing_error],
        'CARD_EXPIRED' => STANDARD_ERROR_CODE[:expired_card],
        'VERIFY_CVV_FAILURE' => STANDARD_ERROR_CODE[:incorrect_cvc],
        'VERIFY_AVS_FAILURE' => STANDARD_ERROR_CODE[:incorrect_zip],
        'CARD_DECLINED' => STANDARD_ERROR_CODE[:card_declined],
        'UNAUTHORIZED' => STANDARD_ERROR_CODE[:config_error]
      }

      # The `login` key is the client_id (also known as application id) 
      #   in the dev portal. Get it after you create a new app:
      #   https://connect.squareup.com/apps/
      # The `password` is the access token (personal or OAuth)
      # The `location_id` must be fetched initially 
      #   https://docs.connect.squareup.com/articles/processing-payment-rest/
      # The `test` indicates if these credentials are for sandbox or 
      #   production (money moving) access
      def initialize(options={})
        requires!(options, :login, :password, :location_id, :test)
        @client_id = options[:login].strip
        @bearer_token = options[:password].strip
        @location_id = options[:location_id].strip

        super
      end

      # To create a charge on a card using a card nonce:
      #     purchase(money, card_nonce, { ...create transaction options... })
      #
      # To create a customer and save a card (via card_nonce) to the customer:
      #     purchase(money, card_nonce, {customer: {...params hash same as in store() method...}, ...})
      #   Note for US and CA, you must have {customer: {billing_address: {zip: 12345}}} which passes AVS to store a card.
      #   Note this always creates a new customer, so it may make a duplicate 
      #   customer if this card was associated to another customer previously.
      #
      # To use a customer's card on file:
      #     purchase(money, nil, {customer: {id: 'customer-id', card_id: 'card-id'}})
      # Note this does not update any fields on the customer.
      #
      # To use a customer, and link a new card to the customer:
      #     purchase(money, card_nonce, {customer: {id: 'customer-id', billing_address: {zip: 12345}})
      # Note the zip is required to store the new nonce, and it must pass AVS.
      # Note this does not update any other fields on the customer.
      #
      # As this may make multiple requests, it returns a MultiResponse.
      def purchase(money, card_nonce, options={})
        raise ArgumentError('money required') if money.nil?
        if card_nonce.nil?
          requires!(options, :customer)
          requires!(options[:customer], :card_id, :id)
        end
        if card_nonce && options[:customer] && options[:customer][:card_id]
          raise ArgumentError('Cannot call with both card_nonce and' +
            ' options[:customer][:card_id], choose one.')
        end

        post = options.slice(:buyer_email_address, :delay_capture, :note,
            :reference_id)
        add_idempotency_key(post, options)
        add_amount(post, money, options)
        add_address(post, options)
        post[:reference_id] = options[:order_id] if options[:order_id]
        post[:note] = options[:description] if options[:description]

        MultiResponse.run do |r|
          if options[:customer] && card_nonce
            # Since customer was passed in, create customer (if needed) and 
            # store card (always in here).
            options[:customer][:customer_id] = options[:customer][:id] if options[:customer][:id] # To make store() happy.
            r.process { store(card_nonce, options[:customer]) }

            # If we just created a customer.
            if options[:customer][:id].nil?
              options[:customer][:id] =
                  r.responses.first.params['customer']['id']
            end

            # We always stored a card, so grab it.
            options[:customer][:card_id] =
                r.responses.last.params['card']['id']

            # Empty the card_nonce, since we now have the card on file.
            card_nonce = nil 
            
            # Invariant: we have a customer and a linked card, and our options
            # hash is correct.
          end

          add_payment(post, card_nonce, options)
          r.process { commit(:post, "locations/#{@location_id}/transactions", post) }
        end
      end

      # Authorize for Square uses the Charge with delay_capture = true option. 
      # https://docs.connect.squareup.com/api/connect/v2/#endpoint-charge
      # Same as with `purchase`, pass nil for `card_nonce` if using a customer's
      # stored card on file.
      # 
      # See purchase for more details for calling this.
      def authorize(money, card_nonce, options={})
        options[:delay_capture] = true
        purchase(money, card_nonce, options)
      end

      # Capture is only used if you did an Authorize, (creating a delayed capture).
      # https://docs.connect.squareup.com/api/connect/v2/#endpoint-capturetransaction
      # Both `money` and `options` are unused. Only a full capture is supported.
      def capture(ignored_money, txn_id, ignored_options={})
        raise ArgumentError('txn_id required') if txn_id.nil?
        commit(:post, "locations/#{CGI.escape(@location_id)}/transactions/#{CGI.escape(txn_id)}/capture")
      end

      # Refund refunds a previously Charged transaction. 
      # https://docs.connect.squareup.com/api/connect/v2/#endpoint-createrefund
      # Options require: `tender_id`, and permit `idempotency_key`, `reason`.
      def refund(money, txn_id, options={})
        raise ArgumentError('txn_id required') if txn_id.nil?
        raise ArgumentError('money required') if money.nil?
        requires!(options, :tender_id)
        
        post = options.slice(:tender_id, :reason)
        add_idempotency_key(post, options)
        add_amount(post, money, options)
        commit(:post, "locations/#{CGI.escape(@location_id)}/transactions/#{CGI.escape(txn_id)}/refund", post)
      end

      # Void cancels a delayed capture (not-yet-captured) transaction.
      # https://docs.connect.squareup.com/api/connect/v2/#endpoint-voidtransaction
      def void(txn_id, options={})
        raise ArgumentError('txn_id required') if txn_id.nil?
        commit(:post, "locations/#{CGI.escape(@location_id)}/transactions/#{CGI.escape(txn_id)}/void")
      end

      # Do an Authorize (Charge with delayed capture) and then Void.
      # Storing a card with a customer will do a verify, however a direct
      # verification only endpoint is not exposed today (Oct '16). 
      def verify(card_nonce, options={})
        raise ArgumentError('card_nonce required') if card_nonce.nil?
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, card_nonce, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end
     
      # Required in options hash one of: 
      # a) :customer_id from the Square CreateCustomer endpoint of customer to link to.
      #     Required in the US and CA: options[:billing_address][:zip] (AVS must pass to link)
      #     https://docs.connect.squareup.com/api/connect/v2/#endpoint-createcustomercard
      # b) :email, :family_name, :given_name, :company_name, :phone_number to create a new customer.
      #
      # Optional: :cardholder_name, :address (to store on customer)
      # Return values (e.g. the card id) are available on the response.params['card']['id']
      def store(card_nonce, options = {})
        raise ArgumentError('card_nonce required') if card_nonce.nil?
        raise ArgumentError.new('card_nonce nil but is a required field.') if card_nonce.nil?
        if options[:billing_address].nil? || options[:billing_address][:zip].nil?
          raise ArgumentError.new('options[:billing_address][:zip] nil but is a required field.')
        end

        MultiResponse.run do |r|
          if !(options[:customer_id])
            r.process { create_customer(options) }
            options[:customer_id] = r.responses.last.params['customer']['id']
          end
          post = options.slice(:cardholder_name, :billing_address)
          post[:billing_address][:postal_code] = options[:billing_address][:zip]
          post[:card_nonce] = card_nonce
          r.process { commit(:post, "customers/#{CGI.escape(options[:customer_id])}/cards", post) }
        end
      end

      def update(customer_id, card_id, options = {})
        raise Exception.new('Square API does not currently support updating' +
          ' a given card_id, instead create a new one and delete the old one.')
      end

      # https://docs.connect.squareup.com/api/connect/v2/#endpoint-updatecustomer
      def update_customer(customer_id, options = {})
        raise ArgumentError.new('customer_id nil but is a required field.') if customer_id.nil?
        options[:email_address] = options[:email] if options[:email]
        options[:note] = options[:description] if options[:description]
        commit(:put, "customers/#{CGI.escape(customer_id)}", options)
      end

      # https://docs.connect.squareup.com/api/connect/v2/#endpoint-deletecustomercard
      # Required options[:customer][:id] and 'card_id' params.
      def unstore(card_id, options = {}, deprecated_options = {})
        raise ArgumentError.new('card_id nil but is a required field.') if card_id.nil?
        requires!(options, :customer)
        requires!(options[:customer], :id)
        commit(:delete, "customers/#{CGI.escape(options[:customer][:id])}/cards/#{CGI.escape(card_id)}", nil)
      end

      # See also store().
      # Options hash takes the keys as defined here:
      # https://docs.connect.squareup.com/api/connect/v2/#endpoint-createcustomer
      def create_customer(options) 
        required_one_of = [:email, :email_address, :family_name, :given_name,
          :company_name, :phone_number]
        if required_one_of.none?{|k| options.key?(k)}
          raise ArgumentError.new("one of these options keys required:" +
            " #{required_one_of} but none included.")
        end

        MultiResponse.run do |r|
          post = options.slice(*required_one_of - [:email] +
              [:phone_number, :reference_id, :note, :nickname])
          post[:email_address] = options[:email] if options[:email]
          post[:note] = options[:description] if options[:description]
          add_address(post, options, :address)
          r.process{ commit(:post, 'customers', post) }
        end
      end

      # Scrubbing removes the access token from the header and the card_nonce.
      # Square does not let the merchant ever see PCI data. All payment card
      # data is directly handled on Square's servers via iframes as described
      # here: https://docs.connect.squareup.com/articles/adding-payment-form/
      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Bearer )[^\r\n]+), '\1[FILTERED]').
          # Extra [\\]* for test. We do an extra escape in the regex of [\\]* 
          # b/c the remote_square_test.rb seems to double escape the
          # backslashes before the quote. This ensures tests pass.
          gsub(%r((\"card_nonce[\\]*\":[\\]*")[^"]+), '\1[FILTERED]')
      end

      private

      def add_address(post, options, non_billing_addr_key = :shipping_address)
        if address = options[:billing_address] || options[:address]
          add_address_for(post, address, :billing_address)
        end        
        non_billing_addr_key = non_billing_addr_key.to_sym
        if address = options[non_billing_addr_key] || options[:address]
          add_address_for(post, address, non_billing_addr_key)
        end
      end

      def add_address_for(post, address, addr_key)
          addr_key = addr_key.to_sym
          post[addr_key] ||= {} # Or-Equals in case they passed in using Square's key format
          post[addr_key][:address_line_1] = address[:address1] if address[:address1]
          post[addr_key][:address_line_2] = address[:address2] if address[:address2]
          post[addr_key][:address_line_3] = address[:address3] if address[:address3]
          
          post[addr_key][:locality] = address[:city] if address[:city]
          post[addr_key][:sublocality] = address[:sublocality] if address[:sublocality]
          post[addr_key][:sublocality_2] = address[:sublocality_2] if address[:sublocality_2]
          post[addr_key][:sublocality_3] = address[:sublocality_3] if address[:sublocality_3]

          post[addr_key][:administrative_district_level_1] = address[:state] if address[:state]
          post[addr_key][:administrative_district_level_2] = address[:administrative_district_level_2] if address[:administrative_district_level_2] # In the US, this is the county.
          post[addr_key][:administrative_district_level_3] = address[:administrative_district_level_3] if address[:administrative_district_level_3] # Used in JP not the US
          post[addr_key][:postal_code] = address[:zip] if address[:zip]
          post[addr_key][:country] = address[:country] if address[:country]
      end

      def add_amount(post, money, options)
        post[:amount_money] = {}
        post[:amount_money][:amount] = Integer(amount(money))
        post[:amount_money][:currency] = 
          (options[:currency] || currency(money))
      end

      def add_payment(post, card_nonce, options)
        if card_nonce.nil?
          # use card on file
          requires!(options, :customer)
          requires!(options[:customer], :id, :card_id)
          post[:customer_id] = options[:customer][:id]
          post[:customer_card_id] = options[:customer][:card_id]
        else
          # use nonce
          post[:card_nonce] = card_nonce
        end          
      end

      def commit(method, endpoint, parameters=nil)
        response = api_request(method, endpoint, parameters)
        success = !response.key?("errors")
        Response.new(success,
          message_from(success, response),
          response,
          authorization: authorization_from(response),
          # Neither avs nor cvv match are not exposed in the api.
          avs_result: nil,
          cvv_result: nil,
          test: test?,
          error_code: success ? nil : error_code_from(response)
        )
      end

      def headers
        {
          'Authorization' => "Bearer " + @bearer_token,
          'User-Agent' => 
            "Square/v2 ActiveMerchantBindings/#{ActiveMerchant::VERSION}",
          'X-Square-Client-User-Agent' => user_agent,
          'Accept' => 'application/json',
          'Content-Type' => 'application/json',
          # Uncomment below to generate request/response json for unit tests.
          # 'Accept-Encoding' => ''
        }
      end

      def add_idempotency_key(post, options)
        post[:idempotency_key] = 
          (options[:idempotency_key] || generate_unique_id).to_s
      end

      def message_from(success, response)
        # e.g. {"errors":[{"category":"INVALID_REQUEST_ERROR","code":"VALUE_TOO_LOW","detail":"`amount_money.amount` must be greater than 100.","field":"amount_money.amount"}]}
        success ? "Success" : response['errors'].first['detail']
      end

      def authorization_from(response)
        if response['transaction'] 
          # This will return the transaction level identifier, of which there
          # is >= 1 nested tender id which you may need to look up depending
          # on your use case (e.g. refunding). That is available in the
          # response.transaction.tenders array.
          return response['transaction']['id']
        end
      end

      def api_request(method, endpoint, parameters)
        json_payload = JSON.generate(parameters) if parameters
        begin
          raw_response = ssl_request(
            method, self.live_url + endpoint, json_payload, headers)
          response = JSON.parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response = response_error(raw_response)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end
        response
      end

      def response_error(raw_response)
        JSON.parse(raw_response)          
      rescue JSON::ParserError
        json_error(raw_response)
      end

      def json_error(raw_response)
        msg = 'Invalid non-parsable json data response from the Square API.' +
          ' Please contact' +
          ' squareup.com/help/us/en/contact?prefill=developer_api' +
          ' if you continue to receive this message.' +
          "  (The raw API response returned was #{raw_response.inspect})"
        {
          "errors" => [{
            "category" => "API_ERROR",
            "detail" => msg
          }]
        }
      end

      def error_code_from(response)
        code = response['errors'].first['code']
        error_code = STANDARD_ERROR_CODE_MAPPING[code]
        error_code
      end
    end
  end
end
