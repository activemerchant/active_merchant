#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Onboarding
        module Request
          class RetrieveSubMerchantRequest < Iyzipay::Client::Request
            attr_accessor :subMerchantExternalId

            def to_PKI_request_string
              PKIRequestStringBuilder.new.append_super(super).
                  append(:subMerchantExternalId, @subMerchantExternalId).
                  get_request_string
            end
          end
        end
      end
    end
  end
end

