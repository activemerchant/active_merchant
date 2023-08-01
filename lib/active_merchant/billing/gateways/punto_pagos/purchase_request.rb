require 'active_merchant/billing/gateways/punto_pagos/request.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module PuntoPagos #:nodoc:
      class PurchaseRequest < Request
        def endpoint
          [url, function].join('/')
        end

        def data
          r = {
            'trx_id' => trx_id_to_s,
            'monto' => amount_to_s
          }

          r['medio_pago'] = payment_method if payment_method
          r.to_json
        end

        private

        def payment_method
          params[:payment_method]
        end

        def message
          [
            function,
            trx_id_to_s,
            amount_to_s,
            timestamp
          ]
        end

        def function
          [path, action].join('/')
        end

        def action
          'crear'
        end
      end
    end
  end
end
