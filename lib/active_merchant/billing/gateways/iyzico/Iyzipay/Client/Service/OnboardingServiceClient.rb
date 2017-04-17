#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Service
      class OnboardingServiceClient < BaseServiceClient
        def self.from_configuration(configuration)
          self.new(configuration)
        end

        def get_sub_merchant(request)
          raw_result = HttpClientTemplate.post("#{@configuration.base_url}/onboarding/submerchant/detail", get_http_header(request), request.to_json_string)
          response = Ecom::Onboarding::Response::RetrieveSubMerchantResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

        def create_sub_merchant(request)
          raw_result = HttpClientTemplate.post("#{@configuration.base_url}/onboarding/submerchant", get_http_header(request), request.to_json_string)
          response = Ecom::Onboarding::Response::CreateSubMerchantResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

        def update_sub_merchant(request)
          raw_result = HttpClientTemplate.put("#{@configuration.base_url}/onboarding/submerchant", get_http_header(request), request.to_json_string)
          response = Ecom::Onboarding::Response::UpdateSubMerchantResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end
      end
    end
  end
end
