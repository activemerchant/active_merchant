#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Payment
        module Request
          class EcomPaymentCheckoutFormInitializeRequest < Iyzipay::Client::Request
            attr_accessor :price
            attr_accessor :paidPrice
            attr_accessor :basketId
            attr_accessor :paymentGroup
            attr_accessor :paymentSource
            attr_accessor :buyer
            attr_accessor :shippingAddress
            attr_accessor :billingAddress
            attr_accessor :basketItems
            attr_accessor :callbackUrl

            def get_json_object
              JsonBuilder.from_json_object(super).
                  add('price', @price).
                  add('basketId', @basketId).
                  add('paymentGroup', @paymentGroup).
                  add('buyer', @buyer).
                  add('shippingAddress', @shippingAddress).
                  add('billingAddress', @billingAddress).
                  add_array('basketItems', @basketItems).
                  add('callbackUrl', @callbackUrl).
                  add('paymentSource', @paymentSource).
                  add('paidPrice', @paidPrice).
                  get_object
            end

            def to_PKI_request_string
              PKIRequestStringBuilder.new.append_super(super).
                  append(:price, @price).
                  append(:basketId, @basketId).
                  append(:paymentGroup, @paymentGroup).
                  append(:buyer, @buyer).
                  append(:shippingAddress, @shippingAddress).
                  append(:billingAddress, @billingAddress).
                  append_array(:basketItems, @basketItems).
                  append(:callbackUrl, @callbackUrl).
                  append(:paymentSource, @paymentSource).
                  append(:paidPrice, @paidPrice).
                  get_request_string
            end
          end
        end
      end
    end
  end
end