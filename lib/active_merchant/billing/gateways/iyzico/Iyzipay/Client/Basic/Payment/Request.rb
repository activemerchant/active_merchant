#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Payment
        module Request
        end
      end
    end
  end
end

require_relative 'Request/PaymentRequest'
require_relative 'Request/PaymentCancelRequest'
require_relative 'Request/PaymentPostAuthRequest'
require_relative 'Request/PaymentRefundRequest'
require_relative 'Request/PaymentThreeDSRequest'
require_relative 'Request/ConnectPaymentRequest'
require_relative 'Request/ConnectPaymentAuthRequest'
require_relative 'Request/ConnectPaymentCancelRequest'
require_relative 'Request/ConnectPaymentPostAuthRequest'
require_relative 'Request/ConnectPaymentPreAuthRequest'
require_relative 'Request/ConnectPaymentRefundRequest'
require_relative 'Request/ConnectPaymentThreeDSInitializeRequest'
require_relative 'Request/ConnectPaymentThreeDSRequest'


