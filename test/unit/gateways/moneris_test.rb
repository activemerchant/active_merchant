require 'test_helper'

class MonerisTest < Test::Unit::TestCase
  include CommStub

  def setup
    Base.mode = :test

    @gateway = MonerisGateway.new(
      login: 'store3',
      password: 'yesguy'
    )

    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @options = { order_id: '1', customer: '1', billing_address: address }
  end

  def test_default_options
    assert_equal 7, @gateway.options[:crypt_type]
    assert_equal 'store3', @gateway.options[:login]
    assert_equal 'yesguy', @gateway.options[:password]
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(100, @credit_card, @options)
    assert_success response
    assert_equal '58-0_3;1026.1', response.authorization
  end

  def test_successful_first_purchase_with_credential_on_file
    gateway = MonerisGateway.new(
      login: 'store3',
      password: 'yesguy'
    )
    gateway.expects(:ssl_post).returns(successful_first_cof_purchase_response)
    assert response = gateway.purchase(
      @amount,
      @credit_card,
      @options.merge(
        issuer_id: '',
        payment_indicator: 'C',
        payment_information: '0'
      )
    )
    assert_success response
    assert_equal 'Approved', response.message
    assert_false response.authorization.blank?
    assert_not_empty response.params['issuer_id']
  end

  def test_successful_subsequent_purchase_with_credential_on_file
    gateway = MonerisGateway.new(
      login: 'store3',
      password: 'yesguy'
    )
    gateway.expects(:ssl_post).returns(successful_first_cof_authorize_response)
    assert response = gateway.authorize(
      @amount,
      @credit_card,
      @options.merge(
        issuer_id: '',
        payment_indicator: 'C',
        payment_information: '0'
      )
    )
    assert_success response
    assert_equal 'Approved', response.message
    assert_false response.authorization.blank?

    gateway.expects(:ssl_post).returns(successful_subsequent_cof_purchase_response)

    assert response2 = gateway.purchase(
      @amount,
      @credit_card,
      @options.merge(
        order_id: response.authorization,
        issuer_id: response.params['issuer_id'],
        payment_indicator: 'U',
        payment_information: '2'
      )
    )
    assert_success response2
    assert_equal 'Approved', response2.message
    assert_false response2.authorization.blank?
  end

  def test_successful_purchase_with_network_tokenization
    @gateway.expects(:ssl_post).returns(successful_purchase_network_tokenization)
    @credit_card = network_tokenization_credit_card('4242424242424242',
      payment_cryptogram: 'BwABB4JRdgAAAAAAiFF2AAAAAAA=',
      verification_value: nil)
    assert response = @gateway.purchase(100, @credit_card, @options)
    assert_success response
    assert_equal '101965-0_10;0bbb277b543a17b6781243889a689573', response.authorization
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.authorize(100, @credit_card, @options)
    assert_failure response
  end

  def test_deprecated_credit
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/txn_number>123<\//), anything).returns('')
    @gateway.expects(:parse).returns({})
    assert_deprecation_warning(Gateway::CREDIT_DEPRECATION_MESSAGE) do
      @gateway.credit(@amount, '123;456', @options)
    end
  end

  def test_refund
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/txn_number>123<\//), anything).returns('')
    @gateway.expects(:parse).returns({})
    @gateway.refund(@amount, '123;456', @options)
  end

  def test_amount_style
    assert_equal '10.34', @gateway.send(:amount, 1034)

    assert_raise(ArgumentError) do
      @gateway.send(:amount, '10.34')
    end
  end

  def test_preauth_is_valid_xml
    params = {
      order_id: 'order1',
      amount: '1.01',
      pan: '4242424242424242',
      expdate: '0303',
      crypt_type: 7
    }

    assert data = @gateway.send(:post_data, 'preauth', params)
    assert REXML::Document.new(data)
    assert_equal xml_capture_fixture.size, data.size
  end

  def test_purchase_is_valid_xml
    params = {
      order_id: 'order1',
      amount: '1.01',
      pan: '4242424242424242',
      expdate: '0303',
      crypt_type: 7
    }

    assert data = @gateway.send(:post_data, 'purchase', params)
    assert REXML::Document.new(data)
    assert_equal xml_purchase_fixture.size, data.size
  end

  def test_capture_is_valid_xml
    params = {
      order_id: 'order1',
      amount: '1.01',
      pan: '4242424242424242',
      expdate: '0303',
      crypt_type: 7
    }

    assert data = @gateway.send(:post_data, 'preauth', params)
    assert REXML::Document.new(data)
    assert_equal xml_capture_fixture.size, data.size
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).returns(successful_verify_response)

    assert response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal '125-0_14;93565164-01571', response.authorization
    assert_equal 'Approved', response.message
  end

  def test_supported_countries
    assert_equal ['CA'], MonerisGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal %i[visa master american_express diners_club discover], MonerisGateway.supported_cardtypes
  end

  def test_should_raise_error_if_transaction_param_empty_on_credit_request
    [nil, '', '1234'].each do |invalid_transaction_param|
      assert_raise(ArgumentError) { @gateway.void(invalid_transaction_param) }
    end
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal 'Successfully registered cc details', response.message
    assert response.params['data_key'].present?
    @data_key = response.params['data_key']
  end

  def test_successful_store_with_duration
    @gateway.expects(:ssl_post).returns(successful_store_with_duration_response)
    assert response = @gateway.store(@credit_card, duration: 600)
    assert_success response
    assert_equal 'Successfully registered cc details', response.message
    assert response.params['data_key'].present?
    @data_key = response.params['data_key']
  end

  def test_successful_unstore
    @gateway.expects(:ssl_post).returns(successful_unstore_response)
    test_successful_store
    assert response = @gateway.unstore(@data_key)
    assert_success response
    assert_equal 'Successfully deleted cc details', response.message
    assert response.params['data_key'].present?
  end

  def test_update
    @gateway.expects(:ssl_post).returns(successful_update_response)
    test_successful_store
    assert response = @gateway.update(@data_key, @credit_card)
    assert_success response
    assert_equal 'Successfully updated cc details', response.message
    assert response.params['data_key'].present?
  end

  def test_successful_purchase_with_vault
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    test_successful_store
    assert response = @gateway.purchase(100, @data_key, { order_id: generate_unique_id, customer: generate_unique_id })
    assert_success response
    assert_equal 'Approved', response.message
    assert response.authorization.present?
  end

  def test_successful_authorize_with_network_tokenization
    @gateway.expects(:ssl_post).returns(successful_authorization_network_tokenization)
    @credit_card = network_tokenization_credit_card('4242424242424242',
      payment_cryptogram: 'BwABB4JRdgAAAAAAiFF2AAAAAAA=',
      verification_value: nil)
    assert response = @gateway.authorize(100, @credit_card, @options)
    assert_success response
    assert_equal '109232-0_10;d88d9f5f3472898832c54d6b5572757e', response.authorization
  end

  def test_successful_authorization_with_vault
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    test_successful_store
    assert response = @gateway.authorize(100, @data_key, { order_id: generate_unique_id, customer: generate_unique_id })
    assert_success response
    assert_equal 'Approved', response.message
    assert response.authorization.present?
  end

  def test_failed_authorization_with_vault
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    test_successful_store
    assert response = @gateway.authorize(100, @data_key, @options)
    assert_failure response
  end

  def test_cvv_enabled_and_provided
    gateway = MonerisGateway.new(login: 'store1', password: 'yesguy', cvv_enabled: true)

    @credit_card.verification_value = '452'
    stub_comms(gateway) do
      gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r{cvd_indicator>1<}, data)
      assert_match(%r{cvd_value>452<}, data)
    end.respond_with(successful_purchase_response)
  end

  def test_cvv_enabled_but_not_provided
    gateway = MonerisGateway.new(login: 'store1', password: 'yesguy', cvv_enabled: true)

    @credit_card.verification_value = ''
    stub_comms(gateway) do
      gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r{cvd_indicator>0<}, data)
      assert_no_match(%r{cvd_value>}, data)
    end.respond_with(successful_purchase_response)
  end

  def test_cvv_disabled_and_provided
    @credit_card.verification_value = '452'
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_no_match(%r{cvd_value>}, data)
      assert_no_match(%r{cvd_indicator>}, data)
    end.respond_with(successful_purchase_response)
  end

  def test_cvv_disabled_but_not_provided
    @credit_card.verification_value = ''
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_no_match(%r{cvd_value>}, data)
      assert_no_match(%r{cvd_indicator>}, data)
    end.respond_with(successful_purchase_response)
  end

  def test_avs_enabled_and_provided
    gateway = MonerisGateway.new(login: 'store1', password: 'yesguy', avs_enabled: true)

    billing_address = address(address1: '1234 Anystreet', address2: '')
    stub_comms(gateway) do
      gateway.purchase(@amount, @credit_card, billing_address: billing_address, order_id: '1')
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r{avs_street_number>1234<}, data)
      assert_match(%r{avs_street_name>Anystreet<}, data)
      assert_match(%r{avs_zipcode>#{billing_address[:zip]}<}, data)
    end.respond_with(successful_purchase_response_with_avs_result)
  end

  def test_avs_enabled_but_not_provided
    gateway = MonerisGateway.new(login: 'store1', password: 'yesguy', avs_enabled: true)

    stub_comms(gateway) do
      gateway.purchase(@amount, @credit_card, @options.tap { |x| x.delete(:billing_address) })
    end.check_request do |_endpoint, data, _headers|
      assert_no_match(%r{avs_street_number>}, data)
      assert_no_match(%r{avs_street_name>}, data)
      assert_no_match(%r{avs_zipcode>}, data)
    end.respond_with(successful_purchase_response)
  end

  def test_avs_disabled_and_provided
    billing_address = address(address1: '1234 Anystreet', address2: '')
    stub_comms do
      @gateway.purchase(@amount, @credit_card, billing_address: billing_address, order_id: '1')
    end.check_request do |_endpoint, data, _headers|
      assert_no_match(%r{avs_street_number>}, data)
      assert_no_match(%r{avs_street_name>}, data)
      assert_no_match(%r{avs_zipcode>}, data)
    end.respond_with(successful_purchase_response_with_avs_result)
  end

  def test_avs_disabled_and_not_provided
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.tap { |x| x.delete(:billing_address) })
    end.check_request do |_endpoint, data, _headers|
      assert_no_match(%r{avs_street_number>}, data)
      assert_no_match(%r{avs_street_name>}, data)
      assert_no_match(%r{avs_zipcode>}, data)
    end.respond_with(successful_purchase_response)
  end

  def test_avs_result_valid_with_address
    @gateway.expects(:ssl_post).returns(successful_purchase_response_with_avs_result)
    assert response = @gateway.purchase(100, @credit_card, @options)
    assert_equal(response.avs_result, {
      'code' => 'A',
      'message' => 'Street address matches, but postal code does not match.',
      'street_match' => 'Y',
      'postal_match' => 'N'
    })
  end

  def test_customer_can_be_specified
    stub_comms do
      @gateway.purchase(@amount, @credit_card, order_id: '3', customer: 'Joe Jones')
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r{cust_id>Joe Jones}, data)
    end.respond_with(successful_purchase_response)
  end

  def test_customer_not_specified_card_name_used
    stub_comms do
      @gateway.purchase(@amount, @credit_card, order_id: '3')
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r{cust_id>Longbob Longsen}, data)
    end.respond_with(successful_purchase_response)
  end

  def test_add_swipe_data_with_creditcard
    @credit_card.track_data = 'Track Data'

    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match '<pos_code>00</pos_code>', data
      assert_match '<track2>Track Data</track2>', data
    end.respond_with(successful_purchase_response)
  end

  def test_scrub
    assert_equal @gateway.scrub(pre_scrub), post_scrub
  end

  def test_supports_scrubbing?
    assert @gateway.supports_scrubbing?
  end

  def test_stored_credential_recurring_cit_initial
    options = stored_credential_options(:cardholder, :recurring, :initial)
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<issuer_id><\/issuer_id>/, data)
      assert_match(/<payment_indicator>C<\/payment_indicator>/, data)
      assert_match(/<payment_information>0<\/payment_information>/, data)
    end.respond_with(successful_first_cof_authorize_response)

    assert_success response
  end

  def test_stored_credential_recurring_cit_used
    options = stored_credential_options(:cardholder, :recurring, id: 'abc123')
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<issuer_id>abc123<\/issuer_id>/, data)
      assert_match(/<payment_indicator>Z<\/payment_indicator>/, data)
      assert_match(/<payment_information>2<\/payment_information>/, data)
    end.respond_with(successful_first_cof_authorize_response)

    assert_success response
  end

  def test_stored_credential_recurring_mit_initial
    options = stored_credential_options(:merchant, :recurring, :initial)
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<issuer_id><\/issuer_id>/, data)
      assert_match(/<payment_indicator>R<\/payment_indicator>/, data)
      assert_match(/<payment_information>0<\/payment_information>/, data)
    end.respond_with(successful_first_cof_authorize_response)

    assert_success response
  end

  def test_stored_credential_recurring_mit_used
    options = stored_credential_options(:merchant, :recurring, id: 'abc123')
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<issuer_id>abc123<\/issuer_id>/, data)
      assert_match(/<payment_indicator>R<\/payment_indicator>/, data)
      assert_match(/<payment_information>2<\/payment_information>/, data)
    end.respond_with(successful_first_cof_authorize_response)

    assert_success response
  end

  def test_stored_credential_installment_cit_initial
    options = stored_credential_options(:cardholder, :installment, :initial)
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<issuer_id><\/issuer_id>/, data)
      assert_match(/<payment_indicator>C<\/payment_indicator>/, data)
      assert_match(/<payment_information>0<\/payment_information>/, data)
    end.respond_with(successful_first_cof_authorize_response)

    assert_success response
  end

  def test_stored_credential_installment_cit_used
    options = stored_credential_options(:cardholder, :installment, id: 'abc123')
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<issuer_id>abc123<\/issuer_id>/, data)
      assert_match(/<payment_indicator>Z<\/payment_indicator>/, data)
      assert_match(/<payment_information>2<\/payment_information>/, data)
    end.respond_with(successful_first_cof_authorize_response)

    assert_success response
  end

  def test_stored_credential_installment_mit_initial
    options = stored_credential_options(:merchant, :installment, :initial)
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<issuer_id><\/issuer_id>/, data)
      assert_match(/<payment_indicator>R<\/payment_indicator>/, data)
      assert_match(/<payment_information>0<\/payment_information>/, data)
    end.respond_with(successful_first_cof_authorize_response)

    assert_success response
  end

  def test_stored_credential_installment_mit_used
    options = stored_credential_options(:merchant, :installment, id: 'abc123')
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<issuer_id>abc123<\/issuer_id>/, data)
      assert_match(/<payment_indicator>R<\/payment_indicator>/, data)
      assert_match(/<payment_information>2<\/payment_information>/, data)
    end.respond_with(successful_first_cof_authorize_response)

    assert_success response
  end

  def test_stored_credential_unscheduled_cit_initial
    options = stored_credential_options(:cardholder, :unscheduled, :initial)
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<issuer_id><\/issuer_id>/, data)
      assert_match(/<payment_indicator>C<\/payment_indicator>/, data)
      assert_match(/<payment_information>0<\/payment_information>/, data)
    end.respond_with(successful_first_cof_authorize_response)

    assert_success response
  end

  def test_stored_credential_unscheduled_cit_used
    options = stored_credential_options(:cardholder, :unscheduled, id: 'abc123')
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<issuer_id>abc123<\/issuer_id>/, data)
      assert_match(/<payment_indicator>Z<\/payment_indicator>/, data)
      assert_match(/<payment_information>2<\/payment_information>/, data)
    end.respond_with(successful_first_cof_authorize_response)

    assert_success response
  end

  def test_stored_credential_unscheduled_mit_initial
    options = stored_credential_options(:merchant, :unscheduled, :initial)
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<issuer_id><\/issuer_id>/, data)
      assert_match(/<payment_indicator>C<\/payment_indicator>/, data)
      assert_match(/<payment_information>0<\/payment_information>/, data)
    end.respond_with(successful_first_cof_authorize_response)

    assert_success response
  end

  def test_stored_credential_unscheduled_mit_used
    options = stored_credential_options(:merchant, :unscheduled, id: 'abc123')
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<issuer_id>abc123<\/issuer_id>/, data)
      assert_match(/<payment_indicator>U<\/payment_indicator>/, data)
      assert_match(/<payment_information>2<\/payment_information>/, data)
    end.respond_with(successful_first_cof_authorize_response)

    assert_success response
  end

  def test_add_cof_overrides_stored_credential_option
    options = stored_credential_options(:merchant, :unscheduled, id: 'abc123').merge(issuer_id: 'xyz987', payment_indicator: 'R', payment_information: '0')
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<issuer_id>xyz987<\/issuer_id>/, data)
      assert_match(/<payment_indicator>R<\/payment_indicator>/, data)
      assert_match(/<payment_information>0<\/payment_information>/, data)
    end.respond_with(successful_first_cof_authorize_response)

    assert_success response
  end

  private

  def stored_credential_options(*args, id: nil)
    {
      order_id: '#1001',
      description: 'AM test',
      currency: 'CAD',
      customer: '123',
      stored_credential: stored_credential(*args, id: id),
      issuer_id: ''
    }
  end

  def successful_purchase_response
    <<~RESPONSE
      <?xml version="1.0"?>
      <response>
        <receipt>
          <ReceiptId>1026.1</ReceiptId>
          <ReferenceNum>661221050010170010</ReferenceNum>
          <ResponseCode>027</ResponseCode>
          <ISO>01</ISO>
          <AuthCode>013511</AuthCode>
          <TransTime>18:41:13</TransTime>
          <TransDate>2008-01-05</TransDate>
          <TransType>00</TransType>
          <Complete>true</Complete>
          <Message>APPROVED * =</Message>
          <TransAmount>1.00</TransAmount>
          <CardType>V</CardType>
          <TransID>58-0_3</TransID>
          <TimedOut>false</TimedOut>
        </receipt>
      </response>

    RESPONSE
  end

  def successful_first_cof_purchase_response
    <<~RESPONSE
      <?xml version=\"1.0\" standalone=\"yes\"?>
      <?xml version=“1.0” standalone=“yes”?>
      <response>
       <receipt>
         <ReceiptId>a33ba7edd448b91ef8d2f85fea614b8d</ReceiptId>
         <ReferenceNum>660114080015099160</ReferenceNum>
         <ResponseCode>027</ResponseCode>
         <ISO>01</ISO>
         <AuthCode>822665</AuthCode>
         <TransTime>07:43:28</TransTime>
         <TransDate>2018-11-11</TransDate>
         <TransType>00</TransType>
         <Complete>true</Complete>
         <Message>APPROVED           *                    =</Message>
         <TransAmount>1.00</TransAmount>
         <CardType>V</CardType>
         <TransID>799655-0_11</TransID>
         <TimedOut>false</TimedOut>
         <BankTotals>null</BankTotals>
         <Ticket>null</Ticket>
         <IssuerId>355689484440192</IssuerId>
         <IsVisaDebit>false</IsVisaDebit>
       </receipt>
      </response>
    RESPONSE
  end

  def successful_first_cof_authorize_response
    <<~RESPONSE
      <?xml version=\"1.0\" standalone=\"yes\"?>
      <response>
        <receipt>
          <ReceiptId>8dbc28468af2007779bbede7ec1bab6c</ReceiptId>
          <ReferenceNum>660109300018229130</ReferenceNum>
          <ResponseCode>027</ResponseCode>
          <ISO>01</ISO>
          <AuthCode>718280</AuthCode>
          <TransTime>07:50:53</TransTime>
          <TransDate>2018-11-11</TransDate>
          <TransType>01</TransType>
          <Complete>true</Complete>
          <Message>APPROVED           *                    =</Message>
          <TransAmount>1.00</TransAmount>
          <CardType>V</CardType>
          <TransID>830724-0_11</TransID>
          <TimedOut>false</TimedOut>
          <BankTotals>null</BankTotals>
          <Ticket>null</Ticket>
          <MessageId>1A8315282537312</MessageId>
          <IssuerId>550923784451193</IssuerId>
          <IsVisaDebit>false</IsVisaDebit>
        </receipt>
      </response>
    RESPONSE
  end

  def successful_subsequent_cof_purchase_response
    <<~RESPONSE
      <?xml version="1.0" standalone="yes"?>
      <response>
        <receipt>
          <ReceiptId>830724-0_11;8dbc28468af2007779bbede7ec1bab6c</ReceiptId>
          <ReferenceNum>660109490014038930</ReferenceNum>
          <ResponseCode>027</ResponseCode>
          <ISO>01</ISO>
          <AuthCode>111234</AuthCode>
          <TransTime>07:50:54</TransTime>
          <TransDate>2018-11-11</TransDate>
          <TransType>00</TransType>
          <Complete>true</Complete>
          <Message>APPROVED           *                    =</Message>
          <TransAmount>1.00</TransAmount>
          <CardType>V</CardType>
          <TransID>455422-0_11</TransID>
          <TimedOut>false</TimedOut>
          <BankTotals>null</BankTotals>
          <Ticket>null</Ticket>
          <IssuerId>762097792112819</IssuerId>
          <IsVisaDebit>false</IsVisaDebit>
        </receipt>
      </response>
    RESPONSE
  end

  def successful_purchase_network_tokenization
    <<~RESPONSE
      <?xml version="1.0"?>
      <response>
         <receipt>
            <ReceiptId>0bbb277b543a17b6781243889a689573</ReceiptId>
            <ReferenceNum>660110910011133780</ReferenceNum>
            <ResponseCode>027</ResponseCode>
            <ISO>01</ISO>
            <AuthCode>368269</AuthCode>
            <TransTime>22:54:10</TransTime>
            <TransDate>2015-07-05</TransDate>
            <TransType>00</TransType>
            <Complete>true</Complete>
            <Message>APPROVED           *                    =</Message>
            <TransAmount>1.00</TransAmount>
            <CardType>V</CardType>
            <TransID>101965-0_10</TransID>
            <TimedOut>false</TimedOut>
            <BankTotals>null</BankTotals>
            <Ticket>null</Ticket>
            <CorporateCard>false</CorporateCard>
            <IsVisaDebit>false</IsVisaDebit>
         </receipt>
      </response>

    RESPONSE
  end

  def successful_authorize_response
    <<-RESPONSE
    <?xml version="1.0"?>
    <response>
      <receipt>
        <ReceiptId>47986100c3ad69c37ca945f5c54abf1c</ReceiptId>
        <ReferenceNum>660144080010396720</ReferenceNum>
        <ResponseCode>027</ResponseCode>
        <ISO>01</ISO>
        <AuthCode>149406</AuthCode>
        <TransTime>09:59:15</TransTime>
        <TransDate>2016-03-10</TransDate>
        <TransType>01</TransType>
        <Complete>true</Complete>
        <Message>APPROVED           *                    =</Message>
        <TransAmount>1.00</TransAmount>
        <CardType>V</CardType>
        <TransID>51340-0_10</TransID>
        <TimedOut>false</TimedOut>
        <BankTotals>null</BankTotals>
        <Ticket>null</Ticket>
        <CorporateCard>false</CorporateCard>
        <MessageId>1A6070359555668</MessageId>
        <IsVisaDebit>false</IsVisaDebit>
      </receipt>
    </response>
    RESPONSE
  end

  def successful_authorization_network_tokenization
    <<~RESPONSE
      <?xml version="1.0"?>
      <response>
         <receipt>
            <ReceiptId>d88d9f5f3472898832c54d6b5572757e</ReceiptId>
            <ReferenceNum>660110910011139740</ReferenceNum>
            <ResponseCode>027</ResponseCode>
            <ISO>01</ISO>
            <AuthCode>873534</AuthCode>
            <TransTime>09:31:41</TransTime>
            <TransDate>2015-07-09</TransDate>
            <TransType>01</TransType>
            <Complete>true</Complete>
            <Message>APPROVED           *                    =</Message>
            <TransAmount>1.00</TransAmount>
            <CardType>V</CardType>
            <TransID>109232-0_10</TransID>
            <TimedOut>false</TimedOut>
            <BankTotals>null</BankTotals>
            <Ticket>null</Ticket>
            <CorporateCard>false</CorporateCard>
            <IsVisaDebit>false</IsVisaDebit>
         </receipt>
      </response>

    RESPONSE
  end

  def successful_purchase_response_with_avs_result
    <<~RESPONSE
      <?xml version="1.0"?>
      <response>
        <receipt>
          <ReceiptId>9c7189ec64b58f541335be1ca6294d09</ReceiptId>
          <ReferenceNum>660110910011136190</ReferenceNum>
          <ResponseCode>027</ResponseCode>
          <ISO>01</ISO>
          <AuthCode>115497</AuthCode>
          <TransTime>15:20:51</TransTime>
          <TransDate>2014-06-18</TransDate>
          <TransType>00</TransType>
          <Complete>true</Complete><Message>APPROVED * =</Message>
          <TransAmount>10.10</TransAmount>
          <CardType>V</CardType>
          <TransID>491573-0_9</TransID>
          <TimedOut>false</TimedOut>
          <BankTotals>null</BankTotals>
          <Ticket>null</Ticket>
          <CorporateCard>false</CorporateCard>
          <AvsResultCode>A</AvsResultCode>
          <ITDResponse>null</ITDResponse>
          <IsVisaDebit>false</IsVisaDebit>
        </receipt>
      </response>

    RESPONSE
  end

  def failed_purchase_response
    <<~RESPONSE
      <?xml version="1.0"?>
      <response>
        <receipt>
          <ReceiptId>1026.1</ReceiptId>
          <ReferenceNum>661221050010170010</ReferenceNum>
          <ResponseCode>481</ResponseCode>
          <ISO>01</ISO>
          <AuthCode>013511</AuthCode>
          <TransTime>18:41:13</TransTime>
          <TransDate>2008-01-05</TransDate>
          <TransType>00</TransType>
          <Complete>true</Complete>
          <Message>DECLINED * =</Message>
          <TransAmount>1.00</TransAmount>
          <CardType>V</CardType>
          <TransID>97-2-0</TransID>
          <TimedOut>false</TimedOut>
        </receipt>
      </response>

    RESPONSE
  end

  def successful_store_response
    <<~RESPONSE
      <?xml version="1.0"?>
      <response>
        <receipt>
          <DataKey>1234567890</DataKey>
          <ResponseCode>027</ResponseCode>
          <Complete>true</Complete>
          <Message>Successfully registered cc details * =</Message>
        </receipt>
      </response>
    RESPONSE
  end

  def successful_store_with_duration_response
    <<~RESPONSE
      <?xml version="1.0"?>
      <response>
        <receipt>
          <DataKey>1234567890</DataKey>
          <ReceiptId>null</ReceiptId>
          <ReferenceNum>null</ReferenceNum>
          <ResponseCode>001</ResponseCode>
          <ISO>null</ISO>
          <AuthCode>null</AuthCode>
          <Message>Successfully registered CC details.</Message>
          <TransType>null</TransType>
          <Complete>true</Complete>
          <TransAmount>null</TransAmount>
          <CardType>null</CardType>
          <TransID>null</TransID>
          <TimedOut>false</TimedOut>
          <CorporateCard>null</CorporateCard>
          <RecurSuccess>null</RecurSuccess>
          <AvsResultCode>null</AvsResultCode>
          <CvdResultCode>null</CvdResultCode>
          <ResSuccess>true</ResSuccess>
          <PaymentType>cc</PaymentType>
          <IsVisaDebit>null</IsVisaDebit>
          <ResolveData>
            <anc1/>
            <masked_pan>4242***4242</masked_pan>
            <expdate>2010</expdate>
          </ResolveData>
        </receipt>
      </response>
    RESPONSE
  end

  def successful_unstore_response
    <<~RESPONSE
      <?xml version="1.0"?>
      <response>
        <receipt>
          <DataKey>1234567890</DataKey>
          <ResponseCode>027</ResponseCode>
          <Complete>true</Complete>
          <Message>Successfully deleted cc details * =</Message>
        </receipt>
      </response>
    RESPONSE
  end

  def successful_update_response
    <<~RESPONSE
      <?xml version="1.0"?>
      <response>
        <receipt>
          <DataKey>1234567890</DataKey>
          <ResponseCode>027</ResponseCode>
          <Complete>true</Complete>
          <Message>Successfully updated cc details * =</Message>
        </receipt>
      </response>
    RESPONSE
  end

  def failed_void_response
    <<-RESPONSE
      <?xml version="1.0"?>
      <response>
        <receipt>
          <ReceiptId>null</ReceiptId>
          <ReferenceNum>null</ReferenceNum>
          <ResponseCode>null</ResponseCode>
          <ISO>null</ISO>
          <AuthCode>null</AuthCode>
          <TransTime>null</TransTime>
          <TransDate>null</TransDate>
          <TransType>null</TransType>
          <Complete>false</Complete>
          <Message>No Pre-auth corresponds to the store Id and order Id and transaction Id entered</Message>
          <TransAmount>null</TransAmount>
          <CardType>null</CardType>
          <TransID>null</TransID>
          <TimedOut>false</TimedOut>
          <BankTotals>null</BankTotals>
          <Ticket>null</Ticket>
          <IsVisaDebit>false</IsVisaDebit>
        </receipt>
      </response>
    RESPONSE
  end

  def successful_verify_response
    <<-RESPONSE
    <?xml version="1.0" standalone="yes"?>
    <response>
      <receipt>
        <ReceiptId>93565164-01571</ReceiptId>
        <ReferenceNum>660158360010251110</ReferenceNum>
        <ResponseCode>027</ResponseCode>
        <ISO>01</ISO>
        <AuthCode>000000</AuthCode>
        <TransTime>16:06:11</TransTime>
        <TransDate>2019-11-04</TransDate>
        <TransType>06</TransType>
        <Complete>true</Complete>
        <Message>APPROVED           *                    =</Message>
        <TransAmount>0.00</TransAmount>
        <CardType>V</CardType>
        <TransID>125-0_14</TransID>
        <TimedOut>false</TimedOut>
        <BankTotals>null</BankTotals>
        <Ticket>null</Ticket>
        <AvsResultCode>null</AvsResultCode>
        <ITDResponse>null</ITDResponse>
        <CvdResultCode>1M</CvdResultCode>
        <CavvResultCode>2</CavvResultCode>
        <IsVisaDebit>false</IsVisaDebit>
      </receipt>
    </response>
    RESPONSE
  end

  def xml_purchase_fixture
    '<request><store_id>store1</store_id><api_token>yesguy</api_token><purchase><amount>1.01</amount><pan>4242424242424242</pan><expdate>0303</expdate><crypt_type>7</crypt_type><order_id>order1</order_id></purchase></request>'
  end

  def xml_capture_fixture
    '<request><store_id>store1</store_id><api_token>yesguy</api_token><preauth><amount>1.01</amount><pan>4242424242424242</pan><expdate>0303</expdate><crypt_type>7</crypt_type><order_id>order1</order_id></preauth></request>'
  end

  def pre_scrub
    <<-REQUEST
      opening connection to esqa.moneris.com:443...
      opened
      starting SSL for esqa.moneris.com:443...
      SSL established
      <- "POST /gateway2/servlet/MpgRequest HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: esqa.moneris.com\r\nContent-Length: 176\r\n\r\n"
      <- "<request><store_id>store1</store_id><api_token>yesguy</api_token><res_add_cc><pan>4242424242424242</pan><expdate>1705</expdate><crypt_type>7</crypt_type></res_add_cc></request>"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Mon, 16 May 2016 02:35:23 GMT\r\n"
      -> "Connection: close\r\n"
      -> "Content-Type: text/html\r\n"
      -> "Set-Cookie: TS011902c9=01649737b1334cfbe6b21538231fb4ad142215050461293f17e2dc76d7821e71c2f25055ea; Path=/\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "\r\n"
      -> "391\r\n"
      reading 913 bytes...
      -> "<?xml version=\"1.0\"?><response><receipt><DataKey>LAmXQeZwdtzUtz1QI1vF6etR2</DataKey><ReceiptId>null</ReceiptId><ReferenceNum>null</ReferenceNum><ResponseCode>001</ResponseCode><ISO>null</ISO><AuthCode>null</AuthCode><Message>Successfully registered CC details.</Message><TransTime>22:35:23</TransTime><TransDate>2016-05-15</TransDate><TransType>null</TransType><Complete>true</Complete><TransAmount>null</TransAmount><CardType>null</CardType><TransID>null</TransID><TimedOut>false</TimedOut><CorporateCard>null</CorporateCard><RecurSuccess>null</RecurSuccess><AvsResultCode>null</AvsResultCode><CvdResultCode>null</CvdResultCode><ResSuccess>true</ResSuccess><PaymentType>cc</PaymentType><IsVisaDebit>null</IsVisaDebit><ResolveData><cust_id></cust_id><phone></phone><email></email><note></note><crypt_type>7</crypt_type><masked_pan>4242***4242</masked_pan><expdate>1705</expdate></ResolveData></receipt></response>"
      read 913 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    REQUEST
  end

  def post_scrub
    <<-REQUEST
      opening connection to esqa.moneris.com:443...
      opened
      starting SSL for esqa.moneris.com:443...
      SSL established
      <- "POST /gateway2/servlet/MpgRequest HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: esqa.moneris.com\r\nContent-Length: 176\r\n\r\n"
      <- "<request><store_id>[FILTERED]</store_id><api_token>[FILTERED]</api_token><res_add_cc><pan>[FILTERED]</pan><expdate>1705</expdate><crypt_type>7</crypt_type></res_add_cc></request>"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Mon, 16 May 2016 02:35:23 GMT\r\n"
      -> "Connection: close\r\n"
      -> "Content-Type: text/html\r\n"
      -> "Set-Cookie: TS011902c9=01649737b1334cfbe6b21538231fb4ad142215050461293f17e2dc76d7821e71c2f25055ea; Path=/\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "\r\n"
      -> "391\r\n"
      reading 913 bytes...
      -> "<?xml version=\"1.0\"?><response><receipt><DataKey>LAmXQeZwdtzUtz1QI1vF6etR2</DataKey><ReceiptId>null</ReceiptId><ReferenceNum>null</ReferenceNum><ResponseCode>001</ResponseCode><ISO>null</ISO><AuthCode>null</AuthCode><Message>Successfully registered CC details.</Message><TransTime>22:35:23</TransTime><TransDate>2016-05-15</TransDate><TransType>null</TransType><Complete>true</Complete><TransAmount>null</TransAmount><CardType>null</CardType><TransID>null</TransID><TimedOut>false</TimedOut><CorporateCard>null</CorporateCard><RecurSuccess>null</RecurSuccess><AvsResultCode>null</AvsResultCode><CvdResultCode>null</CvdResultCode><ResSuccess>true</ResSuccess><PaymentType>cc</PaymentType><IsVisaDebit>null</IsVisaDebit><ResolveData><cust_id></cust_id><phone></phone><email></email><note></note><crypt_type>7</crypt_type><masked_pan>4242***4242</masked_pan><expdate>1705</expdate></ResolveData></receipt></response>"
      read 913 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    REQUEST
  end
end
