module ActiveMerchant # :nodoc:
  module Billing # :nodoc:
    class LoanPaymentProAchGateway < LoanPaymentProGateway
      self.live_url = 'https://www.checkcommerce.com/EpnPublic/ACH.aspx'
      self.test_url = 'https://sandbox.checkcommerce.com/EpnPublic/ACH.aspx'

      API_VERSION = '1.4.2.35'.freeze

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def purchase(money, bank_account, options = {})
        post = {
          Method: options.delete(:method) || :Debit,
          ReferenceNumber: options[:order_id] || SecureRandom.uuid,
          Name: bank_account.name,
          Amount: amount(money),
          RoutingNumber: bank_account.routing_number,
          AccountNumber: bank_account.account_number
        }

        commit(post)
      end

      def authorize(money, bank_account, options = {})
        purchase(money, bank_account, options.merge(method: :Authorize))
      end

      def void(authorization, options = {})
        post = {
          Method: :Cancel,
          TransactionId: authorization.to_s.split('|').first
        }
        commit(post)
      end

      def refund(money, authorization, options = {})
        post = {
          Method: :Refund,
          TransactionId: authorization.to_s.split('|').first,
          Amount: amount(money)
        }
        commit(post)
      end

      private

      def add_credentials_and_version(post)
        post.merge!({
          Login: @options[:login],
          Password: @options[:password],
          Version: API_VERSION,
          Test: test? ? 'True' : 'False'
        })
      end

      def url
        test? ? test_url : live_url
      end

      def commit(post = {}, method = :post, options = {})
        add_credentials_and_version(post)
        response = parse(ssl_request(method, url, post_data(post), {}))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def parse(response_body)
        URI.decode_www_form(response_body.gsub(/\r\n/, '&')).to_h.with_indifferent_access
      end

      def success_from(response)
        response[:Success].to_s.downcase == 'true'
      end

      def message_from(response)
        response[:Message]
      end

      def authorization_from(response = {})
        "#{response[:TransactionID]}|ach"
      end
    end
  end
end
