#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module CardStorage
      module Dto
        class CardDto < RequestDto
          attr_accessor :cardAlias
          attr_accessor :cardNumber
          attr_accessor :expireYear
          attr_accessor :expireMonth
          attr_accessor :cardHolderName

          def get_json_object
            JsonBuilder.new_instance.
                add('cardAlias', @cardAlias).
                add('cardNumber', @cardNumber).
                add('expireYear', @expireYear).
                add('expireMonth', @expireMonth).
                add('cardHolderName', @cardHolderName).
                get_object
          end

          def to_PKI_request_string
            PKIRequestStringBuilder.new.
                append(:cardAlias, @cardAlias).
                append(:cardNumber, @cardNumber).
                append(:expireYear, @expireYear).
                append(:expireMonth, @expireMonth).
                append(:cardHolderName, @cardHolderName).
                get_request_string
          end

        end
      end
    end
  end
end
