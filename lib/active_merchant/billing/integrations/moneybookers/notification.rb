require 'net/http'
require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Moneybookers
        class Notification < ActiveMerchant::Billing::Integrations::Notification

          def initialize(data, options)
            if options[:credential2].nil?
              raise ArgumentError, "You need to provide the md5 secret as the option :credential2 to verify that the notification originated from Moneybookers"
            end
            super
          end
          
          def complete?
            status == "2"
          end

          def status
            params['status']
          end

          def item_id
            params['transaction_id']
          end

          def transaction_id
            params['transaction_id'] || params['mb_transaction_id']
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
          def acknowledge
            fields = [merchant_id, transaction_id, Digest::MD5.hexdigest(secret).upcase, gross, currency, status].join
            md5sig == Digest::MD5.hexdigest(fields).upcase
          end
        end
      end
    end
  end
end
