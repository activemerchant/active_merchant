require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Winpay
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          %w(
            id
            phone
            goodphone
            smstext
            result
            control
          ).each do |param_name|
            define_method(param_name.underscore){ params[param_name] }
          end

          alias_method :shop_payment_id, :id
          alias_method :wallet_id, :phone
          alias_method :shop_id, :goodphone
          alias_method :payment_info, :smstext
          alias_method :result_status, :result

          def status
            if result_status && @options[:req_type] == 'pay' && result_status.to_i == 0
              'completed'
            elsif @options[:req_type] == 'check'
              'pending'
            else
              'failed'
            end
          end

          def amount
            if @options[:req_type] == 'check'
              amount_string = payment_info.split(' ')[2]
              amount_string.nil? ? nil : amount_string.to_f
            else
              nil
            end
          end

          def generate_signature
            if @options[:req_type] == 'pay'
              string = [shop_payment_id, wallet_id, result_status, @options[:secret]].join()
            else
              string = [shop_payment_id, wallet_id, shop_id, payment_info, @options[:secret]].join()
            end
            Digest::MD5.hexdigest(string)
          end

          def acknowledge
            generate_signature == control
          end

        end
      end
    end
  end
end