require 'base64'
require 'openssl'
require 'active_merchant/billing/gateways/punto_pagos/authorization.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module PuntoPagos #:nodoc:
      class Request
        attr_reader :url, :params

        def initialize(params)
          @url = params[:url]
          @key = params[:key]
          @secret = params[:secret]
          @params = params
        end

        def headers
          {
            'Accept' => 'application/json',
            'Accept-Charset' => 'utf-8',
            'Content-Type' => 'application/json; charset=utf-8',
            'Fecha' => timestamp,
            'Autorizacion' => signature
          }
        end

        def endpoint
          raise NotImplementedError
        end

        def message
          raise NotImplementedError
        end

        private

        def action
          raise NotImplementedError
        end

        def trx_id_to_s
          params[:trx_id].to_s
        end

        def amount_to_s
          "%0.2f" % params[:amount].to_s.to_i
        end

        def function
          [path, action].join('/')
        end

        def path
          'transaccion'
        end

        def signature
          @signature ||= Authorization.new(key: @key, secret: @secret).sign(*message)
        end

        def timestamp
          @timestamp ||= Time.now.strftime("%a, %d %b %Y %H:%M:%S GMT")
        end
      end
    end
  end
end
