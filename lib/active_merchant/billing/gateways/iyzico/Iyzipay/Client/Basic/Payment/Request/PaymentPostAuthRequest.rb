#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Payment
        module Request
          class PaymentPostAuthRequest < Iyzipay::Client::Request
            attr_accessor :paymentId
            attr_accessor :ip

            def get_json_object
              super.merge(
                  'paymentId' => @paymentId,
                  'ip' => @ip
              )
            end

            def to_PKI_request_string
              PKIRequestStringBuilder.new.append_super(super).
                  append(:paymentId, @paymentId).
                  append(:ip, @ip).
                  get_request_string
            end
          end
        end
      end
    end
  end
end
