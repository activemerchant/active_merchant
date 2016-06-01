module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module PagarmeRecurringApi #:nodoc:
      module HelpersPagarme #:nodoc:

        def default_object_if_empty(hash)
          hash && hash.attributes || {}
        end

      end
    end
  end
end
