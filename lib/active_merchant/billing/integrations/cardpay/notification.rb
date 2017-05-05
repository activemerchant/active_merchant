require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Cardpay
        class Notification < ActiveMerchant::Billing::Integrations::Notification

          %w(orderXML sha512).each do |param_name|
            define_method(param_name.underscore){ params[param_name] }
          end

          alias_method :signature, :sha512

          def payment_params
            (Hash.from_xml(request_xml) rescue {})["order"]
          end

          def request_xml
            Base64.decode64(order_xml)
          end

          def status
            case payment_params["status"]
              when 'APPROVED' then 'completed'
              when 'DECLINED' then 'canceled'
              when 'PENDING' then 'pending'
              else 'unknown'
            end
          end

          def amount
            payment_params["amount"].to_f
          end

          def currency
            payment_params["currency"]
          end

          def payment_id
            payment_params["number"].to_i
          end

          def generate_signature
            Digest::SHA512.hexdigest(request_xml + @options[:secret])
          end

          def acknowledge
            signature.strip == generate_signature && status == 'completed'
          end

        end
      end
    end
  end
end