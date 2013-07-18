module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module DirecPay
        
        class Status
          include PostsData
                    
          STATUS_TEST_URL = 'https://test.direcpay.com/direcpay/secure/dpMerchantTransaction.jsp'
          STATUS_LIVE_URL = 'https://www.timesofmoney.com/direcpay/secure/dpPullMerchAtrnDtls.jsp'
          
          attr_reader :account, :options
          
          def initialize(account, options = {})
            @account, @options = account, options
          end
          
          
          # Use this method to manually request a status update to the provided notification_url
          def update(authorization, notification_url)
            url = test? ? STATUS_TEST_URL : STATUS_LIVE_URL
            parameters = [ authorization, account, notification_url ]
            data = PostData.new
            data[:requestparams] = parameters.join('|')
            
            response = ssl_get("#{url}?#{data.to_post_data}")
          end

          def test?
            ActiveMerchant::Billing::Base.integration_mode == :test || options[:test]
          end
          
        end
      end
    end
  end
end
