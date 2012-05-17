require 'test_helper'

# Note:
# to successfully run the echeck test cases, your cybersource test account must be set up
# with one of cybersource's check processors; these cases pass against Paymenttech

class RemoteCyberSourceTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test
    @gateway = CyberSourceGateway.new(fixtures(:cyber_source))

    @credit_card = credit_card('4111111111111111', :type => 'visa')
    @declined_card = credit_card('801111111111111', :type => 'visa')

    @amount = 100

    @options = {
      :billing_address => address.merge({
        :first_name => 'Jim',
        :last_name => 'Smith',
        :address1 => "1295 Charleston Rd.",
        :city =>"Mountain View",
        :state => "CA",
        :zip => "94043",
        :country => "US"
        }),
      :order_id => generate_unique_id,
      :line_items => [
        {
          :declared_value => 100,
          :quantity => 2,
          :code => 'default',
          :description => 'Giant Walrus',
          :sku => 'WA323232323232323'
        },
        {
          :declared_value => 100,
          :quantity => 2,
          :description => 'Marble Snowcone',
          :sku => 'FAKE1232132113123'
        }
      ],
      :currency => 'USD',
      :email => 'someguy1232@fakeemail.net',
      :ignore_avs => 'true',
      :ignore_cvv => 'true'
    }

    @subscription_options = {
      :order_id => generate_unique_id,
      :email => 'someguy1232@fakeemail.net',
      :credit_card => @credit_card,
      :billing_address => address.merge(:first_name => 'Jim', :last_name => 'Smith'),
      :subscription => {
        :frequency => "weekly",
        :start_date => Date.today.next_week,
        :occurrences => 4,
        :auto_renew => true,
        :amount => 100
      }
    }

    @check = ActiveMerchant::Billing::Check.new(
      :name => 'Mr CustomerTwo',
      :routing_number => '121042882', # Valid ABA # - Bank of America, TX
      :account_number => '4100',
      :account_holder_type => 'personal',
      :account_type => 'checking'
    )

    check_fields = {
      :billing_address => address.merge(:first_name => 'Jim', :last_name => 'CustomerTwo', :phone_number => "123-456-7890"),
      :drivers_license_number => "C2222222",
      :drivers_license_state  => "CA"
    }

    @check_options = @options.merge(check_fields)

    @check_subscription_options = @subscription_options.merge(check_fields)
  end

  def test_successful_authorization
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
    assert !response.authorization.blank?
  end

  def test_unsuccessful_authorization
    assert response = @gateway.authorize(@amount, @declined_card, @options)
    assert response.test?
    assert_equal 'Invalid account number', response.message
    assert_equal false,  response.success?
  end

  def test_authorize_and_auth_reversal
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal 'Successful transaction', auth.message
    assert_success auth
    assert auth.test?

    assert auth_reversal = @gateway.auth_reversal(@amount, auth.authorization)
    assert_equal 'Successful transaction', auth_reversal.message
    assert_success auth_reversal
    assert auth_reversal.test?
  end

  def test_successful_authorization_and_failed_auth_reversal
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Successful transaction', auth.message

    assert auth_reversal = @gateway.auth_reversal(@amount + 10, auth.authorization)
    assert_failure auth_reversal
    assert_equal 'One or more fields contains invalid data', auth_reversal.message
  end

  def test_successful_tax_calculation
    assert response = @gateway.calculate_tax(@options)
    assert_equal 'Successful transaction', response.message
    assert response.params['totalTaxAmount']
    assert_not_equal "0", response.params['totalTaxAmount']
    assert_success response
    assert response.test?
  end

  def test_successful_tax_calculation_with_nexus
    assert response = @gateway.calculate_tax(@options.merge(:nexus => 'CA'))
    assert_equal 'Successful transaction', response.message
    assert response.params['totalTaxAmount'].to_f > 0
    assert_success response
    assert response.test?
  end

  def test_successful_purchase_with_cc
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end

  def test_successful_purchase_with_echeck
    assert response = @gateway.purchase(@amount, @check, @check_options)
    assert_equal 'Successful transaction', response.message
    assert_success response
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_equal 'Invalid account number', response.message
    assert_failure response
    assert response.test?
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Successful transaction', auth.message

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_successful_authorization_and_failed_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Successful transaction', auth.message

    assert capture = @gateway.capture(@amount + 10, auth.authorization, @options)
    assert_failure capture
    assert_equal "The requested amount exceeds the originally authorized amount",  capture.message
  end

  def test_failed_capture_bad_auth_info
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert capture = @gateway.capture(@amount, "a;b;c", @options)
    assert_failure capture
  end

  def test_invalid_login
    gateway = CyberSourceGateway.new( :login => '', :password => '' )
    authentication_exception = assert_raise ActiveMerchant::ResponseError, 'Failed with 500 Internal Server Error' do
      gateway.purchase(@amount, @credit_card, @options)
    end
    assert response = authentication_exception.response
    assert_match /wsse:InvalidSecurity/, response.body
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
    assert response = @gateway.refund(@amount, response.authorization)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end

  def test_successful_create_subscription_with_cc
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end

  def test_successful_create_subscription_with_cc_and_setup_fee
    assert response = @gateway.store(@credit_card, @subscription_options.merge(:setup_fee => 100))
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end

  def test_successful_create_subscription_with_echeck
    assert response = @gateway.store(@check, @check_subscription_options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end

  def test_successful_update_subscription
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?

    assert response = @gateway.store(response.authorization, {:order_id =>generate_unique_id,:credit_card => @credit_card, :setup_fee => 100})
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end

  def test_successful_purchase_with_cc_subscription
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?

    assert response = @gateway.purchase(@amount, response.authorization, @options.merge(:type => :credit_card))
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end

  def test_successful_purchase_with_echeck_subscription
    assert response = @gateway.store(@check, @check_subscription_options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?

    assert response = @gateway.purchase(@amount, response.authorization, @options.merge(:type => :check))
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end

  def test_successful_retrieve_subscription
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert response.success?
    assert response.test?

    assert response = @gateway.retrieve(response.authorization, :order_id => generate_unique_id)
    assert response.success?
    assert response.test?
  end

  def test_successful_delete_subscription
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert response.success?
    assert response.test?

    assert response = @gateway.unstore(response.authorization, :order_id => generate_unique_id)
    assert response.success?
    assert response.test?
  end
end
