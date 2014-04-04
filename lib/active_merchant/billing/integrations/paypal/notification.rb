require 'net/http'
require 'time'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Paypal
        # Parser and handler for incoming Instant payment notifications from paypal.
        # The Example shows a typical handler in a rails application. Note that this
        # is an example, please read the Paypal API documentation for all the details
        # on creating a safe payment controller.
        #
        # Example
        #
        #   class BackendController < ApplicationController
        #     include ActiveMerchant::Billing::Integrations
        #
        #     def paypal_ipn
        #       notify = Paypal::Notification.new(request.raw_post)
        #
        #       if notify.masspay?
        #         masspay_items = notify.items
        #       end
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
        #           order.status        = 'failed'
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

          def initialize(post, options = {})
            super
            extend MassPayNotification if masspay?
          end

          # Was the transaction complete?
          def complete?
            status == "Completed"
          end

          # Is it a masspay notification?
          def masspay?
            type == "masspay"
          end

          # When was this payment received by the client.
          # sometimes it can happen that we get the notification much later.
          # One possible scenario is that our web application was down. In this case paypal tries several
          # times an hour to inform us about the notification
          def received_at
            parsed_time_fields = DateTime._strptime(params['payment_date'], "%H:%M:%S %b %d, %Y %Z")
            Time.gm(
              parsed_time_fields[:year],
              parsed_time_fields[:mon],
              parsed_time_fields[:mday],
              parsed_time_fields[:hour],
              parsed_time_fields[:min],
              parsed_time_fields[:sec]
            ) - Time.zone_offset(parsed_time_fields[:zone])
          end

          # Status of transaction. List of possible values:
          # <tt>Canceled-Reversal</tt>::
          # <tt>Completed</tt>::
          # <tt>Denied</tt>::
          # <tt>Expired</tt>::
          # <tt>Failed</tt>::
          # <tt>In-Progress</tt>::
          # <tt>Partially-Refunded</tt>::
          # <tt>Pending</tt>::
          # <tt>Processed</tt>::
          # <tt>Refunded</tt>::
          # <tt>Reversed</tt>::
          # <tt>Voided</tt>::
          def status
            params['payment_status']
          end

          # Id of this transaction (paypal number)
          def transaction_id
            params['txn_id']
          end

          # What type of transaction are we dealing with?
          #  "cart" "send_money" "web_accept" are possible here.
          def type
            params['txn_type']
          end

          # the money amount we received in X.2 decimal.
          def gross
            params['mc_gross']
          end

          # the markup paypal charges for the transaction
          def fee
            params['mc_fee']
          end

          # What currency have we been dealing with
          def currency
            params['mc_currency']
          end

          # This is the item number which we submitted to paypal
          # The custom field is also mapped to item_id because PayPal
          # doesn't return item_number in dispute notifications
          def item_id
            params['item_number'] || params['custom']
          end

          # This is the invoice which you passed to paypal
          def invoice
            params['invoice']
          end

          # Was this a test transaction?
          def test?
            params['test_ipn'] == '1'
          end

          def account
            params['business'] || params['receiver_email']
          end

          # Acknowledge the transaction to paypal. This method has to be called after a new
          # ipn arrives. Paypal will verify that all the information we received are correct and will return a
          # ok or a fail.
          #
          # Example:
          #
          #   def paypal_ipn
          #     notify = PaypalNotification.new(request.raw_post)
          #
          #     if notify.acknowledge
          #       ... process order ... if notify.complete?
          #     else
          #       ... log possible hacking attempt ...
          #     end
          def acknowledge(authcode = nil)
            payload =  raw

            response = ssl_post(Paypal.service_url + '?cmd=_notify-validate', payload,
              'Content-Length' => "#{payload.size}",
              'User-Agent'     => "Active Merchant -- http://activemerchant.org"
            )

            raise StandardError.new("Faulty paypal result: #{response}") unless ["VERIFIED", "INVALID"].include?(response)

            response == "VERIFIED"
          end
        end

        module MassPayNotification
          # Mass pay returns a collection of MassPay Items, so inspect items to get the values
          def transaction_id
          end

          # Mass pay returns a collection of MassPay Items, so inspect items to get the values
          def gross
          end

          # Mass pay returns a collection of MassPay Items, so inspect items to get the values
          def fee
          end

          # Mass pay returns a collection of MassPay Items, so inspect items to get the values
          def currency
          end

          # Mass pay returns a collection of MassPay Items, so inspect items to get the values
          def item_id
          end

          # Mass pay returns a collection of MassPay Items, so inspect items to get the values
          def account
          end

          # Collection of notification items returned for MassPay transactions
          def items
            @items ||= (1..number_of_mass_pay_items).map do |item_number|
              MassPayItem.new(
                params["masspay_txn_id_#{item_number}"],
                params["mc_gross_#{item_number}"],
                params["mc_fee_#{item_number}"],
                params["mc_currency_#{item_number}"],
                params["unique_id_#{item_number}"],
                params["receiver_email_#{item_number}"],
                params["status_#{item_number}"]
              )
            end
          end

          private

          def number_of_mass_pay_items
            @number_of_mass_pay_items ||= params.keys.select { |k| k.start_with? 'masspay_txn_id' }.size
          end
        end

        class MassPayItem < Struct.new(:transaction_id, :gross, :fee, :currency, :item_id, :account, :status)
        end
      end
    end
  end
end
