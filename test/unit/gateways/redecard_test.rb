require 'test_helper'

class RedecardTest < Test::Unit::TestCase
  def setup
    @gateway = RedecardGateway.new(
      fixtures(:redecard)
    )

    @credit_card = credit_card
    @amount = 1

    @options = {
        :order_id => generate_unique_id.slice(0, 15),
        :installments => 1
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).twice.returns(successful_authorize_response, successful_capture_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal '4444', response.responses.first.authorization
    assert_success response.responses.first
    assert_success response.responses.last
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    @creditcard = credit_card
    response = @gateway.authorize(@amount, @creditcard, @options)

    assert_instance_of Response, response

    assert_success response

    assert_equal '4444', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)
    @creditcard = credit_card
    response = @gateway.authorize(@amount, @creditcard, @options)

    assert_instance_of Response, response

    assert_failure response
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).at_least(1).returns(successful_authorize_response)
    @creditcard = credit_card
    response = @gateway.authorize(@amount, @creditcard, @options)

    assert_success response

    sale_number = { sale_number: response.params[:numcv] }
    capture = @gateway.capture(@amount, response.authorization, @options.merge(sale_number))

    assert_success capture
    assert capture.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).at_least(2).returns(successful_authorize_response, successful_capture_response)
    @creditcard = credit_card
    response = @gateway.authorize(@amount, @creditcard, @options)

    sale_number = { sale_number: response.params[:numcv] }
    capture = @gateway.capture(@amount, response.authorization, @options.merge(sale_number))

    refund = @gateway.refund(@money, response.authorization, @options.merge(sale_number))

    assert_success refund
    assert refund.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).at_least(2).returns(
      successful_authorize_response,
      successful_capture_response,
      failed_refund_response
    )
    @creditcard = credit_card
    response = @gateway.authorize(@amount, @creditcard, @options)

    sale_number = { sale_number: response.params[:numcv] }
    capture = @gateway.capture(@amount, response.authorization, @options.merge(sale_number))

    refund = @gateway.refund(@money, response.authorization, @options.merge(sale_number))

    assert_failure refund
    assert refund.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_post).twice.returns(successful_authorize_response, successful_void_response)
    @creditcard = credit_card
    response = @gateway.authorize(@amount, @creditcard, @options)

    sale_number = { sale_number: response.params[:numcv] }
    amount = { money: @amount }
    additional_params = sale_number.merge(amount)

    void = @gateway.void(response.authorization, @options.merge(additional_params))

    assert_success void
    assert void.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_post).at_least(2).returns(successful_authorize_response, failed_void_response)
    @creditcard = credit_card
    response = @gateway.authorize(@amount, @creditcard, @options)

    sale_number = { sale_number: response.params[:numcv] }
    amount = { money: @amount }
    additional_params = sale_number.merge(amount)

    void = @gateway.void(response.authorization, @options.merge(additional_params))

    assert_failure void
    assert void.test?
  end

  private

  def successful_authorize_response
    <<-XML
      <?xml version=”1.0” encoding=”utf-8”?>
      <AUTHORIZATION>
        <CODRET>0</CODRET>
        <MSGRET></MSGRET>
        <NUMPEDIDO>123</NUMPEDIDO>
        <DATA>99999999</DATA>
        <NUMAUTOR>4444</NUMAUTOR>
        <NUMCV>1234</NUMCV>
        <NUMAUTENT>5678</NUMAUTENT>
        <NUMSQN>999</NUMSQN>
        <ORIGEM_BIN>XXX</ORIGEM_BIN>
        <CONFCODRET>0</CONFCODRET>
        <CONFMSGRET></CONFMSGRET>
      </AUTHORIZATION>
    XML
  end

  def failed_authorize_response
    <<-XML
      <?xml version=”1.0” encoding=”utf-8”?>
      <AUTHORIZATION>
        <CODRET>0</CODRET>
        <MSGRET></MSGRET>
        <NUMPEDIDO>123</NUMPEDIDO>
        <DATA>99999999</DATA>
        <NUMAUTOR>4444</NUMAUTOR>
        <NUMCV>1234</NUMCV>
        <NUMAUTENT>5678</NUMAUTENT>
        <NUMSQN>999</NUMSQN>
        <ORIGEM_BIN>XXX</ORIGEM_BIN>
        <CONFCODRET>9</CONFCODRET>
        <CONFMSGRET></CONFMSGRET>
      </AUTHORIZATION>
    XML
  end

  def successful_capture_response
    <<-XML
      <?xml version=”1.0” encoding=”utf-8”?>
      <CONFIRMATION>
        <root>
          <codret>0</codret>
          <msgret></msgret>
        </root>
      </CONFIRMATION>
    XML
  end

  def failed_capture_response
    <<-XML
      <?xml version=”1.0” encoding=”utf-8”?>
      <CONFIRMATION>
        <root>
          <codret>20</codret>
          <msgret>Error message</msgret>
        </root>
      </CONFIRMATION>
    XML
  end

  def successful_refund_response
    <<-XML
    ￼ <?xml version=”1.0” encoding=”utf-8”?>
      <CONFIRMATION>
        <root>
          <codret>0</codret>
          <msgret></msgret>
        </root>
      </CONFIRMATION>
    XML
  end

  def failed_refund_response
    <<-XML
    ￼ <?xml version=”1.0” encoding=”utf-8”?>
      <CONFIRMATION>
        <root>
          <codret>20</codret>
          <msgret>Error message</msgret>
        </root>
      </CONFIRMATION>
    XML
  end

  def successful_void_response
    <<-XML
    ￼ <?xml version=”1.0” encoding=”utf-8”?>
      <CONFIRMATION>
        <root>
          <codret>0</codret>
          <msgret></msgret>
        </root>
      </CONFIRMATION>
    XML
  end

  def failed_void_response
    <<-XML
    ￼ <?xml version=”1.0” encoding=”utf-8”?>
      <CONFIRMATION>
        <root>
          <codret>20</codret>
          <msgret>Error message</msgret>
        </root>
      </CONFIRMATION>
    XML
  end
end
