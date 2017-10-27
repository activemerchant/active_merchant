require 'test_helper'

class RemoteCyberSourceTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = CyberSourceGateway.new({nexus: "NC"}.merge(fixtures(:cyber_source)))

    @credit_card = credit_card('4111111111111111', verification_value: '321')
    @declined_card = credit_card('801111111111111')
    @pinless_debit_card = credit_card('4002269999999999')
    @three_ds_enrolled_card = credit_card('4000000000000002',
      verification_value: '321',
      month: "12",
      year: "#{Time.now.year + 2}",
      brand: :visa
    )

    @amount = 100

    @options = {
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
      :ignore_avs => 'true',
      :ignore_cvv => 'true'
    }

    @subscription_options = {
      :order_id => generate_unique_id,
      :credit_card => @credit_card,
      :subscription => {
        :frequency => "weekly",
        :start_date => Date.today.next_week,
        :occurrences => 4,
        :auto_renew => true,
        :amount => 100
      }
    }
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

  def test_network_tokenization_transcript_scrubbing
    credit_card = network_tokenization_credit_card('4111111111111111',
      :brand              => 'visa',
      :eci                => "05",
      :payment_cryptogram => "EHuWW9PiBkWvqE5juRwDzAUFBAk="
    )

    transcript = capture_transcript(@gateway) do
      @gateway.authorize(@amount, credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(credit_card.number, transcript)
    assert_scrubbed(credit_card.payment_cryptogram, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
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

  def test_authorize_and_void
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert void = @gateway.void(auth.authorization, @options)
    assert_equal 'Successful transaction', void.message
    assert_success void
    assert void.test?
  end

  def test_capture_and_void
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert capture = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capture
    assert void = @gateway.void(capture.authorization, @options)
    assert_equal 'Successful transaction', void.message
    assert_success void
    assert void.test?
  end

  def test_successful_tax_calculation
    assert response = @gateway.calculate_tax(@credit_card, @options)
    assert_equal 'Successful transaction', response.message
    assert response.params['totalTaxAmount']
    assert_not_equal "0", response.params['totalTaxAmount']
    assert_success response
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end

  def test_successful_purchase_sans_options
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'Successful transaction', response.message
    assert_success response
  end

  def test_successful_purchase_with_billing_address_override
    @options[:billing_address] = address
    @options[:email] = 'override@example.com'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Successful transaction', response.message
    assert_success response
  end

  def test_successful_purchase_with_long_country_name
    @options[:billing_address] = address(country: "united states", state: "NC")
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Successful transaction', response.message
    assert_success response
  end

  def test_successful_purchase_without_decision_manager
    @options[:decision_manager_enabled] = 'false'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end

  def test_successful_purchase_with_decision_manager_profile
    @options[:decision_manager_enabled] = 'true'
    @options[:decision_manager_profile] = 'Regular'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end

  def test_successful_pinless_debit_card_puchase
    assert response = @gateway.purchase(@amount, @pinless_debit_card, @options.merge(:pinless_debit_card => true))
    assert_equal 'Successful transaction', response.message
    assert_success response
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_equal 'Invalid account number', response.message
    assert_failure response
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
    gateway = CyberSourceGateway.new( :login => 'asdf', :password => 'qwer' )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "wsse:FailedCheck: \nSecurity Data : UsernameToken authentication failed.\n", response.message
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
    assert response = @gateway.refund(@amount, response.authorization)
    assert_equal 'Successful transaction', response.message
    assert_success response
  end

  def test_successful_validate_pinless_debit_card
    assert response = @gateway.validate_pinless_debit_card(@pinless_debit_card, @options)
    assert response.test?
    assert_equal 'Y', response.params["status"]
    assert_equal true,  response.success?
  end

  def test_network_tokenization_authorize_and_capture
    credit_card = network_tokenization_credit_card('4111111111111111',
      :brand              => 'visa',
      :eci                => "05",
      :payment_cryptogram => "EHuWW9PiBkWvqE5juRwDzAUFBAk="
    )

    assert auth = @gateway.authorize(@amount, credit_card, @options)
    assert_success auth
    assert_equal 'Successful transaction', auth.message

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_successful_authorize_with_mdd_fields
    (1..20).each { |e| @options["mdd_field_#{e}".to_sym] = "value #{e}" }
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end

  def test_successful_purchase_with_mdd_fields
    (1..20).each { |e| @options["mdd_field_#{e}".to_sym] = "value #{e}" }
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_successful_authorize_with_nonfractional_currency
    assert response = @gateway.authorize(100, @credit_card, @options.merge(:currency => 'JPY'))
    assert_equal "1", response.params['amount']
    assert_success response
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
    response = @gateway.retrieve(response.authorization, order_id: @subscription_options[:order_id])
    assert_equal "0.49", response.params['recurringAmount']
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

  def test_3ds_purchase_request
    assert response = @gateway.purchase(1202, @three_ds_enrolled_card, @options.merge(payer_auth_enroll_service: true))
    assert_equal "475", response.params["reasonCode"]
    assert !response.params["acsURL"].blank?
    assert !response.params["paReq"].blank?
    assert !response.params["xid"].blank?
    assert !response.success?
  end

  def test_3ds_authorize_request
    assert response = @gateway.authorize(1202, @three_ds_enrolled_card, @options.merge(payer_auth_enroll_service: true))
    assert_equal "475", response.params["reasonCode"]
    assert !response.params["acsURL"].blank?
    assert !response.params["paReq"].blank?
    assert !response.params["xid"].blank?
    assert !response.success?
  end

  def test_3ds_transactions_with_unenrolled_card
    assert response = @gateway.purchase(1202, @credit_card, @options.merge(payer_auth_enroll_service: true))
    assert response.success?

    assert response = @gateway.authorize(1202, @credit_card, @options.merge(payer_auth_enroll_service: true))
    assert response.success?
  end

  def test_verify_credentials
    assert @gateway.verify_credentials

    gateway = CyberSourceGateway.new(login: "an_unknown_login", password: "unknown_password")
    assert !gateway.verify_credentials
  end

end
