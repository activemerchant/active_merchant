#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Payment
        module Dto
          class EcomPaymentAddressDto < RequestDto
            attr_accessor :address
            attr_accessor :zipCode
            attr_accessor :contactName
            attr_accessor :city
            attr_accessor :country

            def get_json_object
              JsonBuilder.new_instance.
                  add('address', @address).
                  add('zipCode', @zipCode).
                  add('contactName', @contactName).
                  add('city', @city).
                  add('country', @country).
                  get_object
            end

            def to_PKI_request_string
              PKIRequestStringBuilder.new.
                  append(:address, @address).
                  append(:zipCode, @zipCode).
                  append(:contactName, @contactName).
                  append(:city, @city).
                  append(:country, @country).
                  get_request_string
            end

          end
        end
      end
    end
  end
end
