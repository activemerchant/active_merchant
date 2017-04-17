#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Reporting
        module Dto
          class BouncedRowDto
            attr_accessor :subMerchantKey
            attr_accessor :iban
            attr_accessor :contactName
            attr_accessor :contactSurname
            attr_accessor :legalCompanyTitle
            attr_accessor :marketplaceSubMerchantType
          end
        end
      end
    end
  end
end
