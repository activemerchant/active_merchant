require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module MollieIdeal
        class Notification < ActiveMerchant::Billing::Integrations::Notification

          def initialize(post_arguments, options = {})
            super

            raise ArgumentError, "The transaction_id needs to be included in the query string." if transaction_id.nil?
            raise ArgumentError, "The credential1 option needs to be set to the Mollie API key." if api_key.blank?
          end

          def complete?
            true
          end

          def item_id
            params['metadata']['order']
          end

          def transaction_id
            params['id']
          end

          def api_key
            @options[:credential1]
          end

          def currency
            "EUR"
          end

          # the money amount we received in X.2 decimal.
          def gross
            @params['amount']
          end

          def gross_cents
            (BigDecimal.new(@params['amount'], 2) * 100).to_i
          end

          def status
            case @params['status']
              when 'open';                 'Pending'
              when 'paidout', 'paid';      'Completed'
              else                         'Failed'
            end
          end

          def test?
            @params['mode'] == 'test'
          end

          def acknowledge(authcode = nil)
            @params = check_payment_status(transaction_id)
            true
          end

          def check_payment_status(transaction_id)
            MollieIdeal.check_payment_status(@options[:credential1], transaction_id)
          end
        end
      end
    end
  end
end
