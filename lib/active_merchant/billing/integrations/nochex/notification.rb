require 'net/http'
require 'date'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Nochex
        # Parser and handler for incoming Automatic Payment Confirmations from Nochex.
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          include ActiveMerchant::PostsData

          def complete?
            status == 'Completed'
          end 

          # Id of the order we passed to Nochex
          def item_id
            params['order_id']
          end

          def transaction_id
            params['transaction_id']
          end

          def currency
            'GBP'
          end
  
          # When was this payment received by the client. 
          def received_at
            # U.K. Format: 27/09/2006 22:30:54
            return if params['transaction_date'].blank?
            time = params['transaction_date'].scan(/\d+/)
            Time.utc(time[2], time[1], time[0], time[3], time[4], time[5])
          end

          def payer_email
            params['from_email']
          end
         
          def receiver_email
            params['to_email']
          end 

          def security_key
            params['security_key']
          end

          # the money amount we received in X.2 decimal.
          def gross
            params['amount']
          end

          # Was this a test transaction?
          def test?
            params['status'] == 'test'
          end

          def status
            'Completed'
          end

          # Acknowledge the transaction to Nochex. This method has to be called after a new 
          # apc arrives. Nochex will verify that all the information we received are correct and will return a 
          # ok or a fail. This is very similar to the PayPal IPN scheme.
          # 
          # Example:
          # 
          #   def nochex_ipn
          #     notify = NochexNotification.new(request.raw_post)
          #
          #     if notify.acknowledge 
          #       ... process order ... if notify.complete?
          #     else
          #       ... log possible hacking attempt ...
          #     end
          def acknowledge      
            payload = raw

            uri = URI.parse(Nochex.notification_confirmation_url)

            request = Net::HTTP::Post.new(uri.path)

            request['Content-Length'] = "#{payload.size}"
            request['User-Agent'] = "Active Merchant -- http://home.leetsoft.com/am"
            request['Content-Type'] = "application/x-www-form-urlencoded" 

            http = Net::HTTP.new(uri.host, uri.port)
            http.verify_mode    = OpenSSL::SSL::VERIFY_NONE unless @ssl_strict
            http.use_ssl        = true

            response = http.request(request, payload)

            raise StandardError.new("Faulty Nochex result: #{response.body}") unless ["AUTHORISED", "DECLINED"].include?(response.body)
            response.body == "AUTHORISED"
          end
        end
      end
    end
  end
end
