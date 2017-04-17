#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Payment
        module Response
          class PaymentPostAuthResponse < Iyzipay::Client::Response
            attr_accessor :payment_id
            attr_accessor :price

            def from_json(json_result)
              Mapper::PaymentPostAuthResponseMapper.new.map_response(self, json_result)
            end
          end
        end
      end
    end
  end
end
