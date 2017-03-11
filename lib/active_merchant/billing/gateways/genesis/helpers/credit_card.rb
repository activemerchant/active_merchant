module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Genesis #:nodoc:
      module Helpers #:nodoc:
        module CreditCard #:nodoc:

          def credit_card_supports_mpi_params?(credit_card)
            credit_card.is_a?(NetworkTokenizationCreditCard)
          end

          def credit_card_expiration_month(credit_card)
            credit_card.month.to_s.rjust(2, '0')
          end
        end
      end
    end
  end
end
