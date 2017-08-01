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

  def test_successful_authorization_and_capture_and_refund
    assert auth = @gateway.authorize(@amount, @mastercard, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture

    assert refund = @gateway.refund(@amount, capture.authorization,
      :description => 'Crediting trx',
      :order_id => generate_unique_id
    )
    assert_success refund
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

  def test_successful_purchase_with_apply_avscv2_field
    @options[:apply_avscv2] = 1
    response = @gateway.purchase(@amount, @visa, @options)
    assert_success response
    assert_equal "Y", response.cvv_result['code']
  end

  def test_successful_purchase_with_pay_pal_callback_url
    @options[:paypal_callback_urll] = 'callback.com'
    response = @gateway.purchase(@amount, @visa, @options)
    assert_success response
  end

  def test_successful_purchase_with_basket
    # Example from "Sage Pay Direct Integration and Protocol Guidelines 3.00"
    # Published: 27/08/2015
    @options[:basket] = '4:Pioneer NSDV99 DVD-Surround Sound System:1:424.68:' \
      '74.32:499.00: 499.00:Donnie Darko Director’s Cut:3:11.91:2.08:13.99:' \
      '41.97: Finding Nemo:2:11.05:1.94:12.99:25.98: Delivery:---:---:---:---' \
      ':4.99'
    response = @gateway.purchase(@amount, @visa, @options)
    assert_success response
  end

  def test_successful_purchase_with_gift_aid_payment
    @options[:gift_aid_payment] = 1
    response = @gateway.purchase(@amount, @visa, @options)
    assert_success response
  end

  def test_successful_transaction_registration_with_apply_3d_secure
    @options[:apply_3d_secure] = 1
    response = @gateway.purchase(@amount, @visa, @options)
    # We receive a different type of response for 3D Secure requiring to
    # redirect the user to the ACSURL given inside the response
    assert response.params.include?('ACSURL')
    assert_equal 'OK', response.params['3DSecureStatus']
    assert_equal '3DAUTH', response.params['Status']
  end

  def test_successful_purchase_with_account_type
    @options[:account_type] = 'E'
    response = @gateway.purchase(@amount, @visa, @options)
    assert_success response
  end

  def test_successful_purchase_with_billing_agreement
    @options[:billing_agreement] = 1
    response = @gateway.purchase(@amount, @visa, @options)
    assert_success response
  end

  def test_successful_purchase_with_basket_xml
    @options[:basket_xml] = basket_xml
    response = @gateway.purchase(@amount, @visa, @options)
    assert_success response
  end

  def test_successful_purchase_with_customer_xml
    @options[:customer_xml] = customer_xml
    response = @gateway.purchase(@amount, @visa, @options)
    assert_success response
  end

  def test_successful_purchase_with_surcharge_xml
    @options[:surcharge_xml] = surcharge_xml
    response = @gateway.purchase(@amount, @visa, @options)
    assert_success response
  end

  def test_successful_purchase_with_vendor_data
    @options[:vendor_data] = 'Data displayed against the transaction in MySagePay'
    response = @gateway.purchase(@amount, @visa, @options)
    assert_success response
  end

  def test_successful_purchase_with_language
    @options[:language] = 'FR'
    response = @gateway.purchase(@amount, @visa, @options)
    assert_success response
  end

  def test_successful_purchase_with_website
    @options[:website] = 'origin-of-transaction.com'
    response = @gateway.purchase(@amount, @visa, @options)
    assert_success response
  end

  def test_successful_repeat_purchase
    response = @gateway.purchase(@amount, @visa, @options)
    assert_success response
    repeat = @gateway.purchase(@amount, response.authorization, @options.merge(order_id: generate_unique_id))
    assert_success repeat
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

  def test_successful_store_and_repurchase_with_resupplied_verification_value
    assert response = @gateway.store(@visa)
    assert_success response
    assert !response.authorization.blank?
    assert purchase = @gateway.purchase(@amount, response.authorization, @options.merge(customer: 1))
    assert purchase = @gateway.purchase(@amount, response.authorization, @options.merge(verification_value: '123', order_id: generate_unique_id))
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

  def test_successful_verify
    response = @gateway.verify(@visa, @options)
    assert_success response
    assert_equal "Success", response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match(/Card Range not supported/, response.message)
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @visa, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@visa.number, clean_transcript)
    assert_scrubbed(@visa.verification_value.to_s, clean_transcript)
  end

  private

  def next_year
    Date.today.year + 1
  end

  # Based on example from http://www.sagepay.co.uk/support/basket-xml
  # Only kept required fields to make sense
  def basket_xml
    <<-XML
<basket>
  <item>
    <description>DVD 1</description>
    <quantity>2</quantity>
    <unitNetAmount>24.50</unitNetAmount>
    <unitTaxAmount>00.50</unitTaxAmount>
    <unitGrossAmount>25.00</unitGrossAmount>
    <totalGrossAmount>50.00</totalGrossAmount>
  </item>
 </basket>
    XML
  end

  # Example from http://www.sagepay.co.uk/support/customer-xml
  def customer_xml
    <<-XML
<customer>
  <customerMiddleInitial>W</customerMiddleInitial>
  <customerBirth>1983-01-01</customerBirth>
  <customerWorkPhone>020 1234567</customerWorkPhone>
  <customerMobilePhone>0799 1234567</customerMobilePhone>
  <previousCust>0</previousCust>
  <timeOnFile>10</timeOnFile>
  <customerId>CUST123</customerId>
</customer>
    XML
  end

  # Example from https://www.sagepay.co.uk/support/12/36/protocol-3-00-surcharge-xml
  def surcharge_xml
    <<-XML
<surcharges>
  <surcharge>
    <paymentType>DELTA</paymentType>
    <fixed>2.50</fixed>
  </surcharge>
  <surcharge>
    <paymentType>VISA</paymentType>
    <fixed>2.50</fixed>
  </surcharge>
  <surcharge>
    <paymentType>AMEX</paymentType>
    <percentage>1.50</percentage>
  </surcharge>
  <surcharge>
    <paymentType>MC</paymentType>
    <percentage>1.50</percentage>
  </surcharge>
</surcharges>
    XML
  end
end
