require "thor/group"

class GatewayGenerator < ActiveMerchantGenerator
  source_root File.expand_path("..", __FILE__)

  def generate
    template "templates/gateway.rb", gateway_file
    template "templates/gateway_test.rb", gateway_test_file
    template "templates/remote_gateway_test.rb", remote_gateway_test_file
  end

  protected

  def gateway_file
    "lib/active_merchant/billing/gateways/#{identifier}.rb"
  end

  def gateway_test_file
    "test/unit/gateways/#{identifier}_test.rb"
  end

  def remote_gateway_test_file
    "test/remote/gateways/remote_#{identifier}_test.rb"
  end
end
