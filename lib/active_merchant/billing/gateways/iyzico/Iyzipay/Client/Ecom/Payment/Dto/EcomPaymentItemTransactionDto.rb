#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Payment
        module Dto
          class EcomPaymentItemTransactionDto
            attr_accessor :itemId
            attr_accessor :paymentTransactionId
            attr_accessor :transactionStatus
            attr_accessor :price
            attr_accessor :paidPrice
            attr_accessor :merchantCommissionRate
            attr_accessor :merchantCommissionRateAmount
            attr_accessor :iyziCommissionRateAmount
            attr_accessor :iyziCommissionFee
            attr_accessor :blockageRate
            attr_accessor :blockageRateAmountMerchant
            attr_accessor :blockageRateAmountSubMerchant
            attr_accessor :blockageResolvedDate
            attr_accessor :subMerchantKey
            attr_accessor :subMerchantPrice
            attr_accessor :subMerchantPayoutRate
            attr_accessor :subMerchantPayoutAmount
            attr_accessor :merchantPayoutAmount
          end
        end
      end
    end
  end
end
