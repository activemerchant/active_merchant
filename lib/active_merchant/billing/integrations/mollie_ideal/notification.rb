require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module MollieIdeal
        class Notification < ActiveMerchant::Billing::Integrations::Notification

          def initialize(query_string, options = {})
            super

            raise ArgumentError, "The transaction_id needs to be included in the query string." if transaction_id.nil?
            raise ArgumentError, "The partner_id or credential1 option needs to be set." if partner_id.blank?
          end

          def complete?
            true
          end

          def item_id
            params['item_id']
          end

          def transaction_id
            params['transaction_id']
          end

          # the money amount we received in X.2 decimal.
          def gross
            BigDecimal.new(gross_cents) / 100
          end

          def gross_cents
            params['amount']
          end

          def status
            return 'Pending' if params['paid'].nil?
            params['paid'] == 'true' ? 'Completed' : 'Failed'
          end

          def currency
            params['currency']
          end

          def partner_id
            @options[:partner_id] || @options[:credential1]
          end

          def acknowledge(authcode = nil)
            xml = MollieIdeal.mollie_api_request(:check, :partner_id => partner_id, :transaction_id => transaction_id)

            params['amount']           = MollieIdeal.extract_response_parameter(xml, 'amount').to_i
            params['paid']             = MollieIdeal.extract_response_parameter(xml, 'payed')
            params['currency']         = MollieIdeal.extract_response_parameter(xml, 'currency')
            params['consumer_name']    = MollieIdeal.extract_response_parameter(xml, 'consumerName')
            params['consumer_account'] = MollieIdeal.extract_response_parameter(xml, 'consumerAccount')
            params['consumer_city']    = MollieIdeal.extract_response_parameter(xml, 'consumerCity')
            params['message']          = MollieIdeal.extract_response_parameter(xml, 'city')
            params['status']           = MollieIdeal.extract_response_parameter(xml, 'status')
            params['message']          = MollieIdeal.extract_response_parameter(xml, 'message')

            params['status'] != 'CheckedBefore'
          end
        end
      end
    end
  end
end
