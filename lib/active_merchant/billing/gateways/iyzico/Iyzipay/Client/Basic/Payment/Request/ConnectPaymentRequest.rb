#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Payment
        module Request
          class ConnectPaymentRequest < PaymentRequest
            attr_accessor :connectorName

            def get_json_object
              super.merge(
                  'connectorName' => @connectorName,
              )
            end

            def to_PKI_request_string
              PKIRequestStringBuilder.new.append_super(super).
                  append(:connectorName, @connectorName).
                  get_request_string
            end
          end
        end
      end
    end
  end
end
