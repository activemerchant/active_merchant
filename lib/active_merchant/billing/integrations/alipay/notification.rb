require 'net/http'
require 'active_merchant/billing/integrations/alipay/sign'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Alipay
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          include Sign

          def complete?
            trade_status == "TRADE_FINISHED"
          end

          def pending?
            trade_status == 'WAIT_BUYER_PAY'
          end

          def status
            trade_status
          end

          def acknowledge
            raise StandardError.new("Faulty alipay result: ILLEGAL_SIGN") unless verify_sign
            true
          end

          ['extra_common_param', 'notify_type', 'notify_id', 'out_trade_no', 'trade_no', 'payment_type', 'subject', 'body',
            'seller_email', 'seller_id', 'buyer_email', 'buyer_id', 'logistics_type', 'logistics_payment',
            'receive_name', 'receive_address', 'receive_zip', 'receive_phone', 'receive_mobile'].each do |param|
            self.class_eval <<-EOF
              def #{param}
                params['#{param}']
              end
            EOF
          end

          ['price', 'discount', 'quantity', 'total_fee', 'coupon_discount', 'logistics_fee'].each do |param|
            self.class_eval <<-EOF
              def #{param}
                params['#{param}']
              end
            EOF
          end

          ['trade_status', 'refund_status', 'logistics_status'].each do |param|
            self.class_eval <<-EOF
              def #{param}
                params['#{param}']
              end
            EOF
          end

          ['notify_time', 'gmt_create', 'gmt_payment', 'gmt_close', 'gmt_refund', 'gmt_send_goods', 'gmt_logistics_modify'].each do |param|
            self.class_eval <<-EOF
              def #{param}
                Time.parse params['#{param}']
              end
            EOF
          end

          ['use_coupon', 'is_total_fee_adjust'].each do |param|
            self.class_eval <<-EOF
              def #{param}?
                'T' == params['#{param}']
              end
            EOF
          end

          private

          # Take the posted data and move the relevant data into a hash
          def parse(post)
            @raw = post
            for line in post.split('&')
              key, value = *line.scan( %r{^(\w+)\=(.*)$} ).flatten
              params[key] = CGI.unescape(value || '')
            end
          end
        end
      end
    end
  end
end
