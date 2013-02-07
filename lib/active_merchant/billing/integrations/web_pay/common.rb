module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module WebPay
        module Common
          def generate_signature(type)
            string = case type
            when :request
              request_signature_string
            when :notify
              notify_signature_string
            end
            if type != :notify && @fields[mappings[:version]] == '2'
              Digest::SHA1.hexdigest(string)
            else
              Digest::MD5.hexdigest(string)
            end
          end

          def request_signature_string
            [
              @fields[mappings[:seed]],
              @fields[mappings[:account]],
              @fields[mappings[:order]],
              @fields[mappings[:test]],
              @fields[mappings[:currency]],
              @fields[mappings[:amount]],
              secret
            ].join
          end

          def notify_signature_string
            [
              params['batch_timestamp'],
              params['currency_id'],
              params['amount'],
              params['payment_method'],
              params['order_id'],
              params['site_order_id'],
              params['transaction_id'],
              params['payment_type'],
              params['rrn'],
              secret
            ].join
          end
        end
      end
    end
  end
end
