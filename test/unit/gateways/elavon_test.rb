require 'test_helper'

class ElavonTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = ElavonGateway.new(
                 :login => 'login',
                 :user => 'user',
                 :password => 'password'
               )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '123456;00000000-0000-0000-0000-00000000000', response.authorization
    assert response.test?
  end

  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '123456;00000000-0000-0000-0000-00000000000', response.authorization
    assert_equal "APPROVED", response.message
    assert response.test?
  end

  def test_failed_authorization
    @gateway.expects(:ssl_post).returns(failed_authorization_response)

    assert response = @gateway.authorize(@amount, @credit_card)
    assert_instance_of Response, response
    assert_failure response
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert response = @gateway.void('123')
    assert_success response
    assert_equal 'APPROVAL', response.message
  end

  def test_unsuccessful_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    assert response = @gateway.void('123')
    assert_failure response
    assert_equal 'The transaction ID is invalid for this transaction type', response.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    assert response = @gateway.refund(123, '456')
    assert_success response
    assert_equal 'APPROVAL', response.message
  end

  def test_unsuccessful_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    assert response = @gateway.refund(123, '456')
    assert_failure response
    assert_equal 'The refund amount exceeds the original transaction amount.', response.message
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(successful_authorization_response, successful_void_response)
    assert_success response
  end

  def test_successful_verify_failed_void
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorization_response, failed_void_response)
    assert_success response
    assert_equal "APPROVED", response.message
  end

  def test_unsuccessful_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(failed_authorization_response, successful_void_response)
    assert_failure response
    assert_equal "The Credit Card Number supplied in the authorization request appears to be invalid.", response.message
  end

  def test_invalid_login
    @gateway.expects(:ssl_post).returns(invalid_login_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)

    assert_equal '7000', response.params['result']
    assert_equal 'The VirtualMerchant ID and/or User ID supplied in the authorization request is invalid.', response.message
    assert_failure response
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover], ElavonGateway.supported_cardtypes
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'X', response.avs_result['code']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'P', response.cvv_result['code']
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)

    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal '7595301425001111', response.params["token"]
    assert response.test?
  end

  def test_failed_store
    @gateway.expects(:ssl_post).returns(failed_store_response)

    assert response = @gateway.store(@credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
  end

  def test_successful_update
    @gateway.expects(:ssl_post).returns(successful_update_response)
    token = '7595301425001111'
    assert response = @gateway.update(token, @credit_card, @options)
    assert_success response
    assert response.test?
  end

  def test_failed_update
    @gateway.expects(:ssl_post).returns(failed_update_response)
    token = '7595301425001111'
    assert response = @gateway.update(token, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
  end

  private
  def successful_purchase_response
    "ssl_card_number=42********4242
    ssl_exp_date=0910
    ssl_amount=1.00
    ssl_invoice_number=
    ssl_description=Test Transaction
    ssl_result=0
    ssl_result_message=APPROVED
    ssl_txn_id=00000000-0000-0000-0000-00000000000
    ssl_approval_code=123456
    ssl_cvv2_response=P
    ssl_avs_response=X
    ssl_account_balance=0.00
    ssl_txn_time=08/07/2009 09:54:18 PM"
  end

  def successful_refund_response
    "ssl_card_number=42*****2222
    ssl_exp_date=
    ssl_amount=1.00
    ssl_customer_code=
    ssl_invoice_number=
    ssl_description=
    ssl_company=
    ssl_first_name=
    ssl_last_name=
    ssl_avs_address=
    ssl_address2=
    ssl_city=
    ssl_state=
    ssl_avs_zip=
    ssl_country=
    ssl_phone=
    ssl_email=
    ssl_result=0
    ssl_result_message=APPROVAL
    ssl_txn_id=AA49315-C3D2B7BA-237C-1168-405A-CD5CAF928B0C
    ssl_approval_code=
    ssl_cvv2_response=
    ssl_avs_response=
    ssl_account_balance=0.00
    ssl_txn_time=08/21/2012 05:43:46 PM"
  end

  def successful_void_response
    "ssl_card_number=42*****2222
    ssl_exp_date=0913
    ssl_amount=1.00
    ssl_invoice_number=
    ssl_description=
    ssl_company=
    ssl_first_name=
    ssl_last_name=
    ssl_avs_address=
    ssl_address2=
    ssl_city=
    ssl_state=
    ssl_avs_zip=
    ssl_country=
    ssl_phone=
    ssl_email=
    ssl_result=0
    ssl_result_message=APPROVAL
    ssl_txn_id=AA49315-F04216E3-E556-E2E0-ADE9-4186A5F69105
    ssl_approval_code=
    ssl_cvv2_response=
    ssl_avs_response=
    ssl_account_balance=1.00
    ssl_txn_time=08/21/2012 05:37:19 PM"
  end

  def failed_purchase_response
    "errorCode=5000
    errorName=Credit Card Number Invalid
    errorMessage=The Credit Card Number supplied in the authorization request appears to be invalid."
  end

  def failed_refund_response
    "errorCode=5091
    errorName=Invalid Refund Amount
    errorMessage=The refund amount exceeds the original transaction amount."
  end

  def failed_void_response
    "errorCode=5040
    errorName=Invalid Transaction ID
    errorMessage=The transaction ID is invalid for this transaction type"
  end

  def invalid_login_response
        <<-RESPONSE
    ssl_result=7000\r
    ssl_result_message=The VirtualMerchant ID and/or User ID supplied in the authorization request is invalid.\r
        RESPONSE
  end

  def successful_authorization_response
    "ssl_card_number=42********4242
    ssl_exp_date=0910
    ssl_amount=1.00
    ssl_invoice_number=
    ssl_description=Test Transaction
    ssl_result=0
    ssl_result_message=APPROVED
    ssl_txn_id=00000000-0000-0000-0000-00000000000
    ssl_approval_code=123456
    ssl_cvv2_response=P
    ssl_avs_response=X
    ssl_account_balance=0.00
    ssl_txn_time=08/07/2009 09:56:11 PM"
  end

  def failed_authorization_response
    "errorCode=5000
    errorName=Credit Card Number Invalid
    errorMessage=The Credit Card Number supplied in the authorization request appears to be invalid."
  end

  def successful_store_response
    "ssl_transaction_type=CCGETTOKEN
     ssl_result=0
     ssl_token=7595301425001111
     ssl_card_number=41**********1111
     ssl_token_response=SUCCESS
     ssl_add_token_response=Card Updated
     vu_aamc_id="
  end

  def failed_store_response
    "errorCode=5000
    errorName=Credit Card Number Invalid
    errorMessage=The Credit Card Number supplied in the authorization request appears to be invalid."
  end

  def successful_update_response
    "ssl_token=7595301425001111
    ssl_card_type=VISA
    ssl_card_number=************1111
    ssl_exp_date=1015
    ssl_company=
    ssl_customer_id=
    ssl_first_name=John
    ssl_last_name=Doe
    ssl_avs_address=
    ssl_address2=
    ssl_avs_zip=
    ssl_city=
    ssl_state=
    ssl_country=
    ssl_phone=
    ssl_email=
    ssl_description=
    ssl_user_id=webpage
    ssl_token_response=SUCCESS
    ssl_result=0"
  end

  def failed_update_response
    "errorCode=5000
    errorName=Credit Card Number Invalid
    errorMessage=The Credit Card Number supplied in the authorization request appears to be invalid."
  end
end
