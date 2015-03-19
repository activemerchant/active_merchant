require 'test_helper'

# Some of the standard tests have been removed at SagePay test
# server is pants and accepts anything and says Status=OK. (shift)
# The tests for American Express will only pass if your account is
# American express enabled.
class RemoteSagePayTest < Test::Unit::TestCase
  # set to true to run the tests in the simulated environment
  SagePayGateway.simulate = false

  def setup
    @gateway = SagePayGateway.new(fixtures(:sage_pay))

    @amex = CreditCard.new(
      :number => '374200000000004',
      :month => 12,
      :year => next_year,
      :verification_value => 4887,
      :first_name => 'Tekin',
      :last_name => 'Suleyman',
      :brand => 'american_express'
    )

    @maestro = CreditCard.new(
      :number => '5641820000000005',
      :month => 12,
      :year => next_year,
      :issue_number => '01',
      :start_month => 12,
      :start_year => next_year - 2,
      :verification_value => 123,
      :first_name => 'Tekin',
      :last_name => 'Suleyman',
      :brand => 'maestro'
    )

    @visa = CreditCard.new(
      :number => '4929000000006',
      :month => 6,
      :year => next_year,
      :verification_value => 123,
      :first_name => 'Tekin',
      :last_name => 'Suleyman',
      :brand => 'visa'
    )

    @mastercard = CreditCard.new(
      :number => '5404000000000001',
      :month => 12,
      :year => next_year,
      :verification_value => 419,
      :first_name => 'Tekin',
      :last_name => 'Suleyman',
      :brand => 'master'
    )

    @electron = CreditCard.new(
      :number => '4917300000000008',
      :month => 12,
      :year => next_year,
      :verification_value => 123,
      :first_name => 'Tekin',
      :last_name => 'Suleyman',
      :brand => 'electron'
    )

    @declined_card = CreditCard.new(
      :number => '4111111111111111',
      :month => 9,
      :year => next_year,
      :first_name => 'Tekin',
      :last_name => 'Suleyman',
      :brand => 'visa'
    )

    @options = {
      :billing_address => {
        :name => 'Tekin Suleyman',
        :address1 => 'Flat 10 Lapwing Court',
        :address2 => 'West Didsbury',
        :city => "Manchester",
        :county => 'Greater Manchester',
        :country => 'GB',
        :zip => 'M20 2PS'
      },
      :shipping_address => {
        :name => 'Tekin Suleyman',
        :address1 => '120 Grosvenor St',
        :city => "Manchester",
        :county => 'Greater Manchester',
        :country => 'GB',
        :zip => 'M1 7QW'
      },
      :order_id => generate_unique_id,
      :description => 'Store purchase',
      :ip => '86.150.65.37',
      :email => 'tekin@tekin.co.uk',
      :phone => '0161 123 4567'
    }

    @amount = 100
  end

  def test_successful_mastercard_purchase
    assert response = @gateway.purchase(@amount, @mastercard, @options)
    assert_success response

    assert response.test?
    assert !response.authorization.blank?
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response

    assert response.test?
  end

  def test_successful_authorization_and_capture
    assert auth = @gateway.authorize(@amount, @mastercard, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_successful_authorization_and_void
    assert auth = @gateway.authorize(@amount, @mastercard, @options)
    assert_success auth

    assert abort = @gateway.void(auth.authorization)
    assert_success abort
  end

  def test_successful_purchase_and_void
    assert purchase = @gateway.purchase(@amount, @mastercard, @options)
    assert_success purchase

    assert void = @gateway.void(purchase.authorization)
    assert_success void
  end

  def test_successful_purchase_and_refund
    assert purchase = @gateway.purchase(@amount, @mastercard, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization,
      :description => 'Crediting trx',
      :order_id => generate_unique_id
    )

    assert_success refund
  end

  def test_successful_visa_purchase
    assert response = @gateway.purchase(@amount, @visa, @options)
    assert_success response
    assert response.test?
    assert !response.authorization.blank?
  end

  def test_successful_maestro_purchase
    assert response = @gateway.purchase(@amount, @maestro, @options)
    assert_success response
    assert response.test?
    assert !response.authorization.blank?
  end

  def test_successful_amex_purchase
    assert response = @gateway.purchase(@amount, @amex, @options)
    assert_success response
    assert response.test?
    assert !response.authorization.blank?
  end

  def test_successful_electron_purchase
    assert response = @gateway.purchase(@amount, @electron, @options)
    assert_success response
    assert response.test?
    assert !response.authorization.blank?
  end

  def test_successful_purchase_with_overly_long_fields
    options = {
      description: "SagePay transactions fail if the description is more than 100 characters. Therefore, we truncate it to 100 characters.",
      order_id: "#{generate_unique_id} SagePay order_id cannot be more than 40 characters.",
      billing_address: {
        name: 'FirstNameCannotBeMoreThanTwentyChars SurnameCannotBeMoreThanTwenty',
        address1: 'The Billing Address 1 Cannot Be More Than One Hundred Characters if it is it will fail.  Therefore, we truncate it.',
        address2: 'The Billing Address 2 Cannot Be More Than One Hundred Characters if it is it will fail.  Therefore, we truncate it.',
        phone: "111222333444555666777888999",
        city: "TheCityCannotBeMoreThanFortyCharactersReally",
        state: "NCStateIsTwoChars",
        country: 'USMustBeTwoChars',
        zip: 'PostalCodeCannotExceedTenChars'
      },
      shipping_address: {
        name: 'FirstNameCannotBeMoreThanTwentyChars SurnameCannotBeMoreThanTwenty',
        address1: 'The Shipping Address 1 Cannot Be More Than One Hundred Characters if it is it will fail.  Therefore, we truncate it.',
        address2: 'The Shipping Address 2 Cannot Be More Than One Hundred Characters if it is it will fail.  Therefore, we truncate it.',
        phone: "111222333444555666777888999",
        city: "TheCityCannotBeMoreThanFortyCharactersReally",
        state: "NCStateIsTwoChars",
        country: 'USMustBeTwoChars',
        zip: 'PostalCodeCannotExceedTenChars'
      }
    }

    @visa.first_name = "FullNameOnACardMustBeLessThanFiftyCharacters"
    @visa.last_name = "OtherwiseSagePayFailsIt"

    assert response = @gateway.purchase(@amount, @visa, options)
    assert_success response
  end

  def test_successful_mastercard_purchase_with_optional_FIxxxx_fields
    @options[:recipient_account_number] = '1234567890'
    @options[:recipient_surname] = 'Withnail'
    @options[:recipient_postcode] = 'AB11AB'
    @options[:recipient_dob] = '19701223'
    assert response = @gateway.purchase(@amount, @mastercard, @options)
    assert_success response

    assert response.test?
    assert !response.authorization.blank?
  end

  def test_invalid_login
    message = SagePayGateway.simulate ? 'VSP Simulator cannot find your vendor name.  Ensure you have have supplied a Vendor field with your VSP Vendor name assigned to it.' : '3034 : The Vendor or VendorName value is required.'

    gateway = SagePayGateway.new(
        :login => ''
    )
    assert response = gateway.purchase(@amount, @mastercard, @options)
    assert_equal message, response.message
    assert_failure response
  end

  def test_successful_store_and_purchace
    assert response = @gateway.store(@visa)
    assert_success response
    assert !response.authorization.blank?
    assert purchase = @gateway.purchase(@amount, response.authorization, @options)
    assert_success purchase
  end

  def test_successful_store_and_authorize
    assert response = @gateway.store(@visa)
    assert_success response
    assert !response.authorization.blank?
    assert authorize = @gateway.authorize(@amount, response.authorization, @options)
    assert_success authorize
  end

  def test_successful_token_creation_from_purchase
    assert response = @gateway.purchase(@amount, @visa, @options.merge(:store => true))
    assert_success response
    assert !response.authorization.blank?
  end

  def test_successful_token_creation_from_authorize
    assert response = @gateway.authorize(@amount, @visa, @options.merge(:store => true))
    assert_success response
    assert !response.authorization.blank?
  end

  def test_successful_unstore
    assert response = @gateway.store(@visa)
    assert_success response
    assert !response.authorization.blank?
    assert unstore = @gateway.unstore(response.authorization)
    assert_success unstore
  end

  private

  def next_year
    Date.today.year + 1
  end
end
