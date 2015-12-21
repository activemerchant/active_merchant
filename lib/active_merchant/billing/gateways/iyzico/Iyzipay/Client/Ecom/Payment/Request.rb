#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Payment
        module Request

        end
      end
    end
  end
end

require_relative 'Request/EcomPaymentRequest'
require_relative 'Request/EcomPaymentAuthRequest'
require_relative 'Request/EcomPaymentPreAuthRequest'
require_relative 'Request/EcomPaymentThreeDSInitializeRequest'
require_relative 'Request/EcomPaymentThreeDSRequest'
require_relative 'Request/EcomPaymentBKMInitializeRequest'
require_relative 'Request/EcomRetrievePaymentBKMAuthRequest'
require_relative 'Request/EcomPaymentCheckoutFormInitializeRequest'
require_relative 'Request/EcomRetrievePaymentCheckoutFormAuthRequest'


