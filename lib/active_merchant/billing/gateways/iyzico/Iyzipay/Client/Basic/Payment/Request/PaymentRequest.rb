#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Payment
        module Request
          class PaymentRequest < Iyzipay::Client::Request
            attr_accessor :price
            attr_accessor :paidPrice
            attr_accessor :installment
            attr_accessor :buyerEmail
            attr_accessor :buyerId
            attr_accessor :buyerIp
            attr_accessor :paymentCard

            def get_json_object
              JsonBuilder.from_json_object(super).
                  add('price', @price).
                  add('paidPrice', paidPrice).
                  add('installment', @installment).
                  add('buyerEmail', @buyerEmail).
                  add('buyerId', @buyerId).
                  add('buyerIp', @buyerIp).
                  add('paymentCard', @paymentCard).
                  get_object
            end

            def to_PKI_request_string
              PKIRequestStringBuilder.new.append_super(super).
                  append(:price, @price).
                  append(:paidPrice, @paidPrice).
                  append(:installment, @installment).
                  append(:buyerEmail, @buyerEmail).
                  append(:buyerId, @buyerId).
                  append(:buyerIp, @buyerIp).
                  append(:paymentCard, @paymentCard).
                  get_request_string
            end
          end
        end
      end
    end
  end
end
