require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Universal
        class Notification < ActiveMerchant::Billing::Integrations::Notification

          def initialize(post, options = {})
            super
            @key = options[:credential2]
          end

          def acknowledge(authcode = nil)
            signature = @params.delete('x_signature')
            signature && signature.casecmp(generate_signature) == 0
          end

          def item_id
            @params['x_reference']
          end

          def currency
            @params['x_currency']
          end

          def gross
            @params['x_amount']
          end

          def transaction_id
            @params['x_gateway_reference']
          end

          def status
            case @params['x_result']
              when 'success'; 'Completed'
              when 'failure'; 'Failed'
              when 'pending'; 'Pending'
            end
          end

          def test?
            @params['x_test'] == 'true'
          end

          private
          def generate_signature
            Universal.sign(@params, @key)
          end

        end
      end
    end
  end
end
