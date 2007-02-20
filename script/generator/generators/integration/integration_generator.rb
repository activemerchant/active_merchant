class IntegrationGenerator < ActiveMerchant::Generator::Base
  def manifest
    @manifest ||= record do |m|
      m.directory "lib/active_merchant/billing/integrations/#{file_name}"
      
      m.template 'integration.rb',
                 "lib/active_merchant/billing/integrations/#{file_name}.rb"
      
      m.template 'helper.rb',
                 "lib/active_merchant/billing/integrations/#{file_name}/helper.rb"
      
      m.template 'notification.rb',
                 "lib/active_merchant/billing/integrations/#{file_name}/notification.rb"

      m.template 'module_test.rb',
                 "test/unit/integrations/#{file_name}_module_test.rb"
      
      m.template 'helper_test.rb',
                 "test/unit/integrations/helpers/#{file_name}_helper_test.rb"
      
      m.template 'notification_test.rb',
                 "test/unit/integrations/notifications/#{file_name}_notification_test.rb"
    end
  end
end
