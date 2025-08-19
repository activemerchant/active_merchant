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
      # * +payment_method+ -- Mandatory. A valid instance of +ActiveMerchant::Billing::CreditCard+, or a String token
      #                       obtained from a previous +store+ operation.
      # * +options+        -- Optional. A hash of options. See below.
      #
      # ==== Options
      #
      # * +:request_id+    -- This is the customer generated request identifier. If a request_id is not provided, one
      #                       will be generated for you. If it is provided, it must be unique. Attempting to re-use a
      #                       request_id will result in a processing error.
      # * +:currency+      -- Will default to 'AUD'.
      # * +:entry_mode+    -- Represents the way in which the payment was collected. If provided, it must be one of
      #                       ENTRY_MODES. If +:entry_mode+ is not provided, +DEFAULT_ENTRY_MODE+ is used (see above).
      # * +:email+         -- The email address of the card-holder.
      # * +:order_id+      -- For reference only, the SecureCo gateway will link the payment to this information.
      # * +:ip+            -- The IP address of the customer. Only relevant when +:entry_mode+ == 'ecommerce'.
      # * +:custom_fields+ -- A hash or 2d array of key-value pairs to attach to the order. Like +:order_id+ above,
      #                       this is only used for future reference.
      #
      # ==== Minimal Example
      #
      #    # Dispatch a request for $10.00
      #    response = gateway.purchase(1000, credit_card)
      #
      # ==== Full Example
      #
      #    gateway = ActiveMerchant::Billing::SecureCoGateway.new(
      #      username: 'yourusername',
      #      password: 'somepassword',
      #      merchant_account_id: '00000000-0000-0000-0000-000000000000'
      #    )
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
      def purchase(money, payment_method, options={})
        request = build_request('purchase') do |xml|
          add_payment_method(xml, payment_method)
          add_request_id(xml, options[:request_id])
          add_requested_amount(xml, amount(money), options[:currency])
          add_entry_mode(xml, options[:entry_mode])
          add_account_holder(xml, payment_method, options[:email])
          add_order_id(xml, options[:order_id])           if options[:order_id]
          add_ip_address(xml, options[:ip])               if options[:ip]
          add_custom_fields(xml, options[:custom_fields]) if options[:custom_fields]
        end

        commit request
      end

      # Tokenizes a credit card.
      #
      # Can be followed by a +purchase+ or +authorize+ operation.
      #
      # Using this method takes a valid credit card and returns a token that can be used in subsequent operations, in
      # lieu of the original credit card details.
      #
      # Note that any request that takes a credit card as a parameter (e.g. +purchase+ and +authorize+) has the
      # side-effect of tokenizing your card (you can find the token in +response.params['card_token']['token_id']+).
      #
      # ==== Parameters
      #
      # * +credit_card+    -- Mandatory. A valid instance of +ActiveMerchant::Billing::CreditCard+.
      # * +options+        -- Optional. A hash of options. See below.
      #
      # ==== Options
      #
      # * +:request_id+    -- This is the customer generated request identifier. If a request_id is not provided, one
      #                       will be generated for you. If it is provided, it must be unique. Attempting to re-use a
      #                       request_id will result in a processing error.
      # * +:entry_mode+    -- Represents the way in which the payment was collected. If provided, it must be one of
      #                       ENTRY_MODES. If +:entry_mode+ is not provided, +DEFAULT_ENTRY_MODE+ is used (see above).
      # * +:email+         -- The email address of the card-holder.
      # * +:order_id+      -- For reference only, the SecureCo gateway will link the payment to this information.
      # * +:ip+            -- The IP address of the customer. Only relevant when +:entry_mode+ == 'ecommerce'
      # * +:custom_fields+ -- A hash or 2d array of key-value pairs to attach to the request. Like +:order_id+ above,
      #                       this is only used for future reference.
      #
      # ==== Minimal Example
      #
      #    response = gateway.store(credit_card)
      #    if response.success?
      #      puts "Token is #{response.authorization}"
      #      # Authorize a $20.00 payment
      #      gateway.authorize(2000, response.authorization)
      #    else
      #      raise "Tokenization failed"
      #    end
      #
      # ==== Full Example
      #
      #    gateway = ActiveMerchant::Billing::SecureCoGateway.new(
      #      username: 'yourusername',
      #      password: 'somepassword',
      #      merchant_account_id: '00000000-0000-0000-0000-000000000000'
      #    )
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
      #      :custom_fields => {client_id: '12345', receipt_id: '54321'},
      #      :email         => 'the.customer@somehost.com',
      #      :ip            => '255.255.255.255',
      #      :order_id      => 'SOME_ORDER 1234',
      #      :request_id    => SecureRandom.uuid,
      #    }
      #
      #    response = gateway.store(credit_card, options)
      #
      #    raise "Tokenization failed" unless response.success?
      #
      #    token = response.authorization # it's just a string
      #
      #    # ...at a later date...
      #
      #    response = gateway.purchase(1000, token)
      #    puts "Purchase request failed. Reason: #{response.message}" unless response.success?
      #
      def store(payment_method, options={})
        request = build_request('tokenize') do |xml|
          add_payment_method(xml, payment_method)
          add_request_id(xml, options[:request_id])
          add_account_holder(xml, payment_method, options[:email])
          add_entry_mode(xml, options[:entry_mode])
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
      # * +payment_method+ -- Mandatory. A valid instance of +ActiveMerchant::Billing::CreditCard+, or a String token
      #                       obtained from a previous +store+ operation.
      # * +options+        -- Optional. A hash of options. See below.
      #
      # ==== Options
      #
      # * +:request_id+    -- This is the customer generated request identifier. If a request_id is not provided, one
      #                       will be generated for you. If it is provided, it must be unique. Attempting to re-use a
      #                       request_id will result in a processing error.
      # * +:currency+      -- Will default to 'AUD'.
      # * +:entry_mode+    -- Represents the way in which the payment was collected. If provided, it must be one of
      #                       ENTRY_MODES. If +:entry_mode+ is not provided, +DEFAULT_ENTRY_MODE+ is used (see above).
      # * +:email+         -- The email address of the card-holder.
      # * +:order_id+      -- For reference only, the SecureCo gateway will link the payment to this information.
      # * +:ip+            -- The IP address of the customer. Only relevant when +:entry_mode+ == 'ecommerce'
      # * +:custom_fields+ -- A hash or 2d array of key-value pairs to attach to the request. Like +:order_id+ above,
      #                       this is only used for future reference.
      #
      # ==== Minimal Example
      #
      #    # Dispatch a request for $10.00
      #    response = gateway.authorize(1000, credit_card)
      #
      # ==== Full Example
      #
      #    gateway = ActiveMerchant::Billing::SecureCoGateway.new(
      #      username: 'yourusername',
      #      password: 'somepassword',
      #      merchant_account_id: '00000000-0000-0000-0000-000000000000'
      #    )
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
      def authorize(money, payment_method, options={})
        request = build_request('authorization') do |xml|
          add_payment_method(xml, payment_method)
          add_request_id(xml, options[:request_id])
          add_requested_amount(xml, amount(money), options[:currency])
          add_entry_mode(xml, options[:entry_mode])
          add_account_holder(xml, payment_method, options[:email])
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
      # * +money+          -- Mandatory. Integer value of cents to claim. Must be equal to or less than the amount
      #                       requested in the preceding +authorize+ request. Also accepts +:full_amount+ for when you
      #                       want to capture the full amount.
      # * +authorization+  -- Mandatory. The authorization credentials produced by a successful +authorize+ request
      # * +options+        -- Optional. A hash of options. See below.
      #
      # ==== Options
      #
      # * +:request_id+    -- This is the customer generated request identifier. If a request_id is not provided, one
      #                       will be generated for you. If it is provided, it must be unique. Attempting to re-use a
      #                       request_id will result in a processing error.
      # * +:currency+      -- Will default to 'AUD'. If the specified currency does not match the currency specified in
      #                       the +authorize+ request, the gateway will return an error. This field is ignored if
      #                       +money+ is set to +:full_amount+.
      # * +:custom_fields+ -- A hash or 2d array of key-value pairs to attach to the request. If any custom fields were
      #                       provided in the preceding +authorize+ step they will be merged, with capture key/values
      #                       taking precedence.
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
      #    gateway = ActiveMerchant::Billing::SecureCoGateway.new(
      #      username: 'yourusername',
      #      password: 'somepassword',
      #      merchant_account_id: '00000000-0000-0000-0000-000000000000'
      #    )
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
        raise ArgumentError.new("Couldn't determine original transaction id") unless original_transaction_id

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
      # * +money+          -- Mandatory. Integer value of cents to claim. Must be equal to or less than the amount
      #                       requested in the preceding request. Also accepts +:full_amount+ for when you want to
      #                       capture the full amount.
      # * +authorization+  -- Mandatory. The authorization credentials produced by a successful +purchase+ or +capture+
      #                       request.
      # * +options+        -- Optional. A hash of options. See below.
      #
      # ==== Options
      #
      # * +:request_id+    -- This is the customer generated request identifier. If a request_id is notprovided, one
      #                       will be generated for you. If it is provided, it must be unique. Attempting to re-use a
      #                       request_id will result in a processing error.
      # * +:currency+      -- Will default to 'AUD'. If the specified currency does not match the currencyspecified in
      #                       the preceding request, the gateway will return an error. This field is ignored if +money+
      #                       is set to +:full_amount+.
      # * +:custom_fields+ -- A hash or 2d array of key-value pairs to attach to the request. If any customfields were
      #                       provided in the preceding steps they will be merged, with refund key/values taking
      #                       precedence.
      #
      # ==== Minimal Examples
      #
      #    # Refund $10.00 of a previously successful purchase request
      #    response = gateway.refund(1000, purchase_response.authorization)
      #
      #    # Refund the full amount of a previously successful capture request
      #    response = gateway.refund(:full_amount, capture_response.authorization)
      #
      # ==== Full Example
      #
      #    gateway = ActiveMerchant::Billing::SecureCoGateway.new(
      #      username: 'yourusername',
      #      password: 'somepassword',
      #      merchant_account_id: '00000000-0000-0000-0000-000000000000'
      #    )
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
        unless trans_mapping.key? original_transaction_type
          raise ArgumentError.new("Can't refund \"#{original_transaction_type}\". Must be one of: #{trans_mapping.keys}")
        end
        raise ArgumentError.new("Couldn't determine original transaction id") unless original_transaction_id

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
      # * +authorization+  -- Mandatory. The authorization credentials produced by a successful +purchase+, +authorize+
      #                       or +capture+ request.
      # * +options+        -- Optional. A hash of options. See below.
      #
      # ==== Options
      #
      # * +:request_id+    -- This is the customer generated request identifier. If a request_id is not provided, one
      #                       will be generated for you. If it is provided, it must be unique. Attempting to re-use a
      #                       request_id will result in a processing error.
      # * +:custom_fields+ -- A hash or 2d array of key-value pairs to attach to the request. If any custom fields were
      #                       provided in the preceding steps they will be merged, with void key/values taking
      #                       precedence.
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
        unless trans_mapping.key? original_transaction_type
          raise ArgumentError.new("Can't void \"#{original_transaction_type}\". Must be one of: #{trans_mapping.keys}")
        end
        raise ArgumentError.new("Couldn't determine original transaction id") unless original_transaction_id

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
      # * +payment_method+ -- Mandatory. A valid instance of +ActiveMerchant::Billing::CreditCard+, or a String token
      #                       obtained from a previous +store+ operation.
      # * +options+        -- Optional. See the description of the +options+ parameter in the documentation for the
      #                       +authorize+ and +void+ methods.
      #
      # ==== Minimal Example
      #
      #    response = gateway.verify(credit_card)
      #    puts "Credit card is valid" if response.success?
      #
      def verify(payment_method, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, payment_method, options) }
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
      # * +transcript+  -- Mandatory. The HTTP transcript.
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
      #    gateway = ActiveMerchant::Billing::SecureCoGateway.new(
      #      username: 'yourusername',
      #      password: 'somepassword',
      #      merchant_account_id: '00000000-0000-0000-0000-000000000000'
      #    )
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
      #      ->(prev_response) { gateway.authorize(
      #         1000,
      #         credit_card,
      #         custom_fields: {
      #           test1: "aut",
      #           test2: "aut"
      #         }
      #      )},
      #      ->(prev_response) { gateway.capture(
      #         :full_amount,
      #         prev_response.authorization,
      #         custom_fields: {
      #           test1: "cap",
      #           test3: "cap"
      #         }
      #      )},
      #      ->(prev_response) { gateway.refund(
      #         800,
      #         prev_response.authorization,
      #         custom_fields: {
      #           test1: "ref",
      #           test4: "ref"
      #         }
      #      )},
      #    ].reduce([]) do |r, req_gen|
      #      r << req_gen.call(r.last)
      #    end.map do |response|
      #      gateway.get_payment_status_by_transaction_id response.params["transaction_id"]
      #    end.each do |response|
      #      pp response.params.slice *[
      #        'transaction_type',
      #        'transaction_state',
      #        'completion_time_stamp',
      #        'transaction_id',
      #        'request_id',
      #        'custom_fields',
      #      ]
      #    end
      #
      #    # => {"transaction_type"=>"authorization",
      #    #  "transaction_state"=>"success",
      #    #  "completion_time_stamp"=>"2017-02-10T01:04:01.000Z",
      #    #  "transaction_id"=>"4e58e9c5-bd7c-496a-b238-89ba33568331",
      #    #  "request_id"=>"52321770e70b7c8b6263348f70d1ae5b",
      #    #  "custom_fields"=>{"test1"=>"aut", "test2"=>"aut"}}
      #    # {"transaction_type"=>"capture-authorization",
      #    #  "transaction_state"=>"success",
      #    #  "completion_time_stamp"=>"2017-02-10T01:04:03.000Z",
      #    #  "transaction_id"=>"74c807d0-c1d6-4854-8657-0586352993a1",
      #    #  "request_id"=>"4af5fad6620be2cb6ff1f06e2916d6b2",
      #    #  "custom_fields"=>{"test1"=>"cap", "test3"=>"cap", "test2"=>"aut"}}
      #    # {"transaction_type"=>"refund-capture",
      #    #  "transaction_state"=>"success",
      #    #  "completion_time_stamp"=>"2017-02-10T01:04:05.000Z",
      #    #  "transaction_id"=>"7fa112bb-1478-4947-bc1d-1b13f4b3c078",
      #    #  "request_id"=>"3ce8219372d3615d8e5530d2faf5d3f6",
      #    #  "custom_fields"=>{"test1"=>"ref", "test4"=>"ref", "test3"=>"cap", "test2"=>"aut"}}
      #
      def get_payment_status_by_transaction_id(transaction_id)
        uri = URI url
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
      #    # Alternatively, the gateway will always block duplicate request_ids, so trying to place the order again with
      #    # the same request_id will indirectly indicate if the original request made it to the gateway.
      #
      def get_payment_status_by_request_id(request_id)
        uri = URI url
        uri.path = '/engine/rest/merchants/%s/payments/search' % @options[:merchant_account_id]
        uri.query = 'payment.request-id=%s' % request_id
        create_response(parse(ssl_get(uri, headers)))
      end

      private

      def url
        test? ? test_url : live_url
      end

      def headers
        {
          'Content-Type' => 'application/xml',
          'Authorization' => ('Basic ' + Base64.strict_encode64("#{@options[:username]}:#{@options[:password]}").strip),
        }
      end

      def parse(body)
        parsed = Hash.from_xml(body)
        unless parsed.key? 'payment'
          raise "Invalid response from gateway"
        end

        parsed = parsed['payment']

        if parsed.key? 'custom_fields'
          parsed['custom_fields'] = parsed['custom_fields']['custom_field'].map do |field|
            field.values_at 'field_name', 'field_value'
          end.to_h
        end

        parsed
      end

      def commit(xml_request)
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
        response['transaction_state'] == 'success'
      end

      def message_from(response)
        response['statuses']['status']['description']
      end

      def authorization_from(response)
        if response['transaction_type'] == 'tokenize'
          if response.key? 'card_token'
            response['card_token']['token_id']
          else
            nil
          end
        else
          response.values_at('transaction_type', 'transaction_id').join ?|
        end
      end

      def error_code_from(response)
        unless success_from(response)
          STANDARD_ERROR_CODE[ERROR_CODE_MAPPING[response['statuses']['status']['code']] || DEFAULT_ERROR_CODE]
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

      def add_request_id(xml, request_id)
        xml.send('request-id', request_id || generate_unique_id)
      end

      def add_order_id(xml, order_id)
        xml.send('order-number', order_id)
      end

      def add_ip_address(xml, ip_address)
        xml.send('ip-address', ip_address)
      end

      def add_parent_transaction_id(xml, parent_transaction_id)
        xml.send('parent-transaction-id', parent_transaction_id)
      end

      def add_authorization_code(xml, authorization_code)
        xml.send('authorization-code', authorization_code)
      end

      def add_merchant_account_id(xml)
        xml.send('merchant-account-id', @options[:merchant_account_id])
      end

      def add_requested_amount(xml, value, currency)
        xml.send('requested-amount', value, currency: (currency || default_currency))
      end

      def add_account_holder(xml, payment_method, email)
        xml.send('account-holder') do
          if payment_method.is_a? CreditCard
            xml.send('first-name', payment_method.first_name)
            xml.send('last-name',  payment_method.last_name)
          end
          xml.send('email', email) if email
        end
      end

      def add_payment_method(xml, payment_method)
        case payment_method
        when String
          xml.send('card-token') do
            xml.send('token-id', payment_method)
          end
        when CreditCard
          card_type = BRAND_MAPPING[payment_method.brand]
          if card_type.nil?
            raise ArgumentError.new(
              "Invalid card brand: \"#{payment_method.brand}\". Must be one of: #{BRAND_MAPPING.keys}"
            )
          end

          xml.send('card') do
            xml.send('account-number',     payment_method.number)
            xml.send('card-security-code', payment_method.verification_value)
            xml.send('card-type',          card_type)
            xml.send('expiration-month',   "%02d" % payment_method.month)
            xml.send('expiration-year',    payment_method.year)
          end
        else
          raise ArgumentError.new(
            "Invalid payment method: \"#{payment_method.class}\". Must be a \"String\" (card token) or \"CreditCard\""
          )
        end
      end

      def add_entry_mode(xml, entry_mode)
        entry_mode = options[:entry_mode] || DEFAULT_ENTRY_MODE
        unless ENTRY_MODES.include? entry_mode
          raise ArgumentError.new("Invalid entry mode: \"#{entry_mode}\". Must be one of: #{ENTRY_MODES}")
        end
        xml.send('entry-mode', entry_mode)
      end

      def add_custom_fields(xml, custom_fields)
        unless [Hash, Array].any? { |klass| custom_fields.is_a? klass }
          raise ArgumentError.new(
            "Invalid custom fields: \"#{custom_fields.class}\". Must be a Hash or Array of Arrays"
          )
        end
        xml.send('custom-fields') do
          custom_fields.each do |key, value|
            xml.send('custom-field', 'field-name' => key, 'field-value' => value)
          end
        end
      end

      def add_transaction_type(xml, transaction_type)
        unless TRANSACTION_TYPES.include? transaction_type
          raise ArgumentError.new(
            "Invalid transaction type: \"#{transaction_type}\". Must be one of: #{TRANSACTION_TYPES}"
          )
        end
        xml.send('transaction-type', transaction_type)
      end
    end
  end
end
