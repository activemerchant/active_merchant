module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      # Platron API: www.platron.ru/PlatronAPI.pdf‎
      module Platron
        autoload :Helper, File.dirname(__FILE__) + '/platron/helper.rb'
        autoload :Notification, File.dirname(__FILE__) + '/platron/notification.rb'
        autoload :Common, File.dirname(__FILE__) + '/platron/common.rb'

        mattr_accessor :service_url
        self.service_url = 'https://www.platron.ru/payment.php'

        def self.notification(raw_post)
          Notification.new(raw_post)
        end

        def self.generate_signature_string(params, path, secret)
          sorted_params = params.sort_by{|k,v| k.to_s}.collect{|k,v| v}
          [path, sorted_params, secret].flatten.compact.join(';')
        end

        def self.generate_signature(params, path, secret)
          Digest::MD5.hexdigest(generate_signature_string(params, path, secret))
        end
      end
    end
  end
end
