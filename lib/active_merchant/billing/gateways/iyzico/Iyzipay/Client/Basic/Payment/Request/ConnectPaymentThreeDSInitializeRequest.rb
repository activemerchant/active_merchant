#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Payment
        module Request
          class ConnectPaymentThreeDSInitializeRequest < ConnectPaymentRequest
            attr_accessor :callbackUrl

            def get_json_object
              super.merge(
                  'callbackUrl' => @callbackUrl,
              )
            end

            def to_PKI_request_string
              PKIRequestStringBuilder.new.append_super(super).
                  append(:callbackUrl, @callbackUrl).
                  get_request_string
            end
          end
        end
      end
    end
  end
end
