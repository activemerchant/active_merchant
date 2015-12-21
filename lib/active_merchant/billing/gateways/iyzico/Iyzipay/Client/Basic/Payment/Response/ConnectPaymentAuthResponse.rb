#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Payment
        module Response
          class ConnectPaymentAuthResponse < ConnectPaymentResponse

            def from_json(json_result)
              Mapper::ConnectPaymentAuthResponseMapper.new.map_response(self, json_result)
            end
          end
        end
      end
    end
  end
end

