#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Approval
        module Request
          class ApprovalRequest < Iyzipay::Client::Request
            attr_accessor :paymentTransactionId

            def get_json_object
              super.merge(
                  'paymentTransactionId' => @paymentTransactionId
              )
            end

            def to_PKI_request_string
              PKIRequestStringBuilder.new.append_super(super).
                  append(:paymentTransactionId, @paymentTransactionId).
                  get_request_string
            end
          end
        end
      end
    end
  end
end
