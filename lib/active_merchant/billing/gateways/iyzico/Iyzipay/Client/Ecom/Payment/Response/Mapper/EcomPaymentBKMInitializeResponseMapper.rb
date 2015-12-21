#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Payment
        module Response
          module Mapper
            class EcomPaymentBKMInitializeResponseMapper < ResponseMapper
              def map_response(response, jsonResult)
                super
                response.html_content = jsonResult['html_content'] unless jsonResult['html_content'].nil?
              end
            end
          end
        end
      end
    end
  end
end
