#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Reporting
        module Response
          module Mapper
            class BouncedRowResponseMapper < ResponseMapper

              def map_response(response, jsonResult)
                super
                response.bounced_rows = map_bounced_rows(jsonResult['bouncedRows']) unless jsonResult['bouncedRows'].nil?
              end

              def map_bounced_rows(bounced_rows)
                bounced_row_dtos = Array.new
                bounced_rows.each do |bounced_row|
                  bounced_row_dto = BouncedRowDto::new
                  bounced_row_dto.subMerchantKey = bounced_row['subMerchantKey'] unless bounced_row['subMerchantKey'].nil?
                  bounced_row_dto.iban = bounced_row['iban'] unless bounced_row['iban'].nil?
                  bounced_row_dto.contactName = bounced_row['contactName'] unless bounced_row['contactName'].nil?
                  bounced_row_dto.contactSurname = bounced_row['contactSurname'] unless bounced_row['contactSurname'].nil?
                  bounced_row_dto.legalCompanyTitle = bounced_row['legalCompanyTitle'] unless bounced_row['legalCompanyTitle'].nil?
                  bounced_row_dto.marketplaceSubMerchantType = bounced_row['marketplaceSubMerchantType'] unless bounced_row['marketplaceSubMerchantType'].nil?
                  bounced_row_dtos << bounced_row_dto
                end
                bounced_row_dtos
              end

            end
          end
        end
      end
    end
  end
end
