#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Service
      class ReportingServiceClient < BaseServiceClient
        def self.from_configuration(configuration)
          self.new(configuration)
        end

        def get_payout_completed_transactions(request)
          raw_result = HttpClientTemplate.post("#{@configuration.base_url}/reporting/settlement/payoutcompleted", get_http_header(request), request.to_json_string)
          response = Basic::Reporting::Response::PayoutCompletedResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

        def get_bounced_rows(request)
          raw_result = HttpClientTemplate.post("#{@configuration.base_url}/reporting/settlement/bounced", get_http_header(request), request.to_json_string)
          response = Basic::Reporting::Response::BouncedRowResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

      end
    end
  end
end
