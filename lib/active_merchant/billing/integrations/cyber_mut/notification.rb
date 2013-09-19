require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module CyberMut
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          # Parser and handler for incoming Instant payment notifications from CyberMut.
          # The Example shows a typical handler in a rails application.
          #
          # Example
          #
          #   class BackendController < ApplicationController
          #     include ActiveMerchant::Billing::Integrations
          #
          #     def cyber_mut
          #       notify = CyberMut::Notification.new(request.raw_post)
          #
          #       order = Order.find(notify.item_id)
          #
          #       if notify.acknowledge && notify.complete? && order.total == notify.amount
          #         order.status = 'success'
          #
          #         shop.ship(order)
          #         receipt = 0
          #       else
          #         logger.error("Failed to verify CyberMut's notification, please investigate")
          #       end
          #
          #     rescue => e
          #       order.status        = 'failed'
          #       raise
          #     ensure
          #       order.save
          #     end
          #   end
          def complete?
            if test?
              status == 'payetest'
            else
              status == 'paiement'
            end
          end

          def item_id
            params['reference']
          end

          def transaction_id
            params['reference']
          end

          # When was this payment received by the client.
          def received_at
            Time.parse(params['date'].gsub('_a_', ' ')) if params['date']
          end

          def payer_email
            params['mail']
          end

          def receiver_email
            params['mail']
          end

          # the money amount we received in X.2 decimal with devise
          # Needs to have dot instead of comma to comply to `to_f`.
          def gross
            params['montant'][0..-4].gsub(",", ".")
          end

          # What currency have we been dealing with
          def currency
            params['montant'][-3..-1]
          end

          # Was this a test transaction?
          def test?
            ActiveMerchant::Billing::Base.mode == :test
          end

          # Status of transaction. List of possible values:
          #
          # * payetest :: Payment accepted on test environment only
          # * paiement :: Payment accepted on prod environment only
          # * Annulation :: Payment refused
          def status
            params['code-retour']
          end

          def acknowledge
            true
          end

          private

          # Take the posted data and move the relevant data into a hash
          def parse(post)
            @raw = post.to_s
            for line in @raw.split('&')
              key, value = *line.scan( %r{^([A-Za-z0-9_.-]+)\=(.*)$} ).flatten.compact
              params[key] = CGI.unescape(value) if key && value
            end
          end
        end
      end
    end
  end
end
