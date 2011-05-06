module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Directebanking 
        autoload :Return,       File.dirname(__FILE__) + '/directebanking/return.rb'
        autoload :Helper,       File.dirname(__FILE__) + '/directebanking/helper.rb'
        autoload :Notification, File.dirname(__FILE__) + '/directebanking/notification.rb'
        
        # Supported countries:
        # Germany - DE
        # Austria - AT
        # Belgium - BE
        # Netherlands - NL
        # Switzerland - CH
        # Great Britain - GB
        
        # Overwrite this if you want to change the directebanking test url
        mattr_accessor :test_url
        self.test_url = 'https://www.directebanking.com/payment/start'
        
        # Overwrite this if you want to change the directebanking production url
        mattr_accessor :production_url 
        self.production_url = 'https://www.directebanking.com/payment/start'
        
        def self.service_url
          mode = ActiveMerchant::Billing::Base.integration_mode
          case mode
          when :production
            self.production_url    
          when :test
            self.test_url
          else
            raise StandardError, "Integration mode set to an invalid value: #{mode}"
          end
        end

        def self.notification(post, options = {})
          Notification.new(post, options)
        end  

        def self.return(post, options = {})
          Return.new(post, options)
        end
      end
    end
  end
end
