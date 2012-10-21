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
    # Additionally, the log level will be set to +DEBUG+.  Therefore,
    # all you have to do is set the +wiredump_device+ and you'll
    # get your debug output from your HTTP interactions with the
    # remote gateway. (Don't enable this in production.)
    #
    # For example:
    #
    #     ActiveMerchant::Billing::BraintreeBlueGateway.wiredump_device = Logger.new(STDOUT)
    #     # => #<Logger:0x107d385f8 ...>
    #
    #     Braintree::Configuration.logger
    #     # => (some other logger, created by default by the gem)
    #
    #     Braintree::Configuration.logger.level
    #     # => 1 (INFO)
    #
    #     ActiveMerchant::Billing::BraintreeBlueGateway.new(:merchant_id => 'x', :public_key => 'x', :private_key => 'x')
    #
    #     Braintree::Configuration.logger
    #     # => #<Logger:0x107d385f8 ...>
    #
    #     Braintree::Configuration.logger.level
    #     # => 0 (DEBUG)
    #
    #  Alternatively, you can avoid setting the +wiredump_device+
    #  and set +Braintree::Configuration.logger+ and/or
    #  +Braintree::Configuration.logger.level+ directly.
    class BraintreeBlueGateway < Gateway
      include BraintreeCommon

      self.display_name = 'Braintree (Blue Platform)'

      def initialize(options = {})
        requires!(options, :merchant_id, :public_key, :private_key)
        @options = options
        @merchant_account_id = options[:merchant_account_id]
        Braintree::Configuration.merchant_id = options[:merchant_id]
        Braintree::Configuration.public_key = options[:public_key]
        Braintree::Configuration.private_key = options[:private_key]
        Braintree::Configuration.environment = (options[:environment] || (test? ? :sandbox : :production)).to_sym
        Braintree::Configuration.custom_user_agent = "ActiveMerchant #{ActiveMerchant::VERSION}"
        if wiredump_device
          Braintree::Configuration.logger = wiredump_device
          Braintree::Configuration.logger.level = Logger::DEBUG
        end
        super
      end

      def authorize(money, credit_card_or_vault_id, options = {})
        create_transaction(:sale, money, credit_card_or_vault_id, options)
      end

      def capture(money, authorization, options = {})
        commit do
          result = Braintree::Transaction.submit_for_settlement(authorization, amount(money).to_s)
          Response.new(result.success?, message_from_result(result))
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
          result = Braintree::Transaction.refund(transaction_id, money)
          Response.new(result.success?, message_from_result(result),
            {:braintree_transaction => (transaction_hash(result.transaction) if result.success?)},
            {:authorization => (result.transaction.id if result.success?)}
           )
        end
      end

      def void(authorization, options = {})
        commit do
          result = Braintree::Transaction.void(authorization)
          Response.new(result.success?, message_from_result(result),
            {:braintree_transaction => (transaction_hash(result.transaction) if result.success?)},
            {:authorization => (result.transaction.id if result.success?)}
          )
        end
      end

      def store(creditcard, options = {})
        commit do
          parameters = {
            :first_name => creditcard.first_name,
            :last_name => creditcard.last_name,
            :email => options[:email],
            :credit_card => {
              :number => creditcard.number,
              :cvv => creditcard.verification_value,
              :expiration_month => creditcard.month.to_s.rjust(2, "0"),
              :expiration_year => creditcard.year.to_s
            }
          }
          result = Braintree::Customer.create(merge_credit_card_options(parameters, options))
          Response.new(result.success?, message_from_result(result),
            {
              :braintree_customer => (customer_hash(result.customer) if result.success?),
              :customer_vault_id => (result.customer.id if result.success?)
            }
          )
        end
      end

      def update(vault_id, creditcard, options = {})
        braintree_credit_card = nil
        commit do
          braintree_credit_card = Braintree::Customer.find(vault_id).credit_cards.detect { |cc| cc.default? }
          return Response.new(false, 'Braintree::NotFoundError') if braintree_credit_card.nil?

          options.merge!(:update_existing_token => braintree_credit_card.token)
          credit_card_params = merge_credit_card_options({
            :credit_card => {
              :number => creditcard.number,
              :cvv => creditcard.verification_value,
              :expiration_month => creditcard.month.to_s.rjust(2, "0"),
              :expiration_year => creditcard.year.to_s
            }
          }, options)[:credit_card]

          result = Braintree::Customer.update(vault_id,
            :first_name => creditcard.first_name,
            :last_name => creditcard.last_name,
            :email => options[:email],
            :credit_card => credit_card_params
          )
          Response.new(result.success?, message_from_result(result),
            :braintree_customer => (customer_hash(Braintree::Customer.find(vault_id)) if result.success?),
            :customer_vault_id => (result.customer.id if result.success?)
          )
        end
      end

      def unstore(customer_vault_id)
        commit do
          Braintree::Customer.delete(customer_vault_id)
          Response.new(true, "OK")
        end
      end
      alias_method :delete, :unstore

      private

      def merge_credit_card_options(parameters, options)
        valid_options = {}
        options.each do |key, value|
          valid_options[key] = value if [:update_existing_token, :verify_card, :verification_merchant_account_id].include?(key)
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
          :postal_code => address[:zip],
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

      def create_transaction(transaction_type, money, credit_card_or_vault_id, options)
        transaction_params = create_transaction_parameters(money, credit_card_or_vault_id, options)

        commit do
          result = Braintree::Transaction.send(transaction_type, transaction_params)
          response_params, response_options, avs_result, cvv_result = {}, {}, {}, {}
          if result.success?
            response_params[:braintree_transaction] = transaction_hash(result.transaction)
            response_params[:customer_vault_id] = result.transaction.customer_details.id
            response_options[:authorization] = result.transaction.id
          end
          if result.transaction
            response_options[:avs_result] = {
              :code => nil, :message => nil,
              :street_match => result.transaction.avs_street_address_response_code,
              :postal_match => result.transaction.avs_postal_code_response_code
            }
            response_options[:cvv_result] = result.transaction.cvv_response_code
            if result.transaction.status == "gateway_rejected"
              message = "Transaction declined - gateway rejected"
            else
              message = "#{result.transaction.processor_response_code} #{result.transaction.processor_response_text}"
            end
          else
            message = message_from_result(result)
          end
          response = Response.new(result.success?, message, response_params, response_options)
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

      def customer_hash(customer)
        credit_cards = customer.credit_cards.map do |cc|
          {
            "bin" => cc.bin,
            "expiration_date" => cc.expiration_date,
            "token" => cc.token,
            "last_4" => cc.last_4,
            "card_type" => cc.card_type,
            "masked_number" => cc.masked_number
          }
        end

        {
          "email" => customer.email,
          "first_name" => customer.first_name,
          "last_name" => customer.last_name,
          "credit_cards" => credit_cards,
          "id" => customer.id
        }
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
            :email => options[:email]
          },
          :options => {
            :store_in_vault => options[:store] ? true : false,
            :submit_for_settlement => options[:submit_for_settlement]
          }
        }

        if merchant_account_id = (options[:merchant_account_id] || @merchant_account_id)
          parameters[:merchant_account_id] = merchant_account_id
        end

        if options[:recurring]
          parameters[:recurring] = true
        end

        if credit_card_or_vault_id.is_a?(String) || credit_card_or_vault_id.is_a?(Integer)
          parameters[:customer_id] = credit_card_or_vault_id
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
        parameters[:billing] = map_address(options[:billing_address]) if options[:billing_address]
        parameters[:shipping] = map_address(options[:shipping_address]) if options[:shipping_address]
        parameters
      end
    end
  end
end

