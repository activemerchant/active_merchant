require File.dirname(__FILE__) + '/verkkomaksut/helper.rb'
require File.dirname(__FILE__) + '/verkkomaksut/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      
      # Usage, see the blog post here: http://blog.kiskolabs.com/post/22374612968/understanding-active-merchant-integrations and E1 API documentation here: http://docs.verkkomaksut.fi/
      module Verkkomaksut 
       
        mattr_accessor :service_url
        self.service_url = 'https://payment.verkkomaksut.fi/'

        def self.notification(post)
          Notification.new(post)
        end  
      end
    end
  end
end
