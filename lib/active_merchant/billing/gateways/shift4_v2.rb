module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class Shift4V2Gateway < SecurionPayGateway
      # same endpont for testing
      self.live_url = 'https://api.shift4.com/'
      self.display_name = 'Shift4'
      self.homepage_url = 'https://dev.shift4.com/us/'

      def credit(money, payment, options = {})
        post = create_post_for_auth_or_purchase(money, payment, options)
        commit('credits', post, options)
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
    end
  end
end
