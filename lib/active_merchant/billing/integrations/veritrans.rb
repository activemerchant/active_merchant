require File.dirname(__FILE__) + '/veritrans/token_request.rb'
require File.dirname(__FILE__) + '/veritrans/commodities.rb'
require File.dirname(__FILE__) + '/veritrans/helper.rb'
require File.dirname(__FILE__) + '/veritrans/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Veritrans
        mattr_accessor :service_url, :token_url, :acknowledge_url
        self.service_url      = 'https://vtweb.veritrans.co.id/web1/paymentStart.action'
        self.token_url        = 'https://vtweb.veritrans.co.id/web1/commodityRegist.action'
        self.acknowledge_url  = 'https://payments.veritrans.co.id/map/api/orders/acknowledge'
        def self.notification(post)
          Notification.new(post)
        end
      end
    end
  end
end
