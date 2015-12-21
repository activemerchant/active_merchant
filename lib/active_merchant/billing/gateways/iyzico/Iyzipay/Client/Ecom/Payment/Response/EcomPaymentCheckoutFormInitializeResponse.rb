#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Payment
        module Response
          class EcomPaymentCheckoutFormInitializeResponse < Iyzipay::Client::Response
            attr_accessor :token
            attr_accessor :checkout_form_content
            attr_accessor :token_expire_time
            def from_json(json_result)
              Mapper::EcomPaymentPreAuthResponseMapper.new.map_response(self, json_result)
            end
          end
        end
      end
    end
  end
end


