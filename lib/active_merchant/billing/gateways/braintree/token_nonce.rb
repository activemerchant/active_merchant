module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class TokenNonce #:nodoc:
      include PostsData
      # This class emulates the behavior of the front-end js library to
      # create token nonce for a bank account base on the docs:
      # https://developer.paypal.com/braintree/docs/guides/ach/client-side

      attr_reader :braintree_gateway, :options

      def initialize(gateway, options = {})
        @braintree_gateway = gateway
        @options = options
      end

      def url
        sandbox = @braintree_gateway.config.environment == :sandbox
        "https://payments#{'.sandbox' if sandbox}.braintree-api.com/graphql"
      end

      def create_token_nonce_for_payment_method(payment_method)
        headers = {
          'Accept' => 'application/json',
          'Authorization' => "Bearer #{client_token}",
          'Content-Type' => 'application/json',
          'Braintree-Version' => '2018-05-10'
        }
        resp = ssl_post(url, build_nonce_request(payment_method), headers)
        json_response = JSON.parse(resp)

        message = json_response['errors'].map { |err| err['message'] }.join("\n") if json_response['errors'].present?
        token = json_response.dig('data', 'tokenizeUsBankAccount', 'paymentMethod', 'id')

        return token, message
      end

      def client_token
        base64_token = @braintree_gateway.client_token.generate
        JSON.parse(Base64.decode64(base64_token))['authorizationFingerprint']
      end

      private

      def graphql_query
        <<-GRAPHQL
        mutation TokenizeUsBankAccount($input: TokenizeUsBankAccountInput!) {
          tokenizeUsBankAccount(input: $input) {
            paymentMethod {
              id
              details {
                ... on UsBankAccountDetails {
                  last4
                }
              }
            }
          }
        }
        GRAPHQL
      end

      def billing_address_from_options
        return nil if options[:billing_address].blank?

        address = options[:billing_address]

        {
          streetAddress: address[:address1],
          extendedAddress: address[:address2],
          city: address[:city],
          state: address[:state],
          zipCode: address[:zip]
        }.compact
      end

      def build_nonce_request(payment_method)
        input = {
          usBankAccount: {
            achMandate: options[:ach_mandate],
            routingNumber: payment_method.routing_number,
            accountNumber: payment_method.account_number,
            accountType: payment_method.account_type.upcase,
            billingAddress: billing_address_from_options
          }
        }

        if payment_method.account_holder_type == 'personal'
          input[:usBankAccount][:individualOwner] = {
            firstName: payment_method.first_name,
            lastName: payment_method.last_name
          }
        else
          input[:usBankAccount][:businessOwner] = {
            businessName: payment_method.name
          }
        end

        {
          clientSdkMetadata: {
            platform: 'web',
            source: 'client',
            integration: 'custom',
            sessionId: SecureRandom.uuid,
            version: '3.83.0'
          },
          query: graphql_query,
          variables: {
            input: input
          }
        }.to_json
      end
    end
  end
end
