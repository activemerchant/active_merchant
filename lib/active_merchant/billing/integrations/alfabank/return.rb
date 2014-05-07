# -- encoding : utf-8 --

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Alfabank
        class Return < ActiveMerchant::Billing::Integrations::Return
          def initialize(prms, options = {})
            super(prms)
            gateway = AlfabankGateway.new options
            @order  = prms['orderNumber'] ? gateway.get_order_status(:order_number => prms['orderNumber']) : gateway.get_order_status(:order_id => prms['orderId'])
          end

          def item_id
            params['order_number']
          end

          def contains_invoice_info?
            true
          end

          def success?
            @order.success?
          end

          def paid?
            status == :paid
          end

          def authorization?
            status == :authorization
          end

          def canceled?
            status == :canceled
          end

          def wait?
            status == :wait
          end

          def transaction_id
            params['attributes'].first['value']
          end

          def params
            @order.params
          end

          def currency
            'RUR'
          end

          def amount
            params['amount'].to_i / 100.0
          end

          def status
            return nil unless success?

            status = @order.params['order_status']
            case status.to_i
              when 0, 1, 5
                :pending
              when 2
                :paid
              when 3, 4, 6
                :canceled
            end
          end

          def gateway_response
            @order.try(:params)
          end

          def status_message
            if success?
              AlfabankGateway::STATUSES_HASH(@order.params['order_status'])
            else
              "Ошибка при оплате"
            end
          end
        end
      end
    end
  end
end
