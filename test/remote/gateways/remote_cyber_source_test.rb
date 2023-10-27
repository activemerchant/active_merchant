require 'test_helper'

class RemoteCyberSourceTest < Test::Unit::TestCase
  # Reduce code duplication: use `assert_successful_response` when feasible!
  def setup
    Base.mode = :test

    @gateway = CyberSourceGateway.new({ nexus: 'NC' }.merge(fixtures(:cyber_source)))
    @gateway_latam = CyberSourceGateway.new({}.merge(fixtures(:cyber_source_latam_pe)))

    @credit_card = credit_card('4111111111111111', verification_value: '987')
    @declined_card = credit_card('801111111111111')
    @master_credit_card = credit_card(
      '5555555555554444',
      verification_value: '321',
      month: '12',
      year: (Time.now.year + 2).to_s,
      brand: :master
    )
    @pinless_debit_card = credit_card('4002269999999999')
    @elo_credit_card = credit_card(
      '5067310000000010',
      verification_value: '321',
      month: '12',
      year: (Time.now.year + 2).to_s,
      brand: :elo
    )
    @three_ds_unenrolled_card = credit_card(
      '4000000000000051',
      verification_value: '321',
      month: '12',
      year: (Time.now.year + 2).to_s,
      brand: :visa
    )
    @three_ds_enrolled_card = credit_card(
      '4000000000000002',
      verification_value: '321',
      month: '12',
      year: (Time.now.year + 2).to_s,
      brand: :visa
    )
    @three_ds_invalid_card = credit_card(
      '4000000000000010',
      verification_value: '321',
      month: '12',
      year: (Time.now.year + 2).to_s,
      brand: :visa
    )
    @three_ds_enrolled_mastercard = credit_card(
      '5200000000001005',
      verification_value: '321',
      month: '12',
      year: (Time.now.year + 2).to_s,
      brand: :master
    )
    @visa_network_token = network_tokenization_credit_card(
      '4111111111111111',
      brand: 'visa',
      eci: '05',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk='
    )
    @amex_network_token = network_tokenization_credit_card(
      '378282246310005',
      brand: 'american_express',
      eci: '05',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk='
    )

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
      taxable: true,
      sales_slip_number: '456',
      airline_agent_code: '7Q',
      tax_management_indicator: 1,
      invoice_amount: '3',
      original_amount: '4',
      reference_data_code: 'ABC123',
      invoice_number: '123',
      mobile_remote_payment_type: 'A1',
      vat_tax_rate: '1'
    }

    @capture_options = {
      gratuity_amount: '3.50'
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
    transcript = capture_transcript(@gateway) do
      @gateway.authorize(@amount, @visa_network_token, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@visa_network_token.number, transcript)
    assert_scrubbed(@visa_network_token.payment_cryptogram, transcript)
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
    options = @options.merge(
      installment_total_count: 2,
      installment_total_amount: 0.50,
      installment_plan_type: 1,
      first_installment_date: '300101',
      installment_annual_interest_rate: 1.09,
      installment_grace_period_duration: 1
    )
    assert response = @gateway.authorize(@amount, @credit_card, options)
    assert_successful_response(response)
    assert !response.authorization.blank?
  end

  def test_successful_authorization_with_less_installment_data
    options = @options.merge(installment_grace_period_duration: '1')

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

  def test_successful_authorization_with_tax_mgmt_indicator
    options = @options.merge(tax_management_indicator: '3')
    assert response = @gateway.authorize(@amount, @credit_card, options)
    assert_successful_response(response)
  end

  def test_successful_bank_account_purchase_with_sec_code
    options = @options.merge(sec_code: 'WEB')
    bank_account = check({ account_number: '4100', routing_number: '011000015' })
    assert response = @gateway.purchase(@amount, bank_account, options)
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

  # Note: This test will only pass with test account credentials which
  # have asynchronous adjustments enabled.
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

  def test_successful_purchase_with_bank_account
    bank_account = check({ account_number: '4100', routing_number: '011000015' })
    assert response = @gateway.purchase(10000, bank_account, @options)
    assert_successful_response(response)
  end

  # To properly run this test couple of test your account needs to be enabled to
  # handle canadian bank accounts.
  def test_successful_purchase_with_a_canadian_bank_account_full_number
    bank_account = check({ account_number: '4100', routing_number: '011000015' })
    @options[:currency] = 'CAD'
    assert response = @gateway.purchase(10000, bank_account, @options)
    assert_successful_response(response)
  end

  def test_successful_purchase_with_a_canadian_bank_account_8_digit_number
    bank_account = check({ account_number: '4100', routing_number: '11000015' })
    @options[:currency] = 'CAD'
    assert response = @gateway.purchase(10000, bank_account, @options)
    assert_successful_response(response)
  end

  def test_successful_purchase_with_bank_account_savings_account
    bank_account = check({ account_number: '4100', routing_number: '011000015', account_type: 'savings' })
    assert response = @gateway.purchase(10000, bank_account, @options)
    assert_successful_response(response)
  end

  def test_unsuccessful_purchase_with_bank_account_card_declined
    bank_account = check({ account_number: '4201', routing_number: '011000015' })
    assert response = @gateway.purchase(10000, bank_account, @options)
    assert_failure response
    assert_equal 'General decline by the processor', response.message
  end

  def test_unsuccessful_purchase_with_bank_account_merchant_configuration
    bank_account = check({ account_number: '4241', routing_number: '011000015' })
    assert response = @gateway.purchase(10000, bank_account, @options)
    assert_failure response
    assert_equal 'A problem exists with your CyberSource merchant configuration', response.message
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

    assert capture = @gateway.capture(@amount, auth.authorization, @capture_options)
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

    assert capture = @gateway.capture(@amount + 100000000, auth.authorization, @options.merge({ national_tax_indicator: 1 }))
    assert_failure capture
    assert_equal 'One or more fields contains invalid data: (Amount limit)', capture.message
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

  def test_successful_refund_with_bank_account_follow_on
    bank_account = check({ account_number: '4100', routing_number: '011000015' })
    assert response = @gateway.purchase(10000, bank_account, @options)
    assert_successful_response(response)

    assert response = @gateway.refund(10000, response.authorization, @options)
    assert_successful_response(response)
  end

  def test_network_tokenization_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @visa_network_token, @options)
    assert_successful_response(auth)

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_successful_response(capture)
  end

  def test_network_tokenization_with_amex_cc_and_basic_cryptogram
    assert auth = @gateway.authorize(@amount, @amex_network_token, @options)
    assert_successful_response(auth)

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_successful_response(capture)
  end

  def test_network_tokenization_with_amex_cc_longer_cryptogram
    # Generate a random 40 bytes binary amex cryptogram => Base64.encode64(Random.bytes(40))
    long_cryptogram = "NZwc40C4eTDWHVDXPekFaKkNYGk26w+GYDZmU50cATbjqOpNxR/eYA==\n"

    credit_card = network_tokenization_credit_card(
      '378282246310005',
      brand: 'american_express',
      eci: '05',
      payment_cryptogram: long_cryptogram
    )

    assert auth = @gateway.authorize(@amount, credit_card, @options)
    assert_successful_response(auth)

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_successful_response(capture)
  end

  def test_purchase_with_network_tokenization_with_amex_cc
    assert auth = @gateway.purchase(@amount, @amex_network_token, @options)
    assert_successful_response(auth)
  end

  def test_purchase_with_apple_pay_network_tokenization_visa_subsequent_auth
    credit_card = network_tokenization_credit_card('4111111111111111',
                                                   brand: 'visa',
                                                   eci: '05',
                                                   source: :apple_pay,
                                                   payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=')
    @options[:stored_credential] = {
      initiator: 'merchant',
      reason_type: 'unscheduled',
      network_transaction_id: '016150703802094'
    }

    assert auth = @gateway.purchase(@amount, credit_card, @options)
    assert_successful_response(auth)
  end

  def test_purchase_with_apple_pay_network_tokenization_mastercard_subsequent_auth
    credit_card = network_tokenization_credit_card('5555555555554444',
                                                   brand: 'master',
                                                   eci: '05',
                                                   source: :apple_pay,
                                                   payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=')
    @options[:stored_credential] = {
      initiator: 'merchant',
      reason_type: 'unscheduled',
      network_transaction_id: '0602MCC603474'
    }

    assert auth = @gateway.purchase(@amount, credit_card, @options)
    assert_successful_response(auth)
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

  # this test should probably be removed, the fields do not appear to be part of the
  # most current XSD file, also they are not added to the request correctly as top level fields
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

  def test_successful_authorize_with_additional_purchase_totals_data
    assert response = @gateway.authorize(100, @credit_card, @options.merge(discount_management_indicator: 'T', purchase_tax_amount: 7.89))
    assert_successful_response(response)
  end

  def test_successful_subscription_authorization
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_successful_response(response)

    assert response = @gateway.authorize(@amount, response.authorization, order_id: generate_unique_id)
    assert_successful_response(response)
    assert !response.authorization.blank?
  end

  def test_successful_subscription_authorization_with_bank_account
    bank_account = check({ account_number: '4100', routing_number: '011000015' })
    assert response = @gateway.store(bank_account, order_id: generate_unique_id)
    assert_successful_response(response)

    assert response = @gateway.purchase(@amount, response.authorization, order_id: generate_unique_id)
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

  def test_successful_credit_with_bank_account
    bank_account = check({ account_number: '4100', routing_number: '011000015' })
    assert response = @gateway.credit(10000, bank_account, order_id: generate_unique_id)

    assert_successful_response(response)
  end

  def test_successful_create_subscription
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_successful_response(response)
    assert_equal 'credit_card', response.authorization.split(';')[7]
  end

  def test_successful_create_subscription_with_bank_account
    bank_account = check({ account_number: '4100', routing_number: '011000015' })
    assert response = @gateway.store(bank_account, @subscription_options)
    assert_successful_response(response)
    assert_equal 'check', response.authorization.split(';')[7]
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

    assert response = @gateway.update(
      response.authorization,
      nil,
      { order_id: generate_unique_id, setup_fee: 100, billing_address: address, email: 'someguy1232@fakeemail.net' }
    )

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

  # to create a valid pares, use the test credentials to request `test_3ds_enroll_request_via_purchase` with debug=true.
  # Extract this XML and generate an accessToken. Using this access token to create a form, visit the stepUpURL provided
  # and check the network exchange in the browser dev console for a CCA, which will contain a usable PaRes. Documentation for this feature
  # can be found at https://docs.cybersource.com/content/dam/new-documentation/documentation/en/fraud-management/payer-auth/so/payer-auth-so.pdf
  # Version => September 2017
  # Chapter 2 "Authenticating Enrolled Cards" page 27
  # something like:
  # <html>
  #   <body onload="document.PAEnrollForm.submit();">
  #     <form id="PAEnrollForm" name="PAEnrollForm" action="acsURL" method="post" target="paInlineFrame">
  #       <input type="hidden" name="PaReq" value="paReq value" />
  #       <input type="hidden" name="TermUrl" value="localhost_url" />
  #       <input type="hidden" name="MD" value="xid value" />
  #     </form>
  #   </body>
  # </html>
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

  def test_successful_authorize_with_3ds_exemption
    @options[:three_d_secure] = {
      version: '2.0',
      eci: '05',
      cavv: 'jJ81HADVRtXfCBATEp01CJUAAAA=',
      xid: 'BwABBJQ1AgAAAAAgJDUCAAAAAAA=',
      ds_transaction_id: '97267598-FAE6-48F2-8083-C23433990FBC'
    }

    assert response = @gateway.authorize(@amount, @three_ds_enrolled_card, @options.merge(three_ds_exemption_type: 'moto'))
    assert_successful_response(response)
  end

  def test_successful_purchase_with_3ds_exemption
    @options[:three_d_secure] = {
      version: '2.0',
      eci: '05',
      cavv: 'jJ81HADVRtXfCBATEp01CJUAAAA=',
      xid: 'BwABBJQ1AgAAAAAgJDUCAAAAAAA=',
      ds_transaction_id: '97267598-FAE6-48F2-8083-C23433990FBC'
    }

    assert response = @gateway.purchase(@amount, @three_ds_enrolled_card, @options.merge(three_ds_exemption_type: 'moto'))
    assert_successful_response(response)
  end

  def test_successful_recurring_cof_authorize_with_3ds_exemption
    @options[:stored_credential] = {
      initiator: 'merchant',
      reason_type: 'recurring',
      initial_transaction: false,
      network_transaction_id: ''
    }

    @options[:three_d_secure] = {
      version: '2.0',
      eci: '05',
      cavv: 'jJ81HADVRtXfCBATEp01CJUAAAA=',
      xid: 'BwABBJQ1AgAAAAAgJDUCAAAAAAA=',
      ds_transaction_id: '97267598-FAE6-48F2-8083-C23433990FBC'
    }

    assert response = @gateway.authorize(@amount, @three_ds_enrolled_card, @options.merge(three_ds_exemption_type: CyberSourceGateway::THREEDS_EXEMPTIONS[:stored_credential]))
    assert_successful_response(response)
  end

  def test_successful_recurring_cof_purchase_with_3ds_exemption
    @options[:stored_credential] = {
      initiator: 'merchant',
      reason_type: 'recurring',
      initial_transaction: false,
      network_transaction_id: ''
    }

    @options[:three_d_secure] = {
      version: '2.0',
      eci: '05',
      cavv: 'jJ81HADVRtXfCBATEp01CJUAAAA=',
      xid: 'BwABBJQ1AgAAAAAgJDUCAAAAAAA=',
      ds_transaction_id: '97267598-FAE6-48F2-8083-C23433990FBC'
    }

    assert response = @gateway.purchase(@amount, @three_ds_enrolled_card, @options.merge(three_ds_exemption_type: CyberSourceGateway::THREEDS_EXEMPTIONS[:stored_credential]))
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

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match '1.00', response.params['amount']
    assert_equal 'Successful transaction', response.message
  end

  def test_successful_verify_zero_amount_visa
    @options[:zero_amount_auth] = true
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match '0.00', response.params['amount']
    assert_equal 'Successful transaction', response.message
  end

  def test_successful_verify_zero_amount_master
    @options[:zero_amount_auth] = true
    response = @gateway.verify(@master_credit_card, @options)
    assert_success response
    assert_match '0.00', response.params['amount']
    assert_equal 'Successful transaction', response.message
  end

  private

  def assert_successful_response(response)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end
end
