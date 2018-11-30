require 'test_helper'

class UsaEpayTransactionTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = UsaEpayTransactionGateway.new(:login => 'LOGIN')

    @credit_card = credit_card('4242424242424242')
    @check = check
    @options = {
      :billing_address  => address,
      :shipping_address => address
    }
    @amount = 100
  end

  def test_urls
    assert_equal 'https://www.usaepay.com/gate',      UsaEpayTransactionGateway.live_url
    assert_equal 'https://sandbox.usaepay.com/gate',  UsaEpayTransactionGateway.test_url
  end

  def test_request_url_live
    gateway = UsaEpayTransactionGateway.new(:login => 'LOGIN', :test => false)
    gateway.expects(:ssl_post).
      with('https://www.usaepay.com/gate', regexp_matches(Regexp.new('^' + Regexp.escape(purchase_request)))).
      returns(successful_purchase_response)
    gateway.purchase(@amount, @credit_card, @options)
  end

  def test_request_url_test
    @gateway.expects(:ssl_post).
      with('https://sandbox.usaepay.com/gate', regexp_matches(Regexp.new('^' + Regexp.escape(purchase_request)))).
      returns(successful_purchase_response)
    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_successful_request
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '55074409', response.authorization
    assert response.test?
  end

  def test_successful_request_with_echeck
    @gateway.expects(:ssl_post).returns(successful_purchase_response_echeck)

    response = @gateway.purchase(@amount, @check, @options)
    assert_success response
    assert_equal '133134803', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_echeck_and_extra_options
    response = stub_comms do
      @gateway.purchase(@amount, @check, @options.merge(check_format: 'ARC', account_type: 'savings'))
    end.check_request do |endpoint, data, headers|
      assert_match(/UMcheckformat=ARC/, data)
      assert_match(/UMaccounttype=savings/, data)
    end.respond_with(successful_purchase_response_echeck)

    assert_equal 'Success', response.message
    assert_equal '133134803', response.authorization
    assert_success response
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(unsuccessful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_purchase_passing_extra_info
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(:order_id => '1337', :description => 'socool'))
    end.check_request do |endpoint, data, headers|
      assert_match(/UMinvoice=1337/, data)
      assert_match(/UMdescription=socool/, data)
      assert_match(/UMtestmode=0/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_successful_purchase_passing_extra_test_mode
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(:test_mode => true))
    end.check_request do |endpoint, data, headers|
      assert_match(/UMtestmode=1/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_successful_purchase_email_receipt
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(:email => 'bobby@hill.com', :cust_receipt => 'Yes', :cust_receipt_name => 'socool'))
    end.check_request do |endpoint, data, headers|
      assert_match(/UMcustreceipt=Yes/, data)
      assert_match(/UMcustreceiptname=socool/, data)
      assert_match(/UMtestmode=0/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_successful_purchase_split_payment
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(
        :split_payments => [
          { :key => 'abc123', :amount => 199, :description => 'Second payee' },
          { :key => 'def456', :amount => 911, :description => 'Third payee' },
        ]
      ))
    end.check_request do |endpoint, data, headers|
      assert_match %r{UM02key=abc123},                data
      assert_match %r{UM02amount=1.99},               data
      assert_match %r{UM02description=Second\+payee}, data

      assert_match %r{UM03key=def456},                data
      assert_match %r{UM03amount=9.11},               data
      assert_match %r{UM03description=Third\+payee},  data

      assert_match %r{UMonError=Void},                data
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_successful_purchase_split_payment_with_custom_on_error
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(
        :split_payments => [
          { :key => 'abc123', :amount => 199, :description => 'Second payee' }
        ],
        :on_error => 'Continue'
      ))
    end.check_request do |endpoint, data, headers|
      assert_match %r{UMonError=Continue}, data
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_successful_purchase_recurring_fields
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(
        :recurring_fields => {
          add_customer: true,
          schedule: 'quarterly',
          bill_source_key: 'bill source key',
          bill_amount: 123,
          num_left: 5,
          start: '20501212',
          recurring_receipt: true
        }
      ))
    end.check_request do |endpoint, data, headers|
      assert_match %r{UMaddcustomer=yes},                 data
      assert_match %r{UMschedule=quarterly},              data
      assert_match %r{UMbillsourcekey=bill\+source\+key}, data
      assert_match %r{UMbillamount=1.23},                 data
      assert_match %r{UMnumleft=5},                       data
      assert_match %r{UMstart=20501212},                  data
      assert_match %r{UMrecurringreceipt=yes},            data
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_successful_purchase_custom_fields
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(
        :custom_fields => {
          1 => 'diablo',
          2 => 'mephisto',
          3 => 'baal'
        }
      ))
    end.check_request do |endpoint, data, headers|
      assert_match %r{UMcustom1=diablo},   data
      assert_match %r{UMcustom2=mephisto}, data
      assert_match %r{UMcustom3=baal},     data
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_successful_purchase_line_items
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(
        :line_items => [
          { :sku=> 'abc123', :cost => 119, :quantity => 1 },
          { :sku => 'def456', :cost => 200, :quantity => 2, :name => 'an item' },
        ]
      ))
    end.check_request do |endpoint, data, headers|
      assert_match %r{UMline0sku=abc123},    data
      assert_match %r{UMline0cost=1.19},     data
      assert_match %r{UMline0qty=1},         data

      assert_match %r{UMline1sku=def456},    data
      assert_match %r{UMline1cost=2.00},     data
      assert_match %r{UMline1qty=2},         data
      assert_match %r{UMline1name=an\+item}, data
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_successful_authorize_request
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal '65074409', response.authorization
    assert response.test?
  end

  def test_successful_authorize_passing_extra_info
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(:order_id => '1337', :description => 'socool'))
    end.check_request do |endpoint, data, headers|
      assert_match(/UMinvoice=1337/, data)
      assert_match(/UMdescription=socool/, data)
      assert_match(/UMtestmode=0/, data)
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_successful_authorize_passing_extra_test_mode
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(:test_mode => true))
    end.check_request do |endpoint, data, headers|
      assert_match(/UMtestmode=1/, data)
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_successful_capture_request
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, '65074409', @options)
    assert_success response
    assert_equal '65074409', response.authorization
    assert response.test?
  end

  def test_successful_capture_passing_extra_info
    response = stub_comms do
      @gateway.capture(@amount, '65074409', @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/UMamount=1.00/, data)
      assert_match(/UMtestmode=0/, data)
    end.respond_with(successful_capture_response)
    assert_success response
  end

  def test_successful_capture_passing_extra_test_mode
    response = stub_comms do
      @gateway.capture(@amount, '65074409', @options.merge(:test_mode => true))
    end.check_request do |endpoint, data, headers|
      assert_match(/UMtestmode=1/, data)
    end.respond_with(successful_capture_response)
    assert_success response
  end

  def test_successful_refund_request
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, '65074409', @options)
    assert_success response
    assert_equal '63813138', response.authorization
    assert response.test?
  end

  def test_successful_refund_request_with_echeck
    @gateway.expects(:ssl_post).returns(successful_refund_response_echeck)

    response = @gateway.refund(@amount, '65074409', @options)
    assert_success response
    assert_equal '133134926', response.authorization
    assert response.test?
  end

  def test_successful_refund_passing_extra_info
    response = stub_comms do
      @gateway.refund(@amount, '65074409', @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/UMamount=1.00/, data)
      assert_match(/UMtestmode=0/, data)
    end.respond_with(successful_refund_response)
    assert_success response
  end

  def test_successful_refund_passing_extra_test_mode
    response = stub_comms do
      @gateway.refund(@amount, '65074409', @options.merge(:test_mode => true))
    end.check_request do |endpoint, data, headers|
      assert_match(/UMtestmode=1/, data)
    end.respond_with(successful_refund_response)
    assert_success response
  end

  def test_successful_void_request
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void('65074409', @options)
    assert_success response
    assert_equal '63812270', response.authorization
    assert response.test?
  end

  def test_successful_void_request_with_echeck
    @gateway.expects(:ssl_post).returns(successful_void_response_echeck)

    response = @gateway.void('65074409', @options)
    assert_success response
    assert_equal '133134971', response.authorization
    assert response.test?
  end

  def test_successful_void_passing_extra_info
    response = stub_comms do
      @gateway.void('65074409', @options.merge(:no_release => true))
    end.check_request do |endpoint, data, headers|
      assert_match(/UMcommand=cc%3Avoid/, data)
      assert_match(/UMtestmode=0/, data)
    end.respond_with(successful_void_response)
    assert_success response
  end

  def test_successful_void_passing_extra_test_mode
    response = stub_comms do
      @gateway.refund(@amount, '65074409', @options.merge(:test_mode => true))
    end.check_request do |endpoint, data, headers|
      assert_match(/UMtestmode=1/, data)
    end.respond_with(successful_void_response)
    assert_success response
  end

  def test_address_key_prefix
    assert_equal 'bill', @gateway.send(:address_key_prefix, :billing)
    assert_equal 'ship', @gateway.send(:address_key_prefix, :shipping)
    assert_nil @gateway.send(:address_key_prefix, :vacation)
  end

  def test_address_key
    assert_equal :shipfname, @gateway.send(:address_key, 'ship', 'fname')
  end

  def test_add_address
    post = {}
    @gateway.send(:add_address, post, @credit_card, @options)
    assert_address(:shipping, post)
    assert_equal 20, post.keys.size
  end

  def test_add_billing_address
    post = {}
    @gateway.send(:add_address, post, @credit_card, @options)
    assert_address(:billing, post)
    assert_equal 20, post.keys.size
  end

  def test_add_billing_and_shipping_addresses
    post = {}
    @gateway.send(:add_address, post, @credit_card, @options)
    assert_address(:shipping, post)
    assert_address(:billing, post)
    assert_equal 20, post.keys.size
  end

  def test_add_address_with_empty_billing_and_shipping_names
    post = {}
    @options[:billing_address].delete(:name)
    @options[:shipping_address][:name] = ''

    @gateway.send(:add_address, post, @credit_card, @options)
    assert_address(:shipping, post, 'Longbob', 'Longsen')
    assert_address(:billing, post, 'Longbob', 'Longsen')
    assert_equal 20, post.keys.size
  end

  def test_add_address_with_single_billing_and_shipping_names
    post = {}
    options = {
        :billing_address  => address(:name => 'Smith'),
        :shipping_address => address(:name => 'Longsen')
    }

    @gateway.send(:add_address, post, @credit_card, options)
    assert_address(:billing, post, '', 'Smith')
    assert_address(:shipping, post, '', 'Longsen')
    assert_equal 20, post.keys.size
  end

  def test_add_test_mode_without_test_mode_option
    post = {}
    @gateway.send(:add_test_mode, post, {})
    assert_nil post[:testmode]
  end

  def test_add_test_mode_with_true_test_mode_option
    post = {}
    @gateway.send(:add_test_mode, post, :test_mode => true)
    assert_equal 1, post[:testmode]
  end

  def test_add_test_mode_with_false_test_mode_option
    post = {}
    @gateway.send(:add_test_mode, post, :test_mode => false)
    assert_equal 0, post[:testmode]
  end

  def test_amount_style
    assert_equal '10.34', @gateway.send(:amount, 1034)

    assert_raise(ArgumentError) do
      @gateway.send(:amount, '10.34')
    end
  end

  def test_supported_countries
    assert_equal ['US'], UsaEpayTransactionGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express], UsaEpayTransactionGateway.supported_cardtypes
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Y', response.avs_result['code']
    assert_equal 'Y', response.avs_result['street_match']
    assert_equal 'Y', response.avs_result['postal_match']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'M', response.cvv_result['code']
  end

  def test_add_track_data_with_creditcard
    @credit_card.track_data = 'data'

    @gateway.expects(:ssl_post).with do |_, body|
      body.include?('UMmagstripe=data')
    end.returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_add_track_data_with_empty_data
    ['', nil].each do |data|
      @credit_card.track_data = data

      @gateway.expects(:ssl_post).with do |_, body|
        refute body.include? 'UMmagstripe='
        body
      end.returns(successful_purchase_response)

      assert response = @gateway.purchase(@amount, @credit_card, @options)
      assert_success response
    end
  end

  def test_manual_entry_is_properly_indicated_on_purchase
    @credit_card.manual_entry = true
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match %r{UMcard=4242424242424242},  data
      assert_match %r{UMcardpresent=true},       data
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_does_not_raise_error_on_missing_values
    @gateway.expects(:ssl_post).returns('status')
    assert_nothing_raised do
      response = @gateway.purchase(@amount, @credit_card, @options)
      assert_failure response
    end
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
    assert_equal @gateway.scrub(pre_scrubbed_track_data), post_scrubbed_track_data
    assert_equal @gateway.scrub(pre_scrubbed_echeck), post_scrubbed_echeck
  end

  private

  def assert_address(type, post, expected_first_name = nil, expected_last_name = nil)
    prefix = key_prefix(type)
    first_name, last_name = split_names(@options[:billing_address][:name])
    first_name = expected_first_name if expected_first_name
    last_name = expected_last_name if expected_last_name

    assert_equal first_name,                            post[key(prefix, 'fname')]
    assert_equal last_name,                             post[key(prefix, 'lname')]
    assert_equal @options[:billing_address][:company],  post[key(prefix, 'company')]
    assert_equal @options[:billing_address][:address1], post[key(prefix, 'street')]
    assert_equal @options[:billing_address][:address2], post[key(prefix, 'street2')]
    assert_equal @options[:billing_address][:city],     post[key(prefix, 'city')]
    assert_equal @options[:billing_address][:state],    post[key(prefix, 'state')]
    assert_equal @options[:billing_address][:zip],      post[key(prefix, 'zip')]
    assert_equal @options[:billing_address][:country],  post[key(prefix, 'country')]
    assert_equal @options[:billing_address][:phone],    post[key(prefix, 'phone')]
  end

  def key_prefix(type)
    @gateway.send(:address_key_prefix, type)
  end

  def key(prefix, key)
    @gateway.send(:address_key, prefix, key)
  end

  def split_names(full_name)
    names = (full_name || '').split
    last_name = names.pop
    first_name = names.join(' ')
    [first_name, last_name]
  end

  def purchase_request
    "UMamount=1.00&UMinvoice=&UMdescription=&UMcard=4242424242424242&UMcvv2=123&UMexpir=09#{@credit_card.year.to_s[-2..-1]}&UMname=Longbob+Longsen&UMbillfname=Jim&UMbilllname=Smith&UMbillcompany=Widgets+Inc&UMbillstreet=456+My+Street&UMbillstreet2=Apt+1&UMbillcity=Ottawa&UMbillstate=ON&UMbillzip=K1C2N6&UMbillcountry=CA&UMbillphone=%28555%29555-5555&UMshipfname=Jim&UMshiplname=Smith&UMshipcompany=Widgets+Inc&UMshipstreet=456+My+Street&UMshipstreet2=Apt+1&UMshipcity=Ottawa&UMshipstate=ON&UMshipzip=K1C2N6&UMshipcountry=CA&UMshipphone=%28555%29555-5555&UMstreet=456+My+Street&UMzip=K1C2N6&UMcommand=cc%3Asale&UMkey=LOGIN&UMsoftware=Active+Merchant&UMtestmode=0"
  end

  def successful_purchase_response
    'UMversion=2.9&UMstatus=Approved&UMauthCode=001716&UMrefNum=55074409&UMavsResult=Address%3A%20Match%20%26%205%20Digit%20Zip%3A%20Match&UMavsResultCode=Y&UMcvv2Result=Match&UMcvv2ResultCode=M&UMresult=A&UMvpasResultCode=&UMerror=Approved&UMerrorcode=00000&UMcustnum=&UMbatch=596&UMisDuplicate=N&UMconvertedAmount=&UMconvertedAmountCurrency=840&UMconversionRate=&UMcustReceiptResult=No%20Receipt%20Sent&UMfiller=filled'
  end

  def unsuccessful_purchase_response
    'UMversion=2.9&UMstatus=Declined&UMauthCode=000000&UMrefNum=55076060&UMavsResult=Address%3A%20Match%20%26%205%20Digit%20Zip%3A%20Match&UMavsResultCode=Y&UMcvv2Result=Not%20Processed&UMcvv2ResultCode=P&UMvpasResultCode=&UMresult=D&UMerror=Card%20Declined&UMerrorcode=10127&UMbatch=596&UMfiller=filled'
  end

  def successful_authorize_response
    'UMversion=2.9&UMstatus=Approved&UMauthCode=101716&UMrefNum=65074409&UMavsResult=Address%3A%20Match%20%26%205%20Digit%20Zip%3A%20Match&UMavsResultCode=Y&UMcvv2Result=Match&UMcvv2ResultCode=M&UMresult=A&UMvpasResultCode=&UMerror=Approved&UMerrorcode=00000&UMcustnum=&UMbatch=596&UMisDuplicate=N&UMconvertedAmount=&UMconvertedAmountCurrency=840&UMconversionRate=&UMcustReceiptResult=No%20Receipt%20Sent&UMfiller=filled'
  end

  def successful_capture_response
    'UMversion=2.9&UMstatus=Approved&UMauthCode=101716&UMrefNum=65074409&UMavsResult=No%20AVS%20response%20%28Typically%20no%20AVS%20data%20sent%20or%20swiped%20transaction%29&UMavsResultCode=&UMcvv2Result=No%20CVV2%2FCVC%20data%20available%20for%20transaction.&UMcvv2ResultCode=&UMresult=A&UMvpasResultCode=&UMerror=Approved&UMerrorcode=00000&UMcustnum=&UMbatch=&UMbatchRefNum=&UMisDuplicate=N&UMconvertedAmount=&UMconvertedAmountCurrency=840&UMconversionRate=&UMcustReceiptResult=No%20Receipt%20Sent&UMprocRefNum=&UMcardLevelResult=&UMauthAmount=&UMfiller=filled'
  end

  def successful_refund_response
    'UMversion=2.9&UMstatus=Approved&UMauthCode=101716&UMrefNum=63813138&UMavsResult=Unmapped%20AVS%20response%20%28%20%20%20%29&UMavsResultCode=%20%20%20&UMcvv2Result=No%20CVV2%2FCVC%20data%20available%20for%20transaction.&UMcvv2ResultCode=&UMresult=A&UMvpasResultCode=&UMerror=&UMerrorcode=00000&UMcustnum=&UMbatch=&UMbatchRefNum=&UMisDuplicate=N&UMconvertedAmount=1.00&UMconvertedAmountCurrency=840&UMconversionRate=&UMcustReceiptResult=No%20Receipt%20Sent&UMprocRefNum=&UMcardLevelResult=&UMauthAmount=&UMfiller=filled'
  end

  def successful_void_response
    'UMversion=2.9&UMstatus=Approved&UMauthCode=&UMrefNum=63812270&UMavsResult=No%20AVS%20response%20%28Typically%20no%20AVS%20data%20sent%20or%20swiped%20transaction%29&UMavsResultCode=&UMcvv2Result=No%20CVV2%2FCVC%20data%20available%20for%20transaction.&UMcvv2ResultCode=&UMresult=A&UMvpasResultCode=&UMerror=Transaction%20Voided%20Successfully&UMerrorcode=00000&UMcustnum=&UMbatch=&UMbatchRefNum=&UMisDuplicate=N&UMconvertedAmount=&UMconvertedAmountCurrency=840&UMconversionRate=&UMcustReceiptResult=No%20Receipt%20Sent&UMprocRefNum=&UMcardLevelResult=&UMauthAmount=&UMfiller=filled'
  end

  def successful_purchase_response_echeck
    'UMversion=2.9&UMstatus=Approved&UMauthCode=TMEC4D&UMrefNum=133134803&UMavsResult=No%20AVS%20response%20%28Typically%20no%20AVS%20data%20sent%20or%20swiped%20transaction%29&UMavsResultCode=&UMcvv2Result=No%20CVV2%2FCVC%20data%20available%20for%20transaction.&UMcvv2ResultCode=&UMresult=A&UMvpasResultCode=&UMerror=&UMerrorcode=00000&UMcustnum=&UMbatch=180316&UMbatchRefNum=&UMisDuplicate=N&UMconvertedAmount=&UMconvertedAmountCurrency=840&UMconversionRate=&UMcustReceiptResult=No%20Receipt%20Sent&UMprocRefNum=18031621233065&UMcardLevelResult=&UMauthAmount=&UMfiller=filled'
  end

  def successful_refund_response_echeck
    'UMversion=2.9&UMstatus=Approved&UMauthCode=TM1E74&UMrefNum=133134926&UMavsResult=No%20AVS%20response%20%28Typically%20no%20AVS%20data%20sent%20or%20swiped%20transaction%29&UMavsResultCode=&UMcvv2Result=No%20CVV2%2FCVC%20data%20available%20for%20transaction.&UMcvv2ResultCode=&UMresult=A&UMvpasResultCode=&UMerror=&UMerrorcode=00000&UMcustnum=&UMbatch=&UMbatchRefNum=&UMisDuplicate=N&UMconvertedAmount=&UMconvertedAmountCurrency=840&UMconversionRate=&UMcustReceiptResult=No%20Receipt%20Sent&UMprocRefNum=&UMcardLevelResult=&UMauthAmount=&UMfiller=filled'
  end

  def successful_void_response_echeck
    'UMversion=2.9&UMstatus=Approved&UMauthCode=TM80A5&UMrefNum=133134971&UMavsResult=No%20AVS%20response%20%28Typically%20no%20AVS%20data%20sent%20or%20swiped%20transaction%29&UMavsResultCode=&UMcvv2Result=No%20CVV2%2FCVC%20data%20available%20for%20transaction.&UMcvv2ResultCode=&UMresult=A&UMvpasResultCode=&UMerror=&UMerrorcode=00000&UMcustnum=&UMbatch=&UMbatchRefNum=&UMisDuplicate=N&UMconvertedAmount=&UMconvertedAmountCurrency=840&UMconversionRate=&UMcustReceiptResult=No%20Receipt%20Sent&UMprocRefNum=&UMcardLevelResult=&UMauthAmount=&UMfiller=filled'
  end

  def pre_scrubbed
    <<-EOS
