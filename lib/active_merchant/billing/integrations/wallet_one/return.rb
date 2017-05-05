module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module WalletOne
        class Return < ActiveMerchant::Billing::Integrations::Return
          def success?
            status == 'Accepted'
          end

          def status
            params['WMI_ORDER_STATE']
          end

          def account
            params['WMI_MERCHANT_ID']
          end

          def payer_wallet_id
            params['WMI_TO_USER_ID']
          end

          def item_id
            params['WMI_PAYMENT_NO']
          end

          def currency
            params['WMI_CURRENCY_ID']
          end

          def transaction_id
            params['payer_trans_id']
          end

          def description
            params['WMI_DESCRIPTION']
          end

          def received_at
            params['WMI_UPDATE_DATE']
          end
        end
      end
    end
  end
end
