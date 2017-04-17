#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module CardStorage
      module Dto
        class CardDetailDto
          attr_accessor :cardToken
          attr_accessor :cardAlias
          attr_accessor :binNumber
          attr_accessor :cardType
          attr_accessor :cardAssociation
          attr_accessor :cardFamily
          attr_accessor :cardBankCode
          attr_accessor :cardBankName
        end
      end
    end
  end
end