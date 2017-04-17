#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Payment
        module Response
          class PaymentResponse < Iyzipay::Client::Response
            attr_accessor :price
            attr_accessor :paid_price
            attr_accessor :installment
            attr_accessor :payment_id
            attr_accessor :merchant_commission_rate
            attr_accessor :merchant_commission_rate_amount
            attr_accessor :iyzi_commission_fee
            attr_accessor :card_type
            attr_accessor :card_association
            attr_accessor :card_family
            attr_accessor :cardToken
            attr_accessor :cardUserKey
            attr_accessor :bin_number
            attr_accessor :paymentTransactionId

            def from_json(json_result)
              Mapper::PaymentResponseMapper.new.map_response(self, json_result)
            end
          end
        end
      end
    end
  end
end
