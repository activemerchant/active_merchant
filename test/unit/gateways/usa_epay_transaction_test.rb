require 'test_helper'

class UsaEpayTransactionTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = UsaEpayTransactionGateway.new(:login => 'LOGIN')

    @credit_card = credit_card('4242424242424242')
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

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(unsuccessful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_purchase_passing_extra_info
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(:order_id => "1337", :description => "socool"))
    end.check_request do |endpoint, data, headers|
      assert_match(/UMinvoice=1337/, data)
      assert_match(/UMdescription=socool/, data)
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

  def test_split_names
    assert_equal ['Longbob', 'Longsen'], @gateway.send(:split_names, 'Longbob Longsen')
  end

  def test_split_names_with_single_name
    assert_equal ['', 'Longsen'], @gateway.send(:split_names, 'Longsen')
  end

  def test_split_names_with_empty_names
    assert_equal [nil, nil], @gateway.send(:split_names, '')
    assert_equal [nil, nil], @gateway.send(:split_names, nil)
    assert_equal [nil, nil], @gateway.send(:split_names, ' ')
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
    @credit_card.track_data = "data"

    @gateway.expects(:ssl_post).with do |_, body|
      body.include?("UMmagstripe=data")
    end.returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_add_track_data_with_empty_data
    ["", nil].each do |data|
      @credit_card.track_data = data

      @gateway.expects(:ssl_post).with do |_, body|
        refute body.include? "UMmagstripe="
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
    @gateway.expects(:ssl_post).returns("status")
    assert_nothing_raised do
      response = @gateway.purchase(@amount, @credit_card, @options)
      assert_failure response
    end
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
    "UMversion=2.9&UMstatus=Approved&UMauthCode=001716&UMrefNum=55074409&UMavsResult=Address%3A%20Match%20%26%205%20Digit%20Zip%3A%20Match&UMavsResultCode=Y&UMcvv2Result=Match&UMcvv2ResultCode=M&UMresult=A&UMvpasResultCode=&UMerror=Approved&UMerrorcode=00000&UMcustnum=&UMbatch=596&UMisDuplicate=N&UMconvertedAmount=&UMconvertedAmountCurrency=840&UMconversionRate=&UMcustReceiptResult=No%20Receipt%20Sent&UMfiller=filled"
  end

  def unsuccessful_purchase_response
    "UMversion=2.9&UMstatus=Declined&UMauthCode=000000&UMrefNum=55076060&UMavsResult=Address%3A%20Match%20%26%205%20Digit%20Zip%3A%20Match&UMavsResultCode=Y&UMcvv2Result=Not%20Processed&UMcvv2ResultCode=P&UMvpasResultCode=&UMresult=D&UMerror=Card%20Declined&UMerrorcode=10127&UMbatch=596&UMfiller=filled"
  end
end
