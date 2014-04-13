module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PagSeguro

        autoload :Helper, 'active_merchant/billing/integrations/pag_seguro/helper.rb'
        autoload :Notification, 'active_merchant/billing/integrations/pag_seguro/notification.rb'

        mattr_accessor :service_url
        self.service_url = 'https://pagseguro.uol.com.br/v2/checkout/payment.html'

        mattr_accessor :invoicing_url
        self.invoicing_url = 'https://ws.pagseguro.uol.com.br/v2/checkout/'

        mattr_accessor :notification_url
        self.notification_url = 'https://ws.pagseguro.uol.com.br/v2/transactions/notifications/'

        def self.notification(post)
          Notification.new(post)
        end
      end
    end
  end
end