opening connection to sandbox.usaepay.com:443...
opened
starting SSL for sandbox.usaepay.com:443...
SSL established
<- "POST /gate HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: sandbox.usaepay.com\r\nContent-Length: 774\r\n\r\n"
<- "UMamount=1.00&UMinvoice=&UMdescription=&UMcard=4000100011112224&UMcvv2=123&UMexpir=0919&UMname=Longbob+Longsen&UMbillfname=Jim&UMbilllname=Smith&UMbillcompany=Widgets+Inc&UMbillstreet=456+My+Street&UMbillstreet2=Apt+1&UMbillcity=Ottawa&UMbillstate=NC&UMbillzip=27614&UMbillcountry=CA&UMbillphone=%28555%29555-5555&UMshipfname=Jim&UMshiplname=Smith&UMshipcompany=Widgets+Inc&UMshipstreet=456+My+Street&UMshipstreet2=Apt+1&UMshipcity=Ottawa&UMshipstate=ON&UMshipzip=K1C2N6&UMshipcountry=CA&UMshipphone=%28555%29555-5555&UMstreet=456+My+Street&UMzip=27614&UMcommand=cc%3Asale&UMkey=4EoZ5U2Q55j976W7eplC71i6b7kn4pcV&UMsoftware=Active+Merchant&UMtestmode=0&UMhash=s%2F5268F91058BC9F9FA944693D799F324B2497B7247850A51E53226309FB2540F0%2F7b4c4f6a4e775141cc0e4e10c0388d9adeb47fd1%2Fn"
-> "HTTP/1.1 200 OK\r\n"
-> "Server: http\r\n"
-> "Date: Tue, 13 Feb 2018 18:17:20 GMT\r\n"
-> "Content-Type: text/html\r\n"
-> "Content-Length: 485\r\n"
-> "Connection: close\r\n"
-> "P3P: policyref=\"http://www.usaepay.com/w3c/p3p.xml\", CP=\"NON TAIa IVAa IVDa OUR NOR PHY ONL UNI FIN INT DEM\"\r\n"
-> "Strict-Transport-Security: max-age=15768000\r\n"
-> "\r\n"
reading 485 bytes...
-> "UMversion=2.9&UMstatus=Approved&UMauthCode=042366&UMrefNum=132020588&UMavsResult=Address%3A%20Match%20%26%205%20Digit%20Zip%3A%20Match&UMavsResultCode=YYY&UMcvv2Result=Match&UMcvv2ResultCode=M&UMresult=A&UMvpasResultCode=&UMerror=Approved&UMerrorcode=00000&UMcustnum=&UMbatch=120&UMbatchRefNum=848&UMisDuplicate=N&UMconvertedAmount=&UMconvertedAmountCurrency=840&UMconversionRate=&UMcustReceiptResult=No%20Receipt%20Sent&UMprocRefNum=&UMcardLevelResult=A&UMauthAmount=1&UMfiller=filled"
read 485 bytes
Conn close
    EOS
  end

  def post_scrubbed
    <<-EOS
