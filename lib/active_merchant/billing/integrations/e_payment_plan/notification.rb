require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module EPaymentPlan
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          def complete?
            params['status'] == "completed"
          end

          def transaction_id
            params['transaction_id']
          end

          def order_id
            params['order_id']
          end

          # When was this payment received by the client.
          def received_at
            params['received_at']
          end

          def security_key
            params['security_key']
          end

          # Was this a test transaction?
          def test?
            params['test'] == 'test'
          end

          def status
            params['status']
          end

          # Acknowledge the transaction to EPaymentPlan. This method has to be called after a new
          # apc arrives. EPaymentPlan will verify that all the information we received are correct and will return a 
          # ok or a fail.
          #
          # Example:
          #
          #   def ipn
          #     notify = EPaymentPlanNotification.new(request.raw_post)
          #
          #     if notify.acknowledge
          #       ... process order ... if notify.complete?
          #     else
          #       ... log possible hacking attempt ...
          #     end

          def ssl_post(payload)
            uri = URI.parse(EPaymentPlan.notification_confirmation_url)

            request = Net::HTTP::Post.new(uri.path)

            request['Content-Length'] = "#{payload.size}"
            request['User-Agent'] = "Active Merchant -- http://home.leetsoft.com/am"
            request['Content-Type'] = "application/x-www-form-urlencoded"

            http = Net::HTTP.new(uri.host, uri.port)
            http.verify_mode    = OpenSSL::SSL::VERIFY_NONE unless @ssl_strict
            http.use_ssl        = true
            response = http.request(request, payload)
            response.body
          end

          def acknowledge
            payload = raw

            response = ssl_post(payload)

            # Replace with the appropriate codes
            raise StandardError.new("Faulty EPaymentPlan result: #{response}") unless ["AUTHORISED", "DECLINED"].include?(response)
            response == "AUTHORISED"
          end

          private
          # Take the posted data and move the relevant data into a hash
          def parse(post)
            @raw = post
            for line in post.split('&')
              key, value = *line.scan( %r{^(\w+)\=(.*)$} ).flatten
              params[key] = value
            end
          end
        end
      end
    end
  end
end
