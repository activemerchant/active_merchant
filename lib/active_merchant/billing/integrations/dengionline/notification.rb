module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Dengionline
        class Notification < ActiveMerchant::Billing::Integrations::Notification

          def initialize(query_string, options = {})
            super(query_string, options)
            self.secret = @options[:secret]
          end

          def gross
            params["amount"]
          end

          def amount
            BigDecimal.new(gross)
          end

          def nickname
            params["userid"]
          end

          def payment_id
            params["paymentid"]
          end

          def verification_hash
            params["key"]
          end

          def transaction_type
            params["paymode"]
          end

          def nick_extra
            params["userid_extra"]
          end

          def order
            params["orderid"]
          end

          def secret
            @secret
          end

          def secret= (value)
            @secret = value.to_s
          end

          def generate_signature
            Digest::MD5.hexdigest [gross, nickname, payment_id, secret].join
          end

          def acknowledged?
            verification_hash == generate_signature
          end
          alias_method :acknowledge, :acknowledged?

          def generate_response(code, options = {})
            options.assert_valid_keys [:id, :comment, :course]
            c = "<code>#{code}</code>"
            o = ""
            options.each { |k, v| s += "<#{k.to_s}>#{v.to_s}</#{k.to_s}>" }
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?><result>#{c}#{o}</result>"
          end

        end
      end
    end
  end
end
