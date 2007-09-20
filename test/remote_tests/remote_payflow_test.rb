require File.dirname(__FILE__) + '/../test_helper'

class RemotePayflowTest < Test::Unit::TestCase
  def setup
    ActiveMerchant::Billing::Base.gateway_mode = :test

    @gateway = PayflowGateway.new(fixtures(:payflow))
    
    @creditcard = credit_card('5105105105105100',
      :type => 'master'
    )

    @options = { :address => { 
                    :name => 'Cody Fauser',
                    :address1 => '1234 Shady Brook Lane',
                    :city => 'Ottawa',
                    :state => 'ON',
                    :country => 'CA',
                    :zip => '90210',
                    :phone => '555-555-5555'
               },
                 :email => 'cody@example.com'
               }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(100000, @creditcard, @options)
    assert_equal "Approved", response.message
    assert_success response
    assert response.test?
    assert_not_nil response.authorization
  end
  
  def test_declined_purchase
    assert response = @gateway.purchase(210000, @creditcard, @options)
    assert_equal 'Declined', response.message
    assert_failure response
    assert response.test?
  end
  
  def test_successful_authorization
    assert response = @gateway.authorize(100, @creditcard, @options)
    assert_equal "Approved", response.message
    assert_success response
    assert response.test?
    assert_not_nil response.authorization
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(100, @creditcard, @options)
    assert_success auth
    assert_equal 'Approved', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(100, auth.authorization)
    assert_success capture
  end
  
  def test_authorize_and_partial_capture
    assert auth = @gateway.authorize(100 * 2, @creditcard, @options)
    assert_success auth
    assert_equal 'Approved', auth.message
    assert auth.authorization
    
    assert capture = @gateway.capture(100, auth.authorization)
    assert_success capture
  end
  
  def test_failed_capture
    assert response = @gateway.capture(100, '999')
    assert_failure response
    assert_equal 'Invalid tender', response.message
  end
  
  def test_authorize_and_void
    assert auth = @gateway.authorize(100, @creditcard, @options)
    assert_success auth
    assert_equal 'Approved', auth.message
    assert auth.authorization
    assert void = @gateway.void(auth.authorization)
    assert_success void
  end
  
  def test_invalid_login
    gateway = PayflowGateway.new(
      :login => '',
      :password => ''
    )
    assert response = gateway.purchase(100, @creditcard, @options)
    assert_equal 'Invalid vendor account', response.message
    assert_failure response
  end
  
  def test_duplicate_request_id
    gateway = PayflowGateway.new(
      :login => @login,
      :password => @password,
      :partner => @partner
    )
    
    request_id = Digest::MD5.hexdigest(rand.to_s)
    gateway.expects(:generate_unique_id).times(2).returns(request_id)
    
    response1 = gateway.purchase(100, @creditcard, @options)
    assert_nil response1.params['duplicate']
    response2 = gateway.purchase(100, @creditcard, @options)
    assert response2.params['duplicate']
  end
  
  def test_create_recurring_profile
    response = @gateway.recurring(1000, @creditcard, :periodicity => :monthly)
    assert_success response
    assert !response.params['profile_id'].blank?
    assert response.test?
  end
  
  def test_create_recurring_profile_with_invalid_date
    response = @gateway.recurring(1000, @creditcard, :periodicity => :monthly, :starting_at => Time.now)
    assert_failure response
    assert_equal 'Field format error: Start or next payment date must be a valid future date', response.message
    assert response.params['profile_id'].blank?
    assert response.test?
  end
  
  def test_create_and_cancel_recurring_profile
    response = @gateway.recurring(1000, @creditcard, :periodicity => :monthly)
    assert_success response
    assert !response.params['profile_id'].blank?
    assert response.test?
    
    response = @gateway.cancel_recurring(response.params['profile_id'])
    assert_success response
    assert response.test?
  end
  
  def test_full_feature_set_for_recurring_profiles
    # Test add
    @options.update(
      :periodicity => :weekly,
      :payments => '12',
      :starting_at => Time.now + 1.day,
      :comment => "Test Profile"
    )
    response = @gateway.recurring(100, @creditcard, @options)
    assert_equal "Approved", response.params['message']
    assert_equal "0", response.params['result']
    assert_success response
    assert response.test?
    assert !response.params['profile_id'].blank?
    @recurring_profile_id = response.params['profile_id']
  
    # Test modify
    @options.update(
      :periodicity => :monthly,
      :starting_at => Time.now + 1.day,
      :payments => '4',
      :profile_id => @recurring_profile_id
    )
    response = @gateway.recurring(400, @creditcard, @options)
    assert_equal "Approved", response.params['message']
    assert_equal "0", response.params['result']
    assert_success response
    assert response.test?
    
    # Test inquiry
    response = @gateway.recurring_inquiry(@recurring_profile_id) 
    assert_equal "0", response.params['result']
    assert_success response
    assert response.test?
    
    # Test cancel
    response = @gateway.cancel_recurring(@recurring_profile_id)
    assert_equal "Approved", response.params['message']
    assert_equal "0", response.params['result']
    assert_success response
    assert response.test?
  end
  
  # Note that this test will only work if you enable reference transactions!!
  def test_reference_purchase
    assert response = @gateway.purchase(10000, @creditcard, @options)
    assert_equal "Approved", response.message
    assert_success response
    assert response.test?
    assert_not_nil pn_ref = response.authorization
    
    # now another purchase, by reference
    assert response = @gateway.purchase(10000, pn_ref)
    assert_equal "Approved", response.message
    assert_success response
    assert response.test?
  end
  
  def test_recurring_with_initial_authorization
    response = @gateway.recurring(1000, @creditcard, 
      :periodicity => :monthly,
      :initial_transaction => {
        :type => :authorization
      }
    )
    
    assert_success response
    assert !response.params['profile_id'].blank?
    assert response.test?
  end
  
  def test_recurring_with_initial_authorization
    response = @gateway.recurring(1000, @creditcard, 
      :periodicity => :monthly,
      :initial_transaction => {
        :type => :purchase,
        :amount => 500
      }
    )
    
    assert_success response
    assert !response.params['profile_id'].blank?
    assert response.test?
  end
  
  def test_purchase_and_referenced_credit
    amount = 100
    
    assert purchase = @gateway.purchase(amount, @creditcard, @options)
    assert_success purchase
    assert_equal 'Approved', purchase.message
    assert !purchase.authorization.blank?
    
    assert credit = @gateway.credit(amount, purchase.authorization)
    assert_success credit
  end
  
  # The default security setting for Payflow Pro accounts is Allow 
  # non-referenced credits = No.
  #
  # Non-referenced credits will fail with Result code 117 (failed the security 
  # check) unless Allow non-referenced credits = Yes in PayPal manager
  def test_purchase_and_non_referenced_credit
    assert credit = @gateway.credit(100, @creditcard, @options)
    assert_success credit
  end
end
