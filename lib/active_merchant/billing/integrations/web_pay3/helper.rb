module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module WebPay3
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          def initialize(order, account, options = {})
            @key = options.delete(:key)
            super
          end

          def form_fields
            @fields.merge(:digest => Digest::SHA1.hexdigest("#{@key}#{@fields['order_number']}#{@fields['amount']}#{@fields['currency']}"))
          end

          # merchant
          mapping :account, 'merchant_token'
          mapping :return_url, 'return_url'
          mapping :language, 'language'

          # order
          mapping :order, 'order_number'
          mapping :amount, 'amount'
          mapping :currency, 'currency'
          mapping :order_info, 'order_info'
          mapping :transaction_type, 'transaction_type'

          # card holder
          mapping :ch_full_name, 'ch_full_name'
          mapping :ch_address, 'ch_address'
          mapping :ch_city, 'ch_city'
          mapping :ch_zip, 'ch_zip'
          mapping :ch_country, 'ch_country'
          mapping :phone, 'ch_phone'
          mapping :ch_email, 'ch_email'
        end
      end
    end
  end
end
