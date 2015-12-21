#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Onboarding
        module Request
          class CreateSubMerchantRequest < SubMerchantRequest
            attr_accessor :subMerchantExternalId
            attr_accessor :identityNumber
            attr_accessor :taxNumber
            attr_accessor :subMerchantType

            def get_json_object
              super.merge(
                  'subMerchantExternalId' => @subMerchantExternalId,
                  'identityNumber' => @identityNumber,
                  'taxNumber' => @taxNumber,
                  'subMerchantType' => @subMerchantType
              )
            end

            def to_PKI_request_string
              PKIRequestStringBuilder.new.append_super(super).
                  append(:subMerchantExternalId, @subMerchantExternalId).
                  append(:identityNumber, @identityNumber).
                  append(:taxNumber, @taxNumber).
                  append(:subMerchantType, @subMerchantType).
                  get_request_string
            end
          end
        end
      end
    end
  end
end
