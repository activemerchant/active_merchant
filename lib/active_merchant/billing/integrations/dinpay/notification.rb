require 'net/http'
require 'openssl'
require 'base64'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Dinpay
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          %w(
            merchant_code
            interface_version
            sign_type
            sign
            notify_type
            notify_id
            order_no
            order_time
            order_amount
            trade_status
            trade_time
            trade_no
            bank_seq_no
            extra_return_param
          ).each do |param_name|
            define_method(param_name.underscore){ params[param_name] }
          end

          alias_method :amount, :order_amount
          alias_method :status, :trade_status

          def generate_signature
            sign = ''
            sign += "bank_seq_no=#{bank_seq_no}&" if bank_seq_no
            sign += "extra_return_param=#{extra_return_param}&" if extra_return_param
            sign += %w(
              interface_version
              merchant_code
              notify_id
              notify_type
              order_amount
              order_no
              order_time
              trade_no
              trade_status
              trade_time
            ).map {|key| "#{key}=#{params[key]}"}.join('&')
          end

          def acknowledge
            dd4sign =  Base64.decode64(sign)
            dd4_key = OpenSSL::PKey::RSA.new(@options[:secret])
            dd4_key.verify(OpenSSL::Digest::MD5.new, dd4sign, generate_signature)
          end
        end
      end
    end
  end
end