opening connection to sandbox.usaepay.com:443...
opened
starting SSL for sandbox.usaepay.com:443...
SSL established
<- "POST /gate HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: sandbox.usaepay.com\r\nContent-Length: 774\r\n\r\n"
<- "UMamount=1.00&UMinvoice=&UMdescription=&UMcard=[FILTERED]&UMcvv2=[FILTERED]&UMexpir=0919&UMname=Longbob+Longsen&UMbillfname=Jim&UMbilllname=Smith&UMbillcompany=Widgets+Inc&UMbillstreet=456+My+Street&UMbillstreet2=Apt+1&UMbillcity=Ottawa&UMbillstate=NC&UMbillzip=27614&UMbillcountry=CA&UMbillphone=%28555%29555-5555&UMshipfname=Jim&UMshiplname=Smith&UMshipcompany=Widgets+Inc&UMshipstreet=456+My+Street&UMshipstreet2=Apt+1&UMshipcity=Ottawa&UMshipstate=ON&UMshipzip=K1C2N6&UMshipcountry=CA&UMshipphone=%28555%29555-5555&UMstreet=456+My+Street&UMzip=27614&UMcommand=cc%3Asale&UMkey=[FILTERED]&UMsoftware=Active+Merchant&UMtestmode=0&UMhash=s%2F5268F91058BC9F9FA944693D799F324B2497B7247850A51E53226309FB2540F0%2F7b4c4f6a4e775141cc0e4e10c0388d9adeb47fd1%2Fn"
-> "HTTP/1.1 200 OK\r\n"
-> "Server: http\r\n"
-> "Date: Tue, 13 Feb 2018 18:17:20 GMT\r\n"
-> "Content-Type: text/html\r\n"
-> "Content-Length: 485\r\n"
-> "Connection: close\r\n"
-> "P3P: policyref=\"http://www.usaepay.com/w3c/p3p.xml\", CP=\"NON TAIa IVAa IVDa OUR NOR PHY ONL UNI FIN INT DEM\"\r\n"
-> "Strict-Transport-Security: max-age=15768000\r\n"
-> "\r\n"
reading 485 bytes...
-> "UMversion=2.9&UMstatus=Approved&UMauthCode=042366&UMrefNum=132020588&UMavsResult=Address%3A%20Match%20%26%205%20Digit%20Zip%3A%20Match&UMavsResultCode=YYY&UMcvv2Result=Match&UMcvv2ResultCode=M&UMresult=A&UMvpasResultCode=&UMerror=Approved&UMerrorcode=00000&UMcustnum=&UMbatch=120&UMbatchRefNum=848&UMisDuplicate=N&UMconvertedAmount=&UMconvertedAmountCurrency=840&UMconversionRate=&UMcustReceiptResult=No%20Receipt%20Sent&UMprocRefNum=&UMcardLevelResult=A&UMauthAmount=1&UMfiller=filled"
read 485 bytes
Conn close
    EOS
  end

  def pre_scrubbed_track_data
    <<-EOS
