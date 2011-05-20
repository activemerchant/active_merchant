require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module EPaymentPlan
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          include ActiveMerchant::PostsData
          def complete?
            status == "Completed"
          end

          def transaction_id
            params['transaction_id']
          end

          def item_id
            params['item_id']
          end

          # When was this payment received by the client.
          def received_at
            Time.parse(params['received_at'].to_s).utc
          end

          def gross
            params['gross']
          end

          def currency
            params['currency']
          end

          def security_key
            params['security_key']
          end

          # Was this a test transaction?
          def test?
            params['test'] == 'test'
          end

          def status
            params['status'].capitalize
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
