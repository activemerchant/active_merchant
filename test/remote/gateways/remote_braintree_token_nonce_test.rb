require 'test_helper'

class RemoteBraintreeTokenNonceTest < Test::Unit::TestCase
  def setup
    @gateway = BraintreeGateway.new(fixtures(:braintree_blue))
    @braintree_backend = @gateway.instance_eval { @braintree_gateway }

    ach_mandate = 'By clicking ["Checkout"], I authorize Braintree, a service of PayPal, ' \
      'on behalf of My Company (i) to verify my bank account information ' \
      'using bank information and consumer reports and (ii) to debit my bank account.'

    @options = {
      billing_address: {
        name: 'Adrain',
        address1: '96706 Onie Plains',
        address2: '01897 Alysa Lock',
        country: 'XXX',
        city: 'Miami',
        state: 'FL',
        zip: '32191',
        phone_number: '693-630-6935'
      },
      ach_mandate: ach_mandate
    }
  end

  def test_client_token_generation
    generator = TokenNonce.new(@braintree_backend)
    client_token = generator.client_token
    assert_not_nil client_token
    assert_not_nil client_token['authorizationFingerprint']
  end

  def test_client_token_generation_with_mid
    @options[:merchant_account_id] = '1234'
    generator = TokenNonce.new(@braintree_backend, @options)
    client_token = generator.client_token
    assert_not_nil client_token
    assert_equal client_token['merchantAccountId'], '1234'
  end

  def test_client_token_generation_with_a_new_mid
    @options[:merchant_account_id] = '1234'
    generator = TokenNonce.new(@braintree_backend, @options)
    client_token = generator.client_token({ merchant_account_id: '5678' })
    assert_not_nil client_token
    assert_equal client_token['merchantAccountId'], '5678'
  end

  def test_successfully_create_token_nonce_for_bank_account
    generator = TokenNonce.new(@braintree_backend, @options)
    bank_account = check({ account_number: '4012000033330125', routing_number: '011000015' })
    tokenized_bank_account, err_messages = generator.create_token_nonce_for_payment_method(bank_account)

    assert_not_nil tokenized_bank_account
    assert_match %r(^tokenusbankacct_), tokenized_bank_account
    assert_nil err_messages
  end

  def test_unsucesfull_create_token_with_invalid_state
    @options[:billing_address][:state] = nil
    generator = TokenNonce.new(@braintree_backend, @options)
    bank_account = check({ account_number: '4012000033330125', routing_number: '011000015' })
    tokenized_bank_account, err_messages = generator.create_token_nonce_for_payment_method(bank_account)

    assert_nil tokenized_bank_account
    assert_equal "Variable 'input' has an invalid value: Field 'state' has coerced Null value for NonNull type 'UsStateCode!'", err_messages
  end

  def test_unsucesfull_create_token_with_invalid_zip_code
    @options[:billing_address][:zip] = nil
    generator = TokenNonce.new(@braintree_backend, @options)
    bank_account = check({ account_number: '4012000033330125', routing_number: '011000015' })
    tokenized_bank_account, err_messages = generator.create_token_nonce_for_payment_method(bank_account)

    assert_nil tokenized_bank_account
    assert_equal "Variable 'input' has an invalid value: Field 'zipCode' has coerced Null value for NonNull type 'UsZipCode!'", err_messages
  end

  def test_url_generation
    config_base = {
      merchant_id: 'test',
      public_key: 'test',
      private_key: 'test',
      environment: :sandbox
    }

    configuration = Braintree::Configuration.new(config_base)
    braintree_backend = Braintree::Gateway.new(configuration)
    generator = TokenNonce.new(braintree_backend)

    assert_equal 'https://payments.sandbox.braintree-api.com/graphql', generator.url

    configuration = Braintree::Configuration.new(config_base.update(environment: :production))
    braintree_backend = Braintree::Gateway.new(configuration)
    generator = TokenNonce.new(braintree_backend)

    assert_equal 'https://payments.braintree-api.com/graphql', generator.url
  end

  def test_successfully_create_token_nonce_for_credit_card
    generator = TokenNonce.new(@braintree_backend, @options)
    credit_card = credit_card('4111111111111111')
    tokenized_credit_card, err_messages = generator.create_token_nonce_for_payment_method(credit_card)
    assert_not_nil tokenized_credit_card
    assert_match %r(^tokencc_), tokenized_credit_card
    assert_nil err_messages
  end
end
