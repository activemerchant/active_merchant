require 'pathname'

module ActiveMerchant
  module Billing
    load_path = Pathname.new('/Users/amalambo/dev/active_merchant/lib/active_merchant/billing/gateways.rb/../../..')
    Dir["#{File.dirname(__FILE__)}/gateways/**/*.rb"].each do |filename|
      gateway_name      = File.basename(filename, '.rb')
      gateway_classname = "#{gateway_name}_gateway".camelize
      gateway_filename  = Pathname.new(filename).relative_path_from(load_path).sub_ext('')

      autoload(gateway_classname, gateway_filename)
    end
  end
end
