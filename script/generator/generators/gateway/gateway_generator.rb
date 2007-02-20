class GatewayGenerator < ActiveMerchant::Generator::Base
  def manifest
    record do |m|
      m.template 'gateway.rb',
                 "lib/active_merchant/billing/gateways/#{file_name}.rb"

      m.template 'gateway_test.rb',
                 "test/unit/gateways/#{file_name}_test.rb"

      m.template 'remote_gateway_test.rb',
                 "test/remote_tests/remote_#{file_name}_test.rb"
    end
  end
end
