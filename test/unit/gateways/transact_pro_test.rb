require 'test_helper'

class TransactProTest < Test::Unit::TestCase
  def setup
    @gateway = TransactProGateway.new(
      guid: 'login',
      password: 'password',
      terminal: 'terminal',
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
    @gateway.expects(:ssl_post).twice.returns(successful_init_response, successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'a27891dedd57e875df653144c518b8fb646b2351|100', response.authorization
    assert_equal 'Success', response.message
    assert_equal 'a27891dedd57e875df653144c518b8fb646b2351', response.params['id']
    assert_equal '646391', response.params['approval_code']
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).twice.returns(successful_init_response, failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'fed54b10b610bb760816aad42721672e8fd19327|100', response.authorization
    assert_equal 'Failed', response.message
    assert_equal '908', response.params['result_code']
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).twice.returns(successful_init_response, successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
    assert_equal '3d25ab044075924479d3836f549b015481d15d74|100', response.authorization
    assert_equal 'HoldOk', response.message
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).twice.returns(successful_init_response, failed_authorize_response)

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_failure response
    assert_equal 'c9c789a575ba8556e2c5f56174d859c23ac56e09|100', response.authorization
    assert_equal 'Failed', response.message
    assert_equal '908', response.params['result_code']
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    capture = @gateway.capture(nil, '3d25ab044075924479d3836f549b015481d15d74|100')
    assert_success capture
    assert_equal '3d25ab044075924479d3836f549b015481d15d74|100', capture.authorization
    assert_equal 'Success', capture.message
  end

  def test_partial_capture
    @gateway.expects(:ssl_post).never

    assert_raise(ArgumentError) do
      @gateway.capture(@amount-1, '3d25ab044075924479d3836f549b015481d15d74|100')
    end
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    capture = @gateway.capture(nil, '3d25ab044075924479d3836f549b015481d15d74|100')
    assert_failure capture
    assert_equal "4dd02f79f428470bbd794590834dfbf38b5721ac|100", capture.authorization
    assert_equal 'Failed', capture.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    assert refund = @gateway.refund(@amount, '3d25ab044075924479d3836f549b015481d15d74|100')
    assert_success refund
    assert_equal 'Refund Success', refund.message
    assert_equal '3d25ab044075924479d3836f549b015481d15d74', refund.authorization
  end

  def test_partial_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    assert refund = @gateway.refund(@amount-1, '3d25ab044075924479d3836f549b015481d15d74|100')
    assert_success refund
    assert_equal 'Refund Success', refund.message
    assert_equal '3d25ab044075924479d3836f549b015481d15d74', refund.authorization
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    assert refund = @gateway.refund(@amount+1, '3d25ab044075924479d3836f549b015481d15d74|100')
    assert_failure refund
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert void = @gateway.void('3d25ab044075924479d3836f549b015481d15d74|100')
    assert_success void
    assert_equal '3d25ab044075924479d3836f549b015481d15d74', void.authorization
    assert_equal 'DMS canceled OK', void.message
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    void = @gateway.void('')
    assert_failure void
    assert_match %r{fail}i, void.message
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).times(3).returns(successful_init_response, successful_authorize_response, successful_void_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
  end

  def test_successful_verify_with_failed_void
    @gateway.expects(:ssl_post).times(3).returns(successful_init_response, successful_authorize_response, failed_void_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).times(2).returns(successful_init_response, failed_authorize_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
  end

  private

  def successful_purchase_response
    "ID:a27891dedd57e875df653144c518b8fb646b2351~Status:Success~MerchantID:1410896668~Terminal:Rietumu - non3D~ResultCode:000~ApprovalCode:646391~CardIssuerCountry:XX"
  end

  def failed_purchase_response
    "ID:fed54b10b610bb760816aad42721672e8fd19327~Status:Failed~MerchantID:1410965369~Terminal:Rietumu - non3D~ResultCode:908~ApprovalCode:-3~CardIssuerCountry:XX"
  end

  def successful_authorize_response
    "ID:3d25ab044075924479d3836f549b015481d15d74~Status:HoldOk~MerchantID:1410974273~Terminal:Rietumu - non3D~ResultCode:000~ApprovalCode:524282~CardIssuerCountry:XX"
  end

  def failed_authorize_response
    "ID:c9c789a575ba8556e2c5f56174d859c23ac56e09~Status:Failed~MerchantID:1410974976~Terminal:Rietumu - non3D~ResultCode:908~ApprovalCode:-3~CardIssuerCountry:XX"
  end

  def successful_capture_response
    "ID:3d25ab044075924479d3836f549b015481d15d74~Status:Success~MerchantID:1410974273~Terminal:Rietumu - non3D~ResultCode:000~ApprovalCode:524282~CardIssuerCountry:XX"
  end

  def failed_capture_response
    "ID:4dd02f79f428470bbd794590834dfbf38b5721ac~Status:Failed~MerchantID:1325788706~Terminal:TerminalName~ResultCode:000~ApprovalCode:804958"
  end

  def successful_refund_response
    "Refund Success"
  end

  def failed_refund_response
    "1411048562:Multiple refund requests 'b8828586f5ece2874e26e8ac021f410610b6f921' detected, please wait 3 minutes and try again:"
  end

  def successful_void_response
    "DMS canceled OK"
  end

  def failed_void_response
    "DMS Cancel failed"
  end

  def successful_init_response
    "OK:a27891dedd57e875df653144c518b8fb646b2351"
  end
end
