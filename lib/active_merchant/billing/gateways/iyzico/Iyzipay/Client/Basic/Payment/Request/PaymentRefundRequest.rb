#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Payment
        module Request
          class PaymentRefundRequest < Iyzipay::Client::Request
            attr_accessor :paymentTransactionId
            attr_accessor :price
            attr_accessor :ip

            def get_json_object
              super.merge(
                  'paymentTransactionId' => @paymentTransactionId,
                  'price' => @price,
                  'ip' => @ip
              )
            end

            def to_PKI_request_string
              PKIRequestStringBuilder.new.append_super(super).
                  append(:paymentTransactionId, @paymentTransactionId).
                  append(:price, @price).
                  append(:ip, @ip).
                  get_request_string
            end
          end
        end
      end
    end
  end
end