opening connection to sandbox.usaepay.com:443...
opened
starting SSL for sandbox.usaepay.com:443...
SSL established
<- "POST /gate HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: sandbox.usaepay.com\r\nContent-Length: 382\r\n\r\n"
<- "UMamount=1.00&UMinvoice=&UMdescription=&UMmagstripe=%25B4000100011112224%5ELONGSEN%2FL.+%5E19091200000000000000%2A%2A123%2A%2A%2A%2A%2A%2A%3F&UMcardpresent=true&UMcommand=cc%3Asale&UMkey=4EoZ5U2Q55j976W7eplC71i6b7kn4pcV&UMsoftware=Active+Merchant&UMtestmode=0&UMhash=s%2FE27734F076643B23131E5432C1E225EFF982A73D350179EFC2F191CA499B59A4%2F13391bd14ab6e61058cc9a1b78f259a4c26aa8e1%2Fn"
-> "HTTP/1.1 200 OK\r\n"
-> "Server: http\r\n"
-> "Date: Tue, 13 Feb 2018 18:13:11 GMT\r\n"
-> "Content-Type: text/html\r\n"
-> "Content-Length: 485\r\n"
-> "Connection: close\r\n"
-> "P3P: policyref=\"http://www.usaepay.com/w3c/p3p.xml\", CP=\"NON TAIa IVAa IVDa OUR NOR PHY ONL UNI FIN INT DEM\"\r\n"
-> "Strict-Transport-Security: max-age=15768000\r\n"
-> "\r\n"
reading 485 bytes...
-> "UMversion=2.9&UMstatus=Approved&UMauthCode=042087&UMrefNum=132020522&UMavsResult=Address%3A%20Match%20%26%205%20Digit%20Zip%3A%20Match&UMavsResultCode=YYY&UMcvv2Result=Match&UMcvv2ResultCode=M&UMresult=A&UMvpasResultCode=&UMerror=Approved&UMerrorcode=00000&UMcustnum=&UMbatch=120&UMbatchRefNum=848&UMisDuplicate=N&UMconvertedAmount=&UMconvertedAmountCurrency=840&UMconversionRate=&UMcustReceiptResult=No%20Receipt%20Sent&UMprocRefNum=&UMcardLevelResult=A&UMauthAmount=1&UMfiller=filled"
read 485 bytes
Conn close
    EOS
  end

  def post_scrubbed_track_data
    <<-EOS
