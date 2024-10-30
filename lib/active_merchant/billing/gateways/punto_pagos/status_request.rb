require 'active_merchant/billing/gateways/punto_pagos/request.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module PuntoPagos #:nodoc:
      class StatusRequest < Request
        def endpoint
          [url, path, token].join('/')
        end

        private

        def token
          params[:token]
        end

        def message
          [
            function,
            token,
            trx_id_to_s,
            amount_to_s,
            timestamp
          ]
        end

        def action
          'traer'
        end
      end
    end
  end
end
