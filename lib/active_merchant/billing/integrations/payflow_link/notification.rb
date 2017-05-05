require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PayflowLink
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          
          # Was the transaction complete?
          def complete?
            status == "Completed"
          end

          # When was this payment received by the client. 
          # sometimes it can happen that we get the notification much later. 
          # One possible scenario is that our web application was down. In this case paypal tries several 
          # times an hour to inform us about the notification
          def received_at
            DateTime.parse(params['TRANSTIME']) if params['TRANSTIME']
          rescue ArgumentError
            nil
          end

          def status
            params['RESPMSG']
          end

          # Id of this transaction (paypal number)
          def transaction_id
            params['PNREF']
          end

          # What type of transaction are we dealing with? 
          def type
            params['TYPE']
          end

          # the money amount we received in X.2 decimal.
          def gross
            params['AMT']
          end

          # What currency have we been dealing with
          def currency
            nil
          end

          def status
            params['RESULT'] == '0' ? 'Completed' : 'Failed'
          end

          # This is the item number which we submitted to paypal 
          def item_id
            params['USER1']
          end

          # This is the invoice which you passed to paypal 
          def invoice
            params['INVNUM']
          end   

          # Was this a test transaction?
          def test?
            params['USER2'] == 'true'
          end
          
          def account
            params["ACCT"]
          end

          def acknowledge(authcode = nil)
            true
          end
        end
      end
    end
  end
end
