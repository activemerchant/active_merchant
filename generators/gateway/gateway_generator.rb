require "thor/group"
require "yaml"

class GatewayGenerator < ActiveMerchantGenerator
  source_root File.expand_path("..", __FILE__)

  def generate
    template "templates/gateway.rb", gateway_file
    template "templates/gateway_test.rb", gateway_test_file
    template "templates/remote_gateway_test.rb", remote_gateway_test_file

    before = (next_identifier ? /(?:\n#[^\n]*)*\n#{next_identifier}:\s*\n/ : /\z/)
    inject_into_file(fixtures_file, <<EOYAML, before: before)

# Working credentials, no need to replace
#{identifier}:
  some_credential: SOMECREDENTIAL
  another_credential: ANOTHERCREDENTIAL
EOYAML
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

  def fixtures_file
    "test/fixtures.yml"
  end

  def next_identifier
    fixtures = (YAML.load(File.read(fixtures_file)).keys + [identifier]).uniq.sort
    fixtures[fixtures.sort.index(identifier)+1]
  end
end
