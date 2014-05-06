require 'test_helper'
require 'remote/integrations/remote_integration_helper'

class RemotePxpayIntegrationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  include ActionViewHelperTestHelper

  def setup
    @output_buffer = ""
    @options = fixtures(:pxpay)
  end

  def test_entire_payment
    @order_id = Digest::MD5.hexdigest("#{Time.now}+#{rand}")[0,6]

    # generate form to redirect customer to pxpay gateway
    generate_valid_redirect_form @order_id

    # submit generated form and ensure we're redirected to the CC info page
    agent = Mechanize.new { |a|
      a.user_agent_alias = 'Mac Safari'
    }

    page = Mechanize::Page.new(nil,{'content-type'=>'text/html'}, @output_buffer, nil, agent)
    gateway_page = agent.submit page.forms.first

    # entire valid test CC credentials and submit form

    assert gateway_page.forms.size > 0

    confirm_page = gateway_page.form_with(:name => 'PmtEnt') do |form|
      form.CardNum = '4111111111111111'
      form.ExMnth = '12'
      form.ExYr = '20'
      form.NmeCard = 'Firstname Lastname'
      form.Cvc2 = '123'
    end.submit

    # pull out redirected URL params
    return_url = confirm_page.link_with(:text => 'Click Here to Proceed to the Next step').href

    assert !return_url.empty?

    param_string = return_url.sub(/.*\?/, "")

    notification = Pxpay.notification(param_string, :credential1 => @options[:login], :credential2 => @options[:password])

    assert notification.acknowledge
    assert notification.complete?
    assert_match "Completed", notification.status
    assert_match "157.00", notification.gross
    assert notification.transaction_id.present?
    assert_match @order_id, notification.item_id
  end

  def test_failed_payment

    @order_id = Digest::MD5.hexdigest("#{Time.now}+#{rand}")[0,6]

    # generate form to redirect customer to pxpay gateway
    generate_valid_redirect_form @order_id

    # submit generated form and ensure we're redirected to the CC info page
    agent = Mechanize.new { |a|
      a.user_agent_alias = 'Mac Safari'
    }

    page = Mechanize::Page.new(nil,{'content-type'=>'text/html'}, @output_buffer, nil, agent)
    gateway_page = agent.submit page.forms.first

    # entire valid test CC credentials and submit form

    assert gateway_page.forms.size > 0

    confirm_page = gateway_page.form_with(:name => 'PmtEnt') do |form|
      form.CardNum = '4111111111111112'
      form.ExMnth = '12'
      form.ExYr = '10'
      form.NmeCard = 'Firstname Lastname'
      form.Cvc2 = '123'
    end.submit

    # pull out redirected URL params
    return_url = confirm_page.link_with(:text => 'Click Here to Proceed to the Next step').href

    assert !return_url.empty?

    param_string = return_url.sub(/.*\?/, "")

    notification = Pxpay.notification(param_string, :credential1 => @options[:login], :credential2 => @options[:password])

    assert_false notification.complete?
    assert notification.acknowledge
    assert_match "Failed", notification.status
    assert_match @order_id, notification.item_id
  end

  private

  def generate_valid_redirect_form(order_id)
    payment_service_for(order_id, @options[:login], :service => :pxpay,  :amount => "157.0", :return_url => "http://example.com/pxpay/return_url") {}
  end
end

