#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Payment
        module Dto

          class EcomPaymentBasketItemDto < RequestDto
            attr_accessor :id
            attr_accessor :price
            attr_accessor :name
            attr_accessor :category1
            attr_accessor :category2
            attr_accessor :itemType
            attr_accessor :subMerchantKey
            attr_accessor :subMerchantPrice

            def get_json_object
              JsonBuilder.new_instance.
                  add('id', @id).
                  add('price', @price).
                  add('name', @name).
                  add('category1', @category1).
                  add('category2', @category2).
                  add('itemType', @itemType).
                  add('subMerchantKey', @subMerchantKey).
                  add('subMerchantPrice', @subMerchantPrice).
                  get_object
            end

            def to_PKI_request_string
              PKIRequestStringBuilder.new.
                  append(:id, @id).
                  append(:price, @price).
                  append(:name, @name).
                  append(:category1, @category1).
                  append(:category2, @category2).
                  append(:itemType, @itemType).
                  append(:subMerchantKey, @subMerchantKey).
                  append(:subMerchantPrice, @subMerchantPrice).
                  get_request_string
            end
          end

        end
      end
    end
  end
end
