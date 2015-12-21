#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Payment
        module Response
          class EcomPaymentThreeDSResponse < EcomPaymentResponse

            def from_json(json_result)
              Mapper::EcomPaymentThreeDSResponseMapper.new.map_response(self, json_result)
            end
          end
        end
      end
    end
  end
end
