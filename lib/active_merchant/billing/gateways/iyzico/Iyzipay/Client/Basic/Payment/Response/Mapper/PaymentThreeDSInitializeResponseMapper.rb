#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Payment
        module Response
          module Mapper
            class PaymentThreeDSInitializeResponseMapper < ResponseMapper

              def map_response(response, jsonResult)
                super
                response.threeDS_html_content = jsonResult['threeDSHtmlContent'] unless jsonResult['threeDSHtmlContent'].nil?
              end

            end
          end
        end
      end
    end
  end
end
