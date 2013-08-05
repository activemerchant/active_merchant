require "digest/sha1"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Ipay88
        class Return < ActiveMerchant::Billing::Integrations::Return
          include ActiveMerchant::PostsData

          def account
            params["MerchantCode"]
          end

          def payment
            params["PaymentId"].to_i
          end

          def order
            params["RefNo"]
          end

          def amount
            params["Amount"]
          end

          def currency
            params["Currency"]
          end

          def remark
            params["Remark"]
          end

          def transaction
            params["TransId"]
          end

          def auth_code
            params["AuthCode"]
          end

          def status
            params["Status"]
          end

          def error
            params["ErrDesc"]
          end

          def signature
            params["Signature"]
          end

          def secure?
            self.generated_signature == self.signature
          end

          def success?
            self.secure? && self.requery == "00" && self.status == "1"
          end

          protected

          def generated_signature
            Helper.sign(self.sig_components)
          end

          def sig_components
            components = [@options[:credential2]]
            [:account, :payment, :order, :amount_in_cents, :currency, :status].each do |i|
              components << self.send(i)
            end
            components.join
          end

          def requery
            data   = { "MerchantCode" => self.account, "RefNo" => self.order, "Amount" => self.amount }
            params = parameterize(data)
            ssl_post Ipay88.service_url, params, { "Content-Length" => params.size.to_s, "User-Agent" => "Active Merchant -- http://activemerchant.org" }
          end

          private

          def parameterize(params)
            params.reject { |k, v| v.blank? }.keys.sort.collect { |key| "#{key}=#{CGI.escape(params[key].to_s)}" }.join("&")
          end

          def amount_in_cents
            @amount_in_cents ||= (self.amount || "").gsub(/[.,]/, "")
          end
        end
      end
    end
  end
end
