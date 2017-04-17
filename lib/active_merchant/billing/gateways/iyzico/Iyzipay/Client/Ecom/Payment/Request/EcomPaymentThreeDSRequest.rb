#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Payment
        module Request
          class EcomPaymentThreeDSRequest < Iyzipay::Client::Request
            attr_accessor :paymentId
            attr_accessor :conversationData

            def get_json_object
              super.merge(
                  'paymentId' => @paymentId,
                  'conversationData' => @conversationData
              )
            end

            def to_PKI_request_string
              PKIRequestStringBuilder.new.append_super(super).
                  append(:paymentId, @paymentId).
                  append(:conversationData, @conversationData).
                  get_request_string
            end
          end
        end
      end
    end
  end
end