opening connection to sandbox.usaepay.com:443...
opened
starting SSL for sandbox.usaepay.com:443...
SSL established
<- "POST /gate HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: sandbox.usaepay.com\r\nContent-Length: 382\r\n\r\n"
<- "UMamount=1.00&UMinvoice=&UMdescription=&UMmagstripe=[FILTERED]&UMcardpresent=true&UMcommand=cc%3Asale&UMkey=[FILTERED]&UMsoftware=Active+Merchant&UMtestmode=0&UMhash=s%2FE27734F076643B23131E5432C1E225EFF982A73D350179EFC2F191CA499B59A4%2F13391bd14ab6e61058cc9a1b78f259a4c26aa8e1%2Fn"
-> "HTTP/1.1 200 OK\r\n"
-> "Server: http\r\n"
-> "Date: Tue, 13 Feb 2018 18:13:11 GMT\r\n"
-> "Content-Type: text/html\r\n"
-> "Content-Length: 485\r\n"
-> "Connection: close\r\n"
-> "P3P: policyref=\"http://www.usaepay.com/w3c/p3p.xml\", CP=\"NON TAIa IVAa IVDa OUR NOR PHY ONL UNI FIN INT DEM\"\r\n"
-> "Strict-Transport-Security: max-age=15768000\r\n"
-> "\r\n"
reading 485 bytes...
-> "UMversion=2.9&UMstatus=Approved&UMauthCode=042087&UMrefNum=132020522&UMavsResult=Address%3A%20Match%20%26%205%20Digit%20Zip%3A%20Match&UMavsResultCode=YYY&UMcvv2Result=Match&UMcvv2ResultCode=M&UMresult=A&UMvpasResultCode=&UMerror=Approved&UMerrorcode=00000&UMcustnum=&UMbatch=120&UMbatchRefNum=848&UMisDuplicate=N&UMconvertedAmount=&UMconvertedAmountCurrency=840&UMconversionRate=&UMcustReceiptResult=No%20Receipt%20Sent&UMprocRefNum=&UMcardLevelResult=A&UMauthAmount=1&UMfiller=filled"
read 485 bytes
Conn close
    EOS
  end

  def pre_scrubbed_echeck
    <<-EOS
