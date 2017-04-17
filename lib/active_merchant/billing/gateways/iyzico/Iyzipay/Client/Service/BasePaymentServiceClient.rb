#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Service
      class BasePaymentServiceClient < BaseServiceClient

        def self.from_configuration(configuration)
          self.new(configuration)
        end

        def test
          raw_result = HttpClientTemplate.get("#{@configuration.base_url}/payment/test", get_plain_http_header)
          response = Response.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

        def check_bin(request)
          raw_result = HttpClientTemplate.post("#{@configuration.base_url}/payment/bin/check", get_http_header(request), request.to_json_string)
          response = Basic::Bin::Response::BinCheckResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

        def get_installment_info(request)
          raw_result = HttpClientTemplate.post("#{@configuration.base_url}/payment/installment", get_http_header(request), request.to_json_string)
          response = Basic::Installment::Response::InstallmentInfoResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

      end
    end
  end
end
