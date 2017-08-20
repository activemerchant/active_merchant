module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Moneta
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          mapping :account, 'MNT_ID'
          mapping :payment_id, 'MNT_TRANSACTION_ID'
          mapping :user_id, 'MNT_SUBSCRIBER_ID'
          mapping :test, 'MNT_TEST_MODE'

          mapping :amount, 'MNT_AMOUNT'
          mapping :currency, 'MNT_CURRENCY_CODE'
          mapping :description, 'MNT_DESCRIPTION'

          mapping :sign, 'MNT_SIGNATURE'

          mapping :success_url, 'MNT_SUCCESS_URL'
          mapping :fail_url, 'MNT_FAIL_URL'
          mapping :inprogress_url, 'MNT_INPROGRESS_URL'
          mapping :return_url, 'MNT_RETURN_URL'

          mapping :locale, 'moneta.locale'
          mapping :unit_ids, 'paymentSystem.unitId'
          mapping :limit_ids, 'paymentSystem.limitIds'

        end
      end
    end
  end
end
