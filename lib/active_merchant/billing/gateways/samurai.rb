module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SamuraiGateway < Gateway

      self.homepage_url = 'https://samurai.feefighters.com'
      self.display_name = 'Samurai'
      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :diners_club]
      self.default_currency = 'USD'
      self.money_format = :dollars

      def initialize(options = {})
        begin
          require 'samurai'
        rescue LoadError
          raise "Could not load the samurai gem (>= 0.2.25).  Use `gem install samurai` to install it."
        end

        requires!(options, :login, :password, :processor_token)
        Samurai.options = {
          :merchant_key       => options[:login],
          :merchant_password  => options[:password],
          :processor_token    => options[:processor_token]
        }

        super
      end

      def authorize(money, credit_card_or_vault_id, options = {})
        token = payment_method_token(credit_card_or_vault_id, options)
        return token if token.is_a?(Response)

        authorize = Samurai::Processor.authorize(token, amount(money), processor_options(options))
        handle_result(authorize)
      rescue ActiveResource::ServerError => e
        Response.new(false, e.message, {}, test: test?)
      end

      def purchase(money, credit_card_or_vault_id, options = {})
        token = payment_method_token(credit_card_or_vault_id, options)
        return token if token.is_a?(Response)

        purchase = Samurai::Processor.purchase(token, amount(money), processor_options(options))
        handle_result(purchase)
      rescue ActiveResource::ServerError => e
        Response.new(false, e.message, {}, test: test?)
      end

      def capture(money, authorization_id, options = {})
        transaction = Samurai::Transaction.find(authorization_id)
        handle_result(transaction.capture(amount(money)))
      rescue ActiveResource::ServerError => e
        Response.new(false, e.message, {}, test: test?)
      end

      def refund(money, transaction_id, options = {})
        transaction = Samurai::Transaction.find(transaction_id)
        handle_result(transaction.credit(amount(money)))
      rescue ActiveResource::ServerError => e
        Response.new(false, e.message, {}, test: test?)
      end

      def void(transaction_id, options = {})
        transaction = Samurai::Transaction.find(transaction_id)
        handle_result(transaction.void)
      rescue ActiveResource::ServerError => e
        Response.new(false, e.message, {}, test: test?)
      end

      def store(creditcard, options = {})
        address = options[:billing_address] || options[:address] || {}

        result = Samurai::PaymentMethod.create({
          :card_number  => creditcard.number,
          :expiry_month => creditcard.month.to_s.rjust(2, "0"),
          :expiry_year  => creditcard.year.to_s,
          :cvv          => creditcard.verification_value,
          :first_name   => creditcard.first_name,
          :last_name    => creditcard.last_name,
          :address_1    => address[:address1],
          :address_2    => address[:address2],
          :city         => address[:city],
          :zip          => address[:zip],
          :sandbox      => test?
        })
        result.retain if options[:retain] && result.is_sensitive_data_valid && result.payment_method_token

        Response.new(result.is_sensitive_data_valid,
                     message_from_result(result),
                     { :payment_method_token => result.is_sensitive_data_valid && result.payment_method_token })
      rescue ActiveResource::ServerError => e
        Response.new(false, e.message, {}, test: test?)
      end

      private

      def payment_method_token(credit_card_or_vault_id, options)
        return credit_card_or_vault_id if credit_card_or_vault_id.is_a?(String)
        store_result = store(credit_card_or_vault_id, options)
        store_result.success? ? store_result.params["payment_method_token"] : store_result
      end

      def handle_result(result)
        response_params, response_options = {}, {}
        if result.success?
          response_options[:test] = test?
          response_options[:authorization] = result.reference_id
          response_params[:reference_id] = result.reference_id
          response_params[:transaction_token] = result.transaction_token
          response_params[:payment_method_token] = result.payment_method.payment_method_token
        end

        response_options[:avs_result] = { :code => result.processor_response && result.processor_response.avs_result_code }
        response_options[:cvv_result] = result.processor_response && result.processor_response.cvv_result_code

        message = message_from_result(result)
        Response.new(result.success?, message, response_params, response_options)
      end

      def message_from_result(result)
        return "OK" if result.success?
        result.errors.map {|_, messages| messages }.join(" ")
      end

      def processor_options(options)
        options.slice(:billing_reference, :customer_reference, :custom, :descriptor)
      end
    end
  end
end
