#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Service
      class EcomPaymentServiceClient < BasePaymentServiceClient

        def self.from_configuration(configuration)
          self.new(configuration)
        end

        def approve(request)
          raw_result = HttpClientTemplate.post("#{@configuration.base_url}/payment/iyzipos/item/approve", get_http_header(request), request.to_json_string)
          response = Ecom::Approval::Response::ApprovalResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

        def disapprove(request)
          raw_result = HttpClientTemplate.post("#{@configuration.base_url}/payment/iyzipos/item/disapprove", get_http_header(request), request.to_json_string)
          response = Ecom::Approval::Response::ApprovalResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

        def auth(request)
          raw_result = HttpClientTemplate.post("#{@configuration.base_url}/payment/iyzipos/auth/ecom", get_http_header(request), request.to_json_string)
          response = Ecom::Payment::Response::EcomPaymentAuthResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

        def pre_auth(request)
          raw_result = HttpClientTemplate.post("#{@configuration.base_url}/payment/iyzipos/preauth/ecom", get_http_header(request), request.to_json_string)
          response = Ecom::Payment::Response::EcomPaymentPreAuthResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

        def post_auth(request)
          raw_result = HttpClientTemplate.post("#{@configuration.base_url}/payment/iyzipos/postauth", get_http_header(request), request.to_json_string)
          response = Ecom::Payment::Response::PaymentPostAuthResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

        def refund(request)
          raw_result = HttpClientTemplate.post("#{@configuration.base_url}/payment/iyzipos/refund", get_http_header(request), request.to_json_string)
          response = Basic::Payment::Response::PaymentRefundResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

        def refund_charged_from_merchant(request)
          raw_result = HttpClientTemplate.post("#{@configuration.base_url}/payment/refund/merchant/charge", get_http_header(request), request.to_json_string)
          response = Basic::Payment::Response::PaymentRefundResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

        def cancel(request)
          raw_result = HttpClientTemplate.post("#{@configuration.base_url}/payment/iyzipos/cancel", get_http_header(request), request.to_json_string)
          response = Basic::Payment::Response::PaymentCancelResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

        def initialize_three_ds(request)
          raw_result = HttpClientTemplate.post("#{@configuration.base_url}/payment/iyzipos/initialize3ds/ecom", get_http_header(request), request.to_json_string)
          response = Ecom::Payment::Response::EcomPaymentThreeDSInitializeResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

        def three_ds_auth(request)
          raw_result = HttpClientTemplate.post("#{@configuration.base_url}/payment/iyzipos/auth3ds/ecom", get_http_header(request), request.to_json_string)
          response = Ecom::Payment::Response::EcomPaymentThreeDSResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

        def initialize_bkm(request)
          raw_result =  HttpClientTemplate.post("#{@configuration.base_url}/payment/iyzipos/initializebkm/ecom", get_http_header(request), request.to_json_string)
          response = Ecom::Payment::Response::EcomPaymentBKMInitializeResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

        def get_bkm_auth_response(request)
          raw_result =  HttpClientTemplate.post("#{@configuration.base_url}/payment/iyzipos/bkm/auth/ecom/detail", get_http_header(request), request.to_json_string)
          response = Ecom::Payment::Response::EcomRetrievePaymentBKMAuthResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

      end
    end
  end
end
