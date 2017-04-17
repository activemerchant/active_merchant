#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Payment
        module Dto
          class EcomPaymentBuyerDto < RequestDto
            attr_accessor :id
            attr_accessor :name
            attr_accessor :surname
            attr_accessor :identityNumber
            attr_accessor :email
            attr_accessor :gsmNumber
            attr_accessor :registrationDate
            attr_accessor :lastLoginDate
            attr_accessor :registrationAddress
            attr_accessor :city
            attr_accessor :country
            attr_accessor :zipCode
            attr_accessor :ip

            def get_json_object
              JsonBuilder.new_instance.
                  add('id', @id).
                  add('name', @name).
                  add('surname', @surname).
                  add('identityNumber', @identityNumber).
                  add('email', @email).
                  add('gsmNumber', @gsmNumber).
                  add('registrationDate', @registrationDate).
                  add('lastLoginDate', @lastLoginDate).
                  add('registrationAddress', @registrationAddress).
                  add('city', @city).
                  add('country', @country).
                  add('zipCode', @zipCode).
                  add('ip', @ip).
                  get_object
            end

            def to_PKI_request_string
              PKIRequestStringBuilder.new.
                  append(:id, @id).
                  append(:name, @name).
                  append(:surname, @surname).
                  append(:identityNumber, @identityNumber).
                  append(:email, @email).
                  append(:gsmNumber, @gsmNumber).
                  append(:registrationDate, @registrationDate).
                  append(:lastLoginDate, @lastLoginDate).
                  append(:registrationAddress, @registrationAddress).
                  append(:city, @city).
                  append(:country, @country).
                  append(:zipCode, @zipCode).
                  append(:ip, @ip).
                  get_request_string
            end
          end
        end
      end
    end
  end
end
