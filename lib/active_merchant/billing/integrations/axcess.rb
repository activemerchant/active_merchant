require File.dirname(__FILE__) + '/axcess/helper.rb'
require File.dirname(__FILE__) + '/axcess/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      # To start with Axcess, follow the instructions for installing 
      # ActiveMerchant as a plugin, as described on 
      # http://www.activemerchant.org/.
      # 
      # The plugin will automatically add the ActionView helper for 
      # ActiveMerchant, which will allow you to make the Nochex payments.  
      # The idea behind the helper is that it generates an invisible 
      # forwarding screen that will automatically redirect the user.  
      # So you would collect all the information about the order and then 
      # simply render the hidden form, which redirects the user to Nochex.
      # 
      # The syntax of the helper is as follows:
      # 
      #   <% payment_service_for 'order id', 'axcess_user_login',
      #                                 :credential2 => 'axcess_user_password',
      #                                 :credential3 => 'axcess_sender',
      #                                 :credential4 => 'axcess_channel',
      #                                 :amount => 50.00,
      #                                 :service => :axcess,
      #                                 :html => { :id => 'axcess-form' } do |service| %>
      #   
      #      <% service.customer :first_name => 'Cody',
      #                         :last_name => 'Fauser',
      #                         :email => 'cody@example.com' %>
      #   
      #      <% service.billing_address :city => 'Ottawa',
      #                                :address => '21 Snowy Brook Lane, Apt. 36',
      #                                :country => 'CA',
      #                                :zip => 'K1J1E5' %>
      #   
      #      <% service.currency 'GBP' %>
      #
      #      <% service.notify_url url_for(:action => 'notify', :only_path => false) %>
      #      <% service.return_url url_for(:action => 'done', :only_path => false) %>
      #    <% end %>
      #   
      # The notify_url is the URL that the Axcess will sent the response too.  You can 
      # handle the notification in your controller action as follows:
      #   
      #   class NotificationController < ApplicationController
      #     include ActiveMerchant::Billing::Integrations
      #   
      #     def notify
      #       notification =  Axcess::Notification.new(request.raw_post)
      #       
      #       begin
      #         if notification.cancel? then
      #           send_data(CANCEL_URL, :type => "text/plain") and return
      #         else
      #           # Acknowledge notification with Axcess
      #           raise StandardError, 'Illegal Notification' unless notification.acknowledge(AXCESS_SECRET)
      #             # Process the payment  
      #             if notification.complete? then
      #              # payment ok => some update code
      #               send_data(notification.params['return_url'], :type => "text/plain") and return
      #             else
      #               # some error occured
      #               # notification.message contains full message
      #               send_data(notification.params['cancel_url'], :type => "text/plain") and return
      #             end
      #         end
      #       rescue => e
      #           logger.warn("Illegal notification received: #{e.message}")
      #       ensure
      #           send_data(CANCEL_URL, :type => "text/plain")
      #       end
      #     end
      #   end
      module Axcess
        autoload :Return, 'active_merchant/billing/integrations/axcess/return.rb'
        autoload :Helper, 'active_merchant/billing/integrations/axcess/helper.rb'
        autoload :Notification, 'active_merchant/billing/integrations/axcess/notification.rb'

        mattr_accessor :test_url
        self.test_url = 'https://test.ctpe.net/frontend/payment.prc'
        
        mattr_accessor :service_url
        self.service_url = 'https://ctpe.net/frontend/payment.prc'

        def self.notification(post)
          Notification.new(post)
        end

        def self.return(query_string, options = {})
          Return.new(query_string)
        end
      end
    end
  end
end
