module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Ipay88
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          include ActiveMerchant::PostsData

          def status
            params["Status"] == '1' ? 'Completed' : 'Failed'
          end

          def complete?
            status == 'Completed'
          end

          def item_id
            params["RefNo"]
          end

          def gross
            params["Amount"]
          end

          def currency
            params["Currency"]
          end

          def account
            params["MerchantCode"]
          end

          def payment
            params["PaymentId"].to_i
          end

          def remark
            params["Remark"]
          end

          def transaction_id
            params["TransId"]
          end

          def auth_code
            params["AuthCode"]
          end

          def error
            params["ErrDesc"]
          end

          def signature
            params["Signature"]
          end

          def secure?
            generated_signature == signature
          end

          def success?
            status == 'Completed'
          end

          def acknowledge
            secure? && success? && requery == "00"
          end

          protected

          def generated_signature
            Helper.sign(sig_components)
          end

          def sig_components
            components = [@options[:credential2]]
            [:account, :payment, :item_id, :amount_in_cents, :currency].each do |i|
              components << send(i)
            end
            components << params["Status"]
            components.join
          end

          def requery
            data   = { "MerchantCode" => account, "RefNo" => item_id, "Amount" => gross }
            params = parameterize(data)
            ssl_post Ipay88.requery_url, params, { "Content-Length" => params.size.to_s, "User-Agent" => "Active Merchant -- http://activemerchant.org" }
          end

          private

          def parameterize(params)
            params.reject { |k, v| v.blank? }.keys.sort.collect { |key| "#{key}=#{CGI.escape(params[key].to_s)}" }.join("&")
          end

          def amount_in_cents
            @amount_in_cents ||= (gross || "").gsub(/[.,]/, "")
          end
        end
      end
    end
  end
end

