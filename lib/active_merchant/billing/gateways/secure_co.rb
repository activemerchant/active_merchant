require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SecureCoGateway < Gateway

      self.display_name = 'SecureCo'
      self.homepage_url = 'https://www.secureco.co/'
      self.test_url     = 'https://testapi.ep2-global.com/engine/rest/payments/'
      self.live_url     = 'https://api.ep2-global.com/engine/rest/payments/'

      self.supported_countries = ['AU']
      self.default_currency    = 'AUD'
      self.supported_cardtypes = [:visa, :master, :american_express]
      self.money_format        = :dollars

      DEFAULT_ERROR_CODE = :processing_error
      ERROR_CODE_MAPPING = { #:nodoc:
        "400.1000" => :invalid_number,
        "400.1001" => :invalid_number,
        "400.1002" => :invalid_number,
        "400.1003" => :invalid_expiry_date,
        "400.1004" => :invalid_expiry_date,
        "400.1006" => :invalid_cvc,
        "400.1007" => :card_declined,
        "400.1017" => :invalid_number,
        "400.1111" => :invalid_number,
        "400.1112" => :incorrect_number,
        "500.1053" => :card_declined,
        "500.1054" => :pickup_card,
        "500.1055" => :call_issuer,
        "500.1059" => :invalid_cvc,
        "500.1062" => :expired_card,
        "500.1063" => :call_issuer,
        "500.1064" => :invalid_expiry_date,
        "500.1069" => :call_issuer,
      }

      BRAND_MAPPING = { #:nodoc:
        'visa'             => 'visa',
        'master'           => 'mastercard',
        'american_express' => 'amex',
      }

      DEFAULT_ENTRY_MODE = 'ecommerce'
      ENTRY_MODES = [
        'empty',           # unknown source
        'ecommerce',       # collected over the Internet
        'mail-order',      # collected over mail order
        'telephone-order', # collected over telephone
        'pos',             # collected by the primary payment instrument
      ]

      TRANSACTION_TYPES = [ #:nodoc:
        'purchase',
        'authorization',
        'capture-authorization',
        'refund-purchase',
        'refund-capture',
        'void-purchase',
        'void-authorization',
        'void-capture',
        'tokenize',
      ]

      # Creates a new SecureCoGateway.
      #
      # All three option fields are mandatory.
      #
      # ==== Options
      #
      # * +:username+ -- Mandatory. Your username.
      # * +:password+ -- Mandatory. Your password.
      # * +:merchant_account_id+ -- Mandatory. Your merchant account ID.
      #
      def initialize(options={})
        requires!(options, :username, :password, :merchant_account_id)
        super
      end

      # Dispatches a purchase request.
      #
      # Can be followed by a +refund+ or +void+ operation.
      #
      # ==== Parameters
      #
      # * +money+          -- Mandatory. Integer value of cents to bill to the customer.
      # * +credit_card+    -- Mandatory. A valid instance of +ActiveMerchant::Billing::CreditCard+.
      # * +options+        -- Optional. A hash of options. See below.
      #
      # ==== Options
      #
      # * +:request_id+    -- Optional. This is the customer generated request identifier.
      #   If a request_id is not provided, one will be generated for you.
      #   If it is provided, it must be unique. Attempting to re-use a request_id will result in a processing error.
      # * +:currency+      -- Optional. Will default to 'AUD'.
      # * +:entry_mode+    -- Optional. Represents the way in which the payment was collected. If provided, it must
      #   be one of ENTRY_MODES. If +:entry_mode+ is not provided, +DEFAULT_ENTRY_MODE+ is used (see above).
      # * +:email+         -- Optional. The email address of the card-holder.
      # * +:order_id+      -- Optional. For reference only, the SecureCo gateway will link the payment to this information.
      # * +:ip+            -- Optional. The IP address of the customer. Only relevant when +:entry_mode+ == 'ecommerce'
      # * +:custom_fields+ -- Optional. A hash or 2d array of key-value pairs to attach to the order.
      #   Like +:order_id+ above, this is only used for future reference.
      #
      # ==== Minimal Example
      #
      #    # Dispatch a request for $10.00
      #    response = gateway.purchase(1000, credit_card)
      #
      # ==== Full Example
      #
      #    gateway = ActiveMerchant::Billing::SecureCoGateway.new(username: 'yourusername', password: 'somepassword', merchant_account_id: '00000000-0000-0000-0000-000000000000')
      #
      #    credit_card = ActiveMerchant::Billing::CreditCard.new(
      #      :brand      => 'visa',
      #      :number     => '4111 1111 1111 1111',
      #      :month      => 10,
      #      :year       => 2017,
      #      :first_name => 'Bob',
      #      :last_name  => 'Bobsen',
      #      :verification_value => '123'
      #    )
      #
      #    options = {
      #      :currency      => 'AUD',
      #      :custom_fields => {client_identifier: '12345', source_host: 'localhost'},
      #      :email         => 'the.customer@somehost.com',
      #      :entry_mode    => 'ecommerce',
      #      :ip            => '255.255.255.255',
      #      :order_id      => 'SOME_ORDER 1234',
      #      :request_id    => SecureRandom.uuid,
      #    }
      #
      #    response = gateway.purchase(1000, credit_card, options)
      #
      #    if response.success?
      #      puts "Purchase request was successful. transaction_id was: #{response.params['transaction_id']}"
      #    else
      #      puts "Purchase request failed. Reason: #{response.message}"
      #    end
      #
      def purchase(money, credit_card, options={})
        request = build_request('purchase') do |xml|
          add_payment_method(xml, 'creditcard')
          add_credit_card(xml, credit_card)
          add_request_id(xml, options[:request_id])
          add_requested_amount(xml, amount(money), options[:currency])
          add_entry_mode(xml, options[:entry_mode])
          add_account_holder(xml, credit_card, options[:email])
          add_order_id(xml, options[:order_id])           if options[:order_id]
          add_ip_address(xml, options[:ip])               if options[:ip]
          add_custom_fields(xml, options[:custom_fields]) if options[:custom_fields]
        end

        commit request
      end

      # Dispatches an authorize request.
      #
      # Can be followed by a +capture+ or +void+ operation.
      #
      # ==== Parameters
      #
      # * +money+          -- Mandatory. Integer value of cents to seek authorization for.
      # * +credit_card+    -- Mandatory. A valid instance of +ActiveMerchant::Billing::CreditCard+
      # * +options+        -- Optional. A hash of options. See below.
      #
      # ==== Options
      #
      # * +:request_id+    -- Optional. This is the customer generated request identifier.
      #   If a request_id is not provided, one will be generated for you.
      #   If it is provided, it must be unique. Attempting to re-use a request_id will result in a processing error.
      # * +:currency+      -- Optional. Will default to 'AUD'.
      # * +:entry_mode+    -- Optional. Represents the way in which the payment was collected. If provided, it must
      #   be one of ENTRY_MODES. If +:entry_mode+ is not provided, +DEFAULT_ENTRY_MODE+ is used (see above).
      # * +:email+         -- Optional. The email address of the card-holder.
      # * +:order_id+      -- Optional. For reference only, the SecureCo gateway will link the payment to this information.
      # * +:ip+            -- Optional. The IP address of the customer. Only relevant when +:entry_mode+ == 'ecommerce'
      # * +:custom_fields+ -- Optional. A hash or 2d array of key-value pairs to attach to the request.
      #   Like +:order_id+ above, this is only used for future reference.
      #
      # ==== Minimal Example
      #
      #    # Dispatch a request for $10.00
      #    response = gateway.authorize(1000, credit_card)
      #
      # ==== Full Example
      #
      #    gateway = ActiveMerchant::Billing::SecureCoGateway.new(username: 'yourusername', password: 'somepassword', merchant_account_id: '00000000-0000-0000-0000-000000000000')
      #
      #    credit_card = ActiveMerchant::Billing::CreditCard.new(
      #      :brand      => 'visa',
      #      :number     => '4111 1111 1111 1111',
      #      :month      => 10,
      #      :year       => 2017,
      #      :first_name => 'Bob',
      #      :last_name  => 'Bobsen',
      #      :verification_value => '123'
      #    )
      #
      #    options = {
      #      :currency      => 'AUD',
      #      :custom_fields => {client_identifier: '12345', source_host: 'localhost'},
      #      :email         => 'the.customer@somehost.com',
      #      :entry_mode    => 'ecommerce',
      #      :ip            => '255.255.255.255',
      #      :order_id      => 'SOME_ORDER 1234',
      #      :request_id    => SecureRandom.uuid,
      #    }
      #
      #    response = gateway.authorize(1000, credit_card, options)
      #
      #    if response.success?
      #      puts "Authorization request was successful. transaction_id was: #{response.params['transaction_id']}"
      #    else
      #      puts "Authorization request failed. Reason: #{response.message}"
      #    end
      #
      def authorize(money, credit_card, options={})
        request = build_request('authorization') do |xml|
          add_credit_card(xml, credit_card)
          add_request_id(xml, options[:request_id])
          add_requested_amount(xml, amount(money), options[:currency])
          add_entry_mode(xml, options[:entry_mode])
          add_account_holder(xml, credit_card, options[:email])
          add_order_id(xml, options[:order_id])           if options[:order_id]
          add_ip_address(xml, options[:ip])               if options[:ip]
          add_custom_fields(xml, options[:custom_fields]) if options[:custom_fields]
        end

        commit request
      end

      # Dispatches a capture request.
      #
      # Must follow a successful +authorize+ operation.
      #
      # Can be followed by a +refund+ or +void+ operation.
      #
      # ==== Parameters
      #
      # * +money+          -- Mandatory. Integer value of cents to claim. Must be equal to or less than the amount requested in the preceding +authorize+ request.
      #   Also accepts +:full_amount+ when you want to capture the full amount
      # * +authorization+  -- Mandatory. The authorization credentials produced by a successful +authorize+ request
      # * +options+        -- Optional. A hash of options. See below.
      #
      # ==== Options
      #
      # * +:request_id+    -- Optional. This is the customer generated request identifier.
      #   If a request_id is not provided, one will be generated for you.
      #   If it is provided, it must be unique. Attempting to re-use a request_id will result in a processing error.
      # * +:currency+      -- Optional. Will default to 'AUD'. If the specified currency does not match the currency specified in the +authorize+ request, the gateway
      #   will return an error. This field is ignored if +money+ is set to +:full_amount+
      # * +:custom_fields+ -- Optional. A hash or 2d array of key-value pairs to attach to the request. If any custom fields were provided in the
      #   preceding +authorize+ step they will be merged, with capture key/values taking precedence.
      #
      # ==== Minimal Examples
      #
      #    # Capture $10.00 of a previously successful authorization request
      #    response = gateway.capture(1000, authorization_response.authorization)
      #
      #    # Capture the full amount of a previously successful authorization request
      #    response = gateway.capture(:full_amount, authorization_response.authorization)
      #
      # ==== Full Example
      #
      #    gateway = ActiveMerchant::Billing::SecureCoGateway.new(username: 'yourusername', password: 'somepassword', merchant_account_id: '00000000-0000-0000-0000-000000000000')
      #
      #    credit_card = ActiveMerchant::Billing::CreditCard.new(
      #      :brand      => 'visa',
      #      :number     => '4111 1111 1111 1111',
      #      :month      => 10,
      #      :year       => 2017,
      #      :first_name => 'Bob',
      #      :last_name  => 'Bobsen',
      #      :verification_value => '123'
      #    )
      #
      #    options = {
      #      :custom_fields => {client_identifier: '12345', source_host: 'localhost'},
      #      :request_id    => SecureRandom.uuid,
      #    }
      #
      #    authorization_response = gateway.authorize(1000, credit_card, options)
      #    raise "Failed authorization: #{authorization_response.message}" unless authorization_response.success?
      #
      #    capture_response = gateway.capture(:full_amount, authorization_response.authorization)
      #    raise "Failed capture: #{capture_response.message}" unless capture_response.success?    
      #
      def capture(money, authorization, options={})
        _, original_transaction_id = authorization.split ?|
        raise ArgumentError.new("Couldn't discern original transaction's id") unless original_transaction_id

        request = build_request('capture-authorization') do |xml|
          add_request_id(xml, options[:request_id])
          add_requested_amount(xml, amount(money), options[:currency]) unless money == :full_amount
          add_parent_transaction_id(xml, original_transaction_id)
          add_custom_fields(xml, options[:custom_fields]) if options[:custom_fields]
        end

        commit request
      end

      # Dispatches a refund request.
      #
      # Must follow a successful +purchase+ or +capture+ operation.
      #
      # ==== Parameters
      #
      # * +money+          -- Mandatory. Integer value of cents to claim. Must be equal to or less than the amount requested in the preceding request.
      #   Also accepts +:full_amount+ when you want to refund the full amount
      # * +authorization+  -- Mandatory. The authorization credentials produced by a successful +purchase+ or +capture+ request
      # * +options+        -- Optional. A hash of options. See below.
      #
      # ==== Options
      #
      # * +:request_id+    -- Optional. This is the customer generated request identifier.
      #   If a request_id is not provided, one will be generated for you.
      #   If it is provided, it must be unique. Attempting to re-use a request_id will result in a processing error.
      # * +:currency+      -- Optional. Will default to 'AUD'. If the specified currency does not match the currency specified in the preceding request, the gateway
      #   will return an error. This field is ignored if +money+ is set to +:full_amount+
      # * +:custom_fields+ -- Optional. A hash or 2d array of key-value pairs to attach to the request. If any custom fields were provided in the
      #   preceding steps they will be merged, with refund key/values taking precedence.
      #
      # ==== Minimal Examples
      #
      #    # Refund $10.00 of a previously successful purchase request
      #    response = gateway.refund(1000, purchase_response.authorization)
      #
      #    # Capture the full amount of a previously successful capture request
      #    response = gateway.capture(:full_amount, capture_response.authorization)
      #
      # ==== Full Example
      #
      #    gateway = ActiveMerchant::Billing::SecureCoGateway.new(username: 'yourusername', password: 'somepassword', merchant_account_id: '00000000-0000-0000-0000-000000000000')
      #
      #    credit_card = ActiveMerchant::Billing::CreditCard.new(
      #      :brand      => 'visa',
      #      :number     => '4111 1111 1111 1111',
      #      :month      => 10,
      #      :year       => 2017,
      #      :first_name => 'Bob',
      #      :last_name  => 'Bobsen',
      #      :verification_value => '123'
      #    )
      #
      #    options = {
      #      :custom_fields => {client_identifier: '12345', source_host: 'localhost'},
      #      :request_id    => SecureRandom.uuid,
      #    }
      #
      #    authorization_response = gateway.authorize(1000, credit_card, options)
      #    raise "Failed authorization: #{authorization_response.message}" unless authorization_response.success?
      #
      #    # Capture the full amount
      #    capture_response = gateway.capture(:full_amount, authorization_response.authorization)
      #    raise "Failed capture: #{capture_response.message}" unless capture_response.success?    
      #
      #    # Refund $5.00 of the capture
      #    refund_response = gateway.refund(500, capture_response.authorization)
      #    raise "Failed refund: #{refund_response.message}" unless refund_response.success?   
      #
      def refund(money, authorization, options={})
        trans_mapping = {
          'purchase'              => 'refund-purchase',
          'authorization'         => 'refund-authorization',
          'capture-authorization' => 'refund-capture',
        }

        original_transaction_type, original_transaction_id = authorization.split ?|
        raise ArgumentError.new("Can't void \"#{original_transaction_type}\". Must be one of: #{trans_mapping.keys}") unless trans_mapping.key? original_transaction_type
        raise ArgumentError.new("Couldn't discern original transaction's id") unless original_transaction_id

        transaction_type = trans_mapping[original_transaction_type]

        request = build_request(transaction_type) do |xml|
          add_request_id(xml, options[:request_id])
          add_requested_amount(xml, amount(money), options[:currency]) unless money == :full_amount
          add_parent_transaction_id(xml, original_transaction_id)
          add_custom_fields(xml, options[:custom_fields]) if options[:custom_fields]
        end

        commit request
      end

      # Dispatches a void request.
      #
      # Must follow a successful +purchase+, +authorize+ or +capture+ operation.
      #
      # ==== Parameters
      #
      # * +authorization+  -- Mandatory. The authorization credentials produced by a successful +purchase+, +authorize+ or +capture+ request.
      # * +options+        -- Optional. A hash of options. See below.
      #
      # ==== Options
      #
      # * +:request_id+    -- Optional. This is the customer generated request identifier.
      #   If a request_id is not provided, one will be generated for you.
      #   If it is provided, it must be unique. Attempting to re-use a request_id will result in a processing error.
      # * +:custom_fields+ -- Optional. A hash or 2d array of key-value pairs to attach to the request. If any custom fields were provided in the
      #   preceding steps they will be merged, with void key/values taking precedence.
      #
      # ==== Minimal Example
      #
      #    # Void a successful purchase request
      #    response = gateway.void(1000, purchase_response.authorization)
      #
      def void(authorization, options={})
        trans_mapping = {
          'purchase'              => 'void-purchase',
          'authorization'         => 'void-authorization',
          'capture-authorization' => 'void-capture',
        }

        original_transaction_type, original_transaction_id = authorization.split ?|
        raise ArgumentError.new("Can't void \"#{original_transaction_type}\". Must be one of: #{trans_mapping.keys}") unless trans_mapping.key? original_transaction_type
        raise ArgumentError.new("Couldn't discern original transaction's id") unless original_transaction_id

        transaction_type = trans_mapping[original_transaction_type]

        request = build_request(transaction_type) do |xml|
          add_request_id(xml, options[:request_id])
          add_parent_transaction_id(xml, original_transaction_id)
          add_custom_fields(xml, options[:custom_fields]) if options[:custom_fields]
        end

        commit request
      end

      # Validates a credit card by issuing an +authorize+ request followed by a +void+ request.
      #
      # ==== Parameters
      #
      # * +credit_card+    -- Mandatory. A valid instance of +ActiveMerchant::Billing::CreditCard+
      # * +options+        -- Optional. See the description of the +options+ parameter in the documentation for the +authorize+ and +void+ methods.
      #
      # ==== Minimal Example
      #
      #    response = gateway.verify(credit_card)
      #    puts "Credit card is valid" if response.success?
      #
      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing? #:nodoc:
        true
      end

      # Scrubs a HTTP transcript of sensitive information.
      #
      # ==== Parameters
      #
      # * +transcript+  -- Mandatory. The HTTP transcript
      #
      # ==== Example
      #
      #    gateway.scrub(transcript)
      #
      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((<(account-number)>)\d+(</\2>)), '\1[FILTERED]\3').
          gsub(%r((<(card-security-code)>)\d+(</\2>)), '\1[FILTERED]\3')
      end

      # A helper method to retrieve order details from the payment gateway.
      #
      # It requires a +transaction_id+; the id created by SecureCo and returned in response to all transaction requests
      #
      # ==== Parameters
      #
      # * +transaction_id+ -- Mandatory
      #
      # ==== Minimal Example
      #
      #    response = gateway.get_payment_status_by_transaction_id(capture_response.params["transaction_id"])
      #
      # ==== Full example
      #
      #    gateway = ActiveMerchant::Billing::SecureCoGateway.new(username: 'username', password: 'password', merchant_account_id: '00000000-0000-0000-0000-000000000000')
      #    
      #    credit_card = ActiveMerchant::Billing::CreditCard.new(
      #      :brand      => 'visa',
      #      :number     => '4111 1111 1111 1111',
      #      :month      => 10,
      #      :year       => 2017,
      #      :first_name => 'Bob',
      #      :last_name  => 'Bobsen',
      #      :verification_value => '123'
      #    )
      #    
      #    [
      #      ->(prev_response){ gateway.authorize(1000,       credit_card,                 custom_fields: {test1: "aut", test2: "aut"})},
      #      ->(prev_response){ gateway.capture(:full_amount, prev_response.authorization, custom_fields: {test1: "cap", test3: "cap"})},
      #      ->(prev_response){ gateway.refund(800,           prev_response.authorization, custom_fields: {test1: "ref", test4: "ref"})},
      #    ].reduce([]) do |r, req_gen|
      #      r << req_gen.call(r.last)
      #    end.map do |response|
      #      gateway.get_payment_status_by_transaction_id response.params["transaction_id"]
      #    end.each do |status|
      #      pp status.params.slice 'transaction_type', 'transaction_state', 'completion_time_stamp', 'transaction_id', 'request_id'
      #    end
      #    
      #    # => {"transaction_type"=>"authorization",
      #    #  "transaction_state"=>"success",
      #    #  "completion_time_stamp"=>"2017-02-09T01:44:24.000Z",
      #    #  "transaction_id"=>"1f98496e-f00e-4967-a8ef-be6e7d2e3531",
      #    #  "request_id"=>"488810f8367bf0334d8f056308e1f34f"}
      #    # {"transaction_type"=>"capture-authorization",
      #    #  "transaction_state"=>"success",
      #    #  "completion_time_stamp"=>"2017-02-09T01:44:25.000Z",
      #    #  "transaction_id"=>"ab545171-c413-48cf-ac21-8407b6393b46",
      #    #  "request_id"=>"04fc42ac5caf786a27a84449a09b913e"}
      #    # {"transaction_type"=>"refund-capture",
      #    #  "transaction_state"=>"success",
      #    #  "completion_time_stamp"=>"2017-02-09T01:44:27.000Z",
      #    #  "transaction_id"=>"462081e5-69e0-4da3-b996-39348216413d",
      #    #  "request_id"=>"f53cbf82ee8618a4f441452cff6e2328"}
      #
      def get_payment_status_by_transaction_id(transaction_id)
        url = test? ? test_url : live_url
        uri = URI(url)
        uri.path = '/engine/rest/merchants/%s/payments/%s' % [@options[:merchant_account_id], transaction_id]
        create_response(parse(ssl_get(uri, headers)))
      end

      # A helper method to retrieve order details from the payment gateway.
      #
      # It requires a +request_id+; the unique id you generate and include in all transaction requests. It is
      # the only way to determine the outcome of a request where there were network issues that prevented you
      # from receiving a response back from the gateway.
      #
      # ==== Parameters
      #
      # * +request_id+ -- Mandatory
      #
      # ==== Minimal Examples
      #
      #    # Process an order for one million dollars:
      #    request_id = SecureRandom.uuid
      #    response = gateway.purchase(1_000_000_00, credit_card, request_id: request_id)
      #
      #    # ⚡⚡⚡ NETWORK ERROR ⚡⚡⚡⚡
      #    # Did our purchase order reach the bank?
      #    
      #    begin
      #      response = gateway.get_payment_status_by_request_id(request_id)
      #      puts "Order reached the gateway. The response was \"#{response.message}\""
      #    rescue ActiveMerchant::ResponseError => e
      #      if e.response.code == '404'
      #        puts "Order did not reach the gateway"
      #      else
      #        puts "Unknown error"
      #      end
      #    end
      #
      #    # Alternatively, the gateway will always prevent duplicate request_ids, so trying to place the order
      #    # again with the same request_id will tangentially indicate if the original request made it to the
      #    # gateway
      #
      def get_payment_status_by_request_id(request_id)
        url = test? ? test_url : live_url
        uri = URI(url)
        uri.path = '/engine/rest/merchants/%s/payments/search' % @options[:merchant_account_id]
        uri.query = 'payment.request-id=%s' % request_id
        create_response(parse(ssl_get(uri, headers)))
      end

      private

      def headers
        {
          'Content-Type' => 'application/xml',
          'Authorization' => ('Basic ' + Base64.strict_encode64("#{@options[:username]}:#{@options[:password]}").strip),
        }
      end

      def parse(body)
        xml = Nokogiri::XML(body).remove_namespaces!

        {
          authorization_code:    'authorization-code',
          card_token_id:         'card-token/token-id',
          group_transaction_id:  'group-transaction-id',
          message:               'statuses/status/@description',
          request_id:            'request-id',
          status_code:           'statuses/status/@code',
          transaction_id:        'transaction-id',
          transaction_state:     'transaction-state',
          transaction_type:      'transaction-type',
          completion_time_stamp: 'completion-time-stamp',
        }.each_with_object({}) do |(key, xpath), obj|
          obj[key] = xml.xpath('/payment/' + xpath).text
        end
      end

      def commit(xml_request)
        url = test? ? test_url : live_url

        create_response(parse(ssl_post(url, xml_request, headers)))
      end

      def create_response(response)
        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          error_code: error_code_from(response),
          test: test?
        )
      end

      def success_from(response)
        response[:transaction_state] == 'success'
      end

      def message_from(response)
        response[:message]
      end

      def authorization_from(response)
        response.values_at(:transaction_type, :transaction_id).join ?|
      end

      def error_code_from(response)
        unless success_from(response)
          STANDARD_ERROR_CODE[ERROR_CODE_MAPPING[response[:status_code]] || DEFAULT_ERROR_CODE]
        end
      end

      def build_request(transaction_type, &block)
        Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |root|
          root.payment('xmlns' => 'http://www.elastic-payments.com/schema/payment') do |xml|
            add_merchant_account_id xml
            add_transaction_type xml, transaction_type
            block.call xml
          end
        end.to_xml(indent: 0)
      end

      def add_credit_card(xml, credit_card)
        card_type = BRAND_MAPPING[credit_card.brand]
        raise ArgumentError.new("Invalid card brand: \"#{credit_card.brand}\". Must be one of: #{BRAND_MAPPING.keys}") if card_type.nil?

        xml.send('card') do
          xml.send('account-number',     credit_card.number)
          xml.send('card-security-code', credit_card.verification_value)
          xml.send('card-type',          card_type)
          xml.send('expiration-month',   "%02d" % credit_card.month)
          xml.send('expiration-year',    credit_card.year)
        end
      end

      def add_requested_amount(xml, value, currency)
        xml.send('requested-amount', value, currency: (currency || default_currency))
      end

      def add_ip_address(xml, ip_address)
        xml.send('ip-address', ip_address)
      end

      def add_payment_method(xml, payment_method)
        xml.send('payment-methods') do
          xml.send('payment-method', 'name' => payment_method)
        end
      end

      def add_entry_mode(xml, entry_mode)
        entry_mode = options[:entry_mode] || DEFAULT_ENTRY_MODE
        raise ArgumentError.new("Invalid entry mode: \"#{entry_mode}\". Must be one of: #{ENTRY_MODES}") unless ENTRY_MODES.include? entry_mode
        xml.send('entry-mode', entry_mode)
      end

      def add_request_id(xml, request_id)
        xml.send('request-id', request_id || generate_unique_id)
      end

      def add_order_id(xml, order_id)
        xml.send('order-number', order_id)
      end

      def add_merchant_account_id(xml)
        xml.send('merchant-account-id', @options[:merchant_account_id])
      end

      def add_custom_fields(xml, custom_fields)
        raise ArgumentError.new("Invalid custom fields: \"#{custom_fields.class}\". Must be a Hash or Array of Arrays") unless [Hash, Array].any? { |klass| custom_fields.is_a? klass }
        xml.send('custom-fields') do
          custom_fields.each do |key, value|
            xml.send('custom-field', 'field-name' => key, 'field-value' => value)
          end
        end
      end

      def add_account_holder(xml, credit_card, email)
        xml.send('account-holder') do
          xml.send('first-name', credit_card.first_name)
          xml.send('last-name',  credit_card.last_name)
          xml.send('email',      email) if email
        end
      end

      def add_transaction_type(xml, transaction_type)
        raise ArgumentError.new("Invalid transaction type: \"#{transaction_type}\". Must be one of: #{TRANSACTION_TYPES}") unless TRANSACTION_TYPES.include? transaction_type
        xml.send('transaction-type', transaction_type)
      end

      def add_parent_transaction_id(xml, parent_transaction_id)
        xml.send('parent-transaction-id', parent_transaction_id)
      end

      def add_authorization_code(xml, authorization_code)
        xml.send('authorization-code', authorization_code)
      end
    end
  end
end
