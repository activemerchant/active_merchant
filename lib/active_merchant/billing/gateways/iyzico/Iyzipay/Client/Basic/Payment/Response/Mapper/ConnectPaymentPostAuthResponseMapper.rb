#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Payment
        module Response
          module Mapper
            class ConnectPaymentPostAuthResponseMapper < PaymentPostAuthResponseMapper

              def map_response(response, jsonResult)
                super
                response.connector_name = jsonResult['connectorName'] unless jsonResult['connectorName'].nil?
              end

            end
          end
        end
      end
    end
  end
end