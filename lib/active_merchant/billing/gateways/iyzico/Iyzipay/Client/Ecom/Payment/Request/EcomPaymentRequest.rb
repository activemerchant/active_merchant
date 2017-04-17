#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Payment
        module Request
          class EcomPaymentRequest < Iyzipay::Client::Request
            attr_accessor :price
            attr_accessor :paidPrice
            attr_accessor :installment
            attr_accessor :paymentChannel
            attr_accessor :basketId
            attr_accessor :paymentGroup
            attr_accessor :paymentCard
            attr_accessor :buyer
            attr_accessor :shippingAddress
            attr_accessor :billingAddress
            attr_accessor :basketItems

            def get_json_object
              JsonBuilder.from_json_object(super).
                  add('price', @price).
                  add('paidPrice', paidPrice).
                  add('installment', @installment).
                  add('paymentChannel', @paymentChannel).
                  add('basketId', @basketId).
                  add('paymentGroup', @paymentGroup).
                  add('paymentCard', @paymentCard).
                  add('buyer', @buyer).
                  add('shippingAddress', @shippingAddress).
                  add('billingAddress', @billingAddress).
                  add_array('basketItems', @basketItems).
                  get_object
            end

            def to_PKI_request_string
              PKIRequestStringBuilder.new.append_super(super).
                  append(:price, @price).
                  append(:paidPrice, @paidPrice).
                  append(:installment, @installment).
                  append(:paymentChannel, @paymentChannel).
                  append(:basketId, @basketId).
                  append(:paymentGroup, @paymentGroup).
                  append(:paymentCard, @paymentCard).
                  append(:buyer, @buyer).
                  append(:shippingAddress, @shippingAddress).
                  append(:billingAddress, @billingAddress).
                  append_array(:basketItems, @basketItems).
                  get_request_string
            end
          end
        end
      end
    end
  end
end