opening connection to sandbox.usaepay.com:443...
opened
starting SSL for sandbox.usaepay.com:443...
SSL established
<- "POST /gate HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: sandbox.usaepay.com\r\nContent-Length: 762\r\n\r\n"
<- "UMamount=1.00&UMinvoice=&UMdescription=&UMaccount=15378535&UMrouting=244183602&UMname=Jim+Smith&UMbillfname=Jim&UMbilllname=Smith&UMbillcompany=Widgets+Inc&UMbillstreet=456+My+Street&UMbillstreet2=Apt+1&UMbillcity=Ottawa&UMbillstate=NC&UMbillzip=27614&UMbillcountry=CA&UMbillphone=%28555%29555-5555&UMshipfname=Jim&UMshiplname=Smith&UMshipcompany=Widgets+Inc&UMshipstreet=456+My+Street&UMshipstreet2=Apt+1&UMshipcity=Ottawa&UMshipstate=ON&UMshipzip=K1C2N6&UMshipcountry=CA&UMshipphone=%28555%29555-5555&UMstreet=456+My+Street&UMzip=27614&UMcommand=check%3Asale&UMkey=4EoZ5U2Q55j976W7eplC71i6b7kn4pcV&UMsoftware=Active+Merchant&UMtestmode=0&UMhash=s%2F7F71E7DCB851901EA1D4E2CA1C60D2A7E8BAB99FA10F6220E821BD8B8331114B%2F85f1a7ab01b725c4eed80a12c78ef65d3fa367e6%2Fn"
-> "HTTP/1.1 200 OK\r\n"
-> "Server: http\r\n"
-> "Date: Fri, 16 Mar 2018 20:54:49 GMT\r\n"
-> "Content-Type: text/html\r\n"
-> "Content-Length: 572\r\n"
-> "Connection: close\r\n"
-> "P3P: policyref=\"http://www.usaepay.com/w3c/p3p.xml\", CP=\"NON TAIa IVAa IVDa OUR NOR PHY ONL UNI FIN INT DEM\"\r\n"
-> "Strict-Transport-Security: max-age=15768000\r\n"
-> "\r\n"
reading 572 bytes...
-> "UMversion=2.9&UMstatus=Approved&UMauthCode=TMEAAF&UMrefNum=133135121&UMavsResult=No%20AVS%20response%20%28Typically%20no%20AVS%20data%20sent%20or%20swiped%20transaction%29&UMavsResultCode=&UMcvv2Result=No%20CVV2%2FCVC%20data%20available%20for%20transaction.&UMcvv2ResultCode=&UMresult=A&UMvpasResultCode=&UMerror=&UMerrorcode=00000&UMcustnum=&UMbatch=180316&UMbatchRefNum=&UMisDuplicate=N&UMconvertedAmount=&UMconvertedAmountCurrency=840&UMconversionRate=&UMcustReceiptResult=No%20Receipt%20Sent&UMprocRefNum=18031621233689&UMcardLevelResult=&UMauthAmount=&UMfiller=filled"
read 572 bytes
Conn close
    EOS
  end

  def post_scrubbed_echeck
    <<-EOS
