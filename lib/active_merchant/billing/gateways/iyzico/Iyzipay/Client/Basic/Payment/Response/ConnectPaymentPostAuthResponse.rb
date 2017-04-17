#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Payment
        module Response
          class ConnectPaymentPostAuthResponse < PaymentPostAuthResponse
            attr_accessor :connector_name

            def from_json(json_result)
              Mapper::ConnectPaymentPostAuthResponseMapper.new.map_response(self, json_result)
            end
          end
        end
      end
    end
  end
end