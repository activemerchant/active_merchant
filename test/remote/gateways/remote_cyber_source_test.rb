require 'test_helper'

class RemoteCyberSourceTest < Test::Unit::TestCase
  # Reduce code duplication: use `assert_successful_response` when feasible!
  def setup
    Base.mode = :test

    @gateway = CyberSourceGateway.new({ nexus: 'NC' }.merge(fixtures(:cyber_source)))
    @gateway_latam = CyberSourceGateway.new({}.merge(fixtures(:cyber_source_latam_pe)))

    @credit_card = credit_card('4111111111111111', verification_value: '987')
    @declined_card = credit_card('801111111111111')
    @pinless_debit_card = credit_card('4002269999999999')
    @elo_credit_card = credit_card('5067310000000010',
      verification_value: '321',
      month: '12',
      year: (Time.now.year + 2).to_s,
      brand: :elo)
    @three_ds_unenrolled_card = credit_card('4000000000000051',
      verification_value: '321',
      month: '12',
      year: (Time.now.year + 2).to_s,
      brand: :visa)
    @three_ds_enrolled_card = credit_card('4000000000000002',
      verification_value: '321',
      month: '12',
      year: (Time.now.year + 2).to_s,
      brand: :visa)
    @three_ds_invalid_card = credit_card('4000000000000010',
      verification_value: '321',
      month: '12',
      year: (Time.now.year + 2).to_s,
      brand: :visa)
    @three_ds_enrolled_mastercard = credit_card('5200000000001005',
      verification_value: '321',
      month: '12',
      year: (Time.now.year + 2).to_s,
      brand: :master)

    @amount = 100

    @options = {
      order_id: generate_unique_id,
      line_items: [
        {
          declared_value: 100,
          quantity: 2,
          code: 'default',
          description: 'Giant Walrus',
          sku: 'WA323232323232323',
          tax_amount: 10,
          national_tax: 5
        }
      ],
      currency: 'USD',
      ignore_avs: 'true',
      ignore_cvv: 'true',
      commerce_indicator: 'internet',
      user_po: 'ABC123',
      taxable: true
    }

    @subscription_options = {
      order_id: generate_unique_id,
      credit_card: @credit_card,
      subscription: {
        frequency: 'weekly',
        start_date: Date.today.next_week,
        occurrences: 4,
        auto_renew: true,
        amount: 100
      }
    }

    @issuer_additional_data = 'PR25000000000011111111111112222222sk111111111111111111111111111'
    + '1111111115555555222233101abcdefghijkl7777777777777777777777777promotionCde'
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
      brand: 'visa',
      eci: '05',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=')

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
    assert_successful_response(response)
    assert !response.authorization.blank?
  end

  def test_successful_authorization_with_reconciliation_id
    options = @options.merge(reconciliation_id: '1936831')
    assert response = @gateway.authorize(@amount, @credit_card, options)
    assert_successful_response(response)
    assert !response.authorization.blank?
  end

  def test_successful_authorize_with_solution_id
    ActiveMerchant::Billing::CyberSourceGateway.application_id = 'A1000000'
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(response)
    assert !response.authorization.blank?
  ensure
    ActiveMerchant::Billing::CyberSourceGateway.application_id = nil
  end

  def test_successful_authorize_with_solution_id_and_stored_creds
    ActiveMerchant::Billing::CyberSourceGateway.application_id = 'A1000000'
    @options[:stored_credential] = {
      initiator: 'cardholder',
      reason_type: '',
      initial_transaction: true,
      network_transaction_id: ''
    }
    @options[:commerce_indicator] = 'internet'

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(response)
    assert !response.authorization.blank?
  ensure
    ActiveMerchant::Billing::CyberSourceGateway.application_id = nil
  end

  def test_successful_authorization_with_issuer_additional_data
    @options[:issuer_additional_data] = @issuer_additional_data

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(response)
    assert !response.authorization.blank?
  end

  def test_successful_authorization_with_issuer_additional_data_and_partner_solution_id
    @options[:issuer_additional_data] = @issuer_additional_data

    ActiveMerchant::Billing::CyberSourceGateway.application_id = 'A1000000'

    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(auth)

    assert void = @gateway.void(auth.authorization, @options)
    assert_successful_response(void)
  ensure
    ActiveMerchant::Billing::CyberSourceGateway.application_id = nil
  end

  def test_successful_authorize_with_merchant_descriptor_and_partner_solution_id
    @options[:merchant_descriptor] = 'Spreedly'

    ActiveMerchant::Billing::CyberSourceGateway.application_id = 'A1000000'

    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(auth)

    assert void = @gateway.void(auth.authorization, @options)
    assert_successful_response(void)
  ensure
    ActiveMerchant::Billing::CyberSourceGateway.application_id = nil
  end

  def test_successful_authorize_with_issuer_additional_data_stored_creds_merchant_desc_and_partner_solution_id
    @options[:issuer_additional_data] = @issuer_additional_data
    @options[:stored_credential] = {
      initiator: 'cardholder',
      reason_type: '',
      initial_transaction: true,
      network_transaction_id: ''
    }
    @options[:commerce_indicator] = 'internet'
    @options[:merchant_descriptor] = 'Spreedly'

    ActiveMerchant::Billing::CyberSourceGateway.application_id = 'A1000000'

    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(auth)
  ensure
    ActiveMerchant::Billing::CyberSourceGateway.application_id = nil
  end

  def test_successful_authorization_with_elo
    assert response = @gateway.authorize(@amount, @elo_credit_card, @options)
    assert_successful_response(response)
    assert !response.authorization.blank?
  end

  def test_successful_authorization_with_installment_data
    options = @options.merge(installment_total_count: 5, installment_plan_type: 1, first_installment_date: '300101')
    assert response = @gateway.authorize(@amount, @credit_card, options)
    assert_successful_response(response)
    assert !response.authorization.blank?
  end

  def test_successful_authorization_with_merchant_tax_id
    options = @options.merge(merchant_tax_id: '123')
    assert response = @gateway.authorize(@amount, @credit_card, options)
    assert_successful_response(response)
  end

  def test_successful_authorization_with_sales_slip_number
    options = @options.merge(sales_slip_number: '456')
    assert response = @gateway.authorize(@amount, @credit_card, options)
    assert_successful_response(response)
  end

  def test_successful_authorization_with_airline_agent_code
    options = @options.merge(airline_agent_code: '7Q')
    assert response = @gateway.authorize(@amount, @credit_card, options)
    assert_successful_response(response)
  end

  def test_unsuccessful_authorization
    assert response = @gateway.authorize(@amount, @declined_card, @options)
    assert response.test?
    assert_equal 'Invalid account number', response.message
    assert_equal false, response.success?
  end

  def test_purchase_and_void
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(purchase)
    assert void = @gateway.void(purchase.authorization, @options)
    assert_successful_response(void)
  end

  def test_successful_asynchronous_adjust
    assert authorize = @gateway_latam.authorize(@amount, @credit_card, @options)
    assert_successful_response(authorize)
    assert adjust = @gateway_latam.adjust(@amount * 2, authorize.authorization, @options)
    assert_success adjust
    assert capture = @gateway_latam.capture(@amount, authorize.authorization, @options.merge({ national_tax_indicator: 1 }))
    assert_successful_response(capture)
  end

  def test_authorize_and_void
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(auth)
    assert void = @gateway.void(auth.authorization, @options)
    assert_successful_response(void)
  end

  def test_capture_and_void
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(auth)
    assert capture = @gateway.capture(@amount, auth.authorization, @options.merge({ national_tax_indicator: 1 }))
    assert_successful_response(capture)
    assert void = @gateway.void(capture.authorization, @options)
    assert_successful_response(void)
  end

  def test_capture_and_void_with_elo
    assert auth = @gateway.authorize(@amount, @elo_credit_card, @options)
    assert_successful_response(auth)
    assert capture = @gateway.capture(@amount, auth.authorization, @options.merge({ national_tax_indicator: 1 }))
    assert_successful_response(capture)
    assert void = @gateway.void(capture.authorization, @options)
    assert_successful_response(void)
  end

  def test_void_with_issuer_additional_data
    @options[:issuer_additional_data] = @issuer_additional_data

    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(auth)
    assert void = @gateway.void(auth.authorization, @options)
    assert_successful_response(void)
  end

  def test_void_with_mdd_fields
    (1..20).each { |e| @options["mdd_field_#{e}".to_sym] = "value #{e}" }

    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(auth)
    assert void = @gateway.void(auth.authorization, @options)
    assert_successful_response(void)
  end

  def test_successful_void_with_solution_id
    ActiveMerchant::Billing::CyberSourceGateway.application_id = 'A1000000'

    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(auth)

    assert void = @gateway.void(auth.authorization, @options)
    assert_successful_response(void)
  ensure
    ActiveMerchant::Billing::CyberSourceGateway.application_id = nil
  end

  def test_successful_tax_calculation
    assert response = @gateway.calculate_tax(@credit_card, @options)
    assert response.params['totalTaxAmount']
    assert_not_equal '0', response.params['totalTaxAmount']
    assert_successful_response(response)
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_purchase_with_national_tax_indicator
    assert purchase = @gateway.purchase(@amount, @credit_card, @options.merge(national_tax_indicator: 1))
    assert_successful_response(purchase)
  end

  def test_successful_purchase_with_issuer_additional_data
    @options[:issuer_additional_data] = @issuer_additional_data

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_purchase_with_merchant_descriptor
    @options[:merchant_descriptor] = 'Spreedly'

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_purchase_with_issuer_additional_data_and_partner_solution_id
    @options[:issuer_additional_data] = @issuer_additional_data

    ActiveMerchant::Billing::CyberSourceGateway.application_id = 'A1000000'

    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(purchase)
  ensure
    ActiveMerchant::Billing::CyberSourceGateway.application_id = nil
  end

  def test_successful_purchase_with_merchant_descriptor_and_partner_solution_id
    @options[:merchant_descriptor] = 'Spreedly'

    ActiveMerchant::Billing::CyberSourceGateway.application_id = 'A1000000'

    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(purchase)
  ensure
    ActiveMerchant::Billing::CyberSourceGateway.application_id = nil
  end

  def test_successful_purchase_with_issuer_additional_data_stored_creds_merchant_desc_and_partner_solution_id
    @options[:issuer_additional_data] = @issuer_additional_data
    @options[:stored_credential] = {
      initiator: 'cardholder',
      reason_type: '',
      initial_transaction: true,
      network_transaction_id: ''
    }
    @options[:commerce_indicator] = 'internet'
    @options[:merchant_descriptor] = 'Spreedly'

    ActiveMerchant::Billing::CyberSourceGateway.application_id = 'A1000000'

    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(purchase)
  ensure
    ActiveMerchant::Billing::CyberSourceGateway.application_id = nil
  end

  def test_successful_purchase_with_reconciliation_id
    options = @options.merge(reconciliation_id: '1936831')
    assert response = @gateway.purchase(@amount, @credit_card, options)
    assert_successful_response(response)
  end

  def test_successful_authorize_with_customer_id
    options = @options.merge(customer_id: '7500BB199B4270EFE05348D0AFCAD')
    assert response = @gateway.authorize(@amount, @credit_card, options)
    assert_successful_response(response)
  end

  def test_authorize_with_national_tax_indicator
    assert authorize = @gateway.authorize(@amount, @credit_card, @options.merge(national_tax_indicator: 1))
    assert_successful_response(authorize)
  end

  def test_successful_purchase_with_customer_id
    options = @options.merge(customer_id: '7500BB199B4270EFE00588D0AFCAD')
    assert response = @gateway.purchase(@amount, @credit_card, options)
    assert_successful_response(response)
  end

  def test_successful_purchase_with_elo
    assert response = @gateway.purchase(@amount, @elo_credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_purchase_sans_options
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'Successful transaction', response.message
    assert_successful_response(response)
  end

  def test_successful_purchase_with_billing_address_override
    billing_address = {
      address1: '111 North Pole Lane',
      city: 'Santaland',
      state: '',
      phone: nil
    }
    @options[:billing_address] = billing_address
    @options[:email] = 'override@example.com'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal true, response.success?
    assert_successful_response(response)
  end

  def test_successful_purchase_with_long_country_name
    @options[:billing_address] = address(country: 'united states', state: 'NC')
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_purchase_without_decision_manager
    @options[:decision_manager_enabled] = 'false'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_purchase_with_decision_manager_profile
    @options[:decision_manager_enabled] = 'true'
    @options[:decision_manager_profile] = 'Regular'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_pinless_debit_card_purchase
    assert response = @gateway.purchase(@amount, @pinless_debit_card, @options.merge(pinless_debit_card: true))
    assert_successful_response(response)
  end

  def test_successful_purchase_with_solution_id
    ActiveMerchant::Billing::CyberSourceGateway.application_id = 'A1000000'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(response)
    assert !response.authorization.blank?
  ensure
    ActiveMerchant::Billing::CyberSourceGateway.application_id = nil
  end

  def test_successful_purchase_with_solution_id_and_stored_creds
    ActiveMerchant::Billing::CyberSourceGateway.application_id = 'A1000000'
    @options[:stored_credential] = {
      initiator: 'cardholder',
      reason_type: '',
      initial_transaction: true,
      network_transaction_id: ''
    }
    @options[:commerce_indicator] = 'internet'

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(response)
    assert !response.authorization.blank?
  ensure
    ActiveMerchant::Billing::CyberSourceGateway.application_id = nil
  end

  def test_successful_purchase_with_country_submitted_as_empty_string
    @options[:billing_address] = { country: '' }
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_equal 'Invalid account number', response.message
    assert_failure response
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(auth)

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_successful_response(capture)
  end

  def test_authorize_and_capture_with_elo
    assert auth = @gateway.authorize(@amount, @elo_credit_card, @options)
    assert_successful_response(auth)

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_successful_response(capture)
  end

  def test_successful_capture_with_issuer_additional_data
    @options[:issuer_additional_data] = @issuer_additional_data
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(auth)

    assert response = @gateway.capture(@amount, auth.authorization)
    assert_successful_response(response)
    assert !response.authorization.blank?
  end

  def test_successful_capture_with_solution_id
    ActiveMerchant::Billing::CyberSourceGateway.application_id = 'A1000000'
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(auth)

    assert response = @gateway.capture(@amount, auth.authorization, @options.merge({ national_tax_indicator: 1 }))
    assert_successful_response(response)
    assert !response.authorization.blank?
  ensure
    ActiveMerchant::Billing::CyberSourceGateway.application_id = nil
  end

  def test_successful_authorization_and_failed_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(auth)

    assert capture = @gateway.capture(@amount + 10, auth.authorization, @options.merge({ national_tax_indicator: 1 }))
    assert_failure capture
    assert_equal 'The requested amount exceeds the originally authorized amount', capture.message
  end

  def test_failed_capture_bad_auth_info
    assert @gateway.authorize(@amount, @credit_card, @options)
    assert capture = @gateway.capture(@amount, 'a;b;c', @options.merge({ national_tax_indicator: 1 }))
    assert_failure capture
  end

  def test_invalid_login
    gateway = CyberSourceGateway.new(login: 'asdf', password: 'qwer')
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "wsse:FailedCheck: \nSecurity Data : UsernameToken authentication failed.\n", response.message
  end

  # Unable to test refunds for Elo cards, as the test account is setup to have
  # Elo transactions routed to Comercio Latino which has very specific rules on
  # refunds (i.e. that you cannot do a "Stand-Alone" refund). This means we need
  # to go through a Capture cycle at least a day before submitting a refund.
  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(response)

    assert response = @gateway.refund(@amount, response.authorization)
    assert_successful_response(response)
  end

  def test_successful_refund_with_solution_id
    ActiveMerchant::Billing::CyberSourceGateway.application_id = 'A1000000'

    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(purchase)

    assert refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_successful_response(refund)
  ensure
    ActiveMerchant::Billing::CyberSourceGateway.application_id = nil
  end

  def test_successful_validate_pinless_debit_card
    assert response = @gateway.validate_pinless_debit_card(@pinless_debit_card, @options)
    assert response.test?
    assert_equal 'Y', response.params['status']
    assert_equal true, response.success?
  end

  def test_network_tokenization_authorize_and_capture
    credit_card = network_tokenization_credit_card('4111111111111111',
      brand: 'visa',
      eci: '05',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=')

    assert auth = @gateway.authorize(@amount, credit_card, @options)
    assert_successful_response(auth)

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_successful_response(capture)
  end

  def test_successful_authorize_with_mdd_fields
    (1..20).each { |e| @options["mdd_field_#{e}".to_sym] = "value #{e}" }

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_purchase_with_mdd_fields
    (1..20).each { |e| @options["mdd_field_#{e}".to_sym] = "value #{e}" }
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_capture_with_mdd_fields
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(auth)

    (1..20).each { |e| @options["mdd_field_#{e}".to_sym] = "value #{e}" }
    assert capture = @gateway.capture(@amount, auth.authorization, @options.merge({ national_tax_indicator: 1 }))
    assert_successful_response(capture)
  end

  def test_merchant_description
    merchant_options = {
      merchantInformation: {
        merchantDescriptor: {
          name: 'Test Name',
          address1: '123 Main Dr',
          locality: 'Durham'
        }
      }
    }

    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(merchant_options))
    assert_successful_response(response)
  end

  def test_successful_capture_with_tax
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(auth)

    capture_options = @options.merge(local_tax_amount: '0.17', national_tax_amount: '0.05', national_tax_indicator: 1)
    assert capture = @gateway.capture(@amount, auth.authorization, capture_options)
    assert_successful_response(capture)
  end

  def test_successful_authorize_with_nonfractional_currency
    assert response = @gateway.authorize(100, @credit_card, @options.merge(currency: 'JPY'))
    assert_equal '1', response.params['amount']
    assert_successful_response(response)
  end

  def test_successful_subscription_authorization
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_successful_response(response)

    assert response = @gateway.authorize(@amount, response.authorization, order_id: generate_unique_id)
    assert_successful_response(response)
    assert !response.authorization.blank?
  end

  def test_successful_subscription_purchase
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_successful_response(response)

    assert response = @gateway.purchase(@amount, response.authorization, order_id: generate_unique_id)
    assert_successful_response(response)
  end

  def test_successful_subscription_purchase_with_elo
    assert response = @gateway.store(@elo_credit_card, @subscription_options)
    assert_successful_response(response)

    assert response = @gateway.purchase(@amount, response.authorization, order_id: generate_unique_id)
    assert_successful_response(response)
  end

  def test_successful_standalone_credit_to_card
    assert response = @gateway.credit(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_standalone_credit_to_card_with_merchant_descriptor
    @options[:merchant_descriptor] = 'Spreedly'
    assert response = @gateway.credit(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_standalone_credit_to_card_with_issuer_additional_data
    @options[:issuer_additional_data] = @issuer_additional_data
    assert response = @gateway.credit(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_standalone_credit_to_card_with_mdd_fields
    (1..20).each { |e| @options["mdd_field_#{e}".to_sym] = "value #{e}" }
    assert response = @gateway.credit(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_failed_standalone_credit_to_card
    assert response = @gateway.credit(@amount, @declined_card, @options)

    assert_equal 'Invalid account number', response.message
    assert_failure response
    assert response.test?
  end

  def test_successful_standalone_credit_to_subscription
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_successful_response(response)

    assert response = @gateway.credit(@amount, response.authorization, order_id: generate_unique_id)
    assert_successful_response(response)
  end

  def test_successful_standalone_credit_to_subscription_with_merchant_descriptor
    @subscription_options[:merchant_descriptor] = 'Spreedly'
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_successful_response(response)

    assert response = @gateway.credit(@amount, response.authorization, order_id: generate_unique_id)
    assert_successful_response(response)
  end

  def test_successful_create_subscription
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_successful_response(response)
  end

  def test_successful_create_subscription_with_elo
    assert response = @gateway.store(@elo_credit_card, @subscription_options)
    assert_successful_response(response)
  end

  def test_successful_create_subscription_with_setup_fee
    assert response = @gateway.store(@credit_card, @subscription_options.merge(setup_fee: 100))
    assert_successful_response(response)
  end

  def test_successful_create_subscription_with_monthly_options
    response = @gateway.store(@credit_card, @subscription_options.merge(setup_fee: 99.0, subscription: { amount: 49.0, automatic_renew: false, frequency: 'monthly' }))
    assert_equal 'Successful transaction', response.message
    response = @gateway.retrieve(response.authorization, order_id: @subscription_options[:order_id])
    assert_equal '0.49', response.params['recurringAmount']
    assert_equal 'monthly', response.params['frequency']
  end

  def test_successful_update_subscription_creditcard
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_successful_response(response)

    assert response = @gateway.update(response.authorization, @credit_card, { order_id: generate_unique_id, setup_fee: 100 })
    assert_successful_response(response)
  end

  def test_successful_update_subscription_billing_address
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_successful_response(response)

    assert response = @gateway.update(response.authorization, nil,
      { order_id: generate_unique_id, setup_fee: 100, billing_address: address, email: 'someguy1232@fakeemail.net' })

    assert_successful_response(response)
  end

  def test_successful_delete_subscription
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert response.success?
    assert response.test?

    assert response = @gateway.unstore(response.authorization, order_id: generate_unique_id)
    assert response.success?
    assert response.test?
  end

  def test_successful_delete_subscription_with_elo
    assert response = @gateway.store(@elo_credit_card, @subscription_options)
    assert response.success?
    assert response.test?

    assert response = @gateway.unstore(response.authorization, order_id: generate_unique_id)
    assert response.success?
    assert response.test?
  end

  def test_successful_retrieve_subscription
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert response.success?
    assert response.test?

    assert response = @gateway.retrieve(response.authorization, order_id: generate_unique_id)
    assert response.success?
    assert response.test?
  end

  def test_3ds_enroll_request_via_purchase
    assert response = @gateway.purchase(1202, @three_ds_enrolled_card, @options.merge(payer_auth_enroll_service: true))
    assert_equal '475', response.params['reasonCode']
    assert !response.params['acsURL'].blank?
    assert !response.params['paReq'].blank?
    assert !response.params['xid'].blank?
    assert !response.success?
  end

  def test_3ds_enroll_request_via_authorize
    assert response = @gateway.authorize(1202, @three_ds_enrolled_card, @options.merge(payer_auth_enroll_service: true))
    assert_equal '475', response.params['reasonCode']
    assert !response.params['acsURL'].blank?
    assert !response.params['paReq'].blank?
    assert !response.params['xid'].blank?
    assert !response.success?
  end

  def test_successful_3ds_requests_with_unenrolled_card
    assert response = @gateway.purchase(1202, @three_ds_unenrolled_card, @options.merge(payer_auth_enroll_service: true))
    assert response.success?

    assert response = @gateway.authorize(1202, @three_ds_unenrolled_card, @options.merge(payer_auth_enroll_service: true))
    assert response.success?
  end

  def test_successful_3ds_validate_purchase_request
    assert response = @gateway.purchase(1202, @three_ds_enrolled_card, @options.merge(payer_auth_validate_service: true, pares: pares))
    assert_equal '100', response.params['reasonCode']
    assert_equal '0', response.params['authenticationResult']
    assert response.success?
  end

  def test_failed_3ds_validate_purchase_request
    assert response = @gateway.purchase(1202, @three_ds_invalid_card, @options.merge(payer_auth_validate_service: true, pares: pares))
    assert_equal '476', response.params['reasonCode']
    assert !response.success?
  end

  def test_successful_3ds_validate_authorize_request
    assert response = @gateway.authorize(1202, @three_ds_enrolled_card, @options.merge(payer_auth_validate_service: true, pares: pares))
    assert_equal '100', response.params['reasonCode']
    assert_equal '0', response.params['authenticationResult']
    assert response.success?
  end

  def test_failed_3ds_validate_authorize_request
    assert response = @gateway.authorize(1202, @three_ds_invalid_card, @options.merge(payer_auth_validate_service: true, pares: pares))
    assert_equal '476', response.params['reasonCode']
    assert !response.success?
  end

  def test_successful_authorize_via_normalized_3ds2_fields
    options = @options.merge(
      three_d_secure: {
        version: '2.0',
        eci: '05',
        cavv: 'jJ81HADVRtXfCBATEp01CJUAAAA=',
        xid: 'BwABBJQ1AgAAAAAgJDUCAAAAAAA=',
        ds_transaction_id: '97267598-FAE6-48F2-8083-C23433990FBC',
        cavv_algorithm: 1,
        enrolled: 'Y',
        authentication_response_status: 'Y'
      },
      commerce_indicator: 'vbv'
    )

    response = @gateway.authorize(@amount, @three_ds_enrolled_card, options)
    assert_successful_response(response)
  end

  def test_successful_mastercard_authorize_via_normalized_3ds2_fields
    options = @options.merge(
      three_d_secure: {
        version: '2.0',
        eci: '05',
        cavv: 'jJ81HADVRtXfCBATEp01CJUAAAA=',
        xid: 'BwABBJQ1AgAAAAAgJDUCAAAAAAA=',
        ds_transaction_id: '97267598-FAE6-48F2-8083-C23433990FBC'
      },
      commerce_indicator: 'spa',
      collection_indicator: 2
    )

    response = @gateway.authorize(@amount, @three_ds_enrolled_mastercard, options)
    assert_successful_response(response)
  end

  def test_successful_purchase_via_normalized_3ds2_fields
    options = @options.merge(
      three_d_secure: {
        version: '2.0',
        eci: '05',
        cavv: 'jJ81HADVRtXfCBATEp01CJUAAAA=',
        xid: 'BwABBJQ1AgAAAAAgJDUCAAAAAAA=',
        ds_transaction_id: '97267598-FAE6-48F2-8083-C23433990FBC'
      }
    )

    response = @gateway.purchase(@amount, @three_ds_enrolled_card, options)
    assert_successful_response(response)
  end

  def test_successful_mastercard_purchase_via_normalized_3ds2_fields
    options = @options.merge(
      three_d_secure: {
        version: '2.0',
        eci: '05',
        cavv: 'jJ81HADVRtXfCBATEp01CJUAAAA=',
        xid: 'BwABBJQ1AgAAAAAgJDUCAAAAAAA=',
        ds_transaction_id: '97267598-FAE6-48F2-8083-C23433990FBC'
      },
      commerce_indicator: 'spa',
      collection_indicator: 2
    )

    response = @gateway.purchase(@amount, @three_ds_enrolled_mastercard, options)
    assert_successful_response(response)
  end

  def test_successful_first_cof_authorize
    @options[:stored_credential] = {
      initiator: 'cardholder',
      reason_type: '',
      initial_transaction: true,
      network_transaction_id: ''
    }
    @options[:commerce_indicator] = 'internet'
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_subsequent_unscheduled_cof_authorize
    @options[:stored_credential] = {
      initiator: 'merchant',
      reason_type: 'unscheduled',
      initial_transaction: false,
      network_transaction_id: '016150703802094'
    }
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_recurring_cof_authorize
    @options[:stored_credential] = {
      initiator: 'merchant',
      reason_type: 'recurring',
      initial_transaction: false,
      network_transaction_id: ''
    }
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_subsequent_recurring_cof_authorize
    @options[:stored_credential] = {
      initiator: 'merchant',
      reason_type: 'recurring',
      initial_transaction: false,
      network_transaction_id: '016150703802094'
    }
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_subsequent_installment_cof_authorize
    @options[:stored_credential] = {
      initiator: 'merchant',
      reason_type: 'installment',
      initial_transaction: false,
      network_transaction_id: '016150703802094'
    }
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_subsequent_unscheduled_cof_purchase
    @options[:stored_credential] = {
      initiator: 'merchant',
      reason_type: 'unscheduled',
      initial_transaction: false,
      network_transaction_id: '016150703802094'
    }
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_invalid_field
    @options = @options.merge({
      address: {
        address1: 'Unspecified',
        city: 'Unspecified',
        state: 'NC',
        zip: '1234567890',
        country: 'US'
      }
    })

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'One or more fields contains invalid data: c:billTo/c:postalCode', response.message
  end

  def pares
    <<~PARES
      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
    PARES
  end

  def test_successful_verify_with_elo
    response = @gateway.verify(@elo_credit_card, @options)
    assert_successful_response(response)
  end

  def test_verify_credentials
    assert @gateway.verify_credentials

    gateway = CyberSourceGateway.new(login: 'an_unknown_login', password: 'unknown_password')
    assert !gateway.verify_credentials
  end

  private

  def assert_successful_response(response)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end
end
