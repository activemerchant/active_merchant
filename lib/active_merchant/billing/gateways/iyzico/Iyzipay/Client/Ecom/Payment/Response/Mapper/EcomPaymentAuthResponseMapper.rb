#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Payment
        module Response
          module Mapper
            class EcomPaymentAuthResponseMapper < EcomPaymentResponseMapper

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
