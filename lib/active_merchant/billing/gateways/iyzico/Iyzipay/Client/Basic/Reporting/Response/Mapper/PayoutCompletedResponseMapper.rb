#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Reporting
        module Response
          module Mapper
            class PayoutCompletedResponseMapper < ResponseMapper

              def map_response(response, jsonResult)
                super
                response.payout_completed_transactions = map_payout_completed_transactions(jsonResult['payoutCompletedTransactions']) unless jsonResult['payoutCompletedTransactions'].nil?
              end

              def map_payout_completed_transactions(payout_completed_transactions)
                payout_completed_tx_dtos = Array.new
                payout_completed_transactions.each do |payout_completed_transaction|
                  payout_completed_tx_dto = Dto::PayoutCompletedTxDto::new
                  payout_completed_tx_dto.paymentTransactionId = payout_completed_transaction['paymentTransactionId'] unless payout_completed_transaction['paymentTransactionId'].nil?
                  payout_completed_tx_dto.payoutAmount = payout_completed_transaction['payoutAmount'] unless payout_completed_transaction['payoutAmount'].nil?
                  payout_completed_tx_dto.payoutType = payout_completed_transaction['payoutType'] unless payout_completed_transaction['payoutType'].nil?
                  payout_completed_tx_dto.subMerchantKey = payout_completed_transaction['subMerchantKey'] unless payout_completed_transaction['subMerchantKey'].nil?
                  payout_completed_tx_dtos << payout_completed_tx_dto
                end
                payout_completed_tx_dtos
              end

            end
          end
        end
      end
    end
  end
end