opening connection to sandbox.usaepay.com:443...
opened
starting SSL for sandbox.usaepay.com:443...
SSL established
<- "POST /gate HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: sandbox.usaepay.com\r\nContent-Length: 762\r\n\r\n"
<- "UMamount=1.00&UMinvoice=&UMdescription=&UMaccount=[FILTERED]&UMrouting=244183602&UMname=Jim+Smith&UMbillfname=Jim&UMbilllname=Smith&UMbillcompany=Widgets+Inc&UMbillstreet=456+My+Street&UMbillstreet2=Apt+1&UMbillcity=Ottawa&UMbillstate=NC&UMbillzip=27614&UMbillcountry=CA&UMbillphone=%28555%29555-5555&UMshipfname=Jim&UMshiplname=Smith&UMshipcompany=Widgets+Inc&UMshipstreet=456+My+Street&UMshipstreet2=Apt+1&UMshipcity=Ottawa&UMshipstate=ON&UMshipzip=K1C2N6&UMshipcountry=CA&UMshipphone=%28555%29555-5555&UMstreet=456+My+Street&UMzip=27614&UMcommand=check%3Asale&UMkey=[FILTERED]&UMsoftware=Active+Merchant&UMtestmode=0&UMhash=s%2F7F71E7DCB851901EA1D4E2CA1C60D2A7E8BAB99FA10F6220E821BD8B8331114B%2F85f1a7ab01b725c4eed80a12c78ef65d3fa367e6%2Fn"
-> "HTTP/1.1 200 OK\r\n"
-> "Server: http\r\n"
-> "Date: Fri, 16 Mar 2018 20:54:49 GMT\r\n"
-> "Content-Type: text/html\r\n"
-> "Content-Length: 572\r\n"
-> "Connection: close\r\n"
-> "P3P: policyref=\"http://www.usaepay.com/w3c/p3p.xml\", CP=\"NON TAIa IVAa IVDa OUR NOR PHY ONL UNI FIN INT DEM\"\r\n"
-> "Strict-Transport-Security: max-age=15768000\r\n"
-> "\r\n"
reading 572 bytes...
-> "UMversion=2.9&UMstatus=Approved&UMauthCode=TMEAAF&UMrefNum=133135121&UMavsResult=No%20AVS%20response%20%28Typically%20no%20AVS%20data%20sent%20or%20swiped%20transaction%29&UMavsResultCode=&UMcvv2Result=No%20CVV2%2FCVC%20data%20available%20for%20transaction.&UMcvv2ResultCode=&UMresult=A&UMvpasResultCode=&UMerror=&UMerrorcode=00000&UMcustnum=&UMbatch=180316&UMbatchRefNum=&UMisDuplicate=N&UMconvertedAmount=&UMconvertedAmountCurrency=840&UMconversionRate=&UMcustReceiptResult=No%20Receipt%20Sent&UMprocRefNum=18031621233689&UMcardLevelResult=&UMauthAmount=&UMfiller=filled"
read 572 bytes
Conn close
    EOS
  end
end
