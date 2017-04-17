#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Payment
        module Response

        end
      end
    end
  end
end

require_relative 'Response/Mapper'
require_relative 'Response/EcomPaymentResponse'
require_relative 'Response/EcomPaymentAuthResponse'
require_relative 'Response/EcomPaymentPreAuthResponse'
require_relative 'Response/EcomPaymentThreeDSInitializeResponse'
require_relative 'Response/EcomPaymentThreeDSResponse'
require_relative 'Response/EcomPaymentBKMInitializeResponse'
require_relative 'Response/EcomRetrievePaymentBKMAuthResponse'
require_relative 'Response/EcomRetrievePaymentCheckoutFormAuthResponse'
require_relative 'Response/EcomPaymentCheckoutFormInitializeResponse'
