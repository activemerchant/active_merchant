require 'mechanize'
require 'test_helper'

class RemoteMyGateTest < Test::Unit::TestCase
  
  def setup
    @gateway = MyGateGateway.new(fixtures(:my_gate))
    
    @amount = 65476 # ZAR 654.76
    
    # Modify this to your own PostBin to separate out the 3DS test
    @postbin_url = 'http://www.postbin.org/znycpi'
    
    # Cards as per the document found {here}[http://mygate.co.za/images/PDFs/myenterprise_userguide.pdf].
    @credit_card   = credit_card('4111111111111111', :first_name => 'Joe', :last_name => 'Soap', :verification_value => '123')
    @declined_card = credit_card('4242424242424242', :first_name => 'Joe', :last_name => 'Soap', :verification_value => '123')
    @enrolled_card = credit_card('4341792000000044', :first_name => 'Joe', :last_name => 'Soap', :verification_value => '123', :month => 10, :year => 2012)
    
    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase',
      :user_agent => "ActiveMerchant v#{ActiveMerchant::VERSION}", 
      :http_accept => '*/*'
    }
    
  end
  
  def test_3d_secure_authorization
    pre_auth_response = @gateway.security_pre_auth(@amount, @enrolled_card, @options)
    assert_success pre_auth_response
    assert pre_auth_response.enrolled
    
    # Now we need to manually reset the password to be able to verify our identity.
    # The process is pretty convoluted and requires quite a few form submissions.
    # For testing purposes I am posting to PostBin and retrieving the values there.
    browser = Mechanize.new
    verification_page = browser.post(pre_auth_response.acs_url, {
      'PaReq' => pre_auth_response.pa_request_message, 
      'TermUrl' => @postbin_url, # Replace with your own PostBin to filter test results
      'TransactionIndex' => pre_auth_response.transaction_index
    })
    # puts "\nVerification page: #{verification_page.title}"    
    password_reset_page = browser.click(verification_page.link_with(:text => /change my password/))
    # puts "Password reset page: #{password_reset_page.title}"
    confirm_new_password_page = set_password(password_reset_page.forms.first)
    # puts "Confirm new password page: #{confirm_new_password_page.title}"
    verification_after_reset_page = set_password(confirm_new_password_page.forms.first)
    # puts "Verification after reset page #{verification_after_reset_page.title}"
    javascript_warning_page = set_password(verification_after_reset_page.forms.first)
    javascript_warning_page.forms.last.click_button # posts to PostBin
    
    sleep(1) # to give PostBin a chance to process the post
    
    # Get the PaRes value - normally you would do this with
    postbin = browser.get(@postbin_url)
    pa_response_message = REXML::Document.new(postbin.body).root.get_elements("//tr[td/@title = 'PaRes']/td/pre").first.text
    assert pa_response_message.size > 20
    
    # Authenticate the result with MyGate
    assert auth_response = @gateway.security_auth(
      { 'PaRes' => pa_response_message }, # params from controller
      { :transaction_index => pre_auth_response.transaction_index } # transaction_index from order
    )
    assert_success auth_response
    assert auth_response.eci.present?
    assert auth_response.xid.present?
    assert auth_response.cavv.present?
  end
  
  def test_successful_purchase
    # 3D-Secure lookup is required, cardholder should not be enrolled, thus avoiding 3DS redirecting
    pre_auth @credit_card
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal MyGate::Response::SUCCESS, response.message
  end
  
  def test_unsuccessful_purchase
    pre_auth @declined_card
    
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert response.message.present?
  end
  
  def test_successful_authorize
    pre_auth @credit_card
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal MyGate::Response::SUCCESS, response.message
  end
  
  def test_authorize_and_capture_and_refund
    pre_auth @credit_card
    
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal MyGate::Response::SUCCESS, auth.message
    
    assert auth.transaction_index
    assert capture = @gateway.capture(@amount, auth.transaction_index)
    assert_success capture
    assert_equal MyGate::Response::SUCCESS, capture.message
    
    assert capture.transaction_index
    assert refund = @gateway.refund(@amount, capture.transaction_index)
    assert_success refund
    assert_equal MyGate::Response::SUCCESS, refund.message
  end
  
  def test_authorize_and_void
    pre_auth @credit_card
    
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal MyGate::Response::SUCCESS, auth.message
    
    assert auth.authorization
    assert void = @gateway.void(auth.transaction_index, @options)
    assert_success void
    assert_equal MyGate::Response::SUCCESS, void.message
  end
  
  def test_failed_capture
    pre_auth @credit_card
    
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'This transaction requires a TransactionIndex.  Please specify a correct transaction index.  If this problem persists, please contact MyGate at support@mygate.co.za', response.message
  end
  
  def test_invalid_login
    gateway = MyGateGateway.new :merchant_id => '', :application_id => '', :gateway => :fnb_live
    
    @options.update :transaction_index => ''
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'A Merchant ID was not specified.  Please check that you have entered a Merchant ID.  If this problem persists, please contact MyGate at support@mygate.co.za', response.message
  end
  
  private
  
  def pre_auth(credit_card, enrolled = false)
    pre_auth_response = @gateway.security_pre_auth(@amount, credit_card, @options)
    assert_success pre_auth_response
    assert_equal enrolled, pre_auth_response.enrolled
    
    @options.update :transaction_index => pre_auth_response.transaction_index
  end
  
  def set_password(form, password = 'fnbtest')
    form['newpassword'] = password
    form.click_button(form.buttons.last)
  end
end
