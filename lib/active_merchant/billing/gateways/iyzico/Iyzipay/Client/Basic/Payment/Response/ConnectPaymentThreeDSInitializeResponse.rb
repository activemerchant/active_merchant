#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Payment
        module Response
          class ConnectPaymentThreeDSInitializeResponse < PaymentThreeDSInitializeResponse

            def from_json(json_result)
              Mapper::ConnectPaymentThreeDSInitializeResponseMapper.new.map_response(self, json_result)
            end
          end
        end
      end
    end
  end
end