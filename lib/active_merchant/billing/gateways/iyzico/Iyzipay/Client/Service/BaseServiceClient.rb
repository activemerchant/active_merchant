#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Service
      class BaseServiceClient
        attr_accessor :configuration

        def initialize(client_configuration)
          @configuration = client_configuration
        end

        def get_http_header(request = nil, authorize_request = true)
          header = {:accept => 'application/json',
                    :'content-type' => 'application/json'}

          if authorize_request
            random_header_value = RandomStringGenerator.random_string(RequestHelper::RANDOM_STRING_SIZE)
            header[:'Authorization'] = "#{prepare_authorization_string(request, random_header_value)}"
            header[:'x-iyzi-rnd'] = "#{random_header_value}"
          end

          header
        end

        def get_plain_http_header
          get_http_header(nil, false)
        end

        def json_decode_and_prepare_response(response, raw_result)
          json_result = JSON::parse(raw_result)
          response.raw_result = raw_result
          response.from_json(json_result)
        end

        def prepare_authorization_string(request, random_header_value)
          hash_digest = calculate_hash(request, random_header_value)
          RequestHelper.format_header_string(@configuration.api_key, hash_digest)
        end

        def calculate_hash(request, random_header_value)
          Digest::SHA1.base64digest("#{@configuration.api_key}#{random_header_value}#{@configuration.secret_key}#{request.to_PKI_request_string}")
        end
      end
    end
  end
end
