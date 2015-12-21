#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Payment
        module Response
          class EcomPaymentPreAuthResponse < EcomPaymentResponse

            def from_json(json_result)
              Mapper::EcomPaymentPreAuthResponseMapper.new.map_response(self, json_result)
            end
          end
        end
      end
    end
  end
end

