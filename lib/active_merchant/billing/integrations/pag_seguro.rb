module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PagSeguro

        autoload :Helper, 'active_merchant/billing/integrations/pag_seguro/helper.rb'
        autoload :Notification, 'active_merchant/billing/integrations/pag_seguro/notification.rb'

        mattr_accessor :service_production_url
        self.service_production_url = 'https://pagseguro.uol.com.br/v2/checkout/payment.html'

        mattr_accessor :service_test_url
        self.service_test_url = 'https://sandbox.pagseguro.uol.com.br/v2/checkout/payment.html'

        mattr_accessor :invoicing_production_url
        self.invoicing_production_url = 'https://ws.pagseguro.uol.com.br/v2/checkout/'

        mattr_accessor :invoicing_test_url
        self.invoicing_test_url = 'https://ws.sandbox.pagseguro.uol.com.br/v2/checkout/'

        mattr_accessor :notification_production_url
        self.notification_production_url = 'https://ws.pagseguro.uol.com.br/v2/transactions/notifications/'

        mattr_accessor :notification_test_url
        self.notification_test_url = 'https://ws.sandbox.pagseguro.uol.com.br/v2/transactions/notifications/'

        def self.service_url
          test? ? service_test_url : service_production_url
        end

        def self.invoicing_url
          test? ? invoicing_test_url : invoicing_production_url
        end

        def self.notification_url
          test? ? notification_test_url : notification_production_url
        end

        def self.notification(query_string, options = {})
          Notification.new(query_string, options)
        end

        def self.return(query_string, options = {})
          Return.new(query_string, options)
        end

        def self.test?
          ActiveMerchant::Billing::Base.integration_mode == :test
        end
      end
    end
  end
end
