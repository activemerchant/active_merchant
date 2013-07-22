require 'test_helper'

class RemoteCyberSourceTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test

    @gateway = CyberSourceGateway.new({nexus: "NC"}.merge(fixtures(:cyber_source)))

    @credit_card = credit_card('4111111111111111')
    @declined_card = credit_card('801111111111111')
    @pinless_debit_card = credit_card('4002269999999999')

    @amount = 100

    @options = {
      :billing_address => address(country: "US", state: "NC"),

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
      :billing_address => address,
      :subscription => {
        :frequency => "weekly",
        :start_date => Date.today.next_week,
        :occurrences => 4,
        :auto_renew => true,
        :amount => 100
      }
    }
  end

  def test_successful_authorization
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
    assert !response.authorization.blank?
  end

  def test_successful_subscription_authorization
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?

    assert response = @gateway.authorize(@amount, response.authorization, :order_id => generate_unique_id)
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
    assert response = @gateway.calculate_tax(@credit_card, @options)
    assert_equal 'Successful transaction', response.message
    assert response.params['totalTaxAmount']
    assert_not_equal "0", response.params['totalTaxAmount']
    assert_success response
    assert response.test?
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end

  def test_successful_pinless_debit_card_puchase
    assert response = @gateway.purchase(@amount, @pinless_debit_card, @options.merge(:pinless_debit_card => true))
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end

  def test_successful_subscription_purchase
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?

    assert response = @gateway.purchase(@amount, response.authorization, :order_id => generate_unique_id)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
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
    assert_match(/wsse:InvalidSecurity/, response.body)
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

  # Pinless debit payment can never be refunded.
  def test_unsuccessful_pinless_debit_card_refund
    assert response = @gateway.purchase(@amount, @pinless_debit_card, @options.merge(:pinless_debit_card => true))
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
    assert response = @gateway.refund(@amount, response.authorization)
    assert_equal 'One or more fields contains invalid data', response.message
    assert_equal false,  response.success?
  end

  def test_successful_subscription_credit
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?

    assert response = @gateway.credit(@amount, response.authorization, :order_id => generate_unique_id)

    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end

  def test_successful_create_subscription
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end

  def test_successful_create_subscription_with_setup_fee
    assert response = @gateway.store(@credit_card, @subscription_options.merge(:setup_fee => 100))
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end

  def test_successful_create_subscription_with_monthly_options
    response = @gateway.store(@credit_card, @subscription_options.merge(:setup_fee => 99.0, :subscription => {:amount => 49.0, :automatic_renew => false, frequency: 'monthly'}))
    assert_equal 'Successful transaction', response.message
    response = @gateway.retrieve(";#{response.params['subscriptionID']};", :order_id => @subscription_options[:order_id])
    assert_equal 49.0, response.params['recurringAmount'].to_f
    assert_equal 'monthly', response.params['frequency']
  end

  def test_successful_update_subscription_creditcard
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?

    assert response = @gateway.update(response.authorization, @credit_card, {:order_id => generate_unique_id, :setup_fee => 100})
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end

  def test_successful_update_subscription_billing_address
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?

    assert response = @gateway.update(response.authorization, nil,
      {:order_id => generate_unique_id, :setup_fee => 100, billing_address: address, email: 'someguy1232@fakeemail.net'})
    assert_equal 'Successful transaction', response.message
    assert_success response
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

  def test_successful_retrieve_subscription
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert response.success?
    assert response.test?

    assert response = @gateway.retrieve(response.authorization, :order_id => generate_unique_id)
    assert response.success?
    assert response.test?
  end

  def test_successful_validate_pinless_debit_card
    assert response = @gateway.validate_pinless_debit_card(@pinless_debit_card, @options)
    assert response.test?
    assert_equal 'Y', response.params["status"]
    assert_equal true,  response.success?
  end
end
