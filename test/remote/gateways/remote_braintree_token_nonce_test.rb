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
    token = generator.client_token
    assert_not_nil token
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
    assert_equal "Field 'state' of variable 'input' has coerced Null value for NonNull type 'UsStateCode!'", err_messages
  end

  def test_unsucesfull_create_token_with_invalid_zip_code
    @options[:billing_address][:zip] = nil
    generator = TokenNonce.new(@braintree_backend, @options)
    bank_account = check({ account_number: '4012000033330125', routing_number: '011000015' })
    tokenized_bank_account, err_messages = generator.create_token_nonce_for_payment_method(bank_account)

    assert_nil tokenized_bank_account
    assert_equal "Field 'zipCode' of variable 'input' has coerced Null value for NonNull type 'UsZipCode!'", err_messages
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
end
