require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module WirecardCheckoutPage
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          include Common

          def complete?
            @paymentstate == 'SUCCESS'
          end

          def item_id
            params['xActiveMerchantOrderId']
          end

          def transaction_id
            params['orderNumber']
          end

          # When was this payment received by the client.
          def received_at
            nil
          end

          # the money amount we received in X.2 decimal.
          def gross
            params['amount']
          end

          # Was this a test transaction?
          def test?
            false
          end

          def status
            case @paymentstate
              when 'SUCCESS'
                'Completed'
              when 'PENDING'
                'Pending'
              when 'CANCEL'
                'Cancelled'
              when 'FAILURE'
                'Failed'
              else
                'Error'
            end
          end

          def status_code
            @paymentstate
          end


          # Acknowledge the transaction to WirecardCheckoutPage. This method has to be called after a new
          # apc arrives. WirecardCheckoutPage will verify that all the information we received are correct and will return a
          # ok or a fail.
          #
          # Example:
          #
          #   def ipn
          #     notify = WirecardCheckoutPageNotification.new(request.raw_post, options)
          #
          #     if notify.acknowledge
          #       ... process order ... if notify.complete?
          #     else
          #       ... log possible hacking attempt ...
          #     end
          def acknowledge
            verify_response(params, @options[:secret])
          end

          def response(umessage = nil)
            if @message || umessage
              '<QPAY-CONFIRMATION-RESPONSE result="NOK" message="' + CGI.escapeHTML(umessage ? umessage : @message) + '"/>'
            else
              '<QPAY-CONFIRMATION-RESPONSE result="OK"/>'
            end
          end

          def method_missing(method_id, *args)
            return params[method_id.to_s] if params.has_key?(method_id.to_s)
          end

          private

          # Take the posted data and move the relevant data into a hash
          def parse(post)
            @raw = post.to_s
            for line in @raw.split('&')
              key, value = *line.scan( %r{^([A-Za-z0-9_.]+)\=(.*)$} ).flatten
              params[key] = CGI.unescape(value)
            end
          end
        end
      end
    end
  end
end
