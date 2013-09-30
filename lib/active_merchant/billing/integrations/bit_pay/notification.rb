require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module BitPay
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          def complete?
            params['status'] = "Completed"
          end

          def item_id
            params['posData']
          end

          def transaction_id
            params['id']
          end

          # When was this payment received by the client.
          def received_at
            params['invoiceTime']
          end

          # the money amount we received in X.2 decimal.
          def gross
            params['price']
          end

          def status
            params['status']
          end

          # Acknowledge the transaction to BitPay. This method has to be called after a new
          # apc arrives. BitPay will verify that all the information we received are correct and will return a
          # ok or a fail.
          #
          # Example:
          #
          #   def ipn
          #     notify = BitPayNotification.new(request.raw_post)
          #
          #     if notify.acknowledge
          #       ... process order ... if notify.complete?
          #     else
          #       ... log possible hacking attempt ...
          #     end
          def acknowledge(order)
            #GET during ack is bad.
            completed? && item_id == order.id
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
