require 'test_helper'
require 'remote/integrations/remote_integration_helper'
require 'nokogiri'

class RemotePxpayIntegrationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  include ActionViewHelperTestHelper

  def setup
    @output_buffer = ""
    @options = fixtures(:pxpay)

    @helper = Pxpay::Helper.new('50', @options[:login], :amount => "120.99", :currency => 'USD', :credential2 => @options[:password])
    @notification = Pxpay::Notification.new('')
  end

  def test_valid_credentials_returns_secure_token
    @helper.return_url "http://t/pxpay/return_url"
    @helper.cancel_return_url "http://t/pxpay/cancel_url"

    response = @helper.request_secure_redirect

    puts response

    assert_equal "1", response[:valid]
    assert !response[:redirect].blank?
  end

  def test_redirect_url_matches_expected
    @helper.return_url "http://t/pxpay/return_url"
    @helper.cancel_return_url "http://t/pxpay/cancel_url"

    response = @helper.request_secure_redirect

    url = URI.parse(response[:redirect])
    assert_equal Pxpay.service_url, "#{url.scheme}://#{url.host}#{url.path}"
  end

  def test_redirect_accepts_form_post
    payment_service_for('1', @options[:login], :service => :pxpay,  :amount => "157.0") do |service|
            
      # You must set :credential2 to your pxpay key
       
      service.credential2 @options[:password]

      service.customer_id 8
      service.customer :first_name => 'g',
                       :last_name => 'g',
                       :email => 'g@g.com',
                       :phone => '3'
      
      service.billing_address :zip => 'g',
                      :country => 'United States of America',
                      :address1 => 'g',
                      :address2 => 'g'
      
      service.ship_to_address :first_name => 'g',
                               :last_name => 'g',
                               :city => '',
                               :address => 'g',
                               :address2 => '',
                               :country => 'United States of America',
                               :zip => 'g'
      
      service.invoice "516428355" # your invoice number
      # The end-user is presented with the HTML produced by the notify_url.
      service.return_url "http://t/pxpay/payment_received_notification_sub_step"
      service.cancel_return_url "http://t/pxpay/payment_cancelled"
      service.payment_header 'My store name'
      service.currency 'USD'

    end

    puts @output_buffer

    # submit generated form and ensure we're redirected to the CC info page
    agent = Mechanize.new { |a|
      a.user_agent_alias = 'Mac Safari'
    }

    page = Mechanize::Page.new(nil,{'content-type'=>'text/html'}, @output_buffer, nil, agent)
    page.forms.first.delete_field!('utf8')
    page.forms.first.method = "GET"

    res = agent.submit page.forms.first

    puts res.body

    assert res.forms.size > 0
  end


end

