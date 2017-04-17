#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Payment
        module Dto
          class EcomPaymentCardDto < RequestDto
            attr_accessor :cardHolderName
            attr_accessor :cardNumber
            attr_accessor :expireYear
            attr_accessor :expireMonth
            attr_accessor :cvc
            attr_accessor :registerCard
            attr_accessor :cardAlias
            attr_accessor :cardToken
            attr_accessor :cardUserKey

            def get_json_object
              JsonBuilder.new_instance.
                  add('cardHolderName', @cardHolderName).
                  add('cardNumber', @cardNumber).
                  add('expireYear', @expireYear).
                  add('expireMonth', @expireMonth).
                  add('cvc', @cvc).
                  add('registerCard', @registerCard).
                  add('cardAlias', @cardAlias).
                  add('cardToken', @cardToken).
                  add('cardUserKey', @cardUserKey).
                  get_object
            end

            def to_PKI_request_string
              PKIRequestStringBuilder.new.
                  append(:cardHolderName, @cardHolderName).
                  append(:cardNumber, @cardNumber).
                  append(:expireYear, @expireYear).
                  append(:expireMonth, @expireMonth).
                  append(:cvc, @cvc).
                  append(:registerCard, @registerCard).
                  append(:cardAlias, @cardAlias).
                  append(:cardToken, @cardToken).
                  append(:cardUserKey, @cardUserKey).
                  get_request_string
            end
          end
        end
      end
    end
  end
end