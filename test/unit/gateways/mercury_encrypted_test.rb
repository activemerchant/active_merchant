require 'test_helper'

class MercuryEncryptedTest < Test::Unit::TestCase

  def setup
    @gateway = MercuryEncryptedGateway.new(fixtures(:mercury_encrypted))
    @amount = 100
    @declined_amount = 2401
    @swiper_output   = "%B4003000050006781^TEST/MPS^19120000000000000?;4003000050006781=19120000000000000000?|0600|7EFC7CD505B74493DC4B01B8506E7B927B947ED2EDBF34E8DB470909238BC1ABAB007BFBB5395A730A48BFC2CD021260|9EF440CE67CAD230A307B5581F063AB8B8971E32F26F7CC64C2C15A274B8BD0E220334C8E964E719||61401000|C95DAB4041E723946C54A63066108634DD24A93E587BDDCF49A0459C5649464B6ABFE8CB714AEB4B3B7F7F803E22548B7E23292200F92D74|B29C0D1120214AA|8BCE84619C673F4F|9012090B29C0D1000003|D860||1000"
    @options = {
      invoice_no: "1",
      ref_no: "1",
      merchant: 'test',
      lane_id: '100',
      description: "ActiveMerchant Mercury E2E Test",
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @swiper_output, @options)
    assert_success response

    assert response.authorization.present?
    assert_equal "1.00", response.params["Purchase"]
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@declined_amount, @swiper_output, @options)

    assert_failure response
    assert_equal "DECLINE", response.message
    assert response.test?
  end

  def test_successful_authorize_and_capture
    @gateway.expects(:ssl_post).twice.returns(successful_authorize_response, successful_capture_response)

    auth = @gateway.authorize(@amount, @swiper_output, @options)
    assert_success auth
    assert_equal "PreAuth", auth.params["TranCode"]
    assert_equal "1.00", auth.params["Authorize"]

    opts = @options.merge({ auth_code: auth.params["AuthCode"], acq_ref_data: auth.params["AcqRefData"] })
    assert capture = @gateway.capture(@amount, auth.authorization, opts)
    assert_success capture
    assert_equal "Captured", capture.params["CaptureStatus"]
    assert_equal "1.00", capture.params["Authorize"]
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@declined_amount, @swiper_output, @options)
    assert_failure response
    assert_equal 'DECLINE', response.message
  end

  def test_partial_capture
    @gateway.expects(:ssl_post).twice.returns(successful_authorize_response, successful_partial_capture_response)

    auth = @gateway.authorize(@amount, @swiper_output, @options)
    assert_success auth

    opts = @options.merge({ auth_code: auth.params["AuthCode"], acq_ref_data: auth.params["AcqRefData"] })
    assert capture = @gateway.capture(@amount-1, auth.authorization, opts)
    assert_success capture
    assert_equal "Captured", capture.params["CaptureStatus"]
    assert_equal "0.99", capture.params["Authorize"]
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).twice.returns(failed_authorize_response, failed_capture_response)

    auth = @gateway.authorize(@declined_amount, @swiper_output, @options)
    assert_failure auth
    
    opts = @options.merge({ auth_code: auth.params["AuthCode"], acq_ref_data: auth.params["AcqRefData"] })
    response = @gateway.capture(@declined_amount, auth.authorization, opts)
    assert_failure response
    assert_equal "Invalid Field - Auth Code", response.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).twice.returns(successful_purchase_response, successful_refund_response)

    purchase = @gateway.purchase(@amount, @swiper_output, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_success refund
    assert_equal "Return", refund.params["TranCode"]
  end

  def test_partial_refund
    @gateway.expects(:ssl_post).twice.returns(successful_purchase_response, successful_partial_refund_response)

    purchase = @gateway.purchase(@amount, @swiper_output, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization, @options)
    assert_success refund
    assert_equal "Return", refund.params["TranCode"]
    assert_equal "0.99", refund.params["Purchase"]
  end

  def test_successful_void
    @gateway.expects(:ssl_post).twice.returns(successful_purchase_response, successful_void_response)
    
    sale = @gateway.purchase(@amount, @swiper_output, @options)
    assert_success sale

    opts = @options.merge({
        auth_code: sale.params["AuthCode"],
        ref_no: sale.params["RefNo"],
        purchase: @amount })
    assert void = @gateway.void(sale.authorization, opts)
    assert_success void
    assert_equal "VOIDED", void.params["AuthCode"]
  end

  def test_failed_void
    @gateway.expects(:ssl_post).twice.returns(successful_purchase_response, failed_void_response)
    
    sale = @gateway.purchase(@amount, @swiper_output, @options)
    assert_success sale

    opts = @options.merge({
        auth_code: sale.params["AuthCode"],
        ref_no: sale.params["RefNo"],
        purchase: @declined_amount })
    response = @gateway.void(sale.authorization, opts)
    assert_failure response
    assert_equal 'INV AMT MATCH', response.message
  end

  private

  def successful_purchase_response
    "ResponseOrigin=Processor&DSIXReturnCode=000000&CmdStatus=Approved&TextResponse=AP&MerchantID=118725340908147&AcctNo=400300XXXXXX6781&ExpDate=XXXX&CardType=VISA&TranCode=Sale&AuthCode=VI0100&CaptureStatus=Captured&RefNo=0023&InvoiceNo=1&Memo=ActiveMerchant+Mercury+E2E+Test&Purchase=1.00&Authorize=1.00&AcqRefData=aEb015188177000483cABCAd5e00fJlA++m000005&RecordNo=shftcrAVgTxYHkG81Pg0IWdpxwlDyUe6TA0I5NcmLB0iEgUQECIQGJHU&ProcessData=%7c00%7c210100200000"
  end

  def failed_purchase_response
    "ResponseOrigin=Processor&DSIXReturnCode=000000&CmdStatus=Declined&TextResponse=DECLINE&MerchantID=118725340908147&AcctNo=400300XXXXXX6781&ExpDate=XXXX&CardType=VISA&TranCode=Sale&RefNo=1&InvoiceNo=1&Memo=ActiveMerchant+Mercury+E2E+Test&Purchase=24.01&Authorize=24.01&RecordNo=Mkqt9jm3Ieq1us5p5kRLLWB2e1cz0G%2bPaOPz7mC1PQ0iEgUQECIQGJHl&ProcessData=%7c00%7c210100200000"
  end

  def successful_authorize_response
    "ResponseOrigin=Processor&DSIXReturnCode=000000&CmdStatus=Approved&TextResponse=AP&MerchantID=118725340908147&AcctNo=400300XXXXXX6781&ExpDate=XXXX&CardType=VISA&TranCode=PreAuth&AuthCode=VI0100&InvoiceNo=1&Memo=ActiveMerchant+Mercury+E2E+Test&Purchase=1.00&Authorize=1.00&AcqRefData=aEb015188177000668cABCAd5e00fJlA++m000005&RecordNo=HWmDILxnQN5iMqvo0g2Y%2btp2aAaKwlgFVe0PDSNTtaQiEgUQECIQGJHp&ProcessData=%7c14%7c210100200000"
  end

  def failed_authorize_response
    "ResponseOrigin=Processor&DSIXReturnCode=000000&CmdStatus=Declined&TextResponse=DECLINE&MerchantID=118725340908147&AcctNo=400300XXXXXX6781&ExpDate=XXXX&CardType=VISA&TranCode=PreAuth&InvoiceNo=1&Memo=ActiveMerchant+Mercury+E2E+Test&Purchase=24.01&Authorize=24.01&RecordNo=2VIckloKHfxgcFWqm4nIi6aePjtPQOHk4a%2bGuYN2rlkiEgUQECIQGJID&ProcessData=%7c14%7c210100200000"
  end

  def successful_capture_response
    "ResponseOrigin=Processor&DSIXReturnCode=000000&CmdStatus=Approved&TextResponse=AP*&MerchantID=118725340908147&AcctNo=400300XXXXXX6781&ExpDate=XXXX&CardType=VISA&TranCode=PreAuthCapture&AuthCode=VI0100&CaptureStatus=Captured&RefNo=0005&InvoiceNo=1&Memo=ActiveMerchant+Mercury+E2E+Test&Purchase=1.00&Authorize=1.00&AcqRefData=aEb015188177000668cABCAd5e00fJlA++m000005&RecordNo=H3FemaQ%2faMzM4Twue%2frKosfLqZgsZGTKNzXmDh85%2bGUiEgUQECIQGJHs&ProcessData=%7c15%7c210100200000"
  end

  def successful_partial_capture_response
    "ResponseOrigin=Processor&DSIXReturnCode=000000&CmdStatus=Approved&TextResponse=AP*&MerchantID=118725340908147&AcctNo=400300XXXXXX6781&ExpDate=XXXX&CardType=VISA&TranCode=PreAuthCapture&AuthCode=VI0100&CaptureStatus=Captured&RefNo=0003&InvoiceNo=1&Memo=ActiveMerchant+Mercury+E2E+Test&Purchase=0.99&Authorize=0.99&AcqRefData=aEb015188177001524cABCAd5e00fJlA++m000005&RecordNo=fx%2fU7jAqTqf9lwU7sgOZGikiN1nVSa%2fAxaLFVXKYrl4iEgUQECIQGJJR&ProcessData=%7c15%7c210100200000"
  end

  def failed_capture_response
    "ResponseOrigin=Server&DSIXReturnCode=100206&CmdStatus=Error&TextResponse=Invalid+Field+-+Auth+Code"
  end

  def successful_refund_response
    "ResponseOrigin=Processor&DSIXReturnCode=000000&CmdStatus=Approved&TextResponse=AP*&MerchantID=118725340908147&AcctNo=400300XXXXXX6781&ExpDate=XXXX&CardType=VISA&TranCode=Return&AuthCode=C17824&CaptureStatus=Captured&RefNo=0006&InvoiceNo=1&Memo=ActiveMerchant+Mercury+E2E+Test&Purchase=1.00&Authorize=1.00&AcqRefData=KaN&RecordNo=p6OObsQq7ICAQ3pmBrax50C1QQ69uB4VJCzWqZ%2brGTsiEgUQECIQGJIN&ProcessData=%7c20%7c210100700000"
  end

  def successful_partial_refund_response
    "ResponseOrigin=Processor&DSIXReturnCode=000000&CmdStatus=Approved&TextResponse=AP*&MerchantID=118725340908147&AcctNo=400300XXXXXX6781&ExpDate=XXXX&CardType=VISA&TranCode=Return&AuthCode=C17714&CaptureStatus=Captured&RefNo=0004&InvoiceNo=1&Memo=ActiveMerchant+Mercury+E2E+Test&Purchase=0.99&Authorize=0.99&AcqRefData=KaN&RecordNo=8LgNj0iJFyAUNRUhcXGEYRSptmev1AeMf35VdEaBooMiEgUQECIQGJJI&ProcessData=%7c20%7c210100700000"
  end

  def successful_void_response
    "ResponseOrigin=Processor&DSIXReturnCode=000000&CmdStatus=Approved&TextResponse=AP&MerchantID=118725340908147&AcctNo=400300XXXXXX6781&ExpDate=XXXX&CardType=VISA&TranCode=VoidSale&AuthCode=VOIDED&CaptureStatus=Captured&RefNo=0023&InvoiceNo=1&Memo=ActiveMerchant+Mercury+E2E+Test&Purchase=1.00&Authorize=1.00&AcqRefData=KaNb015188177000879cABCAd5e00fJj455734150707072119lA++m000005&RecordNo=kA%2fHGw%2fr0KbMIWvxQKwZPGhz%2b3F2kgwYuWsgxJ2%2bJgQiEgUQECIQGJIV&ProcessData=%7cA4%7c210100600000"
  end

  def failed_void_response
    "ResponseOrigin=Processor&DSIXReturnCode=000000&CmdStatus=Declined&TextResponse=INV+AMT+MATCH&MerchantID=118725340908147&AcctNo=400300XXXXXX6781&ExpDate=XXXX&CardType=VISA&TranCode=VoidSale&AuthCode=VI0100&RefNo=0024&InvoiceNo=1&Memo=ActiveMerchant+Mercury+E2E+Test&Purchase=24.01&Authorize=24.01&AcqRefData=KaY&RecordNo=WifH5Isxb%2fVYB6sq0za4BmpYZNdvDocp9xn%2fsKbv%2fMciEgUQECIQGJIX&ProcessData=%7cA4%7c210100600000"
  end
end
