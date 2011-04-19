module ActiveMerchant
  module Billing
    autoload :Gateway, 'active_merchant/billing/gateway'
        
    Dir[File.dirname(__FILE__) + '/gateways/**/*.rb'].each do |f|      
      
      # Get camelized class name 
      filename = File.basename(f, '.rb')
      # Add _gateway suffix
      gateway_name = filename + '_gateway'
      # Camelize the string to get the class name
      gateway_class = gateway_name.camelize      
      
      # Register for autoloading
      autoload gateway_class, f      
    end
  end
end
