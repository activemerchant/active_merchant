#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Installment
        module Dto
          class InstallmentDetailDto
            attr_accessor :binNumber
            attr_accessor :price
            attr_accessor :cardType
            attr_accessor :cardAssociation
            attr_accessor :cardFamilyName
            attr_accessor :force3ds
            attr_accessor :bankCode
            attr_accessor :bankName
            attr_accessor :installmentPrices
          end
        end
      end
    end
  end
end
