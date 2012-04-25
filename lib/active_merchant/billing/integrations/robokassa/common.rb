module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Robokassa
        module Common
          def generate_signature_string
            custom_param_keys = params.keys.select {|key| key =~ /^shp/}.sort
            custom_params = custom_param_keys.map {|key| "#{key}=#{params[key]}"}
            [main_params, secret, custom_params].flatten.compact.join(':')
          end

          def generate_signature
            Digest::MD5.hexdigest(generate_signature_string)
          end
        end
      end
    end
  end
end
