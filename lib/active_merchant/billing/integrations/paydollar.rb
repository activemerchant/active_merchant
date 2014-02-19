require File.dirname(__FILE__) + '/paydollar/helper.rb'
require File.dirname(__FILE__) + '/paydollar/notification.rb'
require File.dirname(__FILE__) + '/paydollar/return.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Paydollar

        CURRENCY_MAP = {
            'AED' => '784',
            'AUD' => '036',
            'BND' => '096',
            'CAD' => '124',
            'CNY' => '156',
            'EUR' => '978',
            'GBP' => '826',
            'HKD' => '344',
            'IDR' => '360',
            'JPY' => '392',
            'KRW' => '410',
            'MOP' => '446',
            'MYR' => '458',
            'NZD' => '554',
            'PHP' => '608',
            'SAR' => '682',
            'SGD' => '702',
            'THB' => '764',
            'TWD' => '901',
            'USD' => '840',
        }

        def self.service_url
          case ActiveMerchant::Billing::Base.integration_mode
          when :production
            'https://www.paydollar.com/b2c2/eng/payment/payForm.jsp'
          when :test
            'https://test.paydollar.com/b2cDemo/eng/payment/payForm.jsp'
          else
            raise StandardError, "Integration mode set to an invalid value: #{mode}"
          end
        end

        def self.notification(post, options = {})
          Notification.new(post, options)
        end

        def self.return(query_string, options = {})
          Return.new(query_string, options)
        end

        def self.sign(fields, secret)
          Digest::SHA1.hexdigest(fields.push(secret).join('|'))
        end

      end
    end
  end
end
