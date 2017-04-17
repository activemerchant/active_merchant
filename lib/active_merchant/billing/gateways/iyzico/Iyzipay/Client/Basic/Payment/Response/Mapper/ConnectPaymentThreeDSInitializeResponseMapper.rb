#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Payment
        module Response
          module Mapper
            class ConnectPaymentThreeDSInitializeResponseMapper < PaymentResponseMapper
              def map_response(response, jsonResult)
                super
              end
            end
          end
        end
      end
    end
  end
end

