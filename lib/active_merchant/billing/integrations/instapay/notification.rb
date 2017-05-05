module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Instapay
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          def self.recognizes?(params)
            params.has_key?('WMI_PAYMENT_AMOUNT') && params.has_key?('WMI_MERCHANT_ID')
          end

          def complete?
            status == 'Accepted'
          end

          def account
            params['WMI_MERCHANT_ID']
          end

          def amount
            BigDecimal.new(gross)
          end

          def item_id
            params['WMI_PAYMENT_NO']
          end

          def transaction_id
            params['payer_trans_id']
          end

          def received_at
            params['WMI_UPDATE_DATE']
          end

          def security_key
            params[ActiveMerchant::Billing::Integrations::WalletOne.signature_parameter_name]
          end

          def currency
            params['WMI_CURRENCY_ID']
          end

          def status
            params['WMI_ORDER_STATE']
          end

          def payer_wallet_id
            params['WMI_TO_USER_ID']
          end

          # the money amount we received in X.2 decimal.
          def gross
            params['WMI_PAYMENT_AMOUNT']
          end

          def generate_signature_string
           # [account, gross, item_id, currency, status, transaction_id, payer_wallet_id, @options[:secret]].flatten.join(':')
            data = params.clone
            data.delete(ActiveMerchant::Billing::Integrations::Instapay.signature_parameter_name)
            data = data.sort
            values = data.map {|key,val| val}
            signature_string = [values, @options[:secret]].flatten.join
            encode_string(signature_string)
          end

          def generate_signature
            Digest::SHA1.base64digest(generate_signature_string)
          end

          def acknowledge
            security_key == generate_signature
          end

          def success_response(*args)
            "WMI_RESULT=OK"
          end
          # @param message
          def retry_response(message='',*args)
            "WMI_RESULT=RETRY&WMI_DESCRIPTION=#{message}"
          end

          def encode_string(data,enc='cp1251')
            if data.respond_to?(:encode!)
              data.encode!('UTF-8', enc)
            else    # for ruby 1.8
              require 'iconv'
              data = Iconv.new('utf-8', enc).iconv(data)
            end
            data
          end

          #def custom_fields
          #  #params['custom_fields']
          #end

        end
      end
    end
  end
end