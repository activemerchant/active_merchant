require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Coinbase
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          def complete?
            status == "completed"
          end

          def item_id
            params['custom']
          end

          def transaction_id
            params['id']
          end

          # When was this payment received by the client.
          def received_at
            Time.iso8601(params['created_at']).to_time.to_i
          end

          # the money amount we received in X.2 decimal.
          def gross
            params['total_native']['cents'].to_f / 100
          end

          def currency
            params['total_native']['currency_iso']
          end

          # Was this a test transaction?
          def test?
            false
          end

          def status
            params['status']
          end

          # Acknowledge the transaction to Coinbase. This method has to be called after a new
          # apc arrives. Coinbase will verify that all the information we received are correct and will return a
          # ok or a fail.
          #
          # authcode should be the same api_key passed into payment_service_for
          #
          # Example:
          #
          #   def ipn
          #     notify = CoinbaseNotification.new(request.raw_post)
          #
          #     if notify.acknowledge(api_key)
          #       ... process order ... if notify.complete?
          #     else
          #       ... log possible hacking attempt ...
          #     end
          def acknowledge(authcode = nil)

            uri = URI.parse(Coinbase.notification_confirmation_url % transaction_id)

            request = Net::HTTP::Get.new("#{uri.path}?api_key=%s" % authcode)

            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl        = true

            response = http.request(request).body
            order = JSON.parse(response)
            
            if order.nil?
            	return false
            end
            
            order = order['order']

            # check all properties with the server
            order['custom'] == @params['custom'] && order['created_at'] == @params['created_at'] && order['total_native'] == @params['total_native'] && order['status'] == @params['status']
          end

          private

          # Take the posted data and move the relevant data into a hash
          def parse(post)
            raw = post.to_s
            @params = JSON.parse(raw)
            @params = @params['order']
          end
        end
      end
    end
  end
end
