require 'test_helper'

class AuthorizenetTest < Test::Unit::TestCase
  def setup
    @gateway = AuthorizenetGateway.new(
      some_credential: 'login',
      another_credential: 'password'
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'REPLACE', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_authorize
  end

  def test_failed_authorize
  end

  def test_successful_capture
  end

  def test_failed_capture
  end

  def test_successful_refund
  end

  def test_failed_refund
  end

  def test_successful_void
  end

  def test_failed_void
  end

  private

  def successful_purchase_response
    <<-eos
      <?xml version="1.0" encoding="utf-8"?>
      <createTransactionResponse
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"
      xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
      <refId>1</refId>
      <messages>
        <resultCode>Ok</resultCode>
          <message>
          <code>I00001</code>
          <text>Successful.</text>
          </message>
      </messages>
      <transactionResponse>
        <responseCode>1</responseCode>
        <authCode>GSOFTZ</authCode>
        <avsResultCode>Y</avsResultCode>
        <cvvResultCode>P</cvvResultCode>
        <cavvResultCode>2</cavvResultCode>
        <transId>2213698343</transId>
          <refTransID/>
          <transHash>655D049EE60E1766C9C28EB47CFAA389</transHash>
        <testRequest>0</testRequest>
        <accountNumber>XXXX2224</accountNumber>
        <accountType>Visa</accountType>
        <messages>
          <message>
            <code>1</code>
            <description>This transaction has been approved.</description>
          </message>
        </messages>
      </transactionResponse>
      </createTransactionResponse>
    eos
  end

  def failed_purchase_response
  end

  def successful_authorize_response
  end

  def failed_authorize_response
  end

  def successful_capture_response
  end

  def failed_capture_response
  end

  def successful_refund_response
  end

  def failed_refund_response
  end

  def successful_void_response
    <<-eos
    <?xml version="1.0" encoding="utf-8"?>
    <createTransactionResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                               xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
    <messages>
      <resultCode>
        Ok
      </resultCode>
      <message>
        <code>
          I00001
        </code>
        <text>
          Successful.
        </text>
      </message>
    </messages>
    <transactionResponse>
      <responseCode>
        1
      </responseCode>
      <authCode>
        MGYEB3
      </authCode>
      <avsResultCode>
        P
      </avsResultCode>
      <cvvResultCode/>
      <cavvResultCode/>
      <transId>
        2213755822
      </transId>
      <refTransID>
        2213755822
      </refTransID>
      <transHash>
        3383BBB85FF98057D61B2D9B9A2DA79F
      </transHash>
      <testRequest>
        0
      </testRequest>
      <accountNumber>
        XXXX0015
      </accountNumber>
      <accountType>
        MasterCard
      </accountType>
      <messages>
        <message>
          <code>
            1
          </code>
          <description>
            This transaction has been approved.
          </description>
        </message>
      </messages>
    </transactionResponse>
    </createTransactionResponse>
    eos
  end

  def failed_void_response
    <<-eos
      <?xml version="1.0" encoding="utf-8"?>
      <createTransactionResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                                 xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
      <messages>
        <resultCode>
          Error
        </resultCode>
        <message>
          <code>
            E00027
          </code>
          <text>
            The transaction was unsuccessful.
          </text>
        </message>
      </messages>
      <transactionResponse>
        <responseCode>
          3
        </responseCode>
        <authCode/>
        <avsResultCode>
          P
        </avsResultCode>
        <cvvResultCode/>
        <cavvResultCode/>
        <transId>
          0
        </transId>
        <refTransID>
          2213755821
        </refTransID>
        <transHash>
          39DC95085A313FEF7278C40EA8A66B16
        </transHash>
        <testRequest>
          0
        </testRequest>
        <accountNumber/>
        <accountType/>
        <errors>
          <error>
            <errorCode>
              16
            </errorCode>
            <errorText>
              The transaction cannot be found.
            </errorText>
          </error>
        </errors>
        <shipTo/>
      </transactionResponse>
      </createTransactionResponse>
    eos
  end
end
