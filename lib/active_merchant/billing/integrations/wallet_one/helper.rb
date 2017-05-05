module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module WalletOne
        class Helper < ActiveMerchant::Billing::Integrations::Helper

          def initialize(order, account, options = {})
            @md5_secret = options.delete(:secret)
            super
          end

          def form_fields
            @md5_secret ?
              @fields.merge(ActiveMerchant::Billing::Integrations::WalletOne.signature_parameter_name => generate_signature) :
              @fields
          end

          def generate_signature_string
            fields = @fields.clone
            fields.delete(ActiveMerchant::Billing::Integrations::WalletOne.signature_parameter_name)
            #throw [(fields.sort.map(&:last) << @md5_secret).join.encode!('UTF-8', 'cp1251'), fields.sort.map(&:first)]
            (fields.sort.map(&:last) << @md5_secret).join.encode!('UTF-8', 'cp1251')
          end

          def generate_signature
            Digest::MD5.base64digest(generate_signature_string)
          end

          # Replace with the real mapping 
          mapping :account, 'WMI_MERCHANT_ID'
          mapping :amount, 'WMI_PAYMENT_AMOUNT'

          mapping :order, 'WMI_PAYMENT_NO'
          mapping :currency, 'WMI_CURRENCY_ID'

          #mapping :notify_url, 'result_url'
          mapping :success_url, 'WMI_SUCCESS_URL'
          mapping :fail_url, 'WMI_FAIL_URL'
          mapping :description, 'WMI_DESCRIPTION'

          mapping :enabled, 'WMI_PTENABLED'

          #mapping :custom_fields, 'custom_fields'
        end
      end
    end
  end
end