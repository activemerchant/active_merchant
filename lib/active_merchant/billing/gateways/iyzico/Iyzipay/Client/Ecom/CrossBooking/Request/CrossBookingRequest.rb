#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module CrossBooking
        module Request
          class CrossBookingRequest < Iyzipay::Client::Request
            attr_accessor :subMerchantKey
            attr_accessor :price
            attr_accessor :reason

            def get_json_object
              super.merge(
                  'subMerchantKey' => @subMerchantKey,
                  'price' => @price,
                  'reason' => @reason
              )
            end

            def to_PKI_request_string
              PKIRequestStringBuilder.new.append_super(super).
                  append(:subMerchantKey, @subMerchantKey).
                  append(:price, @price).
                  append(:reason, @reason).
                  get_request_string
            end
          end
        end
      end
    end
  end
end
