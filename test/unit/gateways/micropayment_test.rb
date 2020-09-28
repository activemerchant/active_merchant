require 'test_helper'

class MicropaymentTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = MicropaymentGateway.new(
      access_key: "key"
    )

    @credit_card = credit_card
    @amount = 100
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |endpoint, data, headers|
      assert_match(/accessKey=key/, data)
      assert_match(/number=#{@credit_card.number}/, data)
      assert_match(/cvc2=#{@credit_card.verification_value}/, data)
      assert_match(/amount=#{@amount}/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal "CCadc2b593ca98bfd730c383582de00faed995b0|www.spreedly.com-IDhm7nyju168", response.authorization
    assert response.test?
  end

  def test_failed_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(failed_purchase_response)

    assert_failure response
    assert_equal "AS stellt falsches Routing fest", response.message
    assert response.test?
  end

  def test_successful_authorize_and_capture
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.check_request do |endpoint, data, headers|
      assert_match(/accessKey=key/, data)
      assert_match(/number=#{@credit_card.number}/, data)
      assert_match(/cvc2=#{@credit_card.verification_value}/, data)
      assert_match(/amount=#{@amount}/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal "CC747358d9598614c3ba1e9a7b82a28318cd81bc|www.spreedly.com-IDhngtaj81a1", response.authorization

    capture = stub_comms do
      @gateway.capture(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/accessKey=key/, data)
      assert_match(/transactionId=www.spreedly.com-IDhngtaj81a1/, data)
      assert_match(/sessionId=CC747358d9598614c3ba1e9a7b82a28318cd81bc/, data)
      assert_match(/amount=#{@amount}/, data)
    end.respond_with(successful_capture_response)

    assert_success capture
  end

  def test_failed_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(failed_authorize_response)

    assert_failure response
    assert_equal "AS stellt falsches Routing fest", response.message
    assert response.test?
  end

  def test_failed_capture
    response = stub_comms do
      @gateway.capture(100, "")
    end.respond_with(failed_capture_response)

    assert_failure response
  end

  def test_successful_void
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response

    void = stub_comms do
      @gateway.void(response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/accessKey=key/, data)
      assert_match(/transactionId=www.spreedly.com-IDhngtaj81a1/, data)
      assert_match(/sessionId=CC747358d9598614c3ba1e9a7b82a28318cd81bc/, data)
    end.respond_with(successful_void_response)

    assert_success void
  end

  def test_failed_void
    response = stub_comms do
      @gateway.void("")
    end.respond_with(failed_void_response)

    assert_failure response
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response

    refund = stub_comms do
      @gateway.refund(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/accessKey=key/, data)
      assert_match(/transactionId=www.spreedly.com-IDhm7nyju168/, data)
      assert_match(/sessionId=CCadc2b593ca98bfd730c383582de00faed995b0/, data)
      assert_match(/amount=#{@amount}/, data)
    end.respond_with(successful_refund_response)

    assert_success refund
  end

  def test_failed_refund
    response = stub_comms do
      @gateway.refund(nil, "")
    end.respond_with(failed_refund_response)

    assert_failure response
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(successful_authorize_response, failed_void_response)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_failed_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(failed_authorize_response, successful_void_response)
    assert_failure response
    assert_equal "AS stellt falsches Routing fest", response.message
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  private

  def invalid_login_response
    %(error=3000\nerrorMessage=Authorization+failed+-+Reason%3A+accesskey+wrong)
  end

  def successful_purchase_response
    %(error=0\ncustomerId=e003ddc41a0d6786b70e6a74dcf5febf4d1d8419\nsessionId=CCadc2b593ca98bfd730c383582de00faed995b0\nsessionStatus=SUCCESS\ntransactionStatus=SUCCESS\ntransactionId=www.spreedly.com-IDhm7nyju168\ntransactionCreated=2015-08-13+21%3A56%3A34\ntransactionAuth=1c0b99395e34bf545f610c0a3ca4d987\nccCountry=US\nipCountry=AU\ntransactionResultCode=00\ntransactionResultMessage=Funktion+fehlerfrei+durchgef%C3%BChrt\ndataStorageId=e2d932a845fd6c52ee317e4615cd5550)
  end

  def failed_purchase_response
    %(error=0\ncustomerId=e1ad848e79c9efd71626bdf186afa09d6cb93e75\nsessionId=CCf25d76fd2b46975c5ce3600690aafab32f3596\nsessionStatus=FAILED\ntransactionStatus=FAILED\ntransactionId=www.spreedly.com-ID7878kjxq8f\ntransactionCreated=2015-08-13+22%3A03%3A43\ntransactionAuth=4e68e239c74c67bd0242f2ba04783a34\nccCountry=US\nipCountry=AU\ntransactionResultCode=ipg92\ntransactionResultMessage=AS+stellt+falsches+Routing+fest\ndataStorageId=e2d932a845fd6c52ee317e4615cd5550)
  end

  def successful_authorize_response
    %(error=0\ncustomerId=4b527481457abafc15f3c96f5c5b6109f708d9c6\nsessionId=CC747358d9598614c3ba1e9a7b82a28318cd81bc\nsessionStatus=SUCCESS\ntransactionStatus=SUCCESS\ntransactionId=www.spreedly.com-IDhngtaj81a1\ntransactionCreated=2015-08-13+22%3A23%3A39\ntransactionAuth=df5e0d54694e12b48b95ad26e676b70a\nccCountry=US\nipCountry=AU\ntransactionResultCode=00\ntransactionResultMessage=Funktion+fehlerfrei+durchgef%C3%BChrt\ndataStorageId=e2d932a845fd6c52ee317e4615cd5550)
  end

  def failed_authorize_response
    %(error=0\ncustomerId=98d94168a1ae360e18c78d29a40e44d67a76e9ab\nsessionId=CC4a4396dd378b7470704e2d9d5fb403df1c57c0\nsessionStatus=FAILED\ntransactionStatus=FAILED\ntransactionId=www.spreedly.com-ID7ngsk9bkcq\ntransactionCreated=2015-08-13+22%3A37%3A28\ntransactionAuth=62b6bcd74130aff939d04e9638ae3a9e\nccCountry=US\nipCountry=AU\ntransactionResultCode=ipg92\ntransactionResultMessage=AS+stellt+falsches+Routing+fest\ndataStorageId=e2d932a845fd6c52ee317e4615cd5550)
  end

  def successful_capture_response
    %(error=0\nsessionStatus=SUCCESS\ntransactionStatus=SUCCESS\ntransactionId=www.spreedly.com-IDhngtaj81a1%231\ntransactionCreated=2015-08-13+22%3A23%3A41\ntransactionAuth=df5e0d54694e12b48b95ad26e676b70a\nccCountry=US\nipCountry=AU\ntransactionResultCode=00\ntransactionResultMessage=Funktion+fehlerfrei+durchgef%C3%BChrt\ndataStorageId=e2d932a845fd6c52ee317e4615cd5550)
  end

  def failed_capture_response
    %(error=3110\nerrorMessage=%22sessionId%22+with+the+value+%221%22+does+not+exist)
  end

  def successful_void_response
    %(error=0\nsessionStatus=SUCCESS\ntransactionStatus=SUCCESS\ntransactionId=www.spreedly.com-IDg8za20ugv4%231\ntransactionCreated=2015-08-17+20%3A32%3A36\ntransactionAuth=698f2fb02df442828316c7f50dba7e10\ntransactionResultCode=00\ntransactionResultMessage=Funktion+fehlerfrei+durchgef%C3%BChrt\ndataStorageId=e2d932a845fd6c52ee317e4615cd5550)
  end

  def failed_void_response
    %(error=3101\nerrorMessage=%22sessionId%22+is+empty)
  end

  def successful_refund_response
    %(error=0\nsessionStatus=SUCCESS\ntransactionStatus=SUCCESS\ntransactionId=www.spreedly.com-ID7nf7n0yf86%231\ntransactionCreated=2015-08-17+20%3A36%3A45\ntransactionAuth=2dd36e70e5d74c7318ed1e27cd1f1efa\nccCountry=US\nipCountry=AU\ntransactionResultCode=00\ntransactionResultMessage=Funktion+fehlerfrei+durchgef%C3%BChrt\ndataStorageId=e2d932a845fd6c52ee317e4615cd5550)
  end

  def failed_refund_response
    %(error=3101\nerrorMessage=%22sessionId%22+is+empty)
  end

  def successful_credit_response
    %()
  end

  def failed_credit_response
    %()
  end

  def successful_store_response
    %()
  end

  def failed_store_response
    %()
  end

  def transcript
    %(amount=250&currency=EUR&project=sprdly&firstname=Longbob&surname=Longsen&number=4111111111111111&cvc2=666&expiryYear=2016&expiryMonth=09&ip=1.1.1.1&sendMail=false&testMode=1&accessKey=0b4832ca37a31e748c4490b58d743986)
  end

  def scrubbed_transcript
    %(amount=250&currency=EUR&project=sprdly&firstname=Longbob&surname=Longsen&number=[FILTERED]&cvc2=[FILTERED]&expiryYear=2016&expiryMonth=09&ip=1.1.1.1&sendMail=false&testMode=1&accessKey=[FILTERED])
  end
end
