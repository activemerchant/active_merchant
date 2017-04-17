#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Service
      class CrossBookingServiceClient < BaseServiceClient
        def self.from_configuration(configuration)
          self.new(configuration)
        end

        def send_to_sub_merchant(request)
          raw_result = HttpClientTemplate.post("#{@configuration.base_url}/crossbooking/send", get_http_header(request), request.to_json_string)
          response = Response.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

        def receive_from_sub_merchant(request)
          raw_result = HttpClientTemplate.post("#{@configuration.base_url}/crossbooking/receive", get_http_header(request), request.to_json_string)
          response = Response.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

      end
    end
  end
end
