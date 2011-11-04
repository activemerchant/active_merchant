module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SamuraiGateway < Gateway

      self.homepage_url = 'https://samurai.feefighters.com'
      self.display_name = 'Samurai'
      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :diners_club]
      self.default_currency = 'USD'
      self.money_format = :cents

      def initialize(options = {})
        begin
          require 'samurai'
        rescue LoadError
          raise "Could not load the samurai gem (>= 0.2.24).  Use `gem install samurai` to install it."
        end

        requires!(options, :merchant_key, :merchant_password, :processor_token)
        @sandbox = options[:sandbox] || false
        Samurai.options = {
          :merchant_key => options[:merchant_key],
          :merchant_password => options[:merchant_password],
          :processor_token => options[:processor_token]
        }
      end

      def purchase(money, credit_card_or_vault_id, options = {})
        if credit_card_or_vault_id.is_a?(ActiveMerchant::Billing::CreditCard)
          store_result = store(credit_card_or_vault_id, options)
          return store_result if !store_result.success?
          credit_card_or_vault_id = store_result.params["payment_method_token"]
        end
        result = Samurai::Processor.purchase(credit_card_or_vault_id,
                                             money,
                                             {
                                               :billing_reference   => options[:billing_reference],
                                               :customer_reference  => options[:customer_reference],
                                               :custom              => options[:custom],
                                               :descriptor          => options[:descriptor],
                                             })
        handle_result(result)
      end

      def capture(money, authorization_id, options = {})
        authorization = Samurai::Transaction.find(authorization_id)  # get the authorization created previously
        capture = money.nil? ? authorization.capture : authorization.capture(money)
        handle_result(capture)
      end

      def credit(money, transaction_id, options = {})
        transaction = Samurai::Transaction.find(transaction_id) # get the transaction
        credit = money.nil? ? transaction.credit : transaction.credit(money)
        handle_result(credit)
      end

      def authorize(money, credit_card_or_vault_id, options = {})
        if credit_card_or_vault_id.is_a?(ActiveMerchant::Billing::CreditCard)
          store_result = store(credit_card_or_vault_id, options)
          return store_result if !store_result.success?
          credit_card_or_vault_id = store_result.params["payment_method_token"]
        end
        authorize = Samurai::Processor.authorize(credit_card_or_vault_id, money, {:billing_reference =>   options[:billing_reference],:customer_reference =>  options[:customer_reference],:custom => options[:custom],:descriptor => options[:descriptor]})
        handle_result(authorize)
      end

      def void(money, transaction_id, options = {})
        void = Samurai::Processor.void(transaction_id, money, {:billing_reference =>   options[:billing_reference],:customer_reference =>  options[:customer_reference],:custom => options[:custom],:descriptor => options[:descriptor]})
        handle_result(void)
      end

      def handle_result(result)
        response_params, response_options, avs_result, cvv_result = {}, {}, {}, {}
        if result.success?
          response_options[:reference_id] = result.reference_id
          response_options[:authorization] = result.reference_id
          response_options[:transaction_token] = result.transaction_token
          response_options[:payment_method_token] = result.payment_method.payment_method_token
        end

        # TODO: handle cvv here
        response_options[:avs_result] = { :code => result.processor_response.avs_result_code }
        message = message_from_result(result)
        Response.new(result.success?, message, response_params, response_options)
      end

      def store(creditcard, options = {})
          options[:billing_address] ||= {}

          result = Samurai::PaymentMethod.create({
            :card_number  => creditcard.number,
            :expiry_month => creditcard.month.to_s.rjust(2, "0"),
            :expiry_year  => creditcard.year.to_s,
            :cvv          => creditcard.verification_value,
            :first_name   => creditcard.first_name,
            :last_name    => creditcard.last_name,
            :address_1    => options[:billing_address][:address1],
            :address_2    => options[:billing_address][:address2],
            :city         => options[:billing_address][:state],
            :zip          => options[:billing_address][:zip],
            :sandbox      => @sandbox
          })

          Response.new(result.is_sensitive_data_valid,
                       message_from_result(result),
                       { :payment_method_token => result.is_sensitive_data_valid && result.payment_method_token })
      end

      def message_from_result(result)
        if result.success?
          "OK"
        else
          result.errors.map {|_, messages| [messages].flatten.first }.first
        end
      end

    end
  end
end