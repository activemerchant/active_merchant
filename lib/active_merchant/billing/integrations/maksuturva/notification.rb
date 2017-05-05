require "net/http"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Maksuturva
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          def complete?
            true
          end

          def transaction_id
            params["pmt_id"]
          end

          def security_key
            params["pmt_hash"]
          end

          def gross
            params["pmt_amount"]
          end

          def currency
            params["pmt_currency"]
          end

          def status
            "PAID"
          end

          def acknowledge(authcode = nil)
            return_authcode = [params["pmt_action"], params["pmt_version"], params["pmt_id"], params["pmt_reference"], params["pmt_amount"], params["pmt_currency"], params["pmt_sellercosts"], params["pmt_paymentmethod"], params["pmt_escrow"], authcode].join("&")
            (Digest::MD5.hexdigest(return_authcode + "&").upcase == params["pmt_hash"])
          end

          private

          def parse(post)
            post.each do |key, value|
              params[key] = value
            end
          end
        end
      end
    end
  end
end
