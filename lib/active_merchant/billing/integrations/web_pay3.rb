module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:

      # Documentation: https://ipg.webteh.hr/en/documentation/form
      module WebPay3
        autoload :Return, File.dirname(__FILE__) + '/web_pay3/return.rb'
        autoload :Helper, File.dirname(__FILE__) + '/web_pay3/helper.rb'

        # sandbox ipg
        mattr_accessor :test_url
        self.test_url = 'https://ipgtest.webteh.hr/form'

        # sandbox ipg
        mattr_accessor :development_url
        self.development_url = 'https://ipgtest.webteh.hr/form'

        # production ipg
        mattr_accessor :production_url
        self.production_url = 'https://ipg.webteh.hr/form'

        def self.service_url
          mode = ActiveMerchant::Billing::Base.integration_mode
          case mode
          when :production
            self.production_url
          when :development
            self.development_url
          when :test
            self.test_url
          else
            raise StandardError, "Integration mode set to an invalid value: #{mode}"
          end
        end

        def self.helper(order, account, options = {})
          Helper.new(order, account, options)
        end

        def self.return(post, options = {})
          Return.new(post, options)
        end
      end
    end
  end
end
