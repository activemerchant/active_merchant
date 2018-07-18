# frozen_string_literal: true

require File.dirname(__FILE__) + '/epayment/helper.rb'
require File.dirname(__FILE__) + '/epayment/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Epayment

        # mattr_accessor :service_url
        # self.service_url = 'https://api.sandbox.epayments.com/merchant/prepare'

        def self.service_url
          'https://api.sandbox.epayments.com/merchant/prepare'
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
