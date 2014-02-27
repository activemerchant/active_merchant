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
            signature = @params.delete('x-signature')
            signature == generate_signature
          end

          def item_id
            @params['x-reference']
          end

          def currency
            @params['x-currency']
          end

          def gross
            @params['x-amount']
          end

          def transaction_id
            @params['x-gateway-reference']
          end

          def status
            case @params['x-result']
              when 'success'; 'Completed'
              when 'failure'; 'Failed'
              when 'pending'; 'Pending'
            end
          end

          def test?
            @params['x-test'] == 'true'
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
