#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Onboarding
        module Response
          class RetrieveSubMerchantResponse < Iyzipay::Client::Response
            attr_accessor :name
            attr_accessor :email
            attr_accessor :gsm_number
            attr_accessor :address
            attr_accessor :iban
            attr_accessor :tax_office
            attr_accessor :contact_name
            attr_accessor :contact_surname
            attr_accessor :legal_company_title
            attr_accessor :sub_merchant_external_id
            attr_accessor :identity_number
            attr_accessor :tax_number
            attr_accessor :sub_merchant_type
            attr_accessor :sub_merchant_key

            def from_json(json_result)
              Mapper::RetrieveSubMerchantResponseMapper.new.map_response(self, json_result)
            end
          end
        end
      end
    end
  end
end
