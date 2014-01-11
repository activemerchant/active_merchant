module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Ccavenue
		 
        autoload :Notification, File.dirname(__FILE__) + '/ccavenue/notification.rb'
        autoload :Helper, File.dirname(__FILE__) + '/ccavenue/helper.rb' 
        	
        mattr_accessor :service_url 		
        self.service_url = 'https://www.ccavenue.com/shopzone/cc_details.jsp' 
		
		def self.helper(order, account, options = {})
          Helper.new(order, account, options)
        end
		
		def self.notification(post,options={})
		    Notification.new(post,options)
        end
		
        def self.return(query_string, options = {})
          Return.new(query_string)
        end
		
	 end
    end
  end
end
