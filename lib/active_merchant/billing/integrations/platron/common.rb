module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Platron
        module Common
          def self.generate_signature_string(params,path,secret)
            sorted_params=params.keys.sort.map{|k|params[k]}
            [path,sorted_params,secret].flatten.compact.join(';')
          end

          def self.generate_signature(params,path,secret)
            Digest::MD5.hexdigest(generate_signature_string(params,path,secret))
          end
        end
      end
    end
  end
end
