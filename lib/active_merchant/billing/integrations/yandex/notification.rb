require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Yandex
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          def self.recognizes?(params)
            params.has_key?('shopId')
          end

          def complete?
            params['request_type'] == 'payment_success' && params['orderIsPaid'] == '1'
          end

          def check?
            @check ||= if params['request_type'] == 'check'
                         true
                       else
                         false
                       end
          end

          def amount
            BigDecimal.new(gross)
          end

          def item_id
            params['orderNumber']
          end

          def transaction_id
            params['invoiceId']
          end

          def security_key
            params[ActiveMerchant::Billing::Integrations::Yandex.signature_parameter_name].to_s.downcase
          end

          def currency
            'RUR'
          end

          def gross
            params['orderSumAmount']
          end

          def status
            'success'
          end

          def generate_signature_string
            %w(orderIsPaid orderSumAmount orderSumCurrencyPaycash orderSumBankPaycash shopId invoiceId customerNumber).map { |param| params[param] }.join(';') + ';' + @options[:secret]
          end

          def generate_signature
            Digest::MD5.hexdigest(generate_signature_string)
          end

          def acknowledge
            security_key == generate_signature
          end

          def success_response(*args)
            xml('0', Time.now)
          end

          def error_response(error_type, options = {})
            if error_type.to_s == 'duplicate_payment'
              success_response
            else
              xml('1000', Time.now, error_type.to_s)
            end
          end

          def xml(code, datetime, msg = nil)
            datetime_str = datetime.strftime("%Y-%m-%dT%H:%M:%S+0#{datetime.gmt_offset / 3600}:00")

            action = case params['request_type']
                       when 'check' then
                         'Check'
                       when 'payment_success' then
                         'PaymentSuccess'
                     end

            %Q{<?xml version="1.0" encoding="windows-1251"?>
<response performedDatetime="#{datetime_str}">
  <result code="#{code}" action="#{action}" shopId="#{@options[:account]}" invoiceId="#{params['invoiceId']}" #{"techMessage=\"#{msg}\"" if msg} />
</response>}
          end
        end
      end
    end
  end
end
