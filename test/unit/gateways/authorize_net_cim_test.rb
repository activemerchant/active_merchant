require 'test_helper'

class AuthorizeNetCimTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = AuthorizeNetCimGateway.new(
      :login => 'X',
      :password => 'Y'
    )
    @amount = 100
    @credit_card = credit_card
    @address = address
    @customer_profile_id = '3187'
    @customer_payment_profile_id = '7813'
    @customer_address_id = '4321'
    @payment = {
      :credit_card => @credit_card
    }
    @profile = {
      :merchant_customer_id => 'Up to 20 chars', # Optional
      :description => 'Up to 255 Characters', # Optional
      :email => 'Up to 255 Characters', # Optional
      :payment_profiles => { # Optional
        :customer_type => 'individual or business', # Optional
        :bill_to => @address,
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

  def test_expdate_formatting
    assert_equal '2009-09', @gateway.send(:expdate, credit_card('4111111111111111', :month => "9", :year => "2009"))
    assert_equal '2013-11', @gateway.send(:expdate, credit_card('4111111111111111', :month => "11", :year => "2013"))
    assert_equal 'XXXX', @gateway.send(:expdate, credit_card('XXXX1234', :month => nil, :year => nil))
  end

  def test_should_create_customer_profile_request
    @gateway.expects(:ssl_post).returns(successful_create_customer_profile_response)

    assert response = @gateway.create_customer_profile(@options)
    assert_instance_of Response, response
    assert_success response
    assert_equal @customer_profile_id, response.authorization
    assert_equal "Successful.", response.message
  end

  def test_should_create_customer_payment_profile_request
    @gateway.expects(:ssl_post).returns(successful_create_customer_payment_profile_response)

    assert response = @gateway.create_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :payment_profile => {
        :customer_type => 'individual',
        :bill_to => @address,
        :payment => @payment
      },
      :validation_mode => :test
    )
    assert_instance_of Response, response
    assert_success response
    assert_equal @customer_payment_profile_id, response.params['customer_payment_profile_id']
    assert_equal "This output is only present if the ValidationMode input parameter is passed with a value of testMode or liveMode", response.params['validation_direct_response']
  end

  def test_should_create_customer_shipping_address_request
    @gateway.expects(:ssl_post).returns(successful_create_customer_shipping_address_response)

    assert response = @gateway.create_customer_shipping_address(
      :customer_profile_id => @customer_profile_id,
      :address => {
        :first_name => 'John',
        :last_name => 'Doe',
        :company => 'Widgets, Inc',
        :address1 => '1234 Fake Street',
        :city => 'Anytown',
        :state => 'MD',
        :country => 'USA',
        :phone_number => '(123)123-1234',
        :fax_number => '(123)123-1234'
      }
    )
    assert_instance_of Response, response
    assert_success response
    assert_nil response.authorization
    assert_equal 'customerAddressId', response.params['customer_address_id']
  end

  def test_should_create_customer_profile_transaction_auth_only_and_then_prior_auth_capture_requests
    @gateway.expects(:ssl_post).returns(successful_create_customer_profile_transaction_response(:auth_only))

    assert response = @gateway.create_customer_profile_transaction(
      :transaction => {
        :customer_profile_id => @customer_profile_id,
        :customer_payment_profile_id => @customer_payment_profile_id,
        :type => :auth_only,
        :amount => @amount
      }
    )
    assert_instance_of Response, response
    assert_success response
    assert_equal response.authorization, response.params['direct_response']['transaction_id']
    assert_equal 'This transaction has been approved.', response.params['direct_response']['message']
    assert_equal 'auth_only', response.params['direct_response']['transaction_type']
    assert_equal 'Gw4NGI', response.params['direct_response']['approval_code']
    assert_equal '508223659', trans_id = response.params['direct_response']['transaction_id']

    assert_equal '1', response.params['direct_response']['response_code']
    assert_equal '1', response.params['direct_response']['response_subcode']
    assert_equal '1', response.params['direct_response']['response_reason_code']
    assert_equal 'Y', response.params['direct_response']['avs_response']
    assert_equal '', response.params['direct_response']['invoice_number']
    assert_equal '', response.params['direct_response']['order_description']
    assert_equal '100.00', response.params['direct_response']['amount']
    assert_equal 'CC', response.params['direct_response']['method']
    assert_equal 'Up to 20 chars', response.params['direct_response']['customer_id']
    assert_equal '', response.params['direct_response']['first_name']
    assert_equal '', response.params['direct_response']['last_name']
    assert_equal '', response.params['direct_response']['company']
    assert_equal '', response.params['direct_response']['address']
    assert_equal '', response.params['direct_response']['city']
    assert_equal '', response.params['direct_response']['state']
    assert_equal '', response.params['direct_response']['zip_code']
    assert_equal '', response.params['direct_response']['country']
    assert_equal '', response.params['direct_response']['phone']
    assert_equal '', response.params['direct_response']['fax']
    assert_equal 'Up to 255 Characters', response.params['direct_response']['email_address']
    assert_equal '', response.params['direct_response']['ship_to_first_name']
    assert_equal '', response.params['direct_response']['ship_to_last_name']
    assert_equal '', response.params['direct_response']['ship_to_company']
    assert_equal '', response.params['direct_response']['ship_to_address']
    assert_equal '', response.params['direct_response']['ship_to_city']
    assert_equal '', response.params['direct_response']['ship_to_state']
    assert_equal '', response.params['direct_response']['ship_to_zip_code']
    assert_equal '', response.params['direct_response']['ship_to_country']
    assert_equal '', response.params['direct_response']['tax']
    assert_equal '', response.params['direct_response']['duty']
    assert_equal '', response.params['direct_response']['freight']
    assert_equal '', response.params['direct_response']['tax_exempt']
    assert_equal '', response.params['direct_response']['purchase_order_number']
    assert_equal '6E5334C13C78EA078173565FD67318E4', response.params['direct_response']['md5_hash']
    assert_equal '', response.params['direct_response']['card_code']
    assert_equal '2', response.params['direct_response']['cardholder_authentication_verification_response']

    assert_equal response.authorization, trans_id

    @gateway.expects(:ssl_post).returns(successful_create_customer_profile_transaction_response(:prior_auth_capture))

    assert response = @gateway.create_customer_profile_transaction(
      :transaction => {
        :customer_profile_id => @customer_profile_id,
        :customer_payment_profile_id => @customer_payment_profile_id,
        :type => :prior_auth_capture,
        :amount => @amount,
        :trans_id => trans_id
      }
    )
    assert_instance_of Response, response
    assert_success response
    assert_equal 'This transaction has been approved.', response.params['direct_response']['message']
  end

  # NOTE - do not pattern your production application after this (refer to
  # test_should_create_customer_profile_transaction_auth_only_and_then_prior_auth_capture_requests
  # instead as the correct way to do an auth then capture). capture_only
  # "is used to complete a previously authorized transaction that was not
  #  originally submitted through the payment gateway or that required voice
  #  authorization" and can in some situations perform an auth_capture leaking
  # the original authorization.
  def test_should_create_customer_profile_transaction_auth_only_and_then_capture_only_requests
    @gateway.expects(:ssl_post).returns(successful_create_customer_profile_transaction_response(:auth_only))

    assert response = @gateway.create_customer_profile_transaction(
      :transaction => {
        :customer_profile_id => @customer_profile_id,
        :customer_payment_profile_id => @customer_payment_profile_id,
        :type => :auth_only,
        :amount => @amount
      }
    )
    assert_instance_of Response, response
    assert_success response
    assert_equal response.authorization, response.params['direct_response']['transaction_id']
    assert_equal 'This transaction has been approved.', response.params['direct_response']['message']
    assert_equal 'auth_only', response.params['direct_response']['transaction_type']
    assert_equal 'Gw4NGI', approval_code = response.params['direct_response']['approval_code']

    @gateway.expects(:ssl_post).returns(successful_create_customer_profile_transaction_response(:capture_only))

    assert response = @gateway.create_customer_profile_transaction(
      :transaction => {
        :customer_profile_id => @customer_profile_id,
        :customer_payment_profile_id => @customer_payment_profile_id,
        :type => :capture_only,
        :amount => @amount,
        :approval_code => approval_code
      }
    )
    assert_instance_of Response, response
    assert_success response
    assert_equal 'This transaction has been approved.', response.params['direct_response']['message']
  end

  def test_should_create_customer_profile_transaction_auth_capture_request
    @gateway.expects(:ssl_post).returns(successful_create_customer_profile_transaction_response(:auth_capture))

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
        :amount => @amount,
        :card_code => '123'
      }
    )
    assert_instance_of Response, response
    assert_success response
    assert_equal 'M', response.params['direct_response']['card_code'] # M => match
    assert_equal response.authorization, response.params['direct_response']['transaction_id']
    assert_equal 'This transaction has been approved.', response.params['direct_response']['message']
  end

  def test_should_create_customer_profile_transaction_auth_capture_request_for_version_3_1
    @gateway.expects(:ssl_post).returns(successful_create_customer_profile_transaction_response(:auth_capture_version_3_1))

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
        :amount => @amount
      }
    )
    assert_instance_of Response, response
    assert_success response
    assert_equal response.authorization, response.params['direct_response']['transaction_id']
    assert_equal 'This transaction has been approved.', response.params['direct_response']['message']
    assert_equal 'auth_capture', response.params['direct_response']['transaction_type']
    assert_equal 'CSYM0K', response.params['direct_response']['approval_code']
    assert_equal '2163585627', response.params['direct_response']['transaction_id']

    assert_equal '1', response.params['direct_response']['response_code']
    assert_equal '1', response.params['direct_response']['response_subcode']
    assert_equal '1', response.params['direct_response']['response_reason_code']
    assert_equal 'Y', response.params['direct_response']['avs_response']
    assert_equal '1234', response.params['direct_response']['invoice_number']
    assert_equal 'Test Order Description', response.params['direct_response']['order_description']
    assert_equal '100.00', response.params['direct_response']['amount']
    assert_equal 'CC', response.params['direct_response']['method']
    assert_equal 'Up to 20 chars', response.params['direct_response']['customer_id']
    assert_equal '', response.params['direct_response']['first_name']
    assert_equal '', response.params['direct_response']['last_name']
    assert_equal 'Widgets Inc', response.params['direct_response']['company']
    assert_equal '1234 My Street', response.params['direct_response']['address']
    assert_equal 'Ottawa', response.params['direct_response']['city']
    assert_equal 'ON', response.params['direct_response']['state']
    assert_equal 'K1C2N6', response.params['direct_response']['zip_code']
    assert_equal 'CA', response.params['direct_response']['country']
    assert_equal '', response.params['direct_response']['phone']
    assert_equal '', response.params['direct_response']['fax']
    assert_equal 'Up to 255 Characters', response.params['direct_response']['email_address']
    assert_equal '', response.params['direct_response']['ship_to_first_name']
    assert_equal '', response.params['direct_response']['ship_to_last_name']
    assert_equal '', response.params['direct_response']['ship_to_company']
    assert_equal '', response.params['direct_response']['ship_to_address']
    assert_equal '', response.params['direct_response']['ship_to_city']
    assert_equal '', response.params['direct_response']['ship_to_state']
    assert_equal '', response.params['direct_response']['ship_to_zip_code']
    assert_equal '', response.params['direct_response']['ship_to_country']
    assert_equal '', response.params['direct_response']['tax']
    assert_equal '', response.params['direct_response']['duty']
    assert_equal '', response.params['direct_response']['freight']
    assert_equal '', response.params['direct_response']['tax_exempt']
    assert_equal '4321', response.params['direct_response']['purchase_order_number']
    assert_equal '02DFBD7934AD862AB16688D44F045D31', response.params['direct_response']['md5_hash']
    assert_equal '', response.params['direct_response']['card_code']
    assert_equal '2', response.params['direct_response']['cardholder_authentication_verification_response']
    assert_equal 'XXXX4242', response.params['direct_response']['account_number']
    assert_equal 'Visa', response.params['direct_response']['card_type']
    assert_equal '', response.params['direct_response']['split_tender_id']
    assert_equal '', response.params['direct_response']['requested_amount']
    assert_equal '', response.params['direct_response']['balance_on_card']
  end

  def test_should_delete_customer_profile_request
    @gateway.expects(:ssl_post).returns(successful_delete_customer_profile_response)

    assert response = @gateway.delete_customer_profile(:customer_profile_id => @customer_profile_id)
    assert_instance_of Response, response
    assert_success response
    assert_equal @customer_profile_id, response.authorization
  end

  def test_should_delete_customer_payment_profile_request
    @gateway.expects(:ssl_post).returns(successful_delete_customer_payment_profile_response)

    assert response = @gateway.delete_customer_payment_profile(:customer_profile_id => @customer_profile_id, :customer_payment_profile_id => @customer_payment_profile_id)
    assert_instance_of Response, response
    assert_success response
    assert_nil response.authorization
  end

  def test_should_delete_customer_shipping_address_request
    @gateway.expects(:ssl_post).returns(successful_delete_customer_shipping_address_response)

    assert response = @gateway.delete_customer_shipping_address(:customer_profile_id => @customer_profile_id, :customer_address_id => @customer_address_id)
    assert_instance_of Response, response
    assert_success response
    assert_nil response.authorization
  end

  def test_should_get_customer_profile_request
    @gateway.expects(:ssl_post).returns(successful_get_customer_profile_response)

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert_instance_of Response, response
    assert_success response
    assert_equal @customer_profile_id, response.authorization
  end

  def test_should_get_customer_profile_ids_request
    @gateway.expects(:ssl_post).returns(successful_get_customer_profile_ids_response)

    assert response = @gateway.get_customer_profile_ids
    assert_instance_of Response, response
    assert_success response
  end

  def test_should_get_customer_profile_request_with_multiple_payment_profiles
    @gateway.expects(:ssl_post).returns(successful_get_customer_profile_response_with_multiple_payment_profiles)

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert_instance_of Response, response
    assert_success response

    assert_equal @customer_profile_id, response.authorization
    assert_equal 2, response.params['profile']['payment_profiles'].size
  end

  def test_should_get_customer_payment_profile_request
    @gateway.expects(:ssl_post).returns(successful_get_customer_payment_profile_response)

    assert response = @gateway.get_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :customer_payment_profile_id => @customer_payment_profile_id,
      :unmask_expiration_date => true
    )
    assert_instance_of Response, response
    assert_success response
    assert_nil response.authorization
    assert_equal @customer_payment_profile_id, response.params['profile']['payment_profiles']['customer_payment_profile_id']
    assert_equal formatted_expiration_date(@credit_card), response.params['profile']['payment_profiles']['payment']['credit_card']['expiration_date']
  end

  def test_should_get_customer_shipping_address_request
    @gateway.expects(:ssl_post).returns(successful_get_customer_shipping_address_response)

    assert response = @gateway.get_customer_shipping_address(
      :customer_profile_id => @customer_profile_id,
      :customer_address_id => @customer_address_id
    )
    assert_instance_of Response, response
    assert_success response
    assert_nil response.authorization
  end

  def test_should_update_customer_profile_request
    @gateway.expects(:ssl_post).returns(successful_update_customer_profile_response)

    assert response = @gateway.update_customer_profile(
      :profile => {
        :customer_profile_id => @customer_profile_id,
        :email => 'new email address'
      }
    )
    assert_instance_of Response, response
    assert_success response
    assert_equal @customer_profile_id, response.authorization
  end

  def test_should_update_customer_payment_profile_request
    @gateway.expects(:ssl_post).returns(successful_update_customer_payment_profile_response)

    assert response = @gateway.update_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :payment_profile => {
        :customer_payment_profile_id => @customer_payment_profile_id,
        :customer_type => 'business'
      }
    )
    assert_instance_of Response, response
    assert_success response
    assert_nil response.authorization
  end

  def test_should_update_customer_payment_profile_request_with_last_four_digits
    last_four_credit_card = ActiveMerchant::Billing::CreditCard.new(:number => "4242") #Credit card with only last four digits

    response = stub_comms do
      @gateway.update_customer_payment_profile(
        :customer_profile_id => @customer_profile_id,
        :payment_profile => {
          :customer_payment_profile_id => @customer_payment_profile_id,
          :bill_to => address(:address1 => "345 Avenue B",
                              :address2 => "Apt 101"),
          :payment => {
            :credit_card => last_four_credit_card
          }
        }
      )
    end.check_request do |endpoint, data, headers|
      assert_match %r{<cardNumber>XXXX4242</cardNumber>}, data
    end.respond_with(successful_update_customer_payment_profile_response)

    assert_instance_of Response, response
    assert_success response
    assert_nil response.authorization
  end

  def test_should_update_customer_shipping_address_request
    @gateway.expects(:ssl_post).returns(successful_update_customer_shipping_address_response)

    assert response = @gateway.update_customer_shipping_address(
      :customer_profile_id => @customer_profile_id,
      :address => {
        :customer_address_id => @customer_address_id,
        :city => 'New City'
      }
    )
    assert_instance_of Response, response
    assert_success response
    assert_nil response.authorization
  end

  def test_should_validate_customer_payment_profile_request
    @gateway.expects(:ssl_post).returns(successful_validate_customer_payment_profile_response)

    assert response = @gateway.validate_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :customer_payment_profile_id => @customer_payment_profile_id,
      :customer_address_id => @customer_address_id,
      :validation_mode => :live
    )
    assert_instance_of Response, response
    assert_success response
    assert_equal response.authorization, response.params['direct_response']['transaction_id']
    assert_equal 'This transaction has been approved.', response.params['direct_response']['message']
  end

  def test_should_create_customer_profile_transaction_auth_capture_and_then_void_request
    response = get_and_validate_auth_capture_response

    @gateway.expects(:ssl_post).returns(successful_create_customer_profile_transaction_response(:void))
    assert response = @gateway.create_customer_profile_transaction(
      :transaction => {
        :type => :void,
        :trans_id => response.params['direct_response']['transaction_id']
      }
    )
    assert_instance_of Response, response
    assert_success response
    assert_equal response.authorization, response.params['direct_response']['transaction_id']
    assert_equal 'This transaction has been approved.', response.params['direct_response']['message']
    return response
  end

  def test_should_create_customer_profile_transaction_auth_capture_and_then_refund_using_profile_ids_request
    response = get_and_validate_auth_capture_response

    @gateway.expects(:ssl_post).returns(unsuccessful_create_customer_profile_transaction_response(:refund))
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
    # You can't test refunds in TEST MODE.  If you authorize or capture a transaction, and the transaction is not yet settled by the payment gateway, you cannot issue a refund. You get an error message saying "The referenced transaction does not meet the criteria for issuing a credit.".
    # more on this http://help.ablecommerce.com/mergedProjects/ablecommerce7/orders/payments/entering_payments.htm and
    # http://www.modernbill.com/support/manual/old/v4/adminhelp/english/Configuration/Payment_Settings/Gateway_API/AuthorizeNet/Module_Authorize.net.htm
    assert_failure response
    assert_equal 'The referenced transaction does not meet the criteria for issuing a credit.', response.params['direct_response']['message']
    assert_equal 'The transaction was unsuccessful.', response.message
    assert_equal "E00027", response.error_code
    return response
  end

  def test_should_create_customer_profile_transaction_auth_capture_and_then_refund_using_masked_credit_card_request
    response = get_and_validate_auth_capture_response

    @gateway.expects(:ssl_post).returns(unsuccessful_create_customer_profile_transaction_response(:refund))
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
    # You can't test refunds in TEST MODE.  If you authorize or capture a transaction, and the transaction is not yet settled by the payment gateway, you cannot issue a refund. You get an error message saying "The referenced transaction does not meet the criteria for issuing a credit.".
    # more on this http://help.ablecommerce.com/mergedProjects/ablecommerce7/orders/payments/entering_payments.htm and
    # http://www.modernbill.com/support/manual/old/v4/adminhelp/english/Configuration/Payment_Settings/Gateway_API/AuthorizeNet/Module_Authorize.net.htm
    assert_failure response
    assert_equal 'The referenced transaction does not meet the criteria for issuing a credit.', response.params['direct_response']['message']
    return response
  end

  # TODO - implement this
  # def test_should_create_customer_profile_transaction_auth_capture_and_then_refund_using_masked_electronic_checking_info_request
  #   response = get_and_validate_auth_capture_response
  #
  #   @gateway.expects(:ssl_post).returns(successful_create_customer_profile_transaction_response(:void))
  #   assert response = @gateway.create_customer_profile_transaction(
  #     :transaction => {
  #       :type => :void,
  #       :trans_id => response.params['direct_response']['transaction_id']
  #     }
  #   )
  #   assert_instance_of Response, response
  #   assert_success response
  #   assert_nil response.authorization
  #   assert_equal 'This transaction has been approved.', response.params['direct_response']['message']
  #   return response
  # end

  def test_should_create_customer_profile_transaction_for_void_request
    @gateway.expects(:ssl_post).returns(successful_create_customer_profile_transaction_response(:void))

    assert response = @gateway.create_customer_profile_transaction_for_void(
      :transaction => {
        :trans_id => 1
        }
    )
    assert_instance_of Response, response
    assert_success response
    assert_equal response.authorization, response.params['direct_response']['transaction_id']
    assert_equal 'This transaction has been approved.', response.params['direct_response']['message']
  end

  def test_should_create_customer_profile_transaction_for_refund_request
    @gateway.expects(:ssl_post).returns(successful_create_customer_profile_transaction_response(:refund))

    assert response = @gateway.create_customer_profile_transaction_for_refund(
      :transaction => {
        :trans_id => 1,
        :amount => "1.00",
        :credit_card_number_masked => "XXXX1234"
        }
    )
    assert_instance_of Response, response
    assert_success response
    assert_equal response.authorization, response.params['direct_response']['transaction_id']
    assert_equal 'This transaction has been approved.', response.params['direct_response']['message']
  end

  def test_should_create_customer_profile_transaction_passing_recurring_flag
    response = stub_comms do
      @gateway.create_customer_profile_transaction(
        :transaction => {
          :customer_profile_id => @customer_profile_id,
          :customer_payment_profile_id => @customer_payment_profile_id,
          :type => :auth_capture,
          :order => {
            :invoice_number => '1234',
            :description => 'Test Order Description',
            :purchase_order_number => '4321'
          },
          :amount => @amount,
          :card_code => '123',
          :recurring_billing => true
        }
      )
    end.check_request do |endpoint, data, headers|
      assert_match %r{<recurringBilling>true</recurringBilling>}, data
    end.respond_with(successful_create_customer_profile_transaction_response(:auth_capture))

    assert_instance_of Response, response
    assert_success response
    assert_equal 'M', response.params['direct_response']['card_code'] # M => match
    assert_equal response.authorization, response.params['direct_response']['transaction_id']
    assert_equal 'This transaction has been approved.', response.params['direct_response']['message']
  end

  def test_full_or_masked_card_number
    assert_equal nil, @gateway.send(:full_or_masked_card_number, nil)
    assert_equal '', @gateway.send(:full_or_masked_card_number, '')
    assert_equal '4242424242424242', @gateway.send(:full_or_masked_card_number, @credit_card.number)
    assert_equal 'XXXX1234', @gateway.send(:full_or_masked_card_number, '1234')
  end

  def test_multiple_errors_when_creating_customer_profile
    @gateway.expects(:ssl_post).returns(unsuccessful_create_customer_profile_transaction_response_with_multiple_errors(:refund))
    assert response = @gateway.create_customer_profile_transaction(
      :transaction => {
        :type => :refund,
        :amount => 1,

        :customer_profile_id => @customer_profile_id,
        :customer_payment_profile_id => @customer_payment_profile_id,
        :trans_id => 1
      }
    )
    assert_equal 'The transaction was unsuccessful.', response.message
    assert_equal 'E00027', response.error_code
  end

  private

  def get_auth_only_response
    @gateway.expects(:ssl_post).returns(successful_create_customer_profile_transaction_response(:auth_only))

    assert response = @gateway.create_customer_profile_transaction(
      :transaction => {
        :customer_profile_id => @customer_profile_id,
        :customer_payment_profile_id => @customer_payment_profile_id,
        :type => :auth_only,
        :amount => @amount
      }
    )
    assert_instance_of Response, response
    assert_success response
    assert_nil response.authorization
    assert_equal 'This transaction has been approved.', response.params['direct_response']['message']
    assert_equal 'auth_only', response.params['direct_response']['transaction_type']
    assert_equal 'Gw4NGI', response.params['direct_response']['approval_code']
    return response
  end

  def get_and_validate_auth_capture_response
    @gateway.expects(:ssl_post).returns(successful_create_customer_profile_transaction_response(:auth_capture))

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
        :amount => @amount
      }
    )
    assert_instance_of Response, response
    assert_success response
    assert_equal response.authorization, response.params['direct_response']['transaction_id']
    assert_equal 'This transaction has been approved.', response.params['direct_response']['message']
    return response
  end

  def successful_create_customer_profile_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?>
      <createCustomerProfileResponse
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xmlns:xsd="http://www.w3.org/2001/XMLSchema"
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
        <refId>refid1</refId>
        <messages>
          <resultCode>Ok</resultCode>
          <message>
            <code>I00001</code>
            <text>Successful.</text>
          </message>
        </messages>
        <customerProfileId>#{@customer_profile_id}</customerProfileId>
      </createCustomerProfileResponse>
    XML
  end

  def successful_create_customer_payment_profile_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?>
      <createCustomerPaymentProfileResponse
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xmlns:xsd="http://www.w3.org/2001/XMLSchema"
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
        <refId>refid1</refId>
        <messages>
          <resultCode>Ok</resultCode>
          <message>
            <code>I00001</code>
            <text>Successful.</text>
          </message>
        </messages>
        <customerPaymentProfileId>#{@customer_payment_profile_id}</customerPaymentProfileId>
        <validationDirectResponse>This output is only present if the ValidationMode input parameter is passed with a value of testMode or liveMode</validationDirectResponse>
      </createCustomerPaymentProfileResponse>
    XML
  end

  def successful_create_customer_shipping_address_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?>
      <createCustomerShippingAddressResponse
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xmlns:xsd="http://www.w3.org/2001/XMLSchema"
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
        <refId>refid1</refId>
        <messages>
          <resultCode>Ok</resultCode>
          <message>
            <code>I00001</code>
            <text>Successful.</text>
          </message>
        </messages>
        <customerAddressId>customerAddressId</customerAddressId>
      </createCustomerShippingAddressResponse>
    XML
  end

  def successful_delete_customer_profile_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?>
      <deleteCustomerProfileResponse
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xmlns:xsd="http://www.w3.org/2001/XMLSchema"
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
        <refId>refid1</refId>
        <messages>
          <resultCode>Ok</resultCode>
          <message>
            <code>I00001</code>
            <text>Successful.</text>
          </message>
        </messages>
        <customerProfileId>#{@customer_profile_id}</customerProfileId>
      </deleteCustomerProfileResponse>
    XML
  end

  def successful_delete_customer_payment_profile_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?>
      <deleteCustomerPaymentProfileResponse
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xmlns:xsd="http://www.w3.org/2001/XMLSchema"
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
        <refId>refid1</refId>
        <messages>
          <resultCode>Ok</resultCode>
          <message>
            <code>I00001</code>
            <text>Successful.</text>
          </message>
        </messages>
      </deleteCustomerPaymentProfileResponse>
    XML
  end

  def successful_delete_customer_shipping_address_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?>
      <deleteCustomerShippingAddressResponse
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xmlns:xsd="http://www.w3.org/2001/XMLSchema"
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
        <refId>refid1</refId>
        <messages>
          <resultCode>Ok</resultCode>
          <message>
            <code>I00001</code>
            <text>Successful.</text>
          </message>
        </messages>
      </deleteCustomerShippingAddressResponse>
    XML
  end

  def successful_get_customer_profile_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?>
      <getCustomerProfileResponse
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xmlns:xsd="http://www.w3.org/2001/XMLSchema"
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
        <refId>refid1</refId>
        <messages>
          <resultCode>Ok</resultCode>
          <message>
            <code>I00001</code>
            <text>Successful.</text>
          </message>
        </messages>
        <customerProfileId>#{@customer_profile_id}</customerProfileId>
        <profile>
          <paymentProfiles>
            <customerPaymentProfileId>123456</customerPaymentProfileId>
            <payment>
              <creditCard>
                  <cardNumber>#{@credit_card.number}</cardNumber>
                  <expirationDate>#{@gateway.send(:expdate, @credit_card)}</expirationDate>
              </creditCard>
            </payment>
          </paymentProfiles>
        </profile>
      </getCustomerProfileResponse>
    XML
  end

  def successful_get_customer_profile_ids_response
    <<-XML
      <?xml version="1.0" encoding="utf-8"?>
      <getCustomerProfileIdsResponse xmlns="AnetApi/xml/v1/schema/
      AnetApiSchema.xsd">
        <messages>
          <resultCode>Ok</resultCode>
          <message>
            <code>I00001</code>
            <text>Successful.</text>
          </message>
        </messages>
        <ids>
          <numericString>10000</numericString>
          <numericString>10001</numericString>
          <numericString>10002</numericString>
        </ids>
      </getCustomerProfileIdsResponse>
    XML
  end

  def successful_get_customer_profile_response_with_multiple_payment_profiles
    <<-XML
      <?xml version="1.0" encoding="utf-8"?>
      <getCustomerProfileResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
        <messages>
          <resultCode>Ok</resultCode>
          <message>
            <code>I00001</code>
            <text>Successful.</text>
          </message>
        </messages>
        <profile>
          <merchantCustomerId>Up to 20 chars</merchantCustomerId>
          <description>Up to 255 Characters</description>
          <email>Up to 255 Characters</email>
          <customerProfileId>#{@customer_profile_id}</customerProfileId>
          <paymentProfiles>
            <customerPaymentProfileId>1000</customerPaymentProfileId>
            <payment>
              <creditCard>
                <cardNumber>#{@credit_card.number}</cardNumber>
                <expirationDate>#{@gateway.send(:expdate, @credit_card)}</expirationDate>
              </creditCard>
            </payment>
          </paymentProfiles>
          <paymentProfiles>
            <customerType>individual</customerType>
            <customerPaymentProfileId>1001</customerPaymentProfileId>
            <payment>
              <creditCard>
                <cardNumber>XXXX1234</cardNumber>
                <expirationDate>XXXX</expirationDate>
              </creditCard>
            </payment>
          </paymentProfiles>
        </profile>
      </getCustomerProfileResponse>
    XML
  end

  def successful_get_customer_payment_profile_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?>
      <getCustomerPaymentProfileResponse
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xmlns:xsd="http://www.w3.org/2001/XMLSchema"
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
        <refId>refid1</refId>
        <messages>
          <resultCode>Ok</resultCode>
          <message>
            <code>I00001</code>
            <text>Successful.</text>
          </message>
        </messages>
        <profile>
          <paymentProfiles>
            <customerPaymentProfileId>#{@customer_payment_profile_id}</customerPaymentProfileId>
            <payment>
              <creditCard>
                  <cardNumber>#{@credit_card.number}</cardNumber>
                  <expirationDate>#{@gateway.send(:expdate, @credit_card)}</expirationDate>
              </creditCard>
            </payment>
          </paymentProfiles>
        </profile>
      </getCustomerPaymentProfileResponse>
    XML
  end

  def successful_get_customer_shipping_address_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?>
      <getCustomerShippingAddressResponse
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xmlns:xsd="http://www.w3.org/2001/XMLSchema"
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
        <refId>refid1</refId>
        <messages>
          <resultCode>Ok</resultCode>
          <message>
            <code>I00001</code>
            <text>Successful.</text>
          </message>
        </messages>
        <address>
          <customerAddressId>#{@customer_address_id}</customerAddressId>
        </address>
      </getCustomerShippingAddressResponse>
    XML
  end

  def successful_update_customer_profile_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?>
      <updateCustomerProfileResponse
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xmlns:xsd="http://www.w3.org/2001/XMLSchema"
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
        <refId>refid1</refId>
        <messages>
          <resultCode>Ok</resultCode>
          <message>
            <code>I00001</code>
            <text>Successful.</text>
          </message>
        </messages>
        <customerProfileId>#{@customer_profile_id}</customerProfileId>
      </updateCustomerProfileResponse>
    XML
  end

  def successful_update_customer_payment_profile_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?>
      <updateCustomerPaymentProfileResponse
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xmlns:xsd="http://www.w3.org/2001/XMLSchema"
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
        <refId>refid1</refId>
        <messages>
          <resultCode>Ok</resultCode>
          <message>
            <code>I00001</code>
            <text>Successful.</text>
          </message>
        </messages>
      </updateCustomerPaymentProfileResponse>
    XML
  end

  def successful_update_customer_shipping_address_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?>
      <updateCustomerShippingAddressResponse
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xmlns:xsd="http://www.w3.org/2001/XMLSchema"
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
        <refId>refid1</refId>
        <messages>
          <resultCode>Ok</resultCode>
          <message>
            <code>I00001</code>
            <text>Successful.</text>
          </message>
        </messages>
      </updateCustomerShippingAddressResponse>
    XML
  end

  SUCCESSFUL_DIRECT_RESPONSE = {
    :auth_only => '1,1,1,This transaction has been approved.,Gw4NGI,Y,508223659,,,100.00,CC,auth_only,Up to 20 chars,,,,,,,,,,,Up to 255 Characters,,,,,,,,,,,,,,6E5334C13C78EA078173565FD67318E4,,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,',
    :capture_only => '1,1,1,This transaction has been approved.,,Y,508223660,,,100.00,CC,capture_only,Up to 20 chars,,,,,,,,,,,Up to 255 Characters,,,,,,,,,,,,,,6E5334C13C78EA078173565FD67318E4,,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,',
    :auth_capture => '1,1,1,This transaction has been approved.,d1GENk,Y,508223661,32968c18334f16525227,Store purchase,1.00,CC,auth_capture,,Longbob,Longsen,,,,,,,,,,,,,,,,,,,,,,,269862C030129C1173727CC10B1935ED,M,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,',
    :void => '1,1,1,This transaction has been approved.,nnCMEx,P,2149222068,1245879759,,0.00,CC,void,1245879759,,,,,,,K1C2N6,,,,,,,,,,,,,,,,,,F240D65BB27ADCB8C80410B92342B22C,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,',
    :refund => '1,1,1,This transaction has been approved.,nnCMEx,P,2149222068,1245879759,,0.00,CC,refund,1245879759,,,,,,,K1C2N6,,,,,,,,,,,,,,,,,,F240D65BB27ADCB8C80410B92342B22C,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,',
    :prior_auth_capture => '1,1,1,This transaction has been approved.,VR0lrD,P,2149227870,1245958544,,1.00,CC,prior_auth_capture,1245958544,,,,,,,K1C2N6,,,,,,,,,,,,,,,,,,0B8BFE0A0DE6FDB69740ED20F79D04B0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,',
    :auth_capture_version_3_1 => '1,1,1,This transaction has been approved.,CSYM0K,Y,2163585627,1234,Test Order Description,100.00,CC,auth_capture,Up to 20 chars,,,Widgets Inc,1234 My Street,Ottawa,ON,K1C2N6,CA,,,Up to 255 Characters,,,,,,,,,,,,,4321,02DFBD7934AD862AB16688D44F045D31,,2,,,,,,,,,,,XXXX4242,Visa,,,,,,,,,,,,,,,,'
  }
  UNSUCCESSUL_DIRECT_RESPONSE = {
    :refund => '3,2,54,The referenced transaction does not meet the criteria for issuing a credit.,,P,0,,,1.00,CC,credit,1245952682,,,Widgets Inc,1245952682 My Street,Ottawa,ON,K1C2N6,CA,,,bob1245952682@email.com,,,,,,,,,,,,,,207BCBBF78E85CF174C87AE286B472D2,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,447250,406104'
  }

  def successful_create_customer_profile_transaction_response(transaction_type)
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?>
      <createCustomerProfileTransactionResponse
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xmlns:xsd="http://www.w3.org/2001/XMLSchema"
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
        <refId>refid1</refId>
        <messages>
          <resultCode>Ok</resultCode>
          <message>
            <code>I00001</code>
            <text>Successful.</text>
          </message>
        </messages>
        <directResponse>#{SUCCESSFUL_DIRECT_RESPONSE[transaction_type]}</directResponse>
      </createCustomerProfileTransactionResponse>
    XML
  end

  def successful_validate_customer_payment_profile_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?>
      <validateCustomerPaymentProfileResponse
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xmlns:xsd="http://www.w3.org/2001/XMLSchema"
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
        <refId>refid1</refId>
        <messages>
          <resultCode>Ok</resultCode>
          <message>
            <code>I00001</code>
            <text>Successful.</text>
          </message>
        </messages>
        <directResponse>1,1,1,This transaction has been approved.,DEsVh8,Y,508276300,none,Test transaction for ValidateCustomerPaymentProfile.,0.01,CC,auth_only,Up to 20 chars,,,,,,,,,,,Up to 255 Characters,John,Doe,Widgets, Inc,1234 Fake Street,Anytown,MD,12345,USA,0.0000,0.0000,0.0000,TRUE,none,7EB3A44624C0C10FAAE47E276B48BF17,,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,</directResponse>
      </validateCustomerPaymentProfileResponse>
    XML
  end

  def unsuccessful_create_customer_profile_transaction_response(transaction_type)
    <<-XML
      <?xml version="1.0" encoding="utf-8"?>
      <createCustomerProfileTransactionResponse
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xmlns:xsd="http://www.w3.org/2001/XMLSchema"
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
        <messages>
          <resultCode>Error</resultCode>
          <message>
            <code>E00027</code>
            <text>The transaction was unsuccessful.</text>
          </message>
        </messages>
        <directResponse>#{UNSUCCESSUL_DIRECT_RESPONSE[transaction_type]}</directResponse>
      </createCustomerProfileTransactionResponse>
    XML
  end

  def unsuccessful_create_customer_profile_transaction_response_with_multiple_errors(transaction_type)
    <<-XML
      <?xml version="1.0" encoding="utf-8"?>
      <createCustomerProfileTransactionResponse
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xmlns:xsd="http://www.w3.org/2001/XMLSchema"
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
        <messages>
          <resultCode>Error</resultCode>
          <message>
            <code>E00027</code>
            <text>The transaction was unsuccessful.</text>
          </message>
          <message>
            <code>E00001</code>
            <text>An error occurred during processing. Please try again.</text>
          </message>
        </messages>
        <directResponse>#{UNSUCCESSUL_DIRECT_RESPONSE[transaction_type]}</directResponse>
      </createCustomerProfileTransactionResponse>
    XML
  end
end
