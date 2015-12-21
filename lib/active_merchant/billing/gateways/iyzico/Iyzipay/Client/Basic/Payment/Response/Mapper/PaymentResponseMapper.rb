#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Payment
        module Response
          module Mapper
            class PaymentResponseMapper < ResponseMapper

              def map_response(response, jsonResult)
                super
                response.price = jsonResult['price'] unless jsonResult['price'].nil?
                response.paid_price = jsonResult['paidPrice'] unless jsonResult['paidPrice'].nil?
                response.installment = jsonResult['installment'] unless jsonResult['installment'].nil?
                response.payment_id = jsonResult['paymentId'] unless jsonResult['paymentId'].nil?
                response.merchant_commission_rate = jsonResult['merchantCommissionRate'] unless jsonResult['merchantCommissionRate'].nil?
                response.merchant_commission_rate_amount = jsonResult['merchantCommissionRateAmount'] unless jsonResult['merchantCommissionRateAmount'].nil?
                response.iyzi_commission_fee = jsonResult['iyziCommissionFee'] unless jsonResult['iyziCommissionFee'].nil?
                response.card_type = jsonResult['cardType'] unless jsonResult['cardType'].nil?
                response.card_association = jsonResult['cardAssociation'] unless jsonResult['cardAssociation'].nil?
                response.card_family = jsonResult['cardFamily'] unless jsonResult['cardFamily'].nil?
                response.card_family = jsonResult['cardToken'] unless jsonResult['cardToken'].nil?
                response.card_family = jsonResult['cardUserKey'] unless jsonResult['cardUserKey'].nil?
                response.bin_number = jsonResult['binNumber'] unless jsonResult['binNumber'].nil?
                response.basket_id = jsonResult['paymentTransactionId'] unless jsonResult['paymentTransactionId'].nil?
              end

            end
          end
        end
      end
    end
  end
end
