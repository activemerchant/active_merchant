require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Paydollar
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          # -1 : Error
	  # 0 : Transaction succeeded
	  # 1 : Transaction failure
	  def complete?
            params['successcode'] == '0'
          end

	  # Order Reference Number
          def item_id
            params['Ref']
          end

	  # Payment Reference Number
          def transaction_id
            params['PayRef']
          end

          # When was this payment received by the client.
	  # Format: YYYY-MM-DD HH:MI:SS.0
          def received_at
            params['TxTime']
          end

          def payer_email
            params['']
          end

          def receiver_email
            params['']
          end

          def security_key
	    params['']
          end

          # the money amount we received in X.2 decimal.
	  # (essentially the transaction amount)
          def gross
            params['Amt']
          end

          # Was this a test transaction?
          def test?
            params[''] == 'test'
          end

	  # Return bank host status code
          def status
            params['Prc']
          end

          # Acknowledge the transaction to Paydollar. This method has to be called after a new
          # apc arrives. Paydollar will verify that all the information we received are correct and will return a
          # ok or a fail.
          #
          # Example:
          #
          #   def ipn
          #     notify = PaydollarNotification.new(request.raw_post)
          #
          #     if notify.acknowledge
          #       ... process order ... if notify.complete?
          #     else
          #       ... log possible hacking attempt ...
          #     end
          def acknowledge()
	    true
          end
        end
      end
    end
  end
end
