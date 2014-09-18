require File.dirname(__FILE__) + '/braintree/braintree_common'

begin
  require "braintree"
rescue LoadError
  raise "Could not load the braintree gem.  Use `gem install braintree` to install it."
end

raise "Need braintree gem 2.x.y. Run `gem install braintree --version '~>2.0'` to get the correct version." unless Braintree::Version::Major == 2

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

      self.display_name = 'Braintree (Blue Platform)'

      def initialize(options = {})
        requires!(options, :merchant_id, :public_key, :private_key)
        @merchant_account_id = options[:merchant_account_id]

        super

        if wiredump_device
          logger = ((Logger === wiredump_device) ? wiredump_device : Logger.new(wiredump_device))
          logger.level = Logger::DEBUG
        else
          logger = Braintree::Configuration.logger.clone
          logger.level = Logger::WARN
        end

        @configuration = Braintree::Configuration.new(
          :merchant_id       => options[:merchant_id],
          :public_key        => options[:public_key],
          :private_key       => options[:private_key],
          :environment       => (options[:environment] || (test? ? :sandbox : :production)).to_sym,
          :custom_user_agent => "ActiveMerchant #{ActiveMerchant::VERSION}",
          :logger            => logger,
        )

        @braintree_gateway = Braintree::Gateway.new( @configuration )
      end

      def authorize(money, credit_card_or_vault_id, options = {})
        create_transaction(:sale, money, credit_card_or_vault_id, options)
      end

      def capture(money, authorization, options = {})
        commit do
          result = @braintree_gateway.transaction.submit_for_settlement(authorization, amount(money).to_s)
          response_from_result(result)
        end
      end

      def purchase(money, credit_card_or_vault_id, options = {})
        authorize(money, credit_card_or_vault_id, options.merge(:submit_for_settlement => true))
      end

      def credit(money, credit_card_or_vault_id, options = {})
        create_transaction(:credit, money, credit_card_or_vault_id, options)
      end

      def refund(*args)
        # legacy signature: #refund(transaction_id, options = {})
        # new signature: #refund(money, transaction_id, options = {})
        money, transaction_id, _ = extract_refund_args(args)
        money = amount(money).to_s if money

        commit do
          response_from_result(@braintree_gateway.transaction.refund(transaction_id, money))
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
            r.process{customer_exists_response = check_customer_exists(options[:customer])}
            r.process do
              if customer_exists_response.params["exists"]
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
          braintree_credit_card = @braintree_gateway.customer.find(vault_id).credit_cards.detect { |cc| cc.default? }
          return Response.new(false, 'Braintree::NotFoundError') if braintree_credit_card.nil?

          options.merge!(:update_existing_token => braintree_credit_card.token)
          credit_card_params = merge_credit_card_options({
            :credit_card => {
              :cardholder_name => creditcard.name,
              :number => creditcard.number,
              :cvv => creditcard.verification_value,
              :expiration_month => creditcard.month.to_s.rjust(2, "0"),
              :expiration_year => creditcard.year.to_s
            }
          }, options)[:credit_card]

          result = @braintree_gateway.customer.update(vault_id,
            :first_name => creditcard.first_name,
            :last_name => creditcard.last_name,
            :email => scrub_email(options[:email]),
            :credit_card => credit_card_params
          )
          Response.new(result.success?, message_from_result(result),
            :braintree_customer => (customer_hash(@braintree_gateway.customer.find(vault_id), :include_credit_cards) if result.success?),
            :customer_vault_id => (result.customer.id if result.success?)
          )
        end
      end

      def unstore(customer_vault_id, options = {})
        commit do
          if(!customer_vault_id && options[:credit_card_token])
            @braintree_gateway.credit_card.delete(options[:credit_card_token])
          else
            @braintree_gateway.customer.delete(customer_vault_id)
          end
          Response.new(true, "OK")
        end
      end
      alias_method :delete, :unstore

      private

      def check_customer_exists(customer_vault_id)
        commit do
          begin
            @braintree_gateway.customer.find(customer_vault_id)
            ActiveMerchant::Billing::Response.new(true, "Customer found", {exists: true}, authorization: customer_vault_id)
          rescue Braintree::NotFoundError
            ActiveMerchant::Billing::Response.new(true, "Customer not found", {exists: false})
          end
        end
      end

      def add_customer_with_credit_card(creditcard, options)
        commit do
          parameters = {
            :first_name => creditcard.first_name,
            :last_name => creditcard.last_name,
            :email => scrub_email(options[:email]),
            :id => options[:customer],
            :credit_card => {
              :cardholder_name => creditcard.name,
              :number => creditcard.number,
              :cvv => creditcard.verification_value,
              :expiration_month => creditcard.month.to_s.rjust(2, "0"),
              :expiration_year => creditcard.year.to_s,
              :token => options[:credit_card_token]
            }
          }
          result = @braintree_gateway.customer.create(merge_credit_card_options(parameters, options))
          Response.new(result.success?, message_from_result(result),
            {
              :braintree_customer => (customer_hash(result.customer, :include_credit_cards) if result.success?),
              :customer_vault_id => (result.customer.id if result.success?),
              :credit_card_token => (result.customer.credit_cards[0].token if result.success?)
            },
            :authorization => (result.customer.id if result.success?)
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
            expiration_month: credit_card.month.to_s.rjust(2, "0"),
            expiration_year: credit_card.year.to_s,
          }
          parameters[:billing_address] = map_address(options[:billing_address]) if options[:billing_address]

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
        return nil if (
          email !~ /^.+@[^\.]+(\.[^\.]+)+[a-z]$/i ||
          email =~ /\.(con|met)$/i
        )
        email
      end

      def scrub_zip(zip)
        return nil unless zip.present?
        return nil if(
          zip.gsub(/[^a-z0-9]/i, '').length > 9 ||
          zip =~ /[^a-z0-9\- ]/i
        )
        zip
      end

      def merge_credit_card_options(parameters, options)
        valid_options = {}
        options.each do |key, value|
          valid_options[key] = value if [:update_existing_token, :verify_card, :verification_merchant_account_id].include?(key)
        end

        if valid_options.include?(:verify_card) && @merchant_account_id
          valid_options[:verification_merchant_account_id] ||= @merchant_account_id
        end

        parameters[:credit_card] ||= {}
        parameters[:credit_card].merge!(:options => valid_options)
        parameters[:credit_card][:billing_address] = map_address(options[:billing_address]) if options[:billing_address]
        parameters
      end

      def map_address(address)
        return {} if address.nil?
        mapped = {
          :street_address => address[:address1],
          :extended_address => address[:address2],
          :company => address[:company],
          :locality => address[:city],
          :region => address[:state],
          :postal_code => scrub_zip(address[:zip]),
        }
        if(address[:country] || address[:country_code_alpha2])
          mapped[:country_code_alpha2] = (address[:country] || address[:country_code_alpha2])
        elsif address[:country_name]
          mapped[:country_name] = address[:country_name]
        elsif address[:country_code_alpha3]
          mapped[:country_code_alpha3] = address[:country_code_alpha3]
        elsif address[:country_code_numeric]
          mapped[:country_code_numeric] = address[:country_code_numeric]
        end
        mapped
      end

      def commit(&block)
        yield
      rescue Braintree::BraintreeError => ex
        Response.new(false, ex.class.to_s)
      end

      def message_from_result(result)
        if result.success?
          "OK"
        elsif result.errors.size == 0 && result.credit_card_verification
          "Processor declined: #{result.credit_card_verification.processor_response_text} (#{result.credit_card_verification.processor_response_code})"
        else
          result.errors.map { |e| "#{e.message} (#{e.code})" }.join(" ")
        end
      end

      def response_from_result(result)
        Response.new(result.success?, message_from_result(result),
          { braintree_transaction: (transaction_hash(result.transaction) if result.success?) },
          { authorization: (result.transaction.id if result.success?) }
         )
      end

      def response_params(result)
        params = {}
        if result.success?
          params[:braintree_transaction] = transaction_hash(result.transaction)
          params[:customer_vault_id] = result.transaction.customer_details.id
        end
        params
      end

      def response_options(result)
        options = {}
        if result.success?
          options[:authorization] = result.transaction.id
        end
        if result.transaction
          options[:avs_result] = {
            :code => nil, :message => nil,
            :street_match => result.transaction.avs_street_address_response_code,
            :postal_match => result.transaction.avs_postal_code_response_code
          }
          options[:cvv_result] = result.transaction.cvv_response_code
        end
        options
      end

      def message_from_transaction_result(result)
        if result.transaction && result.transaction.status == "gateway_rejected"
          "Transaction declined - gateway rejected"
        elsif result.transaction
          "#{result.transaction.processor_response_code} #{result.transaction.processor_response_text}"
        else
          message_from_result(result)
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
          "email" => customer.email,
          "first_name" => customer.first_name,
          "last_name" => customer.last_name,
          "id" => customer.id
        }

        if include_credit_cards
          hash["credit_cards"] = customer.credit_cards.map do |cc|
            {
              "bin" => cc.bin,
              "expiration_date" => cc.expiration_date,
              "token" => cc.token,
              "last_4" => cc.last_4,
              "card_type" => cc.card_type,
              "masked_number" => cc.masked_number,
              "token" => cc.token
            }
          end
        end

        hash
      end

      def transaction_hash(transaction)
        if transaction.vault_customer
          vault_customer = {
          }
          vault_customer["credit_cards"] = transaction.vault_customer.credit_cards.map do |cc|
            {
              "bin" => cc.bin
            }
          end
        else
          vault_customer = nil
        end

        customer_details = {
          "id" => transaction.customer_details.id,
          "email" => transaction.customer_details.email
        }

        billing_details = {
          "street_address"   => transaction.billing_details.street_address,
          "extended_address" => transaction.billing_details.extended_address,
          "company"          => transaction.billing_details.company,
          "locality"         => transaction.billing_details.locality,
          "region"           => transaction.billing_details.region,
          "postal_code"      => transaction.billing_details.postal_code,
          "country_name"     => transaction.billing_details.country_name,
        }

        shipping_details = {
          "street_address"   => transaction.shipping_details.street_address,
          "extended_address" => transaction.shipping_details.extended_address,
          "company"          => transaction.shipping_details.company,
          "locality"         => transaction.shipping_details.locality,
          "region"           => transaction.shipping_details.region,
          "postal_code"      => transaction.shipping_details.postal_code,
          "country_name"     => transaction.shipping_details.country_name,
        }
        credit_card_details = {
          "masked_number"       => transaction.credit_card_details.masked_number,
          "bin"                 => transaction.credit_card_details.bin,
          "last_4"              => transaction.credit_card_details.last_4,
          "card_type"           => transaction.credit_card_details.card_type,
          "token"               => transaction.credit_card_details.token
        }

        {
          "order_id"            => transaction.order_id,
          "status"              => transaction.status,
          "credit_card_details" => credit_card_details,
          "customer_details"    => customer_details,
          "billing_details"     => billing_details,
          "shipping_details"    => shipping_details,
          "vault_customer"      => vault_customer,
          "merchant_account_id" => transaction.merchant_account_id
        }
      end

      def create_transaction_parameters(money, credit_card_or_vault_id, options)
        parameters = {
          :amount => amount(money).to_s,
          :order_id => options[:order_id],
          :customer => {
            :id => options[:store] == true ? "" : options[:store],
            :email => scrub_email(options[:email])
          },
          :options => {
            :store_in_vault => options[:store] ? true : false,
            :submit_for_settlement => options[:submit_for_settlement]
          }
        }

        parameters[:custom_fields] = options[:custom_fields]
        parameters[:device_data] = options[:device_data] if options[:device_data]
        if merchant_account_id = (options[:merchant_account_id] || @merchant_account_id)
          parameters[:merchant_account_id] = merchant_account_id
        end

        if options[:recurring]
          parameters[:recurring] = true
        end

        if credit_card_or_vault_id.is_a?(String) || credit_card_or_vault_id.is_a?(Integer)
          if options[:payment_method_token]
            parameters[:payment_method_token] = credit_card_or_vault_id
          else
            parameters[:customer_id] = credit_card_or_vault_id
          end
        else
          parameters[:customer].merge!(
            :first_name => credit_card_or_vault_id.first_name,
            :last_name => credit_card_or_vault_id.last_name
          )
          parameters[:credit_card] = {
            :number => credit_card_or_vault_id.number,
            :cvv => credit_card_or_vault_id.verification_value,
            :expiration_month => credit_card_or_vault_id.month.to_s.rjust(2, "0"),
            :expiration_year => credit_card_or_vault_id.year.to_s
          }
        end
        parameters[:billing] = map_address(options[:billing_address]) if options[:billing_address] && !options[:payment_method_token]
        parameters[:shipping] = map_address(options[:shipping_address]) if options[:shipping_address]
        parameters[:channel] = application_id if application_id.present? && application_id != "ActiveMerchant"
        parameters
      end
    end
  end
end
