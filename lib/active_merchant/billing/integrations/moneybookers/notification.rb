require 'net/http'
require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Moneybookers
        class Notification < ActiveMerchant::Billing::Integrations::Notification


          def complete?
            status == 'Completed'
          end

          # ‘2’ Processed – This status is sent when the transaction is processed and the funds have been received on your Moneybookers account.
          # ‘0’ Pending – This status is sent when the customers pays via the pending bank transfer option. Such transactions will auto-process IF the bank transfer is received by Moneybookers. We strongly recommend that you do NOT process the order/transaction in your system upon receipt of a pending status from Moneybookers.
          # ‘-1’ Cancelled – Pending transactions can either be cancelled manually by the sender in their online account history or they will auto-cancel after 14 days if still pending.
          # ‘-2’ Failed – This status is sent when the customer tries to pay via Credit Card or Direct Debit but our provider declines the transaction. If you do not accept Credit Card or Direct Debit payments via Moneybookers (see page 17) then you will never receive the failed status.
          # ‘-3’ Chargeback – This status could be received only if your account is configured to receive chargebacks. If this is the case, whenever a chargeback is received by Moneybookers, a -3 status will be posted on the status_url for the reversed transaction.
          def status
            case status_code
            when '2'
              'Completed'
            when '0'
              'Pending'
            when '-1'
              'Cancelled'
            when '-2'
              'Failed'
            when '-3'
              'Reversed'
            else
              'Error'
            end
          end
          
          def status_code
            params['status']
          end
          
          def item_id
            params['transaction_id']
          end

          def transaction_id
            params['mb_transaction_id']
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

          # currency of the payment as posted by the merchant on the entry form
          def currency
            params['currency']
          end

          # amount of the payment as posted by the merchant on the entry form (ex. 39.60/39.6/39)
          def gross
            params['amount']
          end

          # currency of mb_amount, will always be the same as the currency of the beneficiary's account at Moneybookers.com
          def merchant_currency
            params['mb_currency']
          end

          # total amount of the payment in Merchants currency (ex 25.46/25.4/25)
          def merchant_amount
            params['mb_amount']
          end

          # Was this a test transaction?
          def test?
            false
          end
          
          def secret
            @options[:credential2]
          end
          
          # Acknowledge the transaction to MoneyBooker. This method has to be called after a new 
          # apc arrives. It will verify that all the information we received is correct and will return a
          # ok or a fail. The secret (second credential) has to be provided in the parameter :credential2
          # when instantiating the Notification object.
          # 
          # Example:
          # 
          #   def ipn
          #     notify = Moneybookers.notification(request.raw_post, :credential2 => 'secret')
          #
          #     if notify.acknowledge
          #       ... process order ... if notify.complete?
          #     else
          #       ... log possible hacking attempt ...
          #     end
          def acknowledge(authcode = nil)
            fields = [merchant_id, item_id, Digest::MD5.hexdigest(secret.to_s).upcase, merchant_amount, merchant_currency, status_code].join
            md5sig == Digest::MD5.hexdigest(fields).upcase
          end
        end
      end
    end
  end
end
