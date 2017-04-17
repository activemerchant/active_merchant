#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Payment
        module Response
          class EcomPaymentThreeDSInitializeResponse < Iyzipay::Client::Response
            attr_accessor :threeDS_html_content

            def from_json(json_result)
              Mapper::PaymentThreeDSInitializeResponseMapper.new.map_response(self, json_result)
            end
          end
        end
      end
    end
  end
end
