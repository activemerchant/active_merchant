module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Dwolla
        class Return < ActiveMerchant::Billing::Integrations::Return
          include Common

          def initialize(data, options)
            params = parse(data)
            verify_signature(params['checkoutId'], params['amount'], params['signature'], options[:credential3])

            super
          end

          def success?
            (self.error.nil? && self.callback_success?)
          end

          def error
            params['error']
          end

          def error_description
            params['error_description']
          end

          def checkout_id
            params['checkoutId']
          end

          def transaction
            params['transaction']
          end

          def test?
            params['test']
          end

          def callback_success?
            (params['postback'] != "failure")
          end
        end
      end
    end
  end
end
