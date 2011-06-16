require "digest/sha1"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Ipay88
        class Return < ActiveMerchant::Billing::Integrations::Return
          include ActiveMerchant::PostsData

          # Merchant Code assigned by iPay88
          def account
            params["MerchantCode"]
          end

          # The payment method
          def payment
            params["PaymentId"].to_i
          end

          # Unique merchant transaction number
          def order
            params["RefNo"]
          end

          # The payment with two decimals
          def amount
            params["Amount"]
          end

          # The currency. List of possible values:
          # <tt>MYR</tt>::
          # <tt>USD</tt>::
          # <tt>CNY</tt>::
          def currency
            params["Currency"]
          end

          # Merchant remark
          def remark
            params["Remark"]
          end

          # Transaction ID from iPay88
          def transaction
            params["TransId"]
          end

          # Bank's approval code
          def auth_code
            params["AuthCode"]
          end

          # Payment status. List of possible values:
          # <tt>1</tt>:: Success
          # <tt>0</tt>:: Fail
          def status
            params["Status"]
          end

          # The error description. List of possible values:
          # <tt>Duplicate reference number</tt>::
          # <tt>Invalid merchant</tt>::
          # <tt>Invalid parameters</tt>::
          # <tt>Overlimit per transaction</tt>::
          # <tt>Payment not allowed</tt>::
          # <tt>Permission not allow</tt>::
          # <tt>Signature not match</tt>::
          # <tt>Status not approved</tt>::
          def error
            params["ErrDesc"]
          end

          # The hash signature
          def signature
            params["Signature"]
          end

          # Convenience method to check if the request is secure by
          # checking the incoming signature against our own generated
          # signature
          def secure?
            self.generated_signature == self.signature
          end

          # Was the transaction successful?
          def success?
            self.secure? && self.requery == "00" && self.status == "1"
          end

          protected
          def generated_signature #:nodoc:
            Helper.sign(self.sig_components)
          end

          def sig_components #:nodoc:
            components = [Ipay88.merchant_key]
            [:account, :payment, :order, :amount_in_cents, :currency, :status].each do |i|
              components << self.send(i)
            end
            components.join
          end

          def requery #:nodoc:
            data   = { "MerchantCode" => self.account, "RefNo" => self.order, "Amount" => self.amount }
            params = parameterize(data)
            ssl_post Ipay88.service_url, params, { "Content-Length" => params.size.to_s, "User-Agent" => "Active Merchant -- http://activemerchant.org" }
          end

          private
          def parameterize(params) #:nodoc:
            params.reject { |k, v| v.blank? }.keys.sort.collect { |key| "#{key}=#{CGI.escape(params[key].to_s)}" }.join("&")
          end

          def amount_in_cents #:nodoc:
            @amount_in_cents ||= (self.amount || "").gsub(/[.,]/, "")
          end
        end
      end
    end
  end
end
