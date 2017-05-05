module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module A1agregator

        class Status
          include PostsData

          STATUS_TEST_URL = 'https://partner.a1pay.ru/a1lite/info/'

          attr_accessor :login, :password

          def initialize(login, password)
            @login, @password = login, password
          end

          # agregator provides two methods:
          # by tid - transaction id
          # by order_id & service_id
          def update(options = {})
            data = PostData.new
            data[:user] = @login
            data[:pass] = @password
            if options[:tid]
              data[:tid] = options[:tid]
            else
              data[:ord_id] = options[:ord_id]
              data[:service_id] = options[:service_id]
            end

            ssl_post(STATUS_TEST_URL, data.to_post_data)
          end

        end
      end
    end
  end
end
