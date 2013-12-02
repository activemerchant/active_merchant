require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PayFast
        # Parser and handler for incoming ITN from PayFast.
        # The Example shows a typical handler in a rails application.
        #
        # Example
        #
        #   class BackendController < ApplicationController
        #     include ActiveMerchant::Billing::Integrations
        #
        #     def pay_fast_itn
        #       notify = PayFast::Notification.new(request.raw_post)
        #
        #       order = Order.find(notify.item_id)
        #
        #       if notify.acknowledge
        #         begin
        #
        #           if notify.complete? and order.total == notify.amount
        #             order.status = 'success'
        #
        #             shop.ship(order)
        #           else
        #             logger.error("Failed to verify Paypal's notification, please investigate")
        #           end
        #
        #         rescue => e
        #           order.status = 'failed'
        #           raise
        #         ensure
        #           order.save
        #         end
        #       end
        #
        #       render :nothing
        #     end
        #   end
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          include PostsData
          include Common

          # Was the transaction complete?
          def complete?
            status == "Completed"
          end

          # Status of transaction. List of possible values:
          # <tt>COMPLETE</tt>::
          def status
            if params['payment_status'] == "COMPLETE"
              "Completed"
            else
              "Failed"
            end
          end

          # Id of this transaction (uniq PayFast transaction id)
          def transaction_id
            params['pf_payment_id']
          end

          # Id of this transaction (uniq Shopify transaction id)
          def item_id
            params['m_payment_id']
          end

          # The total amount which the payer paid.
          def gross
            params['amount_gross']
          end

          # The total in fees which was deducted from the amount.
          def fee
            params['amount_fee']
          end

          # The net amount credited to the receiver's account.
          def amount
            params['amount_net']
          end

          # The name of the item being charged for.
          def item_name
            params['item_name']
          end

          # The Merchant ID as given by the PayFast system. Used to uniquely identify the receiver's account.
          def merchant_id
            params['merchant_id']
          end
          
          def currency
            nil
          end
          # Generated hash depends on params order so use OrderedHash instead of Hash
          def empty!
            super
            @params  = ActiveSupport::OrderedHash.new
          end

          # Acknowledge the transaction to PayFast. This method has to be called after a new
          # ITN arrives. PayFast will verify that all the information we received are correct and will return a
          # VERIFIED or INVALID status.
          #
          # Example:
          #
          #   def pay_fast_itn
          #     notify = PayFastNotification.new(request.raw_post)
          #
          #     if notify.acknowledge
          #       ... process order ... if notify.complete?
          #     else
          #       ... log possible hacking attempt ...
          #     end
          def acknowledge(authcode = nil)
            if params[PayFast.signature_parameter_name] == generate_signature(:notify)
              response = ssl_post(PayFast.validate_service_url, notify_signature_string,
                'Content-Type' => "application/x-www-form-urlencoded",
                'Content-Length' => "#{notify_signature_string.size}"
              )
              raise StandardError.new("Faulty PayFast result: #{response}") unless ['VALID', 'INVALID'].include?(response)

              response == "VALID"
            end
          end
        end
      end
    end
  end
end
