module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module WirecardCheckoutPage
        class Return < ActiveMerchant::Billing::Integrations::Return
          include Common

          def initialize(postdata, options = {})
            @params  = parse(postdata)
            @options = options
            verify_response(@params, options[:secret])
          end

          def success?
            @paymentstate == 'SUCCESS'
          end

          def cancelled?
            @paymentstate == 'CANCEL'
          end

          def pending?
            @paymentstate == 'PENDING'
          end

          def method_missing(method_id, *args)
            return params[method_id.to_s] if params.has_key?(method_id.to_s)
          end

        end
      end
    end
  end
end

