require "net/http"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Maksuturva
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          def complete?
            # Payment status can only be true, if it's cancelled then cancel url is used
            true
          end 

          def item_id
            params[""]
          end

          def transaction_id
            params["pmt_id"]
          end

          # When was this payment received by the client. 
          def received_at
            params[""]
          end

          def payer_email
            params[""]
          end
         
          def receiver_email
            params[""]
          end 

          def security_key
            params["pmt_hash"]
          end

          # the money amount we received in X.2 decimal.
          def gross
            params["pmt_amount"]
          end
          
          def currency
            params["pmt_currency"]
          end

          # Was this a test transaction?
          def test?
            params[""] == "test"
          end

          def status
            "PAID"
          end

          def acknowledge(authcode)
            return_authcode = [params["pmt_action"], params["pmt_version"], params["pmt_id"], params["pmt_reference"], params["pmt_amount"], params["pmt_currency"], params["pmt_sellercosts"], params["pmt_paymentmethod"], params["pmt_escrow"], authcode].join("&")
            Digest::MD5.hexdigest(return_authcode + "&").upcase == params["pmt_hash"]
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
