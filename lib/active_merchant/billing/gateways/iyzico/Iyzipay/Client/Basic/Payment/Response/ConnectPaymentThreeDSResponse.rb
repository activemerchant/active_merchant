#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Payment
        module Response
          class ConnectPaymentThreeDSResponse < ConnectPaymentResponse

            def from_json(json_result)
              Mapper::ConnectPaymentThreeDSResponseMapper.new.map_response(self, json_result)
            end
          end
        end
      end
    end
  end
end
