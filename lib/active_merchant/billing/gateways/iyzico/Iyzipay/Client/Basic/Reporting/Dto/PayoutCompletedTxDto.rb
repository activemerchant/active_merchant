#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Reporting
        module Dto
          class PayoutCompletedTxDto
            attr_accessor :paymentTransactionId
            attr_accessor :payoutAmount
            attr_accessor :payoutType
            attr_accessor :subMerchantKey
          end
        end
      end
    end
  end
end
