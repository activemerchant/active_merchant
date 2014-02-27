module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Universal
        class Return < ActiveMerchant::Billing::Integrations::Return

          def initialize(query_string, options = {})
            super
            @key = options[:credential2]
          end

          def success?
            signature = @params.delete('x-signature')
            signature == generate_signature
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
