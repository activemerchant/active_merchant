require 'test_helper'
require 'pp'

class AuthorizeNetCimTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = AuthorizeNetCimGateway.new(fixtures(:authorize_net))
    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @payment = {
      :credit_card => @credit_card
    }
    @profile = {
      :merchant_customer_id => 'Up to 20 chars', # Optional
      :description => 'Up to 255 Characters', # Optional
      :email => 'Up to 255 Characters', # Optional
      :payment_profiles => { # Optional
        :customer_type => 'individual', # Optional
        :bill_to => address,
        :payment => @payment
      },
      :ship_to_list => {
        :first_name => 'John',
        :last_name => 'Doe',
        :company => 'Widgets, Inc',
        :address1 => '1234 Fake Street',
        :city => 'Anytown',
        :state => 'MD',
        :zip => '12345',
        :country => 'USA',
        :phone_number => '(123)123-1234', # Optional - Up to 25 digits (no letters)
        :fax_number => '(123)123-1234' # Optional - Up to 25 digits (no letters)
      }
    }
    @options = {
      :ref_id => '1234', # Optional
      :profile => @profile
    }
  end

  def teardown
    if @customer_profile_id
      assert response = @gateway.delete_customer_profile(:customer_profile_id => @customer_profile_id)
      assert_success response
      @customer_profile_id = nil
    end
  end

  def test_successful_profile_create_get_update_and_delete
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert_success response
    assert response.test?

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert response.test?
    assert_success response
    assert_equal @customer_profile_id, response.authorization
    assert_equal 'Successful.', response.message
    assert response.params['profile']['payment_profiles']['customer_payment_profile_id'] =~ /\d+/, 'The customer_payment_profile_id should be a number'
    assert_equal "XXXX#{@credit_card.last_digits}", response.params['profile']['payment_profiles']['payment']['credit_card']['card_number'], "The card number should contain the last 4 digits of the card we passed in #{@credit_card.last_digits}"
    assert_equal @profile[:merchant_customer_id], response.params['profile']['merchant_customer_id']
    assert_equal @profile[:description], response.params['profile']['description']
    assert_equal @profile[:email], response.params['profile']['email']
    assert_equal @profile[:payment_profiles][:customer_type], response.params['profile']['payment_profiles']['customer_type']
    assert_equal @profile[:ship_to_list][:phone_number], response.params['profile']['ship_to_list']['phone_number']
    assert_equal @profile[:ship_to_list][:company], response.params['profile']['ship_to_list']['company']

    assert response = @gateway.update_customer_profile(:profile => {:customer_profile_id => @customer_profile_id, :email => 'new email address'})
    assert response.test?
    assert_success response
    assert_nil response.authorization
    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert_nil response.params['profile']['merchant_customer_id']
    assert_nil response.params['profile']['description']
    assert_equal 'new email address', response.params['profile']['email']
  end

  # NOTE - prior_auth_capture should be used to complete an auth_only request
  # (not capture_only as that will leak the authorization), so don't use this
  # test as a template.
  def test_successful_create_customer_profile_transaction_auth_only_and_then_capture_only_requests
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    @customer_payment_profile_id = response.params['profile']['payment_profiles']['customer_payment_profile_id']

    assert response = @gateway.create_customer_profile_transaction(
      :transaction => {
        :customer_profile_id => @customer_profile_id,
        :customer_payment_profile_id => @customer_payment_profile_id,
        :type => :auth_only,
        :amount => @amount
      }
    )

    assert response.test?
    assert_success response
    assert_equal response.authorization, response.params['direct_response']['transaction_id']
    assert_match %r{(?:(TESTMODE) )?This transaction has been approved.}, response.params['direct_response']['message']
    assert response.params['direct_response']['approval_code'] =~ /\w{6}/
    assert_equal "auth_only", response.params['direct_response']['transaction_type']
    assert_equal "100.00", response.params['direct_response']['amount']
    assert_match %r{\d+}, response.params['direct_response']['transaction_id']

    approval_code = response.params['direct_response']['approval_code']

    # Capture the previously authorized funds

    assert response = @gateway.create_customer_profile_transaction(
      :transaction => {
        :customer_profile_id => @customer_profile_id,
        :customer_payment_profile_id => @customer_payment_profile_id,
        :type => :capture_only,
        :amount => @amount,
        :approval_code => approval_code
      }
    )

    assert response.test?
    assert_success response
    assert_equal response.authorization, response.params['direct_response']['transaction_id']
    assert_match %r{(?:(TESTMODE) )?This transaction has been approved.}, response.params['direct_response']['message']
    assert_equal approval_code, response.params['direct_response']['approval_code']
    assert_equal "capture_only", response.params['direct_response']['transaction_type']
    assert_equal "100.00", response.params['direct_response']['amount']
  end

  def test_successful_create_customer_profile_transaction_auth_capture_request
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    @customer_payment_profile_id = response.params['profile']['payment_profiles']['customer_payment_profile_id']

    assert response = @gateway.create_customer_profile_transaction(
      :transaction => {
        :customer_profile_id => @customer_profile_id,
        :customer_payment_profile_id => @customer_payment_profile_id,
        :type => :auth_capture,
        :order => {
          :invoice_number => '1234',
          :description => 'Test Order Description',
          :purchase_order_number => '4321'
        },
        :recurring_billing => true,
        :card_code => '900', # authorize.net says this is a matching CVV
        :amount => @amount
      }
    )

    assert response.test?
    assert_success response
    assert_equal response.authorization, response.params['direct_response']['transaction_id']
    assert_match %r{(?:(TESTMODE) )?This transaction has been approved.}, response.params['direct_response']['message']
    assert response.params['direct_response']['approval_code'] =~ /\w{6}/
    assert_equal "auth_capture", response.params['direct_response']['transaction_type']
    assert_equal "100.00", response.params['direct_response']['amount']
    assert_equal response.params['direct_response']['invoice_number'], '1234'
    assert_equal response.params['direct_response']['order_description'], 'Test Order Description'
    assert_equal response.params['direct_response']['purchase_order_number'], '4321'
  end

  def test_successful_create_customer_payment_profile_request
    payment_profile = @options[:profile].delete(:payment_profiles)
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert_nil response.params['profile']['payment_profiles']

    assert response = @gateway.create_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :payment_profile => payment_profile
    )

    assert response.test?
    assert_success response
    assert_nil response.authorization
    assert customer_payment_profile_id = response.params['customer_payment_profile_id']
    assert customer_payment_profile_id =~ /\d+/, "The customerPaymentProfileId should be numeric. It was #{customer_payment_profile_id}"
  end

  def test_successful_create_customer_payment_profile_request_with_bank_account
    payment_profile = @options[:profile].delete(:payment_profiles)
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert_nil response.params['profile']['payment_profiles']

    assert response = @gateway.create_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :payment_profile => {
        :customer_type => 'individual', # Optional
        :bill_to => @address,
        :payment => {
          :bank_account => {
            :account_type => :checking,
            :name_on_account => 'John Doe',
            :echeck_type => :ccd,
            :bank_name => 'Bank of America',
            :routing_number => '123456789',
            :account_number => '12345'
          }
        },
        :drivers_license => {
          :state => 'MD',
          :number => '12345',
          :date_of_birth => '1981-3-31'
        },
        :tax_id => '123456789'
      }
    )

    assert response.test?
    assert_success response
    assert_nil response.authorization
    assert customer_payment_profile_id = response.params['customer_payment_profile_id']
    assert customer_payment_profile_id =~ /\d+/, "The customerPaymentProfileId should be numeric. It was #{customer_payment_profile_id}"
  end

  def test_successful_create_customer_shipping_address_request
    shipping_address = @options[:profile].delete(:ship_to_list)
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert_nil response.params['profile']['ship_to_list']

    assert response = @gateway.create_customer_shipping_address(
      :customer_profile_id => @customer_profile_id,
      :address => shipping_address
    )

    assert response.test?
    assert_success response
    assert_nil response.authorization
    assert customer_address_id = response.params['customer_address_id']
    assert customer_address_id =~ /\d+/, "The customerAddressId should be numeric. It was #{customer_address_id}"
  end

  def test_successful_get_customer_profile_with_multiple_payment_profiles
    second_payment_profile = {
      :customer_type => 'individual',
      :bill_to => @address,
      :payment => {
        :credit_card => credit_card('1234123412341234')
      }
    }
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)

    assert response = @gateway.create_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :payment_profile => second_payment_profile
    )

    assert response.test?
    assert_success response
    assert_nil response.authorization
    assert customer_payment_profile_id = response.params['customer_payment_profile_id']
    assert customer_payment_profile_id =~ /\d+/, "The customerPaymentProfileId should be numeric. It was #{customer_payment_profile_id}"

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert_equal 2, response.params['profile']['payment_profiles'].size
    assert_equal 'XXXX4242', response.params['profile']['payment_profiles'][0]['payment']['credit_card']['card_number']
    assert_equal 'XXXX1234', response.params['profile']['payment_profiles'][1]['payment']['credit_card']['card_number']
  end

  def test_successful_delete_customer_payment_profile_request
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert customer_payment_profile_id = response.params['profile']['payment_profiles']['customer_payment_profile_id']

    assert response = @gateway.delete_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :customer_payment_profile_id => customer_payment_profile_id
    )

    assert response.test?
    assert_success response
    assert_nil response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert_nil response.params['profile']['payment_profiles']
  end

  def test_successful_delete_customer_shipping_address_request
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert customer_address_id = response.params['profile']['ship_to_list']['customer_address_id']

    assert response = @gateway.delete_customer_shipping_address(
      :customer_profile_id => @customer_profile_id,
      :customer_address_id => customer_address_id
    )

    assert response.test?
    assert_success response
    assert_nil response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert_nil response.params['profile']['ship_to_list']
  end

  def test_successful_get_customer_payment_profile_request
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert customer_payment_profile_id = response.params['profile']['payment_profiles']['customer_payment_profile_id']

    assert response = @gateway.get_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :customer_payment_profile_id => customer_payment_profile_id
    )

    assert response.test?
    assert_success response
    assert_nil response.authorization
    assert response.params['payment_profile']['customer_payment_profile_id'] =~ /\d+/, 'The customer_payment_profile_id should be a number'
    assert_equal "XXXX#{@credit_card.last_digits}", response.params['payment_profile']['payment']['credit_card']['card_number'], "The card number should contain the last 4 digits of the card we passed in #{@credit_card.last_digits}"
    assert_equal @profile[:payment_profiles][:customer_type], response.params['payment_profile']['customer_type']
    assert_equal 'XXXX', response.params['payment_profile']['payment']['credit_card']['expiration_date']
  end

  def test_successful_get_customer_payment_profile_unmasked_request
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert customer_payment_profile_id = response.params['profile']['payment_profiles']['customer_payment_profile_id']

    assert response = @gateway.get_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :customer_payment_profile_id => customer_payment_profile_id,
      :unmask_expiration_date => true
    )

    assert response.test?
    assert_success response
    assert_nil response.authorization
    assert response.params['payment_profile']['customer_payment_profile_id'] =~ /\d+/, 'The customer_payment_profile_id should be a number'
    assert_equal "XXXX#{@credit_card.last_digits}", response.params['payment_profile']['payment']['credit_card']['card_number'], "The card number should contain the last 4 digits of the card we passed in #{@credit_card.last_digits}"
    assert_equal @profile[:payment_profiles][:customer_type], response.params['payment_profile']['customer_type']
    assert_equal formatted_expiration_date(@credit_card), response.params['payment_profile']['payment']['credit_card']['expiration_date']
  end

  def test_successful_get_customer_shipping_address_request
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert customer_address_id = response.params['profile']['ship_to_list']['customer_address_id']

    assert response = @gateway.get_customer_shipping_address(
      :customer_profile_id => @customer_profile_id,
      :customer_address_id => customer_address_id
    )

    assert response.test?
    assert_success response
    assert_nil response.authorization
    assert response.params['address']['customer_address_id'] =~ /\d+/, 'The customer_address_id should be a number'
    assert_equal @profile[:ship_to_list][:city], response.params['address']['city']
  end

  def test_successful_update_customer_payment_profile_request
    # Create a new Customer Profile with Payment Profile
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    # Get the customerPaymentProfileId
    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert customer_payment_profile_id = response.params['profile']['payment_profiles']['customer_payment_profile_id']

    # Get the customerPaymentProfile
    assert response = @gateway.get_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :customer_payment_profile_id => customer_payment_profile_id
    )

    # The value before updating
    assert_equal "XXXX4242", response.params['payment_profile']['payment']['credit_card']['card_number'], "The card number should contain the last 4 digits of the card we passed in 4242"

    # Update the payment profile
    assert response = @gateway.update_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :payment_profile => {
        :customer_payment_profile_id => customer_payment_profile_id,
        :payment => {
          :credit_card => credit_card('1234123412341234')
        }
      }
    )
    assert response.test?
    assert_success response
    assert_nil response.authorization

    # Get the updated payment profile
    assert response = @gateway.get_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :customer_payment_profile_id => customer_payment_profile_id
    )

    # Show that the payment profile was updated
    assert_equal "XXXX1234", response.params['payment_profile']['payment']['credit_card']['card_number'], "The card number should contain the last 4 digits of the card we passed in: 1234"
    # Show that fields that were left out of the update were cleared
    assert_nil response.params['payment_profile']['customer_type']

    new_billing_address = response.params['payment_profile']['bill_to']
    new_billing_address.update(:first_name => 'Frank', :last_name => 'Brown')
    masked_credit_card = ActiveMerchant::Billing::CreditCard.new(:number => response.params['payment_profile']['payment']['credit_card']['card_number'])

    # Update only the billing address with a masked card and expiration date
    assert response = @gateway.update_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :payment_profile => {
        :customer_payment_profile_id => customer_payment_profile_id,
        :bill_to => new_billing_address,
        :payment => {
          :credit_card => masked_credit_card
        }
      }
    )

    # Get the updated payment profile
    assert response = @gateway.get_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :customer_payment_profile_id => customer_payment_profile_id
    )

    # Show that the billing address on the payment profile was updated
    assert_equal "Frank", response.params['payment_profile']['bill_to']['first_name'], "The billing address should contain the first name we passed in: Frank"
  end

  def test_successful_update_customer_payment_profile_request_with_credit_card_last_four
    # Create a new Customer Profile with Payment Profile
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    # Get the customerPaymentProfileId
    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert customer_payment_profile_id = response.params['profile']['payment_profiles']['customer_payment_profile_id']

    # Get the customerPaymentProfile
    assert response = @gateway.get_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :customer_payment_profile_id => customer_payment_profile_id
    )

    # Card number last 4 digits is 4242
    assert_equal "XXXX4242", response.params['payment_profile']['payment']['credit_card']['card_number'], "The card number should contain the last 4 digits of the card we passed in 4242"

    new_billing_address = response.params['payment_profile']['bill_to']
    new_billing_address.update(:first_name => 'Frank', :last_name => 'Brown')

    # Initialize credit card with only last 4 digits as the number
    last_four_credit_card = ActiveMerchant::Billing::CreditCard.new(:number => "4242") #Credit card with only last four digits

    # Update only the billing address with a card with the last 4 digits and expiration date
    assert response = @gateway.update_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :payment_profile => {
        :customer_payment_profile_id => customer_payment_profile_id,
        :bill_to => new_billing_address,
        :payment => {
          :credit_card => last_four_credit_card
        }
      }
    )

    # Get the updated payment profile
    assert response = @gateway.get_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :customer_payment_profile_id => customer_payment_profile_id
    )

    # Show that the billing address on the payment profile was updated
    assert_equal "Frank", response.params['payment_profile']['bill_to']['first_name'], "The billing address should contain the first name we passed in: Frank"
  end

  def test_successful_update_customer_shipping_address_request
    # Create a new Customer Profile with Shipping Address
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    # Get the customerAddressId
    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert customer_address_id = response.params['profile']['ship_to_list']['customer_address_id']

    # Get the customerShippingAddress
    assert response = @gateway.get_customer_shipping_address(
      :customer_profile_id => @customer_profile_id,
      :customer_address_id => customer_address_id
    )

    assert address = response.params['address']
    # The value before updating
    assert_equal "1234 Fake Street", address['address']

    # Update the address and remove the phone_number
    new_address = address.symbolize_keys.merge!(
      :address => '5678 Fake Street'
    )
    new_address.delete(:phone_number)

    #Update the shipping address
    assert response = @gateway.update_customer_shipping_address(
      :customer_profile_id => @customer_profile_id,
      :address => new_address
    )
    assert response.test?
    assert_success response
    assert_nil response.authorization

    # Get the updated shipping address
    assert response = @gateway.get_customer_shipping_address(
      :customer_profile_id => @customer_profile_id,
      :customer_address_id => customer_address_id
    )

    # Show that the shipping address was updated
    assert_equal "5678 Fake Street", response.params['address']['address']
    # Show that fields that were left out of the update were cleared
    assert_nil response.params['address']['phone_number']
  end

  def test_successful_validate_customer_payment_profile_request_live
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert @customer_payment_profile_id = response.params['profile']['payment_profiles']['customer_payment_profile_id']
    assert @customer_address_id = response.params['profile']['ship_to_list']['customer_address_id']

    assert response = @gateway.validate_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :customer_payment_profile_id => @customer_payment_profile_id,
      :customer_address_id => @customer_address_id,
      :validation_mode => :live
    )

    assert response.test?
    assert_success response
    assert_equal response.authorization, response.params['direct_response']['transaction_id']
    assert_match %r{(?:(TESTMODE) )?This transaction has been approved.}, response.params['direct_response']['message']
  end

  def test_validate_customer_payment_profile_request_live_requires_billing_address
    @options[:profile][:payment_profiles].delete(:bill_to)
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert @customer_payment_profile_id = response.params['profile']['payment_profiles']['customer_payment_profile_id']
    assert @customer_address_id = response.params['profile']['ship_to_list']['customer_address_id']

    assert response = @gateway.validate_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :customer_payment_profile_id => @customer_payment_profile_id,
      :customer_address_id => @customer_address_id,
      :validation_mode => :live
    )

    assert response.test?
    assert_failure response
    assert_equal "There is one or more missing or invalid required fields.", response.message
  end

  def test_validate_customer_payment_profile_request_old_does_not_require_billing_address
    @options[:profile][:payment_profiles].delete(:bill_to)
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert @customer_payment_profile_id = response.params['profile']['payment_profiles']['customer_payment_profile_id']
    assert @customer_address_id = response.params['profile']['ship_to_list']['customer_address_id']

    assert response = @gateway.validate_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :customer_payment_profile_id => @customer_payment_profile_id,
      :customer_address_id => @customer_address_id,
      :validation_mode => :old
    )

    assert response.test?
    assert_success response
    assert_equal "Successful.", response.message
  end

  def test_should_create_duplicate_customer_profile_transactions_with_duplicate_window_alteration
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert @customer_payment_profile_id = response.params['profile']['payment_profiles']['customer_payment_profile_id']

    key = (Time.now.to_f * 1000000).to_i.to_s

    customer_profile_transaction = {
      :transaction => {
        :customer_profile_id => @customer_profile_id,
        :customer_payment_profile_id => @customer_payment_profile_id,
        :type => :auth_capture,
        :order => {
          :invoice_number => key.to_s,
          :description => "Test Order Description #{key.to_s}",
          :purchase_order_number => key.to_s
        },
        :amount => @amount
      },
      :extra_options => { "x_duplicate_window" => 1 }
    }

    assert response = @gateway.create_customer_profile_transaction(customer_profile_transaction)
    assert_success response
    assert_equal "Successful.", response.message

    sleep(5)

    assert response = @gateway.create_customer_profile_transaction(customer_profile_transaction)
    assert_success response
    assert_equal "Successful.", response.message
    assert_nil response.error_code
  end

  def test_should_not_create_duplicate_customer_profile_transactions_without_duplicate_window_alteration
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert @customer_payment_profile_id = response.params['profile']['payment_profiles']['customer_payment_profile_id']

    key = (Time.now.to_f * 1000000).to_i.to_s

    customer_profile_transaction = {
      :transaction => {
        :customer_profile_id => @customer_profile_id,
        :customer_payment_profile_id => @customer_payment_profile_id,
        :type => :auth_capture,
        :order => {
          :invoice_number => key.to_s,
          :description => "Test Order Description #{key.to_s}",
          :purchase_order_number => key.to_s
        },
        :amount => @amount
      }
    }

    assert response = @gateway.create_customer_profile_transaction(customer_profile_transaction)
    assert_success response
    assert_equal "Successful.", response.message

    sleep(5)

    assert response = @gateway.create_customer_profile_transaction(customer_profile_transaction)
    assert_failure response
    assert_equal "A duplicate transaction has been submitted.", response.message
    assert_equal "E00027", response.error_code
  end

  def test_should_create_customer_profile_transaction_auth_capture_and_then_void_request
    response = get_and_validate_auth_capture_response

    assert response = @gateway.create_customer_profile_transaction_for_void(
      :transaction => {
        :type => :void,
        :trans_id => response.params['direct_response']['transaction_id']
      }
    )
    assert_instance_of Response, response
    assert_success response
    assert_equal response.authorization, response.params['direct_response']['transaction_id']
    assert_equal 'This transaction has been approved.', response.params['direct_response']['message']
  end

  def test_should_create_customer_profile_transaction_auth_capture_and_then_refund_using_profile_ids_request
    response = get_and_validate_auth_capture_response

    assert response = @gateway.create_customer_profile_transaction(
      :transaction => {
        :type => :refund,
        :amount => 1,
        :customer_profile_id => @customer_profile_id,
        :customer_payment_profile_id => @customer_payment_profile_id,
        :trans_id => response.params['direct_response']['transaction_id']
      }
    )
    assert_instance_of Response, response
    # You can't test refunds in TEST MODE.  If you authorize or capture
    # a transaction, and the transaction is not yet settled by the payment
    # gateway, you cannot issue a refund. You get an error message
    # saying "The referenced transaction does not meet the criteria for issuing a credit.".
    assert_failure response
    assert_equal 'The referenced transaction does not meet the criteria for issuing a credit.', response.params['direct_response']['message']
  end

  def test_should_create_customer_profile_transaction_auth_capture_and_then_refund_using_profile_ids_request_with_empty_order
    response = get_and_validate_auth_capture_response

    assert response = @gateway.create_customer_profile_transaction(
      :transaction => {
        :type => :refund,
        :amount => 1,
        :customer_profile_id => @customer_profile_id,
        :customer_payment_profile_id => @customer_payment_profile_id,
        :trans_id => response.params['direct_response']['transaction_id'],
        :order => {}
      }
    )
    assert_instance_of Response, response
    # You can't test refunds in TEST MODE.  If you authorize or capture
    # a transaction, and the transaction is not yet settled by the payment
    # gateway, you cannot issue a refund. You get an error message
    # saying "The referenced transaction does not meet the criteria for issuing a credit.".
    assert_failure response
    assert_equal 'The referenced transaction does not meet the criteria for issuing a credit.', response.message
  end

  def test_should_create_customer_profile_transaction_auth_capture_and_then_refund_using_masked_credit_card_request
    response = get_and_validate_auth_capture_response

    assert response = @gateway.create_customer_profile_transaction(
      :transaction => {
        :type => :refund,
        :amount => 1,
        :credit_card_number_masked => 'XXXX4242',
        :trans_id => response.params['direct_response']['transaction_id']
      }
    )
    assert_instance_of Response, response
    # You can't test refunds in TEST MODE.  If you authorize or capture
    # a transaction, and the transaction is not yet settled by the payment
    # gateway, you cannot issue a refund. You get an error message
    # saying "The referenced transaction does not meet the criteria for issuing a credit.".
    assert_failure response
    assert_equal 'The referenced transaction does not meet the criteria for issuing a credit.', response.params['direct_response']['message']
  end

  def test_should_create_customer_profile_transaction_auth_only_and_then_prior_auth_capture_request
    response = get_and_validate_auth_only_response

    assert response = @gateway.create_customer_profile_transaction(
      :transaction => {
        :type => :prior_auth_capture,
        :trans_id => response.params['direct_response']['transaction_id'],
        :amount => response.params['direct_response']['amount']
      }
    )
    assert_instance_of Response, response
    assert_success response
    assert_equal response.authorization, response.params['direct_response']['transaction_id']
    assert_equal 'This transaction has been approved.', response.params['direct_response']['message']
    return response
  end

  def get_and_validate_customer_payment_profile_request_with_bank_account_response
    payment_profile = @options[:profile].delete(:payment_profiles)
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert_nil response.params['profile']['payment_profiles']

    assert response = @gateway.create_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :payment_profile => {
        :customer_type => 'individual', # Optional
        :bill_to => @address,
        :payment => {
          :bank_account => {
            :account_type => :checking,
            :name_on_account => 'John Doe',
            :echeck_type => :ccd,
            :bank_name => 'Bank of America',
            :routing_number => '123456789',
            :account_number => '12345678'
          }
        },
        :drivers_license => {
          :state => 'MD',
          :number => '12345',
          :date_of_birth => '1981-3-31'
        },
        :tax_id => '123456789'
      }
    )

    assert response.test?
    assert_success response
    assert_nil response.authorization
    assert @customer_payment_profile_id = response.params['customer_payment_profile_id']
    assert @customer_payment_profile_id =~ /\d+/, "The customerPaymentProfileId should be numeric. It was #{@customer_payment_profile_id}"
    return response
  end

  def get_and_validate_auth_capture_response
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    @customer_payment_profile_id = response.params['profile']['payment_profiles']['customer_payment_profile_id']

    key = (Time.now.to_f * 1000000).to_i.to_s

    assert response = @gateway.create_customer_profile_transaction(
      :transaction => {
        :customer_profile_id => @customer_profile_id,
        :customer_payment_profile_id => @customer_payment_profile_id,
        :type => :auth_capture,
        :order => {
          :invoice_number => key.to_s,
          :description => "Test Order Description #{key.to_s}",
          :purchase_order_number => key.to_s
        },
        :amount => @amount
      }
    )

    assert response.test?
    assert_success response
    assert_equal response.authorization, response.params['direct_response']['transaction_id']
    assert_match %r{(?:(TESTMODE) )?This transaction has been approved.}, response.params['direct_response']['message']
    assert response.params['direct_response']['approval_code'] =~ /\w{6}/
    assert_equal "auth_capture", response.params['direct_response']['transaction_type']
    assert_equal "100.00", response.params['direct_response']['amount']
    assert_equal response.params['direct_response']['invoice_number'], key.to_s
    assert_equal response.params['direct_response']['order_description'], "Test Order Description #{key.to_s}"
    assert_equal response.params['direct_response']['purchase_order_number'], key.to_s
    return response
  end

  def get_and_validate_auth_only_response
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    key = (Time.now.to_f * 1000000).to_i.to_s

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    @customer_payment_profile_id = response.params['profile']['payment_profiles']['customer_payment_profile_id']
    assert response = @gateway.create_customer_profile_transaction(
     :transaction => {
       :customer_profile_id => @customer_profile_id,
       :customer_payment_profile_id => @customer_payment_profile_id,
       :type => :auth_only,
       :order => {
          :invoice_number => key.to_s,
          :description => "Test Order Description #{key.to_s}",
          :purchase_order_number => key.to_s
        },
       :amount => @amount
     }
    )

    assert response.test?
    assert_success response
    assert_equal response.authorization, response.params['direct_response']['transaction_id']
    assert response.params['direct_response']['approval_code'] =~ /\w{6}/
    assert_equal "auth_only", response.params['direct_response']['transaction_type']
    assert_equal "100.00", response.params['direct_response']['amount']

    return response
  end


end
