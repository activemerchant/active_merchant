require 'active_merchant/billing/gateways/braintree/braintree_common'
require 'active_support/core_ext/array/extract_options'

begin
  require 'braintree'
rescue LoadError
  raise 'Could not load the braintree gem.  Use `gem install braintree` to install it.'
end

raise "Need braintree gem >= 2.78.0. Run `gem install braintree --version '~>2.78'` to get the correct version." unless Braintree::Version::Major == 2 && Braintree::Version::Minor >= 78

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # For more information on the Braintree Gateway please visit their
    # {Developer Portal}[https://www.braintreepayments.com/developers]
    #
    # ==== About this implementation
    #
    # This implementation leverages the Braintree-authored ruby gem:
    # https://github.com/braintree/braintree_ruby
    #
    # ==== Debugging Information
    #
    # Setting an ActiveMerchant +wiredump_device+ will automatically
    # configure the Braintree logger (via the Braintree gem's
    # configuration) when the BraintreeBlueGateway is instantiated.
    # Additionally, the log level will be set to +DEBUG+. Therefore,
    # all you have to do is set the +wiredump_device+ and you'll get
    # your debug output from your HTTP interactions with the remote
    # gateway. (Don't enable this in production.) The ActiveMerchant
    # implementation doesn't mess with the Braintree::Configuration
    # globals at all, so there won't be any side effects outside
    # Active Merchant.
    #
    # If no +wiredump_device+ is set, the logger in
    # +Braintree::Configuration.logger+ will be cloned and the log
    # level set to +WARN+.
    #
    class BraintreeBlueGateway < Gateway
      include BraintreeCommon
      include Empty

      self.display_name = 'Braintree (Blue Platform)'

      ERROR_CODES = {
        cannot_refund_if_unsettled: 91506
      }

      def initialize(options = {})
        requires!(options, :merchant_id, :public_key, :private_key)
        @merchant_account_id = options[:merchant_account_id]

        super

        if wiredump_device.present?
          logger = (Logger === wiredump_device ? wiredump_device : Logger.new(wiredump_device))
          logger.level = Logger::DEBUG
        else
          logger = Braintree::Configuration.logger.clone
          logger.level = Logger::WARN
        end

        @configuration = Braintree::Configuration.new(
          merchant_id: options[:merchant_id],
          public_key: options[:public_key],
          private_key: options[:private_key],
          environment: (options[:environment] || (test? ? :sandbox : :production)).to_sym,
          custom_user_agent: "ActiveMerchant #{ActiveMerchant::VERSION}",
          logger: options[:logger] || logger
        )

        @braintree_gateway = Braintree::Gateway.new(@configuration)
      end

      def authorize(money, credit_card_or_vault_id, options = {})
        create_transaction(:sale, money, credit_card_or_vault_id, options)
      end

      def capture(money, authorization, options = {})
        commit do
          result = @braintree_gateway.transaction.submit_for_settlement(authorization, localized_amount(money, options[:currency] || default_currency).to_s)
          response_from_result(result)
        end
      end

      def purchase(money, credit_card_or_vault_id, options = {})
        authorize(money, credit_card_or_vault_id, options.merge(submit_for_settlement: true))
      end

      def credit(money, credit_card_or_vault_id, options = {})
        create_transaction(:credit, money, credit_card_or_vault_id, options)
      end

      def refund(*args)
        # legacy signature: #refund(transaction_id, options = {})
        # new signature: #refund(money, transaction_id, options = {})
        money, transaction_id, options = extract_refund_args(args)
        money = localized_amount(money, options[:currency] || default_currency).to_s if money

        commit do
          response = response_from_result(@braintree_gateway.transaction.refund(transaction_id, money))

          if !response.success? && options[:force_full_refund_if_unsettled] &&
             response.message =~ /#{ERROR_CODES[:cannot_refund_if_unsettled]}/
            void(transaction_id)
          else
            response
          end
        end
      end

      def void(authorization, options = {})
        commit do
          response_from_result(@braintree_gateway.transaction.void(authorization))
        end
      end

      def verify(credit_card, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def store(creditcard, options = {})
        if options[:customer].present?
          MultiResponse.new.tap do |r|
            customer_exists_response = nil
            r.process { customer_exists_response = check_customer_exists(options[:customer]) }
            r.process do
              if customer_exists_response.params['exists']
                add_credit_card_to_customer(creditcard, options)
              else
                add_customer_with_credit_card(creditcard, options)
              end
            end
          end
        else
          add_customer_with_credit_card(creditcard, options)
        end
      end

      def update(vault_id, creditcard, options = {})
        braintree_credit_card = nil
        commit do
          braintree_credit_card = @braintree_gateway.customer.find(vault_id).credit_cards.detect(&:default?)
          return Response.new(false, 'Braintree::NotFoundError') if braintree_credit_card.nil?

          options[:update_existing_token] = braintree_credit_card.token
          credit_card_params = merge_credit_card_options({
            credit_card: {
              cardholder_name: creditcard.name,
              number: creditcard.number,
              cvv: creditcard.verification_value,
              expiration_month: creditcard.month.to_s.rjust(2, '0'),
              expiration_year: creditcard.year.to_s
            }
          }, options)[:credit_card]

          result = @braintree_gateway.customer.update(vault_id,
            first_name: creditcard.first_name,
            last_name: creditcard.last_name,
            email: scrub_email(options[:email]),
            phone: options[:phone] || (options[:billing_address][:phone] if options[:billing_address] &&
              options[:billing_address][:phone]),
            credit_card: credit_card_params
          )
          Response.new(result.success?, message_from_result(result),
            braintree_customer: (customer_hash(@braintree_gateway.customer.find(vault_id), :include_credit_cards) if result.success?),
            customer_vault_id: (result.customer.id if result.success?)
          )
        end
      end

      def unstore(customer_vault_id, options = {})
        commit do
          if !customer_vault_id && options[:credit_card_token]
            @braintree_gateway.credit_card.delete(options[:credit_card_token])
          else
            @braintree_gateway.customer.delete(customer_vault_id)
          end
          Response.new(true, 'OK')
        end
      end
      alias_method :delete, :unstore

      def supports_network_tokenization?
        true
      end

      def verify_credentials
        begin
          @braintree_gateway.transaction.find('non_existent_token')
        rescue Braintree::AuthenticationError
          return false
        rescue Braintree::NotFoundError
          return true
        end

        true
      end

      private

      def check_customer_exists(customer_vault_id)
        commit do
          @braintree_gateway.customer.find(customer_vault_id)
          ActiveMerchant::Billing::Response.new(true, 'Customer found', {exists: true}, authorization: customer_vault_id)
        rescue Braintree::NotFoundError
          ActiveMerchant::Billing::Response.new(true, 'Customer not found', {exists: false})
        end
      end

      def add_customer_with_credit_card(creditcard, options)
        commit do
          if options[:payment_method_nonce]
            credit_card_params = { payment_method_nonce: options[:payment_method_nonce] }
          else
            credit_card_params = {
              credit_card: {
                cardholder_name: creditcard.name,
                number: creditcard.number,
                cvv: creditcard.verification_value,
                expiration_month: creditcard.month.to_s.rjust(2, '0'),
                expiration_year: creditcard.year.to_s,
                token: options[:credit_card_token]
              }
            }
          end
          parameters = {
            first_name: creditcard.first_name,
            last_name: creditcard.last_name,
            email: scrub_email(options[:email]),
            phone: options[:phone] || (options[:billing_address][:phone] if options[:billing_address] &&
              options[:billing_address][:phone]),
            id: options[:customer],
            device_data: options[:device_data]
          }.merge credit_card_params
          result = @braintree_gateway.customer.create(merge_credit_card_options(parameters, options))
          Response.new(result.success?, message_from_result(result),
            {
              braintree_customer: (customer_hash(result.customer, :include_credit_cards) if result.success?),
              customer_vault_id: (result.customer.id if result.success?),
              credit_card_token: (result.customer.credit_cards[0].token if result.success?)
            },
            authorization: (result.customer.id if result.success?)
          )
        end
      end

      def add_credit_card_to_customer(credit_card, options)
        commit do
          parameters = {
            customer_id: options[:customer],
            token: options[:credit_card_token],
            cardholder_name: credit_card.name,
            number: credit_card.number,
            cvv: credit_card.verification_value,
            expiration_month: credit_card.month.to_s.rjust(2, '0'),
            expiration_year: credit_card.year.to_s,
            device_data: options[:device_data]
          }
          if options[:billing_address]
            address = map_address(options[:billing_address])
            parameters[:billing_address] = address unless address.all? { |_k, v| empty?(v) }
          end

          result = @braintree_gateway.credit_card.create(parameters)
          ActiveMerchant::Billing::Response.new(
            result.success?,
            message_from_result(result),
            {
              customer_vault_id: (result.credit_card.customer_id if result.success?),
              credit_card_token: (result.credit_card.token if result.success?)
            },
            authorization: (result.credit_card.customer_id if result.success?)
          )
        end
      end

      def scrub_email(email)
        return nil unless email.present?
        return nil if
          email !~ /^.+@[^\.]+(\.[^\.]+)+[a-z]$/i ||
          email =~ /\.(con|met)$/i

        email
      end

      def scrub_zip(zip)
        return nil unless zip.present?
        return nil if
          zip.gsub(/[^a-z0-9]/i, '').length > 9 ||
          zip =~ /[^a-z0-9\- ]/i

        zip
      end

      def merge_credit_card_options(parameters, options)
        valid_options = {}
        options.each do |key, value|
          valid_options[key] = value if %i[update_existing_token verify_card verification_merchant_account_id].include?(key)
        end

        valid_options[:verification_merchant_account_id] ||= @merchant_account_id if valid_options.include?(:verify_card) && @merchant_account_id

        parameters[:credit_card] ||= {}
        parameters[:credit_card][:options] = valid_options
        if options[:billing_address]
          address = map_address(options[:billing_address])
          parameters[:credit_card][:billing_address] = address unless address.all? { |_k, v| empty?(v) }
        end
        parameters
      end

      def map_address(address)
        mapped = {
          street_address: address[:address1],
          extended_address: address[:address2],
          company: address[:company],
          locality: address[:city],
          region: address[:state],
          postal_code: scrub_zip(address[:zip])
        }

        mapped[:country_code_alpha2] = (address[:country] || address[:country_code_alpha2]) if address[:country] || address[:country_code_alpha2]
        mapped[:country_name] = address[:country_name] if address[:country_name]
        mapped[:country_code_alpha3] = address[:country_code_alpha3] if address[:country_code_alpha3]
        mapped[:country_code_alpha3] ||= Country.find(address[:country]).code(:alpha3).value unless address[:country].blank?
        mapped[:country_code_numeric] = address[:country_code_numeric] if address[:country_code_numeric]

        mapped
      end

      def commit(&block)
        yield
      rescue Braintree::BraintreeError => ex
        Response.new(false, ex.class.to_s)
      end

      def message_from_result(result)
        if result.success?
          'OK'
        elsif result.errors.any?
          result.errors.map { |e| "#{e.message} (#{e.code})" }.join(' ')
        elsif result.credit_card_verification
          "Processor declined: #{result.credit_card_verification.processor_response_text} (#{result.credit_card_verification.processor_response_code})"
        else
          result.message.to_s
        end
      end

      def response_from_result(result)
        response_hash = { braintree_transaction: transaction_hash(result) }

        Response.new(
          result.success?,
          message_from_result(result),
          response_hash,
          authorization: result.transaction&.id,
          test: test?
        )
      end

      def response_params(result)
        params = {}
        params[:customer_vault_id] = result.transaction.customer_details.id if result.success?
        params[:braintree_transaction] = transaction_hash(result)
        params
      end

      def response_options(result)
        options = {}
        if result.transaction
          options[:authorization] = result.transaction.id
          options[:avs_result] = { code: avs_code_from(result.transaction) }
          options[:cvv_result] = result.transaction.cvv_response_code
        end
        options[:test] = test?
        options
      end

      def avs_code_from(transaction)
        transaction.avs_error_response_code ||
          avs_mapping["street: #{transaction.avs_street_address_response_code}, zip: #{transaction.avs_postal_code_response_code}"]
      end

      def avs_mapping
        {
          'street: M, zip: M' => 'M',
          'street: M, zip: N' => 'A',
          'street: M, zip: U' => 'B',
          'street: M, zip: I' => 'B',
          'street: M, zip: A' => 'B',

          'street: N, zip: M' => 'Z',
          'street: N, zip: N' => 'C',
          'street: N, zip: U' => 'C',
          'street: N, zip: I' => 'C',
          'street: N, zip: A' => 'C',

          'street: U, zip: M' => 'P',
          'street: U, zip: N' => 'N',
          'street: U, zip: U' => 'I',
          'street: U, zip: I' => 'I',
          'street: U, zip: A' => 'I',

          'street: I, zip: M' => 'P',
          'street: I, zip: N' => 'C',
          'street: I, zip: U' => 'I',
          'street: I, zip: I' => 'I',
          'street: I, zip: A' => 'I',

          'street: A, zip: M' => 'P',
          'street: A, zip: N' => 'C',
          'street: A, zip: U' => 'I',
          'street: A, zip: I' => 'I',
          'street: A, zip: A' => 'I',

          'street: B, zip: B' => 'B'
        }
      end

      def message_from_transaction_result(result)
        if result.transaction && result.transaction.status == 'gateway_rejected'
          'Transaction declined - gateway rejected'
        elsif result.transaction
          "#{result.transaction.processor_response_code} #{result.transaction.processor_response_text}"
        else
          message_from_result(result)
        end
      end

      def response_code_from_result(result)
        if result.transaction
          result.transaction.processor_response_code
        elsif result.errors.size == 0 && result.credit_card_verification
          result.credit_card_verification.processor_response_code
        elsif result.errors.size > 0
          result.errors.first.code
        end
      end

      def create_transaction(transaction_type, money, credit_card_or_vault_id, options)
        transaction_params = create_transaction_parameters(money, credit_card_or_vault_id, options)
        commit do
          result = @braintree_gateway.transaction.send(transaction_type, transaction_params)
          response = Response.new(result.success?, message_from_transaction_result(result), response_params(result), response_options(result))
          response.cvv_result['message'] = ''
          response
        end
      end

      def extract_refund_args(args)
        options = args.extract_options!

        # money, transaction_id, options
        if args.length == 1 # legacy signature
          return nil, args[0], options
        elsif args.length == 2
          return args[0], args[1], options
        else
          raise ArgumentError, "wrong number of arguments (#{args.length} for 2)"
        end
      end

      def customer_hash(customer, include_credit_cards=false)
        hash = {
          'email' => customer.email,
          'phone' => customer.phone,
          'first_name' => customer.first_name,
          'last_name' => customer.last_name,
          'id' => customer.id
        }

        if include_credit_cards
          hash['credit_cards'] = customer.credit_cards.map do |cc|
            {
              'bin' => cc.bin,
              'expiration_date' => cc.expiration_date,
              'token' => cc.token,
              'last_4' => cc.last_4,
              'card_type' => cc.card_type,
              'masked_number' => cc.masked_number
            }
          end
        end

        hash
      end

      def transaction_hash(result)
        return { 'processor_response_code' => response_code_from_result(result) } unless result.success?

        transaction = result.transaction
        if transaction.vault_customer
          vault_customer = {
          }
          vault_customer['credit_cards'] = transaction.vault_customer.credit_cards.map do |cc|
            {
              'bin' => cc.bin
            }
          end
        else
          vault_customer = nil
        end

        customer_details = {
          'id' => transaction.customer_details.id,
          'email' => transaction.customer_details.email,
          'phone' => transaction.customer_details.phone
        }

        billing_details = {
          'street_address'   => transaction.billing_details.street_address,
          'extended_address' => transaction.billing_details.extended_address,
          'company'          => transaction.billing_details.company,
          'locality'         => transaction.billing_details.locality,
          'region'           => transaction.billing_details.region,
          'postal_code'      => transaction.billing_details.postal_code,
          'country_name'     => transaction.billing_details.country_name
        }

        shipping_details = {
          'street_address'   => transaction.shipping_details.street_address,
          'extended_address' => transaction.shipping_details.extended_address,
          'company'          => transaction.shipping_details.company,
          'locality'         => transaction.shipping_details.locality,
          'region'           => transaction.shipping_details.region,
          'postal_code'      => transaction.shipping_details.postal_code,
          'country_name'     => transaction.shipping_details.country_name
        }
        credit_card_details = {
          'masked_number'       => transaction.credit_card_details.masked_number,
          'bin'                 => transaction.credit_card_details.bin,
          'last_4'              => transaction.credit_card_details.last_4,
          'card_type'           => transaction.credit_card_details.card_type,
          'token'               => transaction.credit_card_details.token
        }

        if transaction.risk_data
          risk_data = {
            'id'                      => transaction.risk_data.id,
            'decision'                => transaction.risk_data.decision,
            'device_data_captured'    => transaction.risk_data.device_data_captured,
            'fraud_service_provider'  => transaction.risk_data.fraud_service_provider
          }
        else
          risk_data = nil
        end

        {
          'order_id'                => transaction.order_id,
          'amount'                  => transaction.amount.to_s,
          'status'                  => transaction.status,
          'credit_card_details'     => credit_card_details,
          'customer_details'        => customer_details,
          'billing_details'         => billing_details,
          'shipping_details'        => shipping_details,
          'vault_customer'          => vault_customer,
          'merchant_account_id'     => transaction.merchant_account_id,
          'risk_data'               => risk_data,
          'network_transaction_id'  => transaction.network_transaction_id || nil,
          'processor_response_code' => response_code_from_result(result)
        }
      end

      def create_transaction_parameters(money, credit_card_or_vault_id, options)
        parameters = {
          amount: localized_amount(money, options[:currency] || default_currency).to_s,
          order_id: options[:order_id],
          customer: {
            id: options[:store] == true ? '' : options[:store],
            email: scrub_email(options[:email]),
            phone: options[:phone] || (options[:billing_address][:phone] if options[:billing_address] &&
              options[:billing_address][:phone])
          },
          options: {
            store_in_vault: options[:store] ? true : false,
            submit_for_settlement: options[:submit_for_settlement],
            hold_in_escrow: options[:hold_in_escrow]
          }
        }

        parameters[:custom_fields] = options[:custom_fields]
        parameters[:device_data] = options[:device_data] if options[:device_data]
        parameters[:service_fee_amount] = options[:service_fee_amount] if options[:service_fee_amount]

        add_skip_options(parameters, options)
        add_merchant_account_id(parameters, options)

        add_payment_method(parameters, credit_card_or_vault_id, options)
        add_stored_credential_data(parameters, credit_card_or_vault_id, options)
        add_addresses(parameters, options)

        add_descriptor(parameters, options)
        add_travel_data(parameters, options) if options[:travel_data]
        add_lodging_data(parameters, options) if options[:lodging_data]
        add_channel(parameters, options)
        add_transaction_source(parameters, options)

        add_level_2_data(parameters, options)
        add_level_3_data(parameters, options)

        add_3ds_info(parameters, options[:three_d_secure])

        if options[:payment_method_nonce].is_a?(String)
          parameters.delete(:customer)
          parameters[:payment_method_nonce] = options[:payment_method_nonce]
        end

        parameters
      end

      def add_skip_options(parameters, options)
        parameters[:options][:skip_advanced_fraud_checking] = options[:skip_advanced_fraud_checking] if options[:skip_advanced_fraud_checking]
        parameters[:options][:skip_avs] = options[:skip_avs] if options[:skip_avs]
        parameters[:options][:skip_cvv] = options[:skip_cvv] if options[:skip_cvv]
      end

      def add_merchant_account_id(parameters, options)
        return unless merchant_account_id = (options[:merchant_account_id] || @merchant_account_id)

        parameters[:merchant_account_id] = merchant_account_id
      end

      def add_transaction_source(parameters, options)
        parameters[:transaction_source] = options[:transaction_source] if options[:transaction_source]
        parameters[:transaction_source] = 'recurring' if options[:recurring]
      end

      def add_addresses(parameters, options)
        parameters[:billing] = map_address(options[:billing_address]) if options[:billing_address]
        parameters[:shipping] = map_address(options[:shipping_address]) if options[:shipping_address]
      end

      def add_channel(parameters, options)
        channel = @options[:channel] || application_id
        parameters[:channel] = channel if channel
      end

      def add_descriptor(parameters, options)
        return unless options[:descriptor_name] || options[:descriptor_phone] || options[:descriptor_url]

        parameters[:descriptor] = {
          name: options[:descriptor_name],
          phone: options[:descriptor_phone],
          url: options[:descriptor_url]
        }
      end

      def add_level_2_data(parameters, options)
        parameters[:tax_amount] = options[:tax_amount] if options[:tax_amount]
        parameters[:tax_exempt] = options[:tax_exempt] if options[:tax_exempt]
        parameters[:purchase_order_number] = options[:purchase_order_number] if options[:purchase_order_number]
      end

      def add_level_3_data(parameters, options)
        parameters[:shipping_amount] = options[:shipping_amount] if options[:shipping_amount]
        parameters[:discount_amount] = options[:discount_amount] if options[:discount_amount]
        parameters[:ships_from_postal_code] = options[:ships_from_postal_code] if options[:ships_from_postal_code]

        parameters[:line_items] = options[:line_items] if options[:line_items]
      end

      def add_travel_data(parameters, options)
        parameters[:industry] = {
          industry_type:  Braintree::Transaction::IndustryType::TravelAndCruise,
          data: {}
        }

        parameters[:industry][:data][:travel_package] = options[:travel_data][:travel_package] if options[:travel_data][:travel_package]
        parameters[:industry][:data][:departure_date] = options[:travel_data][:departure_date] if options[:travel_data][:departure_date]
        parameters[:industry][:data][:lodging_check_in_date] = options[:travel_data][:lodging_check_in_date] if options[:travel_data][:lodging_check_in_date]
        parameters[:industry][:data][:lodging_check_out_date] = options[:travel_data][:lodging_check_out_date] if options[:travel_data][:lodging_check_out_date]
        parameters[:industry][:data][:lodging_name] = options[:travel_data][:lodging_name] if options[:travel_data][:lodging_name]
      end

      def add_lodging_data(parameters, options)
        parameters[:industry] = {
          industry_type: Braintree::Transaction::IndustryType::Lodging,
          data: {}
        }

        parameters[:industry][:data][:folio_number] = options[:lodging_data][:folio_number] if options[:lodging_data][:folio_number]
        parameters[:industry][:data][:check_in_date] = options[:lodging_data][:check_in_date] if options[:lodging_data][:check_in_date]
        parameters[:industry][:data][:check_out_date] = options[:lodging_data][:check_out_date] if options[:lodging_data][:check_out_date]
        parameters[:industry][:data][:room_rate] = options[:lodging_data][:room_rate] if options[:lodging_data][:room_rate]
      end

      def add_3ds_info(parameters, three_d_secure_opts)
        return if empty?(three_d_secure_opts)

        pass_thru = {}

        pass_thru[:three_d_secure_version] = three_d_secure_opts[:version] if three_d_secure_opts[:version]
        pass_thru[:eci_flag] = three_d_secure_opts[:eci] if three_d_secure_opts[:eci]
        pass_thru[:cavv_algorithm] = three_d_secure_opts[:cavv_algorithm] if three_d_secure_opts[:cavv_algorithm]
        pass_thru[:cavv] = three_d_secure_opts[:cavv] if three_d_secure_opts[:cavv]
        pass_thru[:directory_response] = three_d_secure_opts[:directory_response_status] if three_d_secure_opts[:directory_response_status]
        pass_thru[:authentication_response] = three_d_secure_opts[:authentication_response_status] if three_d_secure_opts[:authentication_response_status]

        parameters[:three_d_secure_pass_thru] = pass_thru.merge(xid_or_ds_trans_id(three_d_secure_opts))
      end

      def xid_or_ds_trans_id(three_d_secure_opts)
        if three_d_secure_opts[:version].to_f >= 2
          { ds_transaction_id: three_d_secure_opts[:ds_transaction_id] }
        else
          { xid: three_d_secure_opts[:xid] }
        end
      end

      def add_stored_credential_data(parameters, credit_card_or_vault_id, options)
        return unless (stored_credential = options[:stored_credential])

        parameters[:external_vault] = {}
        if stored_credential[:initial_transaction]
          parameters[:external_vault][:status] = 'will_vault'
        else
          parameters[:external_vault][:status] = 'vaulted'
          parameters[:external_vault][:previous_network_transaction_id] = stored_credential[:network_transaction_id]
        end
        if stored_credential[:initiator] == 'merchant'
          if stored_credential[:reason_type] == 'installment'
            parameters[:transaction_source] = 'recurring'
          else
            parameters[:transaction_source] = stored_credential[:reason_type]
          end
        else
          parameters[:transaction_source] = ''
        end
      end

      def add_payment_method(parameters, credit_card_or_vault_id, options)
        if credit_card_or_vault_id.is_a?(String) || credit_card_or_vault_id.is_a?(Integer)
          if options[:payment_method_token]
            parameters[:payment_method_token] = credit_card_or_vault_id
            options.delete(:billing_address)
          elsif options[:payment_method_nonce]
            parameters[:payment_method_nonce] = credit_card_or_vault_id
          else
            parameters[:customer_id] = credit_card_or_vault_id
          end
        else
          parameters[:customer].merge!(
            first_name: credit_card_or_vault_id.first_name,
            last_name: credit_card_or_vault_id.last_name
          )
          if credit_card_or_vault_id.is_a?(NetworkTokenizationCreditCard)
            if credit_card_or_vault_id.source == :apple_pay
              parameters[:apple_pay_card] = {
                number: credit_card_or_vault_id.number,
                expiration_month: credit_card_or_vault_id.month.to_s.rjust(2, '0'),
                expiration_year: credit_card_or_vault_id.year.to_s,
                cardholder_name: credit_card_or_vault_id.name,
                cryptogram: credit_card_or_vault_id.payment_cryptogram,
                eci_indicator: credit_card_or_vault_id.eci
              }
            elsif credit_card_or_vault_id.source == :android_pay || credit_card_or_vault_id.source == :google_pay
              parameters[:android_pay_card] = {
                number: credit_card_or_vault_id.number,
                cryptogram: credit_card_or_vault_id.payment_cryptogram,
                expiration_month: credit_card_or_vault_id.month.to_s.rjust(2, '0'),
                expiration_year: credit_card_or_vault_id.year.to_s,
                google_transaction_id: credit_card_or_vault_id.transaction_id,
                source_card_type: credit_card_or_vault_id.brand,
                source_card_last_four: credit_card_or_vault_id.last_digits,
                eci_indicator: credit_card_or_vault_id.eci
              }
            end
          else
            parameters[:credit_card] = {
              number: credit_card_or_vault_id.number,
              cvv: credit_card_or_vault_id.verification_value,
              expiration_month: credit_card_or_vault_id.month.to_s.rjust(2, '0'),
              expiration_year: credit_card_or_vault_id.year.to_s,
              cardholder_name: credit_card_or_vault_id.name
            }
          end
        end
      end
    end
  end
end
