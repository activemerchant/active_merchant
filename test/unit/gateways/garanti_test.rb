# coding: utf-8

require 'test_helper'

class GarantiTest < Test::Unit::TestCase
  def setup
    @original_kcode = nil
    if RUBY_VERSION < '1.9' && $KCODE == "NONE"
      @original_kcode = $KCODE
      $KCODE = 'u'
    end

    Base.gateway_mode = :test
    @gateway = GarantiGateway.new(:login => 'a', :password => 'b', :terminal_id => 'c', :merchant_id => 'd')

    @credit_card = credit_card(4242424242424242)
    @amount = 1000 #1000 cents, 10$

    @options = {
      :order_id => 'db4af18c5222503d845180350fbda516',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def teardown
    $KCODE = @original_kcode if @original_kcode
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response

    # Replace with authorization number from the successful response
    assert_equal 'db4af18c5222503d845180350fbda516', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_character_normalization
    if ActiveSupport::Inflector.method(:transliterate).arity == -2
      assert_equal 'ABCCDEFGGHIIJKLMNOOPRSSTUUVYZ', @gateway.send(:normalize, 'ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ')
      assert_equal 'abccdefgghiijklmnooprsstuuvyz', @gateway.send(:normalize, 'abcçdefgğhıijklmnoöprsştuüvyz')
    elsif RUBY_VERSION >= '1.9'
      assert_equal 'ABCDEFGHIJKLMNOPRSTUVYZ', @gateway.send(:normalize, 'ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ')
      assert_equal 'abcdefghijklmnoprstuvyz', @gateway.send(:normalize, 'abcçdefgğhıijklmnoöprsştuüvyz')
    else
      assert_equal 'ABCCDEFGGHIIJKLMNOOPRSSTUUVYZ', @gateway.send(:normalize, 'ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ')
      assert_equal 'abccdefgghijklmnooprsstuuvyz', @gateway.send(:normalize, 'abcçdefgğhıijklmnoöprsştuüvyz')
    end
  end

  def test_nil_normalization
    assert_nil @gateway.send(:normalize, nil)
  end


  private

  # Place raw successful response from gateway here
  def successful_purchase_response
    <<-EOF
<GVPSResponse>
      <Mode></Mode>
      <Order>
            <OrderID>db4af18c5222503d845180350fbda516</OrderID>
            <GroupID></GroupID>
      </Order>
      <Transaction>
            <Response>
                  <Source>HOST</Source>
                  <Code>00</Code>
                  <ReasonCode>00</ReasonCode>
                  <Message>Approved</Message>
                  <ErrorMsg></ErrorMsg>
                  <SysErrMsg></SysErrMsg>
            </Response>
            <RetrefNum>035208609374</RetrefNum>
            <AuthCode>784260</AuthCode>
            <BatchNum>000089</BatchNum>
            <SequenceNum>000008</SequenceNum>
            <ProvDate>20101218 08:56:39</ProvDate>
            <CardNumberMasked></CardNumberMasked>
            <CardHolderName></CardHolderName>
            <HostMsgList></HostMsgList>
            <RewardInqResult>
                  <RewardList></RewardList>
                  <ChequeList></ChequeList>
            </RewardInqResult>
      </Transaction>
</GVPSResponse>
  EOF
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    <<-EOF
<GVPSResponse>
      <Mode></Mode>
      <Order>
            <OrderID>db4af18c5222503d845180350fbda516</OrderID>
            <GroupID></GroupID>
      </Order>
      <Transaction>
            <Response>
                  <Source>GVPS</Source>
                  <Code>92</Code>
                  <ReasonCode>0651</ReasonCode>
                  <Message>Declined</Message>
                  <ErrorMsg></ErrorMsg>
                  <SysErrMsg>ErrorId: 0651</SysErrMsg>
            </Response>
            <RetrefNum></RetrefNum>
            <AuthCode> </AuthCode>
            <BatchNum></BatchNum>
            <SequenceNum></SequenceNum>
            <ProvDate>20101220 01:58:41</ProvDate>
            <CardNumberMasked></CardNumberMasked>
            <CardHolderName></CardHolderName>
            <HostMsgList></HostMsgList>
            <RewardInqResult>
                  <RewardList></RewardList>
                  <ChequeList></ChequeList>
            </RewardInqResult>
      </Transaction>
</GVPSResponse>
    EOF
  end
end
