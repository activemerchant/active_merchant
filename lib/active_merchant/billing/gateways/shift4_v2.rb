module ActiveMerchant # :nodoc:
  module Billing # :nodoc:
    class Shift4V2Gateway < SecurionPayGateway
      # same endpont for testing
      self.live_url = 'https://api.shift4.com/'
      self.display_name = 'Shift4'
      self.homepage_url = 'https://dev.shift4.com/us/'

      def credit(money, payment, options = {})
        post = create_post_for_auth_or_purchase(money, payment, options)
        commit('credits', post, options)
      end

      def store(payment_method, options = {})
        post = case payment_method
               when CreditCard
                 cc = {}.tap { |card| add_creditcard(card, payment_method, options) }[:card]
                 options[:customer_id].blank? ? { email: options[:email], card: cc } : cc
               when Check
                 bank_account_object(payment_method, options)
               else
                 raise ArgumentError.new("Unhandled payment method #{payment_method.class}.")
               end

        commit url_for_store(payment_method, options), post, options
      end

      def url_for_store(payment_method, options = {})
        case payment_method
        when CreditCard
          options[:customer_id].blank? ? 'customers' : "customers/#{options[:customer_id]}/cards"
        when Check then 'payment-methods'
        end
      end

      def unstore(reference, options = {})
        commit("customers/#{options[:customer_id]}/cards/#{reference}", nil, options, :delete)
      end

      def create_post_for_auth_or_purchase(money, payment, options)
        super.tap do |post|
          add_stored_credentials(post, options)
        end
      end

      def add_stored_credentials(post, options)
        return unless options[:stored_credential].present?

        initiator = options.dig(:stored_credential, :initiator)
        reason_type = options.dig(:stored_credential, :reason_type)

        post_type = {
          %w[cardholder recurring] => 'first_recurring',
          %w[merchant recurring] => 'subsequent_recurring',
          %w[cardholder unscheduled] => 'customer_initiated',
          %w[merchant installment] => 'merchant_initiated'
        }[[initiator, reason_type]]
        post[:type] = post_type if post_type
      end

      def headers(options = {})
        super.tap do |headers|
          headers['User-Agent'] = "Shift4/v2 ActiveMerchantBindings/#{ActiveMerchant::VERSION}"
        end
      end

      def scrub(transcript)
        super.
          gsub(%r((card\[expMonth\]=)\d+), '\1[FILTERED]').
          gsub(%r((card\[expYear\]=)\d+), '\1[FILTERED]').
          gsub(%r((card\[cardholderName\]=)\w+[^ ]\w+), '\1[FILTERED]')
      end

      def json_error(raw_response)
        super(raw_response, 'Shift4 V2')
      end

      def add_amount(post, money, options, include_currency = false)
        super
        post[:currency]&.upcase!
      end

      def add_creditcard(post, payment_method, options)
        return super unless payment_method.is_a?(Check)

        post[:paymentMethod] = bank_account_object(payment_method, options)
      end

      def bank_account_object(payment_method, options)
        {
          type: :ach,
          fraudCheckData: {
            ipAddress: options[:ip],
            email: options[:email]
          }.compact,
          billing: {
            name: payment_method.name,
            address: { country: options.dig(:billing_address, :country) }
          }.compact,
          ach: {
            account: {
              routingNumber: payment_method.routing_number,
              accountNumber: payment_method.account_number,
              accountType: get_account_type(payment_method)
            },
            verificationProvider: :external
          }
        }
      end

      def get_account_type(check)
        holder = (check.account_holder_type || '').match(/business/i) ? :corporate : :personal
        "#{holder}_#{check.account_type}"
      end
    end
  end
end
