#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Installment
        module Request
          class InstallmentInfoRequest < Iyzipay::Client::Request
            attr_accessor :binNumber
            attr_accessor :price

            def get_json_object
              super.merge(
                  'binNumber' => @binNumber,
                  'price' => @price
              )
            end

            def to_PKI_request_string
              PKIRequestStringBuilder.new.append_super(super).
                  append(:binNumber, @binNumber).
                  append(:price, @price).
                  get_request_string
            end
          end
        end
      end
    end
  end
end
