#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Service
    end
  end
end

require_relative 'Service/BaseServiceClient'
require_relative 'Service/BasePaymentServiceClient'
require_relative 'Service/OnboardingServiceClient'
require_relative 'Service/EcomPaymentServiceClient'
require_relative 'Service/ConnectPaymentServiceClient'
require_relative 'Service/ReportingServiceClient'
require_relative 'Service/CardStorageServiceClient'
require_relative 'Service/CrossBookingServiceClient'
require_relative 'Service/EcomCheckoutFormServiceClient'
