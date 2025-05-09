require 'test_helper'

class OppTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = OppGateway.new(fixtures(:opp))
    @amount = 100

    @valid_card = credit_card('4200000000000000', month: 05, year: Date.today.year + 2, verification_value: '123')
    @invalid_card = credit_card('4444444444444444', month: 05, year: Date.today.year + 2, verification_value: '123')

    request_type = 'complete' # 'minimal' || 'complete'
    time = Time.now.to_i
    ip = '101.102.103.104'
    @complete_request_options = {
      order_id: "Order #{time}",
      merchant_transaction_id: "active_merchant_test_complete #{time}",
      address:,
      description: 'Store Purchase - Books',
      #      risk_workflow: true,
      #      test_mode: 'EXTERNAL' # or 'INTERNAL', valid only for test system

      billing_address: {
        name:     'Billy Billing',
        address1: 'My Street On the Moon, Apt 42/3.14',
        city:     'Istambul',
        state:    'IS',
        zip:      'H12JK2354',
        country:  'TR'
      },
      shipping_address: {
        name:     '',
        address1: 'My Street On Upiter, Apt 3.14/2.78',
        city:     'Moskau',
        state:    'MO',
        zip:      'MO2342432',
        country:  'RU'
      },
      customer: {
        merchant_customer_id:  "merchantCustomerId #{ip}",
        givenname:  'Billy',
        surname:  'Billing',
        birth_date:  '1965-05-01',
        phone:  '(?!?)555-5555',
        mobile:  '(?!?)234-23423',
        email:  'billy.billing@nosuchdeal.com',
        company_name:  'No such deal Ltd.',
        identification_doctype:  'PASSPORT',
        identification_docid:  'FakeID2342431234123',
        ip:
      }
    }

    @minimal_request_options = {
      order_id: "Order #{time}",
      description: 'Store Purchase - Books'
    }

    @complete_request_options['customParameters[SHOPPER_test124TestName009]'] = 'customParameters_test'
    @complete_request_options['customParameters[SHOPPER_otherCustomerParameter]'] = 'otherCustomerParameter_test'

    @test_success_id = '8a82944a4e008ca9014e1273e0696122'
    @test_failure_id = '8a8294494e0078a6014e12b371fb6a8e'

    @options = @minimal_request_options if request_type == 'minimal'
    @options = @complete_request_options if request_type == 'complete'
  end

  # ****************************************** SUCCESSFUL TESTS ******************************************
  def test_successful_purchase
    @gateway.expects(:raw_ssl_request).returns(successful_response('DB', @test_success_id))
    response = @gateway.purchase(@amount, @valid_card, @options)
    assert_success response, 'Failed purchase'
    assert_equal @test_success_id, response.authorization
    assert response.test?
  end

  def test_successful_authorize
    @gateway.expects(:raw_ssl_request).returns(successful_response('PA', @test_success_id))
    response = @gateway.authorize(@amount, @valid_card, @options)
    assert_success response, 'Authorization Failed'
    assert_equal @test_success_id, response.authorization
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:raw_ssl_request).returns(successful_response('PA', @test_success_id))
    auth = @gateway.authorize(@amount, @valid_card, @options)
    assert_success auth, 'Authorization Failed'
    assert_equal @test_success_id, auth.authorization
    assert auth.test?
    @gateway.expects(:raw_ssl_request).returns(successful_response('CP', @test_success_id))
    capt = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capt, 'Capture failed'
    assert_equal @test_success_id, capt.authorization
    assert capt.test?
  end

  def test_successful_refund
    @gateway.expects(:raw_ssl_request).returns(successful_response('DB', @test_success_id))
    purchase = @gateway.purchase(@amount, @valid_card, @options)
    assert_success purchase, 'Purchase failed'
    assert purchase.test?
    @gateway.expects(:raw_ssl_request).returns(successful_response('RF', @test_success_id))
    refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_success refund, 'Refund failed'
    assert_equal @test_success_id, refund.authorization
    assert refund.test?
  end

  def test_successful_void
    @gateway.expects(:raw_ssl_request).returns(successful_response('DB', @test_success_id))
    purchase = @gateway.purchase(@amount, @valid_card, @options)
    assert_success purchase, 'Purchase failed'
    assert purchase.test?
    @gateway.expects(:raw_ssl_request).returns(successful_response('RV', @test_success_id))
    void = @gateway.void(purchase.authorization, @options)
    assert_success void, 'Void failed'
    assert_equal @test_success_id, void.authorization
    assert void.test?
  end

  def test_successful_store
    @gateway.expects(:raw_ssl_request).returns(successful_store_response(@test_success_id))
    store = @gateway.store(@valid_card)
    assert_success store
    assert_equal "Request successfully processed in 'Merchant in Integrator Test Mode'", store.message
    assert_equal @test_success_id, store.authorization
  end

  # ****************************************** FAILURE TESTS ******************************************
  def test_failed_purchase
    @gateway.expects(:raw_ssl_request).returns(failed_response('DB', @test_failure_id))
    response = @gateway.purchase(@amount, @invalid_card, @options)
    assert_failure response
    assert_equal '100.100.101', response.error_code
  end

  def test_failed_authorize
    @gateway.expects(:raw_ssl_request).returns(failed_response('PA', @test_failure_id))
    response = @gateway.authorize(@amount, @invalid_card, @options)
    assert_failure response
    assert_equal '100.100.101', response.error_code
  end

  def test_failed_capture
    @gateway.expects(:raw_ssl_request).returns(failed_response('CP', @test_failure_id))
    response = @gateway.capture(@amount, @invalid_card)
    assert_failure response
    assert_equal '100.100.101', response.error_code
  end

  def test_failed_refund
    @gateway.expects(:raw_ssl_request).returns(failed_response('PF', @test_failure_id))
    response = @gateway.refund(@amount, @test_success_id)
    assert_failure response
    assert_equal '100.100.101', response.error_code
  end

  def test_failed_void
    @gateway.expects(:raw_ssl_request).returns(failed_response('RV', @test_failure_id))
    response = @gateway.void(@test_success_id, @options)
    assert_failure response
    assert_equal '100.100.101', response.error_code
  end

  def test_failed_store
    @gateway.expects(:raw_ssl_request).returns(failed_store_response(@test_failure_id))
    store = @gateway.store(@invalid_card)
    assert_failure store
    assert_equal '100.100.101', store.error_code
  end

  def test_passes_3d_secure_fields
    options = @complete_request_options.merge({ eci: 'eci', cavv: 'cavv', xid: 'xid' })

    response = stub_comms(@gateway, :raw_ssl_request) do
      @gateway.purchase(@amount, @valid_card, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/threeDSecure.eci=eci/, data)
      assert_match(/threeDSecure.verificationId=cavv/, data)
      assert_match(/threeDSecure.xid=xid/, data)
    end.respond_with(successful_response('DB', @test_success_id))

    assert_success response
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    'paymentType=DB&amount=1.00&currency=EUR&descriptor=&merchantInvoiceId=&merchantTransactionId=50b5c1763c20c456a6208f7831dd0a04&paymentBrand=VISA&card.holder=Longbob+Longsen&card.number=4200000000000000&card.expiryMonth=05&card.expiryYear=2022&card.cvv=123&customParameters[SHOPPER_pluginId]=activemerchant&authentication.entityId=5c6602174b7ecb28014b96992'
  end

  def post_scrubbed
    'paymentType=DB&amount=1.00&currency=EUR&descriptor=&merchantInvoiceId=&merchantTransactionId=50b5c1763c20c456a6208f7831dd0a04&paymentBrand=VISA&card.holder=Longbob+Longsen&card.number=[FILTERED]&card.expiryMonth=05&card.expiryYear=2022&card.cvv=[FILTERED]&customParameters[SHOPPER_pluginId]=activemerchant&authentication.entityId=5c6602174b7ecb28014b96992'
  end

  def successful_response(type, id)
    OppMockResponse.new(
      200,
      JSON.generate({
        'id' => id,
        'paymentType' => type,
        'paymentBrand' => 'VISA',
        'amount' => '1.00',
        'currency' => 'EUR',
        'descriptor' => '5410.9959.0306 OPP_Channel',
        'result' => {
          'code' => '000.100.110',
          'description' => "Request successfully processed in 'Merchant in Integrator Test Mode'"
        },
        'card' => {
          'bin' => '420000',
          'last4Digits' => '0000',
          'holder' => 'Longbob Longsen',
          'expiryMonth' => '05',
          'expiryYear' => '2018'
        },
        'buildNumber' => '20150618-111601.r185004.opp-tags-20150618_stage',
        'timestamp' => '2015-06-20 19:31:01+0000',
        'ndc' => '8a8294174b7ecb28014b9699220015ca_4453edbc001f405da557c05cb3c3add9'
      })
    )
  end

  def successful_store_response(id)
    OppMockResponse.new(
      200,
      JSON.generate({
        'id' => id,
        'result' => {
          'code' => '000.100.110',
          'description' => "Request successfully processed in 'Merchant in Integrator Test Mode'"
        },
        'card' => {
          'bin' => '420000',
          'last4Digits' => '0000',
          'holder' => 'Longbob Longsen',
          'expiryMonth' => '05',
          'expiryYear' => '2018'
        },
        'buildNumber' => '20150618-111601.r185004.opp-tags-20150618_stage',
        'timestamp' => '2015-06-20 19:31:01+0000',
        'ndc' => '8a8294174b7ecb28014b9699220015ca_4453edbc001f405da557c05cb3c3add9'
      })
    )
  end

  def failed_response(type, id, code = '100.100.101')
    OppMockResponse.new(
      400,
      JSON.generate({
        'id' => id,
        'paymentType' => type,
        'paymentBrand' => 'VISA',
        'result' => {
          'code' => code,
          'description' => 'invalid creditcard, bank account number or bank name'
        },
        'card' => {
          'bin' => '444444',
          'last4Digits' => '4444',
          'holder' => 'Longbob Longsen',
          'expiryMonth' => '05',
          'expiryYear' => '2018'
        },
        'buildNumber' => '20150618-111601.r185004.opp-tags-20150618_stage',
        'timestamp' => '2015-06-20 20:40:26+0000',
        'ndc' => '8a8294174b7ecb28014b9699220015ca_5200332e7d664412a84ed5f4777b3c7d'
      })
    )
  end

  def failed_store_response(id, code = '100.100.101')
    OppMockResponse.new(
      400,
      JSON.generate({
        'id' => id,
        'result' => {
          'code' => code,
          'description' => 'invalid creditcard, bank account number or bank name'
        },
        'card' => {
          'bin' => '444444',
          'last4Digits' => '4444',
          'holder' => 'Longbob Longsen',
          'expiryMonth' => '05',
          'expiryYear' => '2018'
        },
        'buildNumber' => '20150618-111601.r185004.opp-tags-20150618_stage',
        'timestamp' => '2015-06-20 20:40:26+0000',
        'ndc' => '8a8294174b7ecb28014b9699220015ca_5200332e7d664412a84ed5f4777b3c7d'
      })
    )
  end

  class OppMockResponse
    attr_reader :code, :body

    def initialize(code, body)
      @code = code
      @body = body
    end
  end
end
