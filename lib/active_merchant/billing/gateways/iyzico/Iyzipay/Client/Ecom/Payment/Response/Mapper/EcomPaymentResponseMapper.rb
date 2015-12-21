#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Payment
        module Response
          module Mapper
            class EcomPaymentResponseMapper < Iyzipay::Client::ResponseMapper

              def map_response(response, jsonResult)
                super
                response.price = jsonResult['price'] unless jsonResult['price'].nil?
                response.paid_price = jsonResult['paidPrice'] unless jsonResult['paidPrice'].nil?
                response.installment = jsonResult['installment'] unless jsonResult['installment'].nil?
                response.payment_id = jsonResult['paymentId'] unless jsonResult['paymentId'].nil?
                response.fraud_status = jsonResult['fraudStatus'] unless jsonResult['fraudStatus'].nil?
                response.merchant_commission_rate = jsonResult['merchantCommissionRate'] unless jsonResult['merchantCommissionRate'].nil?
                response.merchant_commission_rate_amount = jsonResult['merchantCommissionRateAmount'] unless jsonResult['merchantCommissionRateAmount'].nil?
                response.iyzi_commission_rate_amount = jsonResult['iyziCommissionRateAmount'] unless jsonResult['iyziCommissionRateAmount'].nil?
                response.iyzi_commission_fee = jsonResult['iyziCommissionFee'] unless jsonResult['iyziCommissionFee'].nil?
                response.card_type = jsonResult['cardType'] unless jsonResult['cardType'].nil?
                response.card_association = jsonResult['cardAssociation'] unless jsonResult['cardAssociation'].nil?
                response.card_family = jsonResult['cardFamily'] unless jsonResult['cardFamily'].nil?
                response.card_token = jsonResult['cardToken'] unless jsonResult['cardToken'].nil?
                response.card_user_key = jsonResult['cardUserKey'] unless jsonResult['cardUserKey'].nil?
                response.bin_number = jsonResult['binNumber'] unless jsonResult['binNumber'].nil?
                response.basket_id = jsonResult['basketId'] unless jsonResult['basketId'].nil?
                response.item_transactions = map_payment_item_transactions(jsonResult['itemTransactions']) unless jsonResult['itemTransactions'].nil?
              end

              def map_payment_item_transactions(item_transactions)
                item_transaction_dtos = Array.new
                item_transactions.each do |item_transaction|
                  item_transaction_dto = Dto::EcomPaymentItemTransactionDto::new
                  item_transaction_dto.itemId = item_transaction['itemId'] unless item_transaction['itemId'].nil?
                  item_transaction_dto.paymentTransactionId = item_transaction['paymentTransactionId'] unless item_transaction['paymentTransactionId'].nil?
                  item_transaction_dto.transactionStatus = item_transaction['transactionStatus'] unless item_transaction['transactionStatus'].nil?
                  item_transaction_dto.price = item_transaction['price'] unless item_transaction['price'].nil?
                  item_transaction_dto.paidPrice = item_transaction['paidPrice'] unless item_transaction['paidPrice'].nil?
                  item_transaction_dto.merchantCommissionRate = item_transaction['merchantCommissionRate'] unless item_transaction['merchantCommissionRate'].nil?
                  item_transaction_dto.merchantCommissionRateAmount = item_transaction['merchantCommissionRateAmount'] unless item_transaction['merchantCommissionRateAmount'].nil?
                  item_transaction_dto.iyziCommissionRateAmount = item_transaction['iyziCommissionRateAmount'] unless item_transaction['iyziCommissionRateAmount'].nil?
                  item_transaction_dto.iyziCommissionFee = item_transaction['iyziCommissionFee'] unless item_transaction['iyziCommissionFee'].nil?
                  item_transaction_dto.blockageRate = item_transaction['blockageRate'] unless item_transaction['blockageRate'].nil?
                  item_transaction_dto.blockageRateAmountMerchant = item_transaction['blockageRateAmountMerchant'] unless item_transaction['blockageRateAmountMerchant'].nil?
                  item_transaction_dto.blockageRateAmountSubMerchant = item_transaction['blockageRateAmountSubMerchant'] unless item_transaction['blockageRateAmountSubMerchant'].nil?
                  item_transaction_dto.blockageResolvedDate = item_transaction['blockageResolvedDate'] unless item_transaction['blockageResolvedDate'].nil?
                  item_transaction_dto.subMerchantKey = item_transaction['subMerchantKey'] unless item_transaction['subMerchantKey'].nil?
                  item_transaction_dto.subMerchantPrice = item_transaction['subMerchantPrice'] unless item_transaction['subMerchantPrice'].nil?
                  item_transaction_dto.subMerchantPayoutRate = item_transaction['subMerchantPayoutRate'] unless item_transaction['subMerchantPayoutRate'].nil?
                  item_transaction_dto.subMerchantPayoutAmount = item_transaction['subMerchantPayoutAmount'] unless item_transaction['subMerchantPayoutAmount'].nil?
                  item_transaction_dto.merchantPayoutAmount = item_transaction['merchantPayoutAmount'] unless item_transaction['merchantPayoutAmount'].nil?
                  item_transaction_dtos << item_transaction_dto
                end
                item_transaction_dtos
              end

            end
          end
        end
      end
    end
  end
end

