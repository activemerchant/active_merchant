require 'test_helper'

class PacNetRavenGatewayTest < Test::Unit::TestCase
  def setup
    @gateway = PacNetRavenGateway.new(
      user: 'user',
      secret: 'secret',
      prn: 123456
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      billing_address: address
    }
  end

  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal 'This transaction has been approved', response.message
    assert_equal '123456789', response.authorization
    assert response.test?
  end

  def test_invalid_credit_card_authorization
    @gateway.expects(:ssl_post).returns(invalid_credit_card_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Error processing transaction because CardNumber is not between 12 and 19 in length", response.message
  end

  def test_expired_credit_card_authorization
    @gateway.expects(:ssl_post).returns(expired_credit_card_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Invalid because the card expiry date is not a date in the future", response.message
  end

  def test_declined_authorization
    @gateway.expects(:ssl_post).returns(declined_purchese_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'This transaction has been declined', response.message
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal 'This transaction has been approved', response.message
    assert_equal '123456789', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_avs_cvv
    @gateway.expects(:ssl_post).returns(successful_purchase_response_with_avs_cvv)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal 'This transaction has been approved', response.message
    assert_equal '123456789', response.authorization
    assert response.test?
    assert_equal 'Y', response.avs_result['street_match']
    assert_equal 'Y', response.avs_result['postal_match']
    assert_equal 'Y', response.cvv_result['code']
  end

  def test_successful_purchase_with_failed_avs_cvv
    @gateway.expects(:ssl_post).returns(successful_purchase_response_with_failed_avs_cvv)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal 'This transaction has been approved', response.message
    assert_equal '123456789', response.authorization
    assert response.test?
    assert_equal 'N', response.avs_result['street_match']
    assert_equal 'N', response.avs_result['postal_match']
    assert_equal 'N', response.cvv_result['code']
  end

  def test_invalid_credit_card_number_purchese
    @gateway.expects(:ssl_post).returns(invalid_credit_card_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Error processing transaction because CardNumber is not between 12 and 19 in length", response.message
  end

  def test_expired_credit_card_purchese
    @gateway.expects(:ssl_post).returns(expired_credit_card_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Invalid because the card expiry date is not a date in the future", response.message
  end

  def test_declined_purchese
    @gateway.expects(:ssl_post).returns(declined_purchese_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'This transaction has been declined', response.message
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    assert response = @gateway.capture(@amount, '123456789')
    assert_instance_of Response, response
    assert_success response
    assert_equal 'This transaction has been approved', response.message
    assert_equal '123456789', response.authorization
    assert response.test?
  end

  def test_invalid_preauth_number_capture
    @gateway.expects(:ssl_post).returns(invalid_preauth_number_response)
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Error processing transaction because the pre-auth number', response.message
  end

  def test_insufficient_preauth_amount_capture
    @gateway.expects(:ssl_post).returns(insufficient_preauth_amount_response)
    assert response = @gateway.capture(200, '123456789')
    assert_failure response
    assert_equal 'Invalid because the preauthorization amount 100 is insufficient', response.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    assert response = @gateway.refund(@amount, '123456789')
    assert_success response
    assert_equal 'This transaction has been approved', response.message
  end

  def test_amount_greater_than_original_amount_refund
    @gateway.expects(:ssl_post).returns(amount_greater_than_original_amount_refund_response)
    assert response = @gateway.refund(200, '123456789')
    assert_failure response
    assert_equal 'Invalid because the payment amount cannot be greater than the original charge', response.message
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)
    assert response = @gateway.void('123456789')
    assert_success response
    assert_equal "This transaction has been voided", response.message
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)
    assert response = @gateway.void('123456789')
    assert_failure response
    assert_equal "Error processing transaction because the payment may not be voided", response.message
  end

  def test_argument_error_prn
    exception = assert_raises(ArgumentError){
      PacNetRavenGateway.new(:user => 'user', :secret => 'secret')
    }
    assert_equal 'Missing required parameter: prn', exception.message
  end

  def test_argument_error_user
    exception = assert_raises(ArgumentError){
      PacNetRavenGateway.new(:secret => 'secret', :prn => 123456)
    }
    assert_equal 'Missing required parameter: user', exception.message
  end

  def test_argument_error_secret
    exception = assert_raises(ArgumentError){
      PacNetRavenGateway.new(:user => 'user', :prn => 123456)
    }
    assert_equal 'Missing required parameter: secret', exception.message
  end

  def test_add_address
    result = {}
    @gateway.send(:add_address, result, :billing_address => {:address1 => 'Address 1', :address2 => 'Address 2', :zip => 'ZIP'} )
    assert_equal ["BillingPostalCode", "BillingStreetAddressLineFour", "BillingStreetAddressLineOne"], result.stringify_keys.keys.sort
    assert_equal 'ZIP', result['BillingPostalCode']
    assert_equal 'Address 2', result['BillingStreetAddressLineFour']
    assert_equal 'Address 1', result['BillingStreetAddressLineOne']
  end

  def test_add_creditcard
    result = {}
    @gateway.send(:add_creditcard, result, @credit_card)
    assert_equal ["CVV2", "CardNumber", "Expiry"], result.stringify_keys.keys.sort
    assert_equal @credit_card.number, result['CardNumber']
    assert_equal @gateway.send(:expdate, @credit_card), result['Expiry']
    assert_equal @credit_card.verification_value, result['CVV2']
  end

  def test_add_currency_code_default
    result = {}
    @gateway.send(:add_currency_code, result, 100, {})
    assert_equal 'USD', result['Currency']
  end

  def test_add_currency_code_from_options
    result = {}
    @gateway.send(:add_currency_code, result, 100, {currency: 'CAN'})
    assert_equal 'CAN', result['Currency']
  end

  def test_parse
    result = @gateway.send(:parse, "key1=value1&key2=value2")
    h = {'key1' => 'value1', 'key2' => 'value2'}
    assert_equal h, result
  end

  def test_endpoint_for_void
    assert_equal 'void', @gateway.send(:endpoint, 'void')
  end

  def test_endpoint_for_cc_debit
    assert_equal 'submit', @gateway.send(:endpoint, 'cc_debit')
  end

  def test_endpoint_for_cc_preauth
    assert_equal 'submit', @gateway.send(:endpoint, 'cc_preauth')
  end

  def test_endpoint_for_cc_settle
    assert_equal 'submit', @gateway.send(:endpoint, 'cc_settle')
  end

  def test_endpoint_for_cc_refund
    assert_equal 'submit', @gateway.send(:endpoint, 'cc_refund')
  end

  def test_success
    assert @gateway.send(:success?, {
      :action => 'cc_settle',
      'ApprovalCode' => '123456',
      'ErrorCode' => nil,
      'Status' => 'Approved'
    })

    refute @gateway.send(:success?, {
      :action => 'cc_settle',
      'ApprovalCode' => nil,
      'ErrorCode' => 'SomeError',
      'Status' => 'SomeError'
    })

    assert @gateway.send(:success?, {
      :action => 'cc_debit',
      'ApprovalCode' => '123456',
      'ErrorCode' => nil,
      'Status' => 'Approved'
    })

    refute @gateway.send(:success?, {
      :action => 'cc_debit',
      'ApprovalCode' => nil,
      'ErrorCode' => 'SomeError',
      'Status' => 'SomeError'
    })

    assert @gateway.send(:success?, {
      :action => 'cc_preauth',
      'ApprovalCode' => '123456',
      'ErrorCode' => nil,
      'Status' => 'Approved'
    })

    refute @gateway.send(:success?, {
      :action => 'cc_preauth',
      'ApprovalCode' => nil,
      'ErrorCode' => 'SomeError',
      'Status' => 'SomeError'
    })

    assert @gateway.send(:success?, {
      :action => 'cc_refund',
      'ApprovalCode' => '123456',
      'ErrorCode' => nil,
      'Status' => 'Approved'
    })

    refute @gateway.send(:success?, {
      :action => 'cc_refund',
      'ApprovalCode' => nil,
      'ErrorCode' => 'SomeError',
      'Status' => 'SomeError'
    })

    assert @gateway.send(:success?, {
      :action => 'void',
      'ApprovalCode' => '123456',
      'ErrorCode' => nil,
      'Status' => 'Voided'
    })

    refute @gateway.send(:success?, {
      :action => 'void',
      'ApprovalCode' => nil,
      'ErrorCode' => 'SomeError',
      'Status' => 'SomeError'
    })
  end

  def test_message_from_approved
    assert_equal "This transaction has been approved", @gateway.send(:message_from, {
      'Status' => 'Approved',
      'Message'=> nil
    })
  end

  def test_message_from_declined
    assert_equal "This transaction has been declined", @gateway.send(:message_from, {
      'Status' => 'Declined',
      'Message'=> nil
    })
  end

  def test_message_from_voided
    assert_equal "This transaction has been voided", @gateway.send(:message_from, {
      'Status' => 'Voided',
      'Message'=> nil
    })
  end

  def test_message_from_status
    assert_equal "This is the message", @gateway.send(:message_from, {
      'Status' => 'SomeStatus',
      'Message'=> "This is the message"
    })
  end

  def test_post_data
    @gateway.stubs(:request_id => "wouykiikdvqbwwxueppby")
    @gateway.stubs(:timestamp => "2013-10-08T14:31:54.Z")

    assert_equal "PymtType=cc_preauth&RAPIVersion=2&UserName=user&Timestamp=2013-10-08T14%3A31%3A54.Z&RequestID=wouykiikdvqbwwxueppby&Signature=7794efc8c0d39f0983edc10f778e6143ba13531d&CardNumber=4242424242424242&Expiry=09#{@credit_card.year.to_s[-2..-1]}&CVV2=123&Currency=USD&BillingStreetAddressLineOne=Address+1&BillingStreetAddressLineFour=Address+2&BillingPostalCode=ZIP123",
      @gateway.send(:post_data, 'cc_preauth', {
      'CardNumber' => @credit_card.number,
      'Expiry' => @gateway.send(:expdate, @credit_card),
      'CVV2' => @credit_card.verification_value,
      'Currency' => 'USD',
      'BillingStreetAddressLineOne' => 'Address 1',
      'BillingStreetAddressLineFour' => 'Address 2',
      'BillingPostalCode' => 'ZIP123'
    })
  end

  def test_signature_for_cc_preauth_action
    assert_equal 'd5ff154d6631333c21d0c78975b3bf5d9ccd0ef8', @gateway.send(:signature, 'cc_preauth', {
      'UserName' => 'user',
      'Timestamp' => '2013-10-08T14:31:54.Z',
      'RequestID' => 'wouykiikdvqbwwxueppby',
      'PymtType' => 'cc_preauth'
    }, {
        'Amount' => 100,
        'Currency' => 'USD',
        'TrackingNumber' => '123456789'
    })
  end

  def test_signature_for_cc_settle_action
    assert_equal 'c80cccf6c77438785726b5a447d5aed84738c6d1', @gateway.send(:signature, 'cc_settle', {
      'UserName' => 'user',
      'Timestamp' => '2013-10-08T14:31:54.Z',
      'RequestID' => 'wouykiikdvqbwwxueppby',
      'PymtType' => 'cc_settle'
    }, {
        'Amount' => 100,
        'Currency' => 'USD',
        'TrackingNumber' => '123456789'
    })
  end

  def test_signature_for_cc_debit_action
    assert_equal 'b2a0eb307cfd092152d44b06a49a360feccdb1b9', @gateway.send(:signature, 'cc_debit', {
      'UserName' => 'user',
      'Timestamp' => '2013-10-08T14:31:54.Z',
      'RequestID' => 'wouykiikdvqbwwxueppby',
      'PymtType' => 'cc_debit'
    }, {
        'Amount' => 100,
        'Currency' => 'USD',
        'TrackingNumber' => '123456789'
    })
  end

  def test_signature_for_cc_refund_action
    assert_equal '9b174f1ebf5763e4793a52027645ff5156fca2e3', @gateway.send(:signature, 'cc_refund', {
      'UserName' => 'user',
      'Timestamp' => '2013-10-08T14:31:54.Z',
      'RequestID' => 'wouykiikdvqbwwxueppby',
      'PymtType' => 'cc_refund'
    }, {
        'Amount' => 100,
        'Currency' => 'USD',
        'TrackingNumber' => '123456789'
    })
  end

  def test_signature_for_void_action
    assert_equal '236d4a857ee2e8cfec851be250159367d2c7c52e', @gateway.send(:signature, 'void', {
      'UserName' => 'user',
      'Timestamp' => '2013-10-08T14:31:54.Z',
      'RequestID' => 'wouykiikdvqbwwxueppby'
    }, {
        'Amount' => 100,
        'Currency' => 'USD',
        'TrackingNumber' => '123456789'
    })
  end

  def test_expdate
    @credit_card.year = 2015
    @credit_card.month = 9
    assert_equal "0915", @gateway.send(:expdate, @credit_card)
  end

  private

  def failed_void_response
    %w(
      ApprovalCode=
      ErrorCode=error:canNotBeVoided
      Message=Error+processing+transaction+because+the+payment+may+not+be+voided
      RequestNumber=603758541
      RequestResult=ok
      Status=Approved
      TrackingNumber=123456789
    ).join('&')
  end

  def successful_authorization_response
    %w(
      ApprovalCode=123456
      ErrorCode=
      Message=
      RequestNumber=603758541
      RequestResult=ok
      Status=Approved
      TrackingNumber=123456789
    ).join('&')
  end

  def successful_purchase_response
    %w(
      ApprovalCode=123456
      ErrorCode=
      Message=
      RequestNumber=603758541
      RequestResult=ok
      Status=Approved
      TrackingNumber=123456789
    ).join('&')
  end

  def successful_purchase_response_with_avs_cvv
    %w(
      ApprovalCode=123456
      ErrorCode=
      Message=
      RequestNumber=603758541
      RequestResult=ok
      Status=Approved
      TrackingNumber=123456789
      AVSAddressResponseCode=avs_address_matched
      AVSPostalResponseCode=avs_postal_matched
      CVV2ResponseCode=cvv2_matched
    ).join('&')
  end

  def successful_purchase_response_with_failed_avs_cvv
    %w(
      ApprovalCode=123456
      ErrorCode=
      Message=
      RequestNumber=603758541
      RequestResult=ok
      Status=Approved
      TrackingNumber=123456789
      AVSAddressResponseCode=avs_address_not_matched
      AVSPostalResponseCode=avs_postal_not_matched
      CVV2ResponseCode=cvv2_not_matched
    ).join('&')
  end

  def successful_capture_response
    %w(
      ApprovalCode=123456
      ErrorCode=
      Message=
      RequestNumber=603758541
      RequestResult=ok
      Status=Approved
      TrackingNumber=123456789
    ).join('&')
  end

  def invalid_preauth_number_response
    %w(
      ApprovalCode=
      ErrorCode=invalid:PreAuthNumber
      Message=Error+processing+transaction+because+the+pre-auth+number
      RequestNumber=603758541
      RequestResult=ok
      Status=Invalid:PreauthNumber
      TrackingNumber=123456789
    ).join('&')
  end

  def insufficient_preauth_amount_response
    %w(
      ApprovalCode=
      ErrorCode=rejected:PreauthAmountInsufficient
      Message=Invalid+because+the+preauthorization+amount+100+is+insufficient
      RequestNumber=603758541
      RequestResult=ok
      Status=Rejected:PreauthAmountInsufficient
      TrackingNumber=123456789
    ).join('&')
  end

  def invalid_credit_card_response
    %w(
      ApprovalCode=
      ErrorCode=invalid:cardNumber
      Message=Error+processing+transaction+because+CardNumber+is+not+between+12+and+19+in+length
      RequestNumber=603758541
      RequestResult=ok
      Status=Invalid:CardNumber
      TrackingNumber=123456789
    ).join('&')
  end

  def expired_credit_card_response
    %w(
      ApprovalCode=
      ErrorCode=invalid:CustomerCardExpiryDate
      Message=Invalid+because+the+card+expiry+date+is+not+a+date+in+the+future
      RequestNumber=603758541
      RequestResult=ok
      Status=Invalid:CustomerCardExpiryDate
      TrackingNumber=123456789
    ).join('&')
  end

  def declined_purchese_response
    %w(
      ApprovalCode=123456
      ErrorCode=
      Message=
      RequestNumber=603758541
      RequestResult=ok
      Status=Declined
      TrackingNumber=123456789
    ).join('&')
  end

  def successful_refund_response
    %w(
      ApprovalCode=123456
      ErrorCode=
      Message=
      RequestNumber=603758541
      RequestResult=ok
      Status=Approved
      TrackingNumber=123456789
    ).join('&')
  end

  def amount_greater_than_original_amount_refund_response
    %w(
      ApprovalCode=
      ErrorCode=invalid:RefundAmountGreaterThanOriginalAmount
      Message=Invalid+because+the+payment+amount+cannot+be+greater+than+the+original+charge
      RequestNumber=603758541
      RequestResult=ok
      Status=Invalid:RefundAmountGreaterThanOriginalAmount
      TrackingNumber=123456789
    ).join('&')
  end

  def successful_void_response
    %w(
      ApprovalCode=123456
      ErrorCode=
      Message=
      RequestNumber=603758541
      RequestResult=ok
      Status=Voided
      TrackingNumber=123456789
    ).join('&')
  end
end
