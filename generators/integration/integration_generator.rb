require "thor/group"

class IntegrationGenerator < ActiveMerchantGenerator
  source_root File.expand_path("..", __FILE__)

  def generate
    template "templates/integration.rb", "#{lib}.rb"
    template "templates/helper.rb", "#{lib}/helper.rb"
    template "templates/notification.rb", "#{lib}/notification.rb"

    template "templates/module_test.rb", "#{test_dir}/#{identifier}_module_test.rb"
    template "templates/helper_test.rb", "#{test_dir}/helpers/#{identifier}_helper_test.rb"
    template "templates/notification_test.rb", "#{test_dir}/notifications/#{identifier}_notification_test.rb"
  end

  protected

  def lib
    "lib/active_merchant/billing/integrations/#{identifier}"
  end

  def test_dir
    "test/unit/integrations"
  end
end
