require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Adyen
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          def complete?
            ((params['eventCode'] == 'AUTHORISATION') and (params['success'] == 'true'))
          end 

          def event_code
            params['eventCode']
          end

          def item_id
            params['merchantReference']
          end

          def transaction_id
            params['pspReference']
          end

          # When was this payment received by the client. 
          def received_at
            params['eventDate']
          end

          def payer_email
            ''#params['']
          end
         
          def receiver_email
            ''#params['']
          end 

          def security_key
            ''#params['']
          end

          # the money amount we received in X.2 decimal.
          def gross
            params['value']
          end

          # Was this a test transaction?
          def test?
            params['live'] == 'false'
          end

          def status
            params['success']
          end

          def currency
            params['currency']
          end

          # Acknowledge the transaction to Adyen. This method has to be called after a new 
          # apc arrives. Adyen will verify that all the information we received are correct and will return a 
          # ok or a fail. 
          # 
          # Example:
          # 
          #   def ipn
          #     notify = AdyenNotification.new(request.raw_post)
          #
          #     if notify.acknowledge 
          #       ... process order ... if notify.complete?
          #     else
          #       ... log possible hacking attempt ...
          #     end
          def acknowledge      
            # this is a stub because Adyen does not support this feature, as of 2009-10-12
            true
          end
 private

          # Take the posted data and move the relevant data into a hash
          def parse(post)
            @raw = post
            for line in post.split('&')
              key, value = *line.scan( %r{^(\w+)\=(.*)$} ).flatten
              @params[key] = value
            end
          end
        end
      end
    end
  end
end
