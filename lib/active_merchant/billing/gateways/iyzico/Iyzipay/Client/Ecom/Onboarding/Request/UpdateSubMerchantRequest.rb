#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Onboarding
        module Request
          class UpdateSubMerchantRequest < SubMerchantRequest
            attr_accessor :subMerchantKey
            attr_accessor :identityNumber
            attr_accessor :taxNumber

            def get_json_object
              super.merge(
                  'subMerchantKey' => @subMerchantKey,
                  'identityNumber' => @identityNumber,
                  'taxNumber' => @taxNumber
              )
            end

            def to_PKI_request_string
              PKIRequestStringBuilder.new.append_super(super).
                  append(:subMerchantKey, @subMerchantKey).
                  append(:identityNumber, @identityNumber).
                  append(:taxNumber, @taxNumber).
                  get_request_string
            end
          end
        end
      end
    end
  end
end

