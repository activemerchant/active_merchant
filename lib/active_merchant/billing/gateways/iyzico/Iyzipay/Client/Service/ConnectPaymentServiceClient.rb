#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Service
      class ConnectPaymentServiceClient < BasePaymentServiceClient

        def self.from_configuration(configuration)
          self.new(configuration)
        end

        def auth(request)
          raw_result = HttpClientTemplate.post("#{@configuration.base_url}/payment/iyziconnect/auth", get_http_header(request), request.to_json_string)
          response = Basic::Payment::Response::ConnectPaymentAuthResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

        def pre_auth(request)
          raw_result = HttpClientTemplate.post("#{@configuration.base_url}/payment/iyziconnect/preauth", get_http_header(request), request.to_json_string)
          response = Basic::Payment::Response::ConnectPaymentPreAuthResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

        def post_auth(request)
          raw_result = HttpClientTemplate.post("#{@configuration.base_url}/payment/iyziconnect/postauth", get_http_header(request), request.to_json_string)
          response = Basic::Payment::Response::ConnectPaymentPostAuthResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

        def refund(request)
          raw_result = HttpClientTemplate.post("#{@configuration.base_url}/payment/iyziconnect/refund", get_http_header(request), request.to_json_string)
          response = Basic::Payment::Response::ConnectPaymentRefundResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

        def cancel(request)
          raw_result = HttpClientTemplate.post("#{@configuration.base_url}/payment/iyziconnect/cancel", get_http_header(request), request.to_json_string)
          response = Basic::Payment::Response::ConnectPaymentCancelResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

        def initialize_three_ds(request)
          raw_result = HttpClientTemplate.post("#{@configuration.base_url}/payment/iyziconnect/initialize3ds", get_http_header(request), request.to_json_string)
          response =Basic::Payment:: Response::ConnectPaymentThreeDSInitializeResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

        def three_ds_auth(request)
          raw_result = HttpClientTemplate.post("#{@configuration.base_url}/payment/iyziconnect/auth3ds", get_http_header(request), request.to_json_string)
          response = Basic::Payment::Response::ConnectPaymentThreeDSResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

      end
    end
  end
end
