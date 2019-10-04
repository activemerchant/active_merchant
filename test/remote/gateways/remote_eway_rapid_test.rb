require 'test_helper'

class RemoteEwayRapidTest < Test::Unit::TestCase
  def setup
    @gateway = EwayRapidGateway.new(fixtures(:eway_rapid))

    @amount = 100
    @failed_amount = -100
    @credit_card = credit_card('4444333322221111')

    @options = {
      order_id: '1',
      invoice: 'I1234',
      billing_address: address,
      description: 'Store Purchase',
      redirect_url: 'http://bogus.com'
    }
  end

  def test_successful_purchase_with_billing_address
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'Transaction Approved Successful', response.message

    customer = response.params['Customer']

    assert_address_match(customer, @options[:billing_address])
  end

  def test_successful_purchase_with_address
    @options[:billing_address] = nil
    @options[:address] = address

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'Transaction Approved Successful', response.message

    customer = response.params['Customer']

    assert_address_match(customer, @options[:address])
  end

  def test_successful_purchase_without_address
    email = 'test@example.com'

    @options[:billing_address] = nil
    @options[:email] = email

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'Transaction Approved Successful', response.message

    customer = response.params['Customer']

    assert_equal customer['FirstName'], @credit_card.first_name
    assert_equal customer['LastName'], @credit_card.last_name
    assert_equal customer['Email'], email
  end

  def test_successful_purchase_with_shipping_address
    @options[:shipping_address] = address

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'Transaction Approved Successful', response.message

    # eWAY Rapid does not include the shipping address in the request response,
    # so we can only test that the transaction is successful.
  end

  def test_fully_loaded_purchase
    response = @gateway.purchase(@amount, @credit_card,
      redirect_url: 'http://awesomesauce.com',
      ip: '0.0.0.0',
      application_id: 'Woohoo',
      partner_id: 'Woohoo',
      transaction_type: 'Purchase',
      description: 'Description',
      order_id: 'orderid1',
      invoice: 'I1234',
      currency: 'AUD',
      email: 'jim@example.com',
      billing_address: {
        title:    'Mr.',
        name:     'Jim Awesome Smith',
        company:  'Awesome Co',
        address1: '1234 My Street',
        address2: 'Apt 1',
        city:     'Ottawa',
        state:    'ON',
        zip:      'K1C2N6',
        country:  'CA',
        phone:    '(555)555-5555',
        fax:      '(555)555-6666'
      },
      shipping_address: {
        title:    'Ms.',
        name:     'Baker',
        company:  'Elsewhere Inc.',
        address1: '4321 Their St.',
        address2: 'Apt 2',
        city:     'Chicago',
        state:    'IL',
        zip:      '60625',
        country:  'US',
        phone:    '1115555555',
        fax:      '1115556666'
      }
    )
    assert_success response
  end

  def test_successful_purchase_with_overly_long_fields
    options = {
      order_id: 'OrderId must be less than 50 characters otherwise it fails',
      invoice: 'Max 12 chars',
      description: 'EWay Rapid transactions fail if the description is more than 64 characters.',
      billing_address: {
        address1: 'The Billing Address 1 Cannot Be More Than Fifty Characters.',
        address2: 'The Billing Address 2 Cannot Be More Than Fifty Characters.',
        city: 'TheCityCannotBeMoreThanFiftyCharactersOrItAllFallsApart',
      },
      shipping_address: {
        address1: 'The Shipping Address 1 Cannot Be More Than Fifty Characters.',
        address2: 'The Shipping Address 2 Cannot Be More Than Fifty Characters.',
        city: 'TheCityCannotBeMoreThanFiftyCharactersOrItAllFallsApart',
      }
    }
    @credit_card.first_name = 'FullNameOnACardMustBeLessThanFiftyCharacters'
    @credit_card.last_name = 'LastName'

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Transaction Approved Successful', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@failed_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid Payment TotalAmount', response.message
  end

  def test_successful_authorize_with_billing_address
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'Transaction Approved Successful', response.message

    customer = response.params['Customer']

    assert_address_match(customer, @options[:billing_address])
  end

  def test_successful_authorize_with_address
    @options[:billing_address] = nil
    @options[:address] = address

    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'Transaction Approved Successful', response.message

    customer = response.params['Customer']

    assert_address_match(customer, @options[:address])
  end

  def test_successful_authorize_without_address
    email = 'test@example.com'

    @options[:billing_address] = nil
    @options[:email] = email

    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'Transaction Approved Successful', response.message

    customer = response.params['Customer']

    assert_equal customer['FirstName'], @credit_card.first_name
    assert_equal customer['LastName'], @credit_card.last_name
    assert_equal customer['Email'], email
  end

  def test_successful_authorize_with_shipping_address
    @options[:shipping_address] = address

    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'Transaction Approved Successful', response.message

    # eWAY Rapid does not include the shipping address in the request response,
    # so we can only test that the transaction is successful.
  end

  def test_successful_authorize_and_capture
    authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize
    assert_equal 'Transaction Approved Successful', authorize.message

    capture = @gateway.capture(nil, authorize.authorization)
    assert_success capture
  end

  def test_failed_authorize
    response = @gateway.authorize(@failed_amount, @credit_card, @options)
    assert_failure response
    assert_equal '', response.message
  end

  def test_failed_capture
    response = @gateway.capture(@amount, 'bogus')
    assert_failure response
    assert_equal 'Invalid Auth Transaction ID for Capture/Void', response.message
  end

  def test_successful_void
    authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize

    void = @gateway.void(authorize.authorization)
    assert_success void
  end

  def test_failed_void
    response = @gateway.void('bogus')
    assert_failure response
    assert_equal 'Failed', response.message
  end

  def test_successful_refund
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction Approved Successful', response.message

    response = @gateway.refund(@amount, response.authorization, @options)
    assert_success response
    assert_equal 'Transaction Approved Successful', response.message
  end

  def test_failed_refund
    response = @gateway.refund(@amount, 'fakeid', @options)
    assert_failure response
    assert_equal 'Invalid DirectRefundRequest, Transaction ID', response.message
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'Transaction Approved Successful', response.message

    customer = response.params['Customer']

    assert_address_match(customer, @options[:billing_address])
  end

  def test_successful_store_with_shipping_address
    @options[:shipping_address] = address

    response = @gateway.store(@credit_card, @options)

    assert_success response
    assert_equal 'Transaction Approved Successful', response.message

    # eWAY Rapid does not include the shipping address in the request response,
    # so we can only test that the transaction is successful.
  end

  def test_failed_store
    @options[:billing_address][:country] = nil
    response = @gateway.store(@credit_card, @options)
    assert_failure response
    assert_equal 'V6044', response.params['Errors']
    assert_equal 'Customer CountryCode Required', response.message
  end

  def test_successful_update_with_billing_address
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'Transaction Approved Successful', response.message
    response = @gateway.update(response.authorization, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction Approved Successful', response.message

    customer = response.params['Customer']
    assert_address_match(customer, @options[:billing_address])
  end

  def test_successful_update_with_address
    @options[:billing_address] = nil
    @options[:address] = address

    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'Transaction Approved Successful', response.message

    response = @gateway.update(response.authorization, @credit_card, @options)

    assert_success response
    assert_equal 'Transaction Approved Successful', response.message

    customer = response.params['Customer']

    assert_address_match(customer, @options[:address])
  end

  def test_successful_update_without_address
    email = 'test@example.com'
    @options[:email] = email

    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'Transaction Approved Successful', response.message

    @options[:billing_address] = nil

    response = @gateway.update(response.authorization, @credit_card, @options)

    assert_success response
    assert_equal 'Transaction Approved Successful', response.message

    customer = response.params['Customer']

    assert_equal customer['FirstName'], @credit_card.first_name
    assert_equal customer['LastName'], @credit_card.last_name
    assert_equal customer['Email'], email
  end

  def test_successful_update_with_shipping_address
    @options[:shipping_address] = address

    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'Transaction Approved Successful', response.message

    response = @gateway.update(response.authorization, @credit_card, @options)

    assert_success response
    assert_equal 'Transaction Approved Successful', response.message

    # eWAY Rapid does not include the shipping address in the request response,
    # so we can only test that the transaction is successful.
  end

  def test_successful_store_purchase
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'Transaction Approved Successful', response.message

    response = @gateway.purchase(@amount, response.authorization, transaction_type: 'MOTO')
    assert_success response
    assert_equal 'Transaction Approved Successful', response.message
  end

  def test_invalid_login
    gateway = EwayRapidGateway.new(
      login: 'bogus',
      password: 'bogus'
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Unauthorized', response.message
  end

  def test_transcript_scrubbing
    credit_card_success = credit_card('4444333322221111', verification_value: 976225)

    transcript = capture_transcript(@gateway) do
      @gateway.purchase(100, credit_card_success, {})
    end

    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(credit_card_success.number, clean_transcript)
    assert_scrubbed(credit_card_success.verification_value.to_s, clean_transcript)
  end

  private

  def assert_address_match(customer, address)
    assert_equal customer['FirstName'],   address[:name].split[0]
    assert_equal customer['LastName'],    address[:name].split[1]
    assert_equal customer['CompanyName'], address[:company]
    assert_equal customer['Street1'],     address[:address1]
    assert_equal customer['Street2'],     address[:address2]
    assert_equal customer['City'],        address[:city]
    assert_equal customer['State'],       address[:state]
    assert_equal customer['PostalCode'],  address[:zip]
    assert_equal customer['Country'],     address[:country].to_s.downcase
    assert_equal customer['Phone'],       address[:phone]
    assert_equal customer['Fax'],         address[:fax]
  end
end
