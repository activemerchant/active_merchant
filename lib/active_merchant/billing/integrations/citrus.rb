module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Citrus
		autoload :Helper, File.dirname(__FILE__) + '/citrus/helper.rb'
        autoload :Notification, File.dirname(__FILE__) + '/citrus/notification.rb'
        autoload :Return, File.dirname(__FILE__) + '/citrus/return.rb'
        
        mattr_accessor :sandbox_url
        mattr_accessor :staging_url
        mattr_accessor :production_url
        mattr_accessor :pmt_url
		
		
        self.sandbox_url = 'https://sandbox.citruspay.com/'
        self.staging_url = 'https://stg.citruspay.com/'
        self.production_url = 'https://www.citruspay.com/'
        
		
        def self.service_url
          mode = ActiveMerchant::Billing::Base.integration_mode
          case mode
          when :production
            self.production_url + self.pmt_url   
          when :test
            self.sandbox_url + self.pmt_url
          when :staging
          	self.staging_url + self.pmt_url
          else
            raise StandardError, "Integration mode set to an invalid value: #{mode}"
          end
        end

		def self.helper(order, account, options = {})
          Helper.new(order, account, options)
        end
		
        def self.notification(post, options = {})
          Notification.new(post)
        end
        
        def self.return(query_string, options = {})
          Return.new(query_string)
        end
        
        def self.checksum(secret_key, payload_items )
         digest = OpenSSL::Digest::Digest.new('sha1')
		 sig=OpenSSL::HMAC.hexdigest(digest, secret_key, payload_items)
		 return sig
        end
        
      end
    end
  end
end
