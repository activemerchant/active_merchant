=begin
 * Shop System Plugins - Terms of use
 *
 * This terms of use regulates warranty and liability between Wirecard Central Eastern Europe (subsequently referred to as WDCEE) and it's
 * contractual partners (subsequently referred to as customer or customers) which are related to the use of plugins provided by WDCEE.
 *
 * The Plugin is provided by WDCEE free of charge for it's customers and must be used for the purpose of WDCEE's payment platform
 * integration only. It explicitly is not part of the general contract between WDCEE and it's customer. The plugin has successfully been tested
 * under specific circumstances which are defined as the shopsystem's standard configuration (vendor's delivery state). The Customer is
 * responsible for testing the plugin's functionality before putting it into production environment.
 * The customer uses the plugin at own risk. WDCEE does not guarantee it's full functionality neither does WDCEE assume liability for any
 * disadvantage related to the use of this plugin. By installing the plugin into the shopsystem the customer agrees to the terms of use.
 * Please do not use this plugin if you do not agree to the terms of use!
=end

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module WirecardCheckoutPage
        autoload :Common, File.dirname(__FILE__) + '/wirecard_checkout_page/common.rb'
        autoload :Helper, File.dirname(__FILE__) + '/wirecard_checkout_page/helper.rb'
        autoload :Notification, File.dirname(__FILE__) + '/wirecard_checkout_page/notification.rb'
        autoload :Return, File.dirname(__FILE__) + '/wirecard_checkout_page/return.rb'

        mattr_accessor :service_url
        self.service_url = 'https://checkout.wirecard.com/page/init.php'

        def self.notification(post, options)
          Notification.new(post, options)
        end

        def self.return(postdata, options)
          Return.new(postdata, options)
        end

      end
    end
  end
end
