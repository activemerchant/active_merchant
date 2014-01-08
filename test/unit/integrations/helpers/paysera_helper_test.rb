require 'test_helper'

class PayseraHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @order_id = '2'
    @project_id = '123'
    @amount = '500'
    @currency = 'USD'
    @secret = '8c5ebe834bb61a2e5ab8ef38f8d940f3'
    @expected_signature = '1c810aeb969787e136d17461fc5c1e70'

    @basic_fields = {
        :amount => @amount,
        :currency => @currency,
        :credential2 => @secret
    }

    @helper = reset_helper
  end
 
  def test_basic_helper_fields
    assert_field 'projectid', @project_id
    assert_field 'amount', @amount
    assert_field 'orderid', @order_id
    assert_field 'currency', @currency
  end
  
  def test_customer_fields
    @helper.customer :first_name => 'Cody', :last_name => 'Fauser', :email => 'cody@example.com'
    assert_field 'p_firstname', 'Cody'
    assert_field 'p_lastname', 'Fauser'
    assert_field 'p_email', 'cody@example.com'
  end

  def test_address_mapping
    @helper.billing_address :city => 'Leeds',
                            :state => 'Yorkshire',
                            :zip => 'LS2 7EE',
                            :country  => 'CA'
   
    assert_field 'p_city', 'Leeds'
    assert_field 'p_state', 'Yorkshire'
    assert_field 'p_zip', 'LS2 7EE'
    assert_field 'p_countrycode', 'CA'
  end

  def test_url_mapping
    @helper.notify_url 'callbackurl', 'http://callback_url'
    assert_field 'callbackurl', 'http://callback_url'

    @helper.return_url 'accepturl', 'http://accept_url'
    assert_field 'accepturl', 'http://accept_url'

    @helper.cancel_return_url 'cancelurl', 'http://cancel_url'
    assert_field 'cancelurl', 'http://cancel_url'
  end

  def test_creates_test_field
    ActiveMerchant::Billing::Base.integration_mode = :production
    @helper = reset_helper
    assert_nil @helper.fields['test']

    ActiveMerchant::Billing::Base.integration_mode = :test
    @helper = reset_helper
    assert_field 'test', '1'
    assert_field 'payment', 'wallet'
  end

  def test_request_signature_string
    assert_equal @expected_signature, @helper.generate_signature_v1(combined_fields_in_base64, @secret)
  end

  def test_form_fields
    assert_equal combined_fields_in_base64, @helper.form_fields[:data]
    assert_equal @expected_signature, @helper.form_fields[:sign]
  end

  private
  def combined_fields_in_base64
    Base64.urlsafe_encode64 combined_fields_mock
  end

  def combined_fields_mock
    'orderid=2&projectid=123&amount=50000&currency=USD&test=1&payment=wallet&version=1.6'
  end

  def reset_helper
    Paysera::Helper.new(@order_id, @project_id, @basic_fields)
  end
end
