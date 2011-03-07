require 'net/http'
require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Moneybookers
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          include PostsData

          # was the transaction comlete?
          def complete?
            status == "2"
          end

          def status
            params['status']
          end

          def item_id
            nil
          end

          def transaction_id
            if params.has_key?("transaction_id")
              params['transaction_id']
            else
              params['mb_transaction_id']
            end
          end

          # When was this payment received by the client. 
          def received_at
            nil
          end

          def payer_email
            params['pay_from_email']
          end
         
          def receiver_email
            params['pay_to_email']
          end 

          def md5sig
            params['md5sig']
          end

          #Unique ID from the merchant's Moneybookers.com account, needed for calculatinon of md5 sig
          def merchant_id
            params['merchant_id']
          end

          # currency of mb_amount, will always be the same as the currency of the beneficiary's account at Moneybookers.com
          def currency
            params['mb_currency']
          end

          # total amount of the payment in Merchants currency (ex 25.46/25.4/25)
          def gross
            params['mb_amount']
          end

          # currency of the payment as posted by the merchant on the entry form
          def posted_currency
            params['currency']
          end

          # amount of the payment as posted by the merchant on the entry form (ex. 39.60/39.6/39)
          def posted_amount
            params['amount']
          end

          # Was this a test transaction?
          def test?
            false
          end

          # Acknowledge the transaction to MoneyBooker. This method has to be called after a new 
          # apc arrives. It will verify that all the information we received is correct and will return a
          # ok or a fail.
          # 
          # Example:
          # 
          #   def ipn
          #     notify = Moneybookers::Notification.new(request.raw_post)
          #
          #     if notify.acknowledge('secretpass')
          #       ... process order ... if notify.complete?
          #     else
          #       ... log possible hacking attempt ...
          #     end
          def acknowledge(secret = '')
            fields = [merchant_id, transaction_id, Digest::MD5.hexdigest(secret).upcase, gross, currency, status].join
            md5sig == Digest::MD5.hexdigest(fields).upcase
          end
        end
      end
    end
  end
end
