require 'test_helper'

class DataCashTest < Test::Unit::TestCase
  # 100 Cents
  AMOUNT = 100

  def setup
    @gateway = DataCashGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )

    @credit_card = credit_card('4242424242424242')
    
    @address = { 
      :name     => 'Mark McBride',
      :address1 => 'Flat 12/3',
      :address2 => '45 Main Road',
      :city     => 'London',
      :state    => 'None',
      :country  => 'GBR',
      :zip      => 'A987AA',
      :phone    => '(555)555-5555'
    }
    
    @options = {
      :order_id => generate_unique_id,
      :billing_address => @address
    }
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert response.test?
    assert_equal 'ACCEPTED', response.message
    assert_equal '4400200050664928;123456789;', response.authorization
  end

  def test_credit
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/<method>refund<\/method>/)).returns(successful_purchase_response)

    @gateway.credit(@amount, @credit_card, @options)
  end

  def test_deprecated_credit
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/<method>txn_refund<\/method>/)).returns(successful_purchase_response)
    assert_deprecation_warning(Gateway::CREDIT_DEPRECATION_MESSAGE, @gateway) do
      @gateway.credit(@amount, "transaction_id", @options)
    end
  end

  def test_refund
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/<method>txn_refund<\/method>/)).returns(successful_purchase_response)

    @gateway.refund(@amount, "transaction_id", @options)
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert response.test?
    assert_equal 'DECLINED', response.message
  end
  
  def test_error_response
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert response.test?
    assert_equal 'DECLINED', response.message
  end
  
  def test_supported_countries
    assert_equal ['GB'], DataCashGateway.supported_countries
  end
  
  def test_supported_card_types
    assert_equal [ :visa, :master, :american_express, :discover, :diners_club, :jcb, :maestro, :switch, :solo, :laser ], DataCashGateway.supported_cardtypes
  end
  
  def test_purchase_with_missing_order_id_option
    assert_raise(ArgumentError){ @gateway.purchase(100, @credit_card, {}) }
  end
  
  def test_authorize_with_missing_order_id_option
    assert_raise(ArgumentError){ @gateway.authorize(100, @credit_card, {}) }
  end
  
  def test_purchase_does_not_raise_exception_with_missing_billing_address
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert @gateway.authorize(100, @credit_card, {:order_id => generate_unique_id }).is_a?(ActiveMerchant::Billing::Response)
  end
  
  def test_continuous_authority_purchase_with_missing_continuous_authority_reference
    assert_raise(ArgumentError) do
      @gateway.authorize(100, "a;b;", @options)
    end
  end
  
  def test_successful_continuous_authority_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_using_continuous_authority_response)

    response = @gateway.purchase(@amount, '4400200050664928;123456789;10000000', @options)
    assert_instance_of Response, response
    assert_success response
    assert response.test?
    assert_equal 'ACCEPTED', response.message
  end

  def test_capture_method_is_ecomm
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/<capturemethod>ecomm<\/capturemethod>/)).returns(successful_purchase_response)
    response = @gateway.purchase(100, @credit_card, @options)
    assert_success response
  end
  
  private
  def failed_purchase_response
    <<-XML
<Response>
  <CardTxn>
    <authcode>NOT AUTHORISED</authcode>
    <card_scheme>Mastercard</card_scheme>
    <country>Japan</country>
  </CardTxn>
  <datacash_reference>4500203037300784</datacash_reference>
  <merchantreference>85613a50952067796b1c6ab61c2cac</merchantreference>
  <mode>TEST</mode>
  <reason>DECLINED</reason>
  <status>7</status>
  <time>1363364315</time>
</Response>
    XML
  end
  
  def successful_purchase_response
    <<-XML
<Response>
  <CardTxn>
    <Cv2Avs>
      <address_policy matched='accept' notchecked='accept' notmatched='reject' notprovided='accept' partialmatch='accept'></address_policy>
      <address_result numeric='0'>notprovided</address_result>
      <cv2_policy matched='accept' notchecked='reject' notmatched='reject' notprovided='reject' partialmatch='reject'></cv2_policy>
      <cv2_result numeric='2'>matched</cv2_result>
      <cv2avs_status>ACCEPTED</cv2avs_status>
      <postcode_policy matched='accept' notchecked='accept' notmatched='reject' notprovided='accept' partialmatch='accept'></postcode_policy>
      <postcode_result numeric='0'>notprovided</postcode_result>
    </Cv2Avs>
    <authcode>123456789</authcode>
    <card_scheme>Visa</card_scheme>
    <country>United Kingdom</country>
  </CardTxn>
  <datacash_reference>4400200050664928</datacash_reference>
  <merchantreference>2d24cc91284c1ed5c65d8821f1e752c7</merchantreference>
  <mode>TEST</mode>
  <reason>ACCEPTED</reason>
  <status>1</status>
  <time>1196414665</time>
</Response>
    XML
  end

  def successful_purchase_using_continuous_authority_response
    <<-XML
<Response>
  <CardTxn>
    <authcode>123456789</authcode>
    <card_scheme>VISA Debit</card_scheme>
    <country>United Kingdom</country>
    <issuer>Barclays Bank PLC</issuer>
  </CardTxn>
  <ContAuthTxn>
    <account_status>Using account ref 4500203037301241. CONT_AUTH transaction complete</account_status>
  </ContAuthTxn>
  <datacash_reference>4400200050664928</datacash_reference>
  <merchantreference>3fc2b05ab38b70f0eb3a6b6d35c0de</merchantreference>
  <mode>TEST</mode>
  <reason>ACCEPTED</reason>
  <status>1</status>
  <time>1363364966</time>
</Response>
    XML
  end  
end
