module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module EasyPay
        module Common
          def generate_signature(type)
            string = case type
                     when :request
                       request_signature_string
                     when :notify
                       notify_signature_string
                     end

            Digest::MD5.hexdigest(string)
          end

          def request_signature_string
            [
              @fields[mappings[:account]],
              @secret,
              @fields[mappings[:order]],
              @fields[mappings[:amount]]
            ].join
          end

          def notify_signature_string
            [
              params['order_mer_code'],
              params['sum'],
              params['mer_no'],
              params['card'],
              params['purch_date'],
              secret
            ].join
          end
        end
      end
    end
  end
end
