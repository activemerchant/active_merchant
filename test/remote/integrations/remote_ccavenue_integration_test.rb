require 'test_helper'

class RemoteCcavenueIntegrationTest < Test::Unit::TestCase
	include ActiveMerchant::Billing::Integrations

		def setup
			@order = "order#{generate_unique_id}"
			@merchant_id = fixtures(:ccavenue)[:merchant_id]
			@workingKey = fixtures(:ccavenue)[:workingKey]
			@helper = Ccavenue::Helper.new(@order,@merchant_id, :workingKey=>@workingKey ,:amount => 500, :currency => 'INR')
			@notification = Ccavenue::Notification.new(@order,@merchant_id, :workingKey=>@workingKey ,:amount => 500, :currency => 'INR')
		end

		def tear_down
			ActiveMerchant::Billing::Base.integration_mode = :test
		end
	  
		def test_return_is_always_acknowledged
			assert_equal "https://www.ccavenue.com/shopzone/cc_details.jsp", Ccavenue.service_url
			assert_nothing_raised do
			assert_equal true, @notification.parse
		end
	end 
end
