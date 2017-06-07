module ActiveMerchant
  module Billing
    module OffsiteGateways        
    
      Dir[File.dirname(__FILE__) + '/offsite_gateways/*.rb'].each do |f|      
        
        # Get the class name that should be defined in the file      
        gateway_class = File.basename(f, '.rb').camelize.to_sym

        # Register the class for autoloading
        autoload gateway_class, f
      end
    end
  end
end
