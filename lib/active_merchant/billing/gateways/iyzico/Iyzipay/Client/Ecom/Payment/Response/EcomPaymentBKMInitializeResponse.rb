#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Payment
        module Response
          class EcomPaymentBKMInitializeResponse < EcomPaymentResponse
            attr_accessor :html_content

            def from_json(json_result)
              Mapper::EcomPaymentBKMInitializeResponseMapper.new.map_response(self, json_result)
            end
          end
        end
      end
    end
  end
end

