require 'digest/sha2'
require 'bigdecimal'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PayuIn
        autoload :Return, 'active_merchant/payu_in/return.rb'
        autoload :Helper, 'active_merchant/payu_in/helper.rb'
        autoload :Notification, 'active_merchant/payu_in/notification.rb'
        autoload :WebService, 'active_merchant/payu_in/web_service.rb'

        mattr_accessor :merchant_id
        mattr_accessor :secret_key

        # Overwrite this if you want to change the PayU.in test url
        mattr_accessor :test_url
        self.test_url = 'https://test.payu.in/_payment.php'

        # Overwrite this if you want to change the PayU.in test web
        # service url
        mattr_accessor :test_web_service_url
        self.test_web_service_url = 'https://test.payu.in/merchant/postservice.php'

        # Overwrite this if you want to change the PayU.in production url
        mattr_accessor :production_url
        self.production_url = 'https://secure.payu.in/_payment.php'

        # Overwrite this if you want to change the PayU.in production web
        # service url
        mattr_accessor :production_web_service_url
        self.production_web_service_url = 'https://info.payu.in/merchant/postservice.php'

        def self.new( options = {} )
          self.merchant_id = options[:merchant_id]
          self.secret_key = options[:secret_key]
          self
        end

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

        def self.web_service_url
          mode = ActiveMerchant::Billing::Base.integration_mode
          case mode
          when :production
            self.production_web_service_url
          when :test
            self.test_web_service_url
          else
            raise StandardError, "Integration mode set to an invalid value: #{mode}"
          end
        end

        # Query the PayU server using there web services
        def self.query( command, *args )
          WebService.send( command, *args )
        end

        def self.return(query_string, options = {})
          Return.new(query_string, options)
        end

        def self.checksum( *payload_items )
          options = payload_items.pop if Hash === payload_items.last
          options ||= {}
          payload = if options[:reverse] then
            payload_items.dup.push( self.merchant_id || "" ).unshift( self.secret_key || "" ).collect{ |x| trim(x) }.join("|")
          else
            payload_items.dup.unshift( self.merchant_id || "" ).push( self.secret_key || "" ).collect{ |x| trim(x) }.join("|")
          end
          if options[:debug]
            puts "-"*80
            puts payload
            puts "-"*80
          end
          Digest::SHA512.hexdigest( payload )
        end

        # PayU uses php trim when building the string to compute the checksum
        # trim removes whitespaces from start and end of the string
        # and floats cannot have trailing zeros
        def self.trim(obj)
          # if (BigDecimal === obj)
          #   obj.to_s('F')
          # else
          #   obj.to_s
          # end.strip.gsub(/(\\d+)\\.0$/){ $1 }.gsub(/(\\d+)(\\.[1-9]+)0+$/){ $1+$2 }
          obj.to_s
        end

      end
    end
  end
end
