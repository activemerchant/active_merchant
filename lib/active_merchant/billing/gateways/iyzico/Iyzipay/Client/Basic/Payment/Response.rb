#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Payment
        module Response
        end
      end
    end
  end
end

require_relative 'Response/Mapper'
require_relative 'Response/PaymentResponse'
require_relative 'Response/PaymentCancelResponse'
require_relative 'Response/PaymentPostAuthResponse'
require_relative 'Response/PaymentRefundResponse'
require_relative 'Response/PaymentThreeDSInitializeResponse'
require_relative 'Response/ConnectPaymentResponse'
require_relative 'Response/ConnectPaymentAuthResponse'
require_relative 'Response/ConnectPaymentCancelResponse'
require_relative 'Response/ConnectPaymentPostAuthResponse'
require_relative 'Response/ConnectPaymentPreAuthResponse'
require_relative 'Response/ConnectPaymentRefundResponse'
require_relative 'Response/ConnectPaymentThreeDSInitializeResponse'
require_relative 'Response/ConnectPaymentThreeDSResponse'
