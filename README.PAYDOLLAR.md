# Active Merchant - PayDollar payment gateway support

NOTE - For details on Active Merchant read the README.md file.

This document provide details on the Paydollar branch and how to use the Paydollar module for client posts (i.e integration mode, where the credit card information page is put up by PayDollar)

## About the Code
The code is to be used with a Spree project, and therefore it is forked from ActiveMerchant v1.29.3 (since Spree requires v1.29).

## Usage
The first step is to download the "paydollar" ActiveMerchant branch and generate the "active_merchant" gem file and install it.

Next, create a rails project (the code was tested with Rails 3.2.13) and make the following changes:
- add active_merchant gem to the GemFile
- To use ActionView helper from active_merchant, create activemerchant.rb file under "config/initializers" folder and add the following lines to it:
################ Add these to activemerchant.rb file ################# 
require 'active_merchant'
require 'active_merchant/billing/integrations/action_view_helper'

ActionView::Base.send(:include, ActiveMerchant::Billing::Integrations::ActionViewHelper)

if Rails.env.production?
  ActiveMerchant::Billing::Base.integration_mode = :production
else
  ActiveMerchant::Billing::Base.integration_mode = :test
end 
############# activemerchant.rb changes end here ################

# Sample Controller & View
NOTE: The sample code below does not contain any business logic so that
one can clearly understand the usage of Paydollar module. In real scenario
add the business logic as per the requirement.

class PaymentController < ApplicationController
  include ActiveMerchant::Billing::Integrations

  before_filter :initialize_params

  def success
   @order_id = params[:Ref]
  end

  def cancel
   @order_id = params[:Ref]
  end

  def fail
   @order_id = params[:Ref]
  end

  def initialize_params
    # After processing (success, failure, error)
    # this is the value retured by PayDollar
    @order_id = "Order_PD_1000" 
    @amount = "100.94"  # The billing amount
    #secret_hash is used only when merchant has
    #registered for "secure hash" function
    @secret_hash = "Put the secure hash secret provided by PayDollar here"
    @merchant_id = "Put the merchant Id provided by PayDollar here"
    @currency = "344" # must be one of the values supported by PayDollar
    @pay_type = "N"   # must be one of the values supported by PayDollar
    @language = "E"   # must be one of the values supported by PayDollar
    @pay_method = "CC" # must be one of the values supported by PayDollar
    @mps_mode = "NIL" # must be one of the values supported by PayDollar
    @success_url = "http://localhost:3000/payment/success"
    @cancel_url = "http://localhost:3000/payment/cancel"
    @fail_url = "http://localhost:3000/payment/fail"
  end
end

# VIEW
<% payment_service_for @order_id, "",
  :service => :paydollar do |service| 
    service.amount = @amount 
    service.secret_hash(@secret_hash)
    service.merchant_id = @merchant_id
    service.currency = @currency
    service.pay_type = @pay_type
    service.language = @language
    service.pay_method = @pay_method
    service.mps_mode = @mps_mode
    service.return_url = @success_url
    service.cancel_return_url = @cancel_url
    service.fail_url = @fail_url
%>
<%= submit_tag 'Pay this order' %>
<% end %>



