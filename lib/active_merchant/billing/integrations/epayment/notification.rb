require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Epayment
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          %w(token 
             partnerid
             sing
             orderid
             amount
             currency
             details
             nickname
             lifetime
             successurl
             declineurl
            ).each do |param_name|
              define_method(param_name.underscore){ params[param_name] }
            end
        end
      end
    end
  end
end
