module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PayuIn
        class Return < ActiveMerchant::Billing::Integrations::Return

          def initialize(query_string, options = {})
            @notification = Notification.new(query_string, options)
          end

          # PayU Transaction Id
          #
          def transaction_id
            @notification.transaction_id
          end

          # Returns the status of the transaction as a string
          # The status can be one of the following
          #
          # invalid - transaction id not present
          # tampered - checksum does not mismatch
          # mismatch - order id mismatch
          # success - transaction success
          # pending - transaction pending
          # failure - transaction failure
          #
          # payu does not put the discount field in the checksum
          # it can be easily forged by the attacker without detection
          #
          def status( order_id, order_amount )
            if @notification.invoice_ok?( order_id ) && @notification.amount_ok?( order_amount )
              @notification.status
            else
              'mismatch'.freeze
            end
          end

          # check success of the transaction
          # check order_id and
          def success?( order_id, order_amount )
            status( order_id, order_amount ) == 'success'
          end

          def cancelled?
            false
          end

          def message
            @notification.message
          end

        end
      end
    end
  end
end
