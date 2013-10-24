require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module BitPay
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          def complete?
            status == "complete"
          end

          def transaction_id
            params['id']
          end

          # When was this payment received by the client.
          def received_at
            params['invoiceTime'].to_i
          end

          def currency
            params['currency']
          end

          def amount
            params['price']
          end

          # the money amount we received in X.2 decimal.
          def btcPrice 
            params['btcPrice'].to_f
          end

          def status
            params['status'].downcase
          end

          def acknowledge(authcode = nil)
            authcode == params['posData']
          end

          private

          # Take the posted data and move the relevant data into a hash
          def parse(post)
            @raw = post.to_s
            params.merge!(Rack::Utils.parse_query(@raw.force_encoding('ASCII-8BIT')))
          end
        end
      end
    end
  end
end
