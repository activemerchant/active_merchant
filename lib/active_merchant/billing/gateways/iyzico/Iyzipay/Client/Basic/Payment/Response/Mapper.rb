#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Payment
        module Response
          module Mapper

          end
        end
      end
    end
  end
end

require_relative 'Mapper/PaymentResponseMapper'
require_relative 'Mapper/PaymentCancelResponseMapper'
require_relative 'Mapper/PaymentPostAuthResponseMapper'
require_relative 'Mapper/PaymentRefundResponseMapper'
require_relative 'Mapper/PaymentThreeDSInitializeResponseMapper'
require_relative 'Mapper/ConnectPaymentResponseMapper'
require_relative 'Mapper/ConnectPaymentAuthResponseMapper'
require_relative 'Mapper/ConnectPaymentCancelResponseMapper'
require_relative 'Mapper/ConnectPaymentPostAuthResponseMapper'
require_relative 'Mapper/ConnectPaymentPreAuthResponseMapper'
require_relative 'Mapper/ConnectPaymentRefundResponseMapper'
require_relative 'Mapper/ConnectPaymentThreeDSInitializeResponseMapper'
require_relative 'Mapper/ConnectPaymentThreeDSResponseMapper'


