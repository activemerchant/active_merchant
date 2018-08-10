# frozen_string_literal: true

require File.dirname(__FILE__) + '/black42_pay/helper.rb'
require File.dirname(__FILE__) + '/black42_pay/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Black42Pay

        def self.service_url
          'https://wallet.black42pay.com/process_card.htm'
        end

        def self.helper(order, account, options = {})
          Helper.new(order, account, options)
        end

        def self.notification(*args)
          Notification.new(*args)
        end
      end
    end
  end
end
