#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Onboarding
        module Response
          module Mapper
            class RetrieveSubMerchantResponseMapper < ResponseMapper
              def map_response(response, jsonResult)
                super
                response.name = jsonResult['name'] unless jsonResult['name'].nil?
                response.email = jsonResult['email'] unless jsonResult['email'].nil?
                response.gsm_number = jsonResult['gsmNumber'] unless jsonResult['gsmNumber'].nil?
                response.address = jsonResult['address'] unless jsonResult['address'].nil?
                response.iban = jsonResult['iban'] unless jsonResult['iban'].nil?
                response.tax_office = jsonResult['taxOffice'] unless jsonResult['taxOffice'].nil?
                response.contact_name = jsonResult['contactName'] unless jsonResult['contactName'].nil?
                response.contact_surname = jsonResult['contactSurname'] unless jsonResult['contactSurname'].nil?
                response.legal_company_title = jsonResult['legalCompanyTitle'] unless jsonResult['legalCompanyTitle'].nil?
                response.sub_merchant_external_id = jsonResult['subMerchantExternalId'] unless jsonResult['subMerchantExternalId'].nil?
                response.identity_number = jsonResult['identityNumber'] unless jsonResult['identityNumber'].nil?
                response.tax_number = jsonResult['taxNumber'] unless jsonResult['taxNumber'].nil?
                response.sub_merchant_type = jsonResult['subMerchantType'] unless jsonResult['subMerchantType'].nil?
                response.sub_merchant_key = jsonResult['subMerchantKey'] unless jsonResult['subMerchantKey'].nil?
              end
            end
          end
        end
      end
    end
  end
end