module ActiveMerchant
  module Billing
    module Integrations
      module Citrus
        autoload :Helper, File.dirname(__FILE__) + '/citrus/helper.rb'
        autoload :Notification, File.dirname(__FILE__) + '/citrus/notification.rb'
        autoload :Return, File.dirname(__FILE__) + '/citrus/return.rb'

        mattr_accessor :sandbox_url
        mattr_accessor :staging_url
        mattr_accessor :production_url

        self.sandbox_url = 'https://sandbox.citruspay.com/'
        self.staging_url = 'https://stg.citruspay.com/'
        self.production_url = 'https://www.citruspay.com/'

        def self.credential_based_url(options)
          pmt_url = options[:credential3]

          case ActiveMerchant::Billing::Base.integration_mode
          when :production
            self.production_url + pmt_url
          when :test
            self.sandbox_url    + pmt_url
          when :staging
          	self.staging_url    + pmt_url
          else
            raise StandardError, "Integration mode set to an invalid value: #{mode}"
          end
        end

        def self.helper(order, account, options = {})
          Helper.new(order, account, options)
        end

        def self.notification(post, options = {})
          Notification.new(post, options)
        end

        def self.return(query_string, options = {})
          Return.new(query_string, options)
        end

        def self.checksum(secret_key, payload_items )
          digest = OpenSSL::Digest::Digest.new('sha1')
		      OpenSSL::HMAC.hexdigest(digest, secret_key, payload_items)
        end
      end
    end
  end
end
