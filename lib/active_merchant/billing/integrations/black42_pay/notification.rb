# frozen_string_literal: true

require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Black42Pay
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          %w[member
             secret
             action
             buyer
             email
             description
             product
             currency
             price
             quantity
             ureturn
             unotify
             ucancel].each do |param_name|
            define_method(param_name.underscore) { params[param_name] }
          end
        end
      end
    end
  end
end
