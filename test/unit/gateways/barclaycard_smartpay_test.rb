require 'test_helper'

class BarclaycardSmartpayTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = BarclaycardSmartpayGateway.new(
      company: 'company',
      merchant: 'merchant',
      password: 'password'
    )

    @credit_card = credit_card
    @three_ds_enrolled_card = credit_card('4212345678901237', brand: :visa)
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }

    @options_with_alternate_address = {
      order_id: '1',
      billing_address: {
        name:     'PU JOI SO',
        address1: '新北市店溪路3579號139樓',
        company:  'Widgets Inc',
        city:     '新北市',
        zip:      '231509',
        country:  'TW',
        phone:    '(555)555-5555',
        fax:      '(555)555-6666'
      },
      email: 'pujoi@so.com',
      customer: 'PU JOI SO',
      description: 'Store Purchase'
    }

    @options_with_house_number_and_street = {
      order_id: '1',
      street: 'Top Level Drive',
      house_number: '1000',
      billing_address: address,
      description: 'Store Purchase'
    }

    @options_with_shipping_house_number_and_shipping_street = {
        order_id: '1',
        street: 'Top Level Drive',
        house_number: '1000',
        billing_address: address,
        shipping_house_number: '999',
        shipping_street: 'Downtown Loop',
        shipping_address: {
            name:     'PU JOI SO',
            address1: '新北市店溪路3579號139樓',
            company:  'Widgets Inc',
            city:     '新北市',
            zip:      '231509',
            country:  'TW',
            phone:    '(555)555-5555',
            fax:      '(555)555-6666'
        },
        description: 'Store Purchase'
    }

    @options_with_credit_fields = {
      order_id: '1',
      billing_address:       {
              name:     'Jim Smith',
              address1: '100 Street',
              company:  'Widgets Inc',
              city:     'Ottawa',
              state:    'ON',
              zip:      'K1C2N6',
              country:  'CA',
              phone:    '(555)555-5555',
              fax:      '(555)555-6666'},
      email: 'long@bob.com',
      customer: 'Longbob Longsen',
      description: 'Store Purchase',
      date_of_birth: '1990-10-11',
      entity_type: 'NaturalPerson',
      nationality: 'US',
      shopper_name: {
        firstName: 'Longbob',
        lastName: 'Longsen',
        gender: 'MALE'
      }
    }

    @avs_address = @options.clone
    @avs_address.update(billing_address: {
        name:     'Jim Smith',
        street:   'Test AVS result',
        houseNumberOrName: '2',
        city:     'Cupertino',
        state:    'CA',
        zip:      '95014',
        country:  'US'
        })

    @normalized_3ds_2_options = {
      reference: '345123',
      shopper_email: 'john.smith@test.com',
      shopper_ip: '77.110.174.153',
      shopper_reference: 'John Smith',
      billing_address: address(),
      order_id: '123',
      stored_credential: {reason_type: 'unscheduled'},
      three_ds_2: {
        channel: 'browser',
        browser_info: {
          accept_header: 'unknown',
          depth: 100,
          java: false,
          language: 'US',
          height: 1000,
          width: 500,
          timezone: '-120',
          user_agent: 'unknown'
        },
        notification_url: 'https://example.com/notification'
      }
    }
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(successful_authorize_response, successful_capture_response)

    assert_success response
    assert_equal '7914002629995504#8814002632606717', response.authorization
    assert response.test?
  end

  def test_successful_authorize_with_alternate_address
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options_with_alternate_address)
    end.check_request do |endpoint, data, headers|
      assert_match(/billingAddress.houseNumberOrName=%E6%96%B0%E5%8C%97%E5%B8%82%E5%BA%97%E6%BA%AA%E8%B7%AF3579%E8%99%9F139%E6%A8%93/, data)
      assert_match(/billingAddress.street=Not\+Provided/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal '7914002629995504', response.authorization
    assert response.test?
  end

  def test_successful_authorize_with_house_number_and_street
    response = stub_comms do
      @gateway.authorize(@amount,
        @credit_card,
        @options_with_house_number_and_street)
    end.check_request do |endpoint, data, headers|
      assert_match(/billingAddress.street=Top\+Level\+Drive/, data)
      assert_match(/billingAddress.houseNumberOrName=1000/, data)
    end.respond_with(successful_authorize_response)

    assert response
    assert_success response
    assert_equal '7914002629995504', response.authorization
  end

  def test_successful_authorize_with_shipping_house_number_and_street
    response = stub_comms do
      @gateway.authorize(@amount,
        @credit_card,
        @options_with_shipping_house_number_and_shipping_street)
    end.check_request do |endpoint, data, headers|
      assert_match(/billingAddress.street=Top\+Level\+Drive/, data)
      assert_match(/billingAddress.houseNumberOrName=1000/, data)
      assert_match(/deliveryAddress.street=Downtown\+Loop/, data)
      assert_match(/deliveryAddress.houseNumberOrName=999/, data)
    end.respond_with(successful_authorize_response)

    assert response
    assert_success response
    assert_equal '7914002629995504', response.authorization
  end

  def test_successful_authorize_with_extra_options
    shopper_interaction = 'ContAuth'
    shopper_statement   = 'One-year premium subscription'
    device_fingerprint  = 'abcde123'

    response = stub_comms do
      @gateway.authorize(
        @amount,
        @credit_card,
        @options.merge(
          shopper_interaction: shopper_interaction,
          device_fingerprint: device_fingerprint,
          shopper_statement: shopper_statement
        )
      )
    end.check_request do |endpoint, data, headers|
      assert_match(/shopperInteraction=#{shopper_interaction}/, data)
      assert_match(/shopperStatement=#{Regexp.quote(CGI.escape(shopper_statement))}/, data)
      assert_match(/deviceFingerprint=#{device_fingerprint}/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_successful_authorize
    @gateway.stubs(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal '7914002629995504', response.authorization
    assert response.test?
  end

  def test_successful_authorize_with_3ds
    @gateway.stubs(:ssl_post).returns(successful_authorize_with_3ds_response)

    response = @gateway.authorize(@amount, @three_ds_enrolled_card, @options)

    assert_equal '8815161318854998', response.authorization
    refute response.params['issuerUrl'].blank?
    refute response.params['md'].blank?
    refute response.params['paRequest'].blank?
    assert response.test?
  end

  def test_successful_authorize_with_3ds2_browser_client_data
    @gateway.stubs(:ssl_post).returns(successful_authorize_with_3ds2_response)

    assert response = @gateway.authorize(@amount, @three_ds_enrolled_card, @normalized_3ds_2_options)
    assert response.test?
    assert_equal '8815609737078177', response.authorization
    assert_equal response.params['resultCode'], 'IdentifyShopper'
    refute response.params['additionalData']['threeds2.threeDS2Token'].blank?
    refute response.params['additionalData']['threeds2.threeDSServerTransID'].blank?
    refute response.params['additionalData']['threeds2.threeDSMethodURL'].blank?
  end

  def test_failed_authorize
    @gateway.stubs(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_capture
    @gateway.stubs(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, '7914002629995504', @options)
    assert_success response
    assert_equal '7914002629995504#8814002632606717', response.authorization
    assert response.test?
  end

  def test_failed_capture
    @gateway.stubs(:ssl_post).raises(ActiveMerchant::ResponseError.new(stub(:code => '422', :body => failed_capture_response)))

    response = @gateway.capture(@amount, '0000000000000000', @options)
    assert_failure response
    assert_equal('167: Original pspReference required for this operation', response.message)
    assert response.test?
  end

  def test_legacy_capture_psp_reference_passed_for_refund
    response = stub_comms do
      @gateway.refund(@amount, '8814002632606717', @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/originalReference=8814002632606717/, data)
    end.respond_with(successful_refund_response)

    assert_success response
    assert response.test?
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.refund(@amount, '7914002629995504#8814002632606717', @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/originalReference=7914002629995504&/, data)
      assert_no_match(/8814002632606717/, data)
    end.respond_with(successful_refund_response)

    assert_success response
    assert response.test?
  end

  def test_failed_refund
    @gateway.stubs(:ssl_post).raises(ActiveMerchant::ResponseError.new(stub(:code => '422', :body => failed_refund_response)))

    response = @gateway.refund(@amount, '0000000000000000', @options)
    assert_failure response
    assert_equal('137: Invalid amount specified', response.message)
    assert response.test?
  end

  def test_successful_credit
    @gateway.expects(:ssl_post).returns(successful_credit_response)

    response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response
  end

  def test_failed_credit
    @gateway.expects(:ssl_post).returns(failed_credit_response)

    response = @gateway.credit(nil, @credit_card, @options)
    assert_failure response
  end

  def test_credit_contains_all_fields
    response = stub_comms do
      @gateway.credit(@amount, @credit_card, @options_with_credit_fields)
    end.check_request do |endpoint, data, headers|
      assert_match(%r{/refundWithData}, endpoint)
      assert_match(/dateOfBirth=1990-10-11&/, data)
      assert_match(/entityType=NaturalPerson&/, data)
      assert_match(/nationality=US&/, data)
      assert_match(/shopperName.firstName=Longbob&/, data)
    end.respond_with(successful_credit_response)

    assert_success response
    assert response.test?
  end

  def test_successful_third_party_payout
    response = stub_comms do
      @gateway.credit(@amount, @credit_card, @options_with_credit_fields.merge({third_party_payout: true}))
    end.check_request do |endpoint, data, headers|
      if /storeDetailAndSubmitThirdParty/ =~ endpoint
        assert_match(%r{/storeDetailAndSubmitThirdParty}, endpoint)
        assert_match(/dateOfBirth=1990-10-11&/, data)
        assert_match(/entityType=NaturalPerson&/, data)
        assert_match(/nationality=US&/, data)
        assert_match(/shopperName.firstName=Longbob&/, data)
        assert_match(/recurring\.contract=PAYOUT/, data)
      else
        assert_match(/originalReference=/, data)
      end
    end.respond_with(successful_payout_store_response, successful_payout_confirm_response)

    assert_success response
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void('7914002629995504', @options)
    assert_success response
    assert response.test?
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
  end

  def test_unsuccessful_verify
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
    assert_equal 'Refused', response.message
  end

  def test_authorize_nonfractional_currency
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(currency: 'JPY'))
    end.check_request do |endpoint, data, headers|
      assert_match(/amount.value=1/, data)
      assert_match(/amount.currency=JPY/,  data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_authorize_three_decimal_currency
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(currency: 'OMR'))
    end.check_request do |endpoint, data, headers|
      assert_match(/amount.value=100/, data)
      assert_match(/amount.currency=OMR/,  data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)

    response = @gateway.store(@credit_card, @options)
    assert_success response
  end

  def test_failed_store
    @gateway.stubs(:ssl_post).raises(ActiveMerchant::ResponseError.new(stub(:code => '422', :body => failed_store_response)))

    response = @gateway.store(@credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(failed_avs_response)

    response = @gateway.authorize(@amount, @credit_card, @avs_address)
    assert_failure response
    assert_equal 'N', response.avs_result['code']
    assert response.test?
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  def test_proper_error_response_handling
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(configuration_error_response)

    message = "#{response.params['errorCode']}: #{response.params['message']}"
    assert_equal('905: Payment details are not supported', message)

    response2 = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(validation_error_response)

    message2 = "#{response2.params['errorCode']}: #{response2.params['message']}"
    assert_equal('702: Internal error', message2)
  end

  private

  def successful_authorize_response
    'pspReference=7914002629995504&authCode=56469&resultCode=Authorised'
  end

  def successful_authorize_with_3ds_response
    'pspReference=8815161318854998&resultCode=RedirectShopper&issuerUrl=https%3A%2F%2Ftest.adyen.com%2Fhpp%2F3d%2Fvalidate.shtml&md=WIFa2sF3CuPyN53Txjt3U%2F%2BDuCsddzywiY5NLgEAdUAXPksHUzXL5E%2BsfvdpolkGWR8b1oh%2FNA3jNaUP9UCgfjhXqRslGFy9OGqcZ1ITMz54HHm%2FlsCKN9bTftKnYA4F7GqvOgcIIrinUZjbMvW9doGifwzSqYLo6ASOm6bARL5n7cIFV8IWtA2yPlO%2FztKSTRJt1glN4s8sMcpE57z4soWKMuycbdXdpp6d4ZRSa%2F1TPF0MnJF0zNaSAAkw9JpXqGMOz5sFF2Smpc38HXJzM%2FV%2B1mmoDhhWmXXOb5YQ0QSCS7DXKIcr8ZtuGuGmFp0QOfZiO41%2B2I2N7VhONVx8xSn%2BLu4m6vaDIg5qsnd9saxaWwbJpl9okKm6pB2MJap9ScuBCcvI496BPCrjQ2LHxvDWhk6M3Exemtv942NQIGlsiPaW0KXoC2dQvBsxWh0K&paRequest=eNpVUtuOgjAQ%2FRXj%2B1KKoIWMTVgxWR%2B8RNkPaMpEycrFUlb8%2B20B190%2BnXPm0pnTQnpRiMkJZauQwxabRpxxkmfLacQYDeiczihjgR%2BGbMrhEB%2FxxuEbVZNXJaeO63hAntSUK3kRpeYg5O19s%2BPUm%2FnBHMhIoUC1SXiKjT4URSxvba5QARlkKEWB%2FFSbgbLr41QIpXFVFUB6HWTVllo9OPNMwyeBVl35Reu6iQi53%2B9OM5Y7sipMVqmF1G9tA8QmAnlNeGgtakzjLs%2F4Pjl3u3TtbdNtZzDdJV%2FBPu7PEojNgExo5J5LmUvpfELDyPcjPwDS6yAKOxFffx4nxhXXrDwIUNt74oFQG%2FgrgLFdYSkfPFwws9WTAXZ1VaLJMPb%2BYiCvoVcf1mSpjW%2B%2BN9i8YKFr0MLa3Qdsl9yYREM37NtYAsSWkvElyfjiBv37CT9ySbE1'
  end

  def successful_authorize_with_3ds2_response
    'additionalData.threeds2.threeDS2Token=BQABAQB9sBAzFS%2BrvT1fuY78N4P5BA5DO6s9Y6jCIzvMcH%2Bk5%2B0ms8dRPEZZhO8CYx%2Fa5NCl8r4vyJj0nI0HZ9CBl%2FQLxtGLYfVu6sNxZc9xZry%2Bm24pBGTtHsd4vunorPNPAGlYWHBXtf4h0Sj9Qy0bzlau7a%2Feayi1cpjbfV%2B8Eqw%2FAod1B80heU8sX2DKm5SHlR4o0qTu0WQUSJfKRxjdJ1AntgAxjYo3uFUlU%2FyhNpdRiAxgauLImbllfQTGVTcYBQXsY9FSakfAZRW1kT7bNMraCvRUpp4o1Z5ZezJxPcksfCEzFVPyJYcTvcV4odQK4tT6imRLRvG1OgUVNzNAuDBnEJtFOC%2BE5YwAwfKuloCqB9oAAOzL5ZHXOXPASY2ehJ3RaCZjqj5vmAX8L9GY35FV8q49skYZpzIvlMICWjErI2ayKMCiXHFDE54f2GJEhVRKpY9s506740UGQc0%2FMgbKyLyqtU%2BRG30BwA9bSt3NQKchm9xoOL7U%2Bzm6OIeikmw94TBq%2BmBN7SdQi%2BK2W4yfMkqFsl7hc7HHBa%2BOc6At7wxxdxCLg6wksQmDxElXeQfFkWvoBuR96fIHaXILnVHKjWcTbeulXBhVPA5Y47MLEtZL3G8k%2BzKTFUCW7O0MN2WxUoMBT8foan1%2B9QhZejEqiamreIs56PLQkJvhigyRQmiqwnVjXiFOv%2FEcWn0Z6IM2TnAfw3Kd2KwZ9JaePLtZ2Ck7%2FUEsdt1Kj2HYeE86WM4PESystER5oBT12xWXvbp8CEA7Mulmpd3bkiMl5IVRoSBL5pl4qZd1CrnG%2FeuvtXYTsN%2FdA%2BIcWwiLiXpmSwqaRB8DfChwouuNMAAkfKhQ6b3vLAToc3o%2B3Xa1QetsK8GI1pmjkoZRvLd2xfGhVe%2FmCl23wzQsAicwB9ZXXMgWbaS2OwdwsISQGOmsWrajzp7%2FvR0T4aHqJlrFvKnc9BrWEWbDi8g%2BDFZ2E2ifhFYSYhrHVA7yOIIDdTQnH3CIzaevxUAnbIyFsxrhy8USdP6R6CdJZ%2Bg0rIJ5%2FeZ5P8JjDiYJWi5FDJwy%2BNP9PQIFFim6psbELCtnAaW1m7pU1FeNwjYUGIdVD2f%2BVYJe4cWHPCaWAAsARNXTzjrfUEq%2BpEYDcs%2FLyTB8f69qSrmTSDGsCETsNNy27LY%2BtodGDKsxtW35jIqoV8l2Dra3wucman8nIZp3VTNtNvZDCqWetLXxBbFVZN6ecuoMPwhER5MBFUrkkXCSSFBK%2FNGp%2FXaEDP6A2hmUKvXikL3F9S7MIKQCUYC%2FI7K4DFYFBjTBzN4%3D&additionalData.threeds2.threeDSServerTransID=efbf9d05-5e6b-4659-a64e-f1dfa5d846c4&additionalData.threeds2.threeDSMethodURL=https%3A%2F%2Fpal-test.adyen.com%2Fthreeds2simulator%2Facs%2FstartMethod.shtml&pspReference=8815609737078177&resultCode=IdentifyShopper'
  end

  def failed_authorize_response
    'pspReference=7914002630895750&refusalReason=Refused&resultCode=Refused'
  end

  def successful_capture_response
    'pspReference=8814002632606717&response=%5Bcapture-received%5D'
  end

  def failed_capture_response
    'errorType=validation&errorCode=167&message=Original+pspReference+required+for+this+operation&status=422'
  end

  def successful_refund_response
    'pspReference=8814002634988063&response=%5Brefund-received%5D'
  end

  def failed_refund_response
    'errorType=validation&errorCode=137&message=Invalid+amount+specified&status=422'
  end

  def successful_credit_response
    'fraudResult.accountScore=70&fraudResult.results.0.accountScore=20&fraudResult.results.0.checkId=2&fraudResult.results.0.name=CardChunkUsage&fraudResult.results.1.accountScore=25&fraudResult.results.1.checkId=4&fraudResult.results.1.name=HolderNameUsage&fraudResult.results.2.accountScore=25&fraudResult.results.2.checkId=8&fraudResult.results.2.name=ShopperEmailUsage&fraudResult.results.3.accountScore=0&fraudResult.results.3.checkId=1&fraudResult.results.3.name=PaymentDetailRefCheck&fraudResult.results.4.accountScore=0&fraudResult.results.4.checkId=13&fraudResult.results.4.name=IssuerRefCheck&fraudResult.results.5.accountScore=0&fraudResult.results.5.checkId=15&fraudResult.results.5.name=IssuingCountryReferral&fraudResult.results.6.accountScore=0&fraudResult.results.6.checkId=26&fraudResult.results.6.name=ShopperEmailRefCheck&fraudResult.results.7.accountScore=0&fraudResult.results.7.checkId=27&fraudResult.results.7.name=PmOwnerRefCheck&fraudResult.results.8.accountScore=0&fraudResult.results.8.checkId=56&fraudResult.results.8.name=ShopperReferenceTrustCheck&fraudResult.results.9.accountScore=0&fraudResult.results.9.checkId=10&fraudResult.results.9.name=HolderNameContainsNumber&fraudResult.results.10.accountScore=0&fraudResult.results.10.checkId=11&fraudResult.results.10.name=HolderNameIsOneWord&fraudResult.results.11.accountScore=0&fraudResult.results.11.checkId=21&fraudResult.results.11.name=EmailDomainValidation&pspReference=8514743049239955&resultCode=Received'
  end

  def successful_payout_store_response
    'pspReference=8815391117417347&resultCode=%5Bpayout-submit-received%5D'
  end

  def successful_payout_confirm_response
    'pspReference=8815391117421182&response=%5Bpayout-confirm-received%5D'
  end

  def failed_credit_response
    'errorType=validation&errorCode=137&message=Invalid+amount+specified&status=422'
  end

  def successful_void_response
    'pspReference=7914002636728161&response=%5Bcancel-received%5D'
  end

  def successful_store_response
    'alias=H167852639363479&aliasType=Default&pspReference=8614540938336754&rechargeReference=8314540938334240&recurringDetailReference=8414540862673349&result=Success'
  end

  def failed_store_response
    'errorType=validation&errorCode=129&message=Expiry+Date+Invalid&status=422'
  end

  def failed_avs_response
    'additionalData.liabilityShift=false&additionalData.authCode=3115&additionalData.avsResult=2+Neither+postal+code+nor+address+match&additionalData.cardHolderName=Longbob+Longsen&additionalData.threeDOffered=false&additionalData.refusalReasonRaw=AUTHORISED&additionalData.issuerCountry=US&additionalData.cvcResult=1+Matches&additionalData.avsResultRaw=2&additionalData.threeDAuthenticated=false&additionalData.cvcResultRaw=1&additionalData.acquirerCode=SmartPayTestPmmAcquirer&additionalData.acquirerReference=7F50RDN2L06&fraudResult.accountScore=170&fraudResult.results.0.accountScore=20&fraudResult.results.0.checkId=2&fraudResult.results.0.name=CardChunkUsage&fraudResult.results.1.accountScore=25&fraudResult.results.1.checkId=4&fraudResult.results.1.name=HolderNameUsage&fraudResult.results.2.accountScore=25&fraudResult.results.2.checkId=8&fraudResult.results.2.name=ShopperEmailUsage&fraudResult.results.3.accountScore=0&fraudResult.results.3.checkId=1&fraudResult.results.3.name=PaymentDetailRefCheck&fraudResult.results.4.accountScore=0&fraudResult.results.4.checkId=13&fraudResult.results.4.name=IssuerRefCheck&fraudResult.results.5.accountScore=0&fraudResult.results.5.checkId=15&fraudResult.results.5.name=IssuingCountryReferral&fraudResult.results.6.accountScore=0&fraudResult.results.6.checkId=26&fraudResult.results.6.name=ShopperEmailRefCheck&fraudResult.results.7.accountScore=0&fraudResult.results.7.checkId=27&fraudResult.results.7.name=PmOwnerRefCheck&fraudResult.results.8.accountScore=0&fraudResult.results.8.checkId=10&fraudResult.results.8.name=HolderNameContainsNumber&fraudResult.results.9.accountScore=0&fraudResult.results.9.checkId=11&fraudResult.results.9.name=HolderNameIsOneWord&fraudResult.results.10.accountScore=0&fraudResult.results.10.checkId=21&fraudResult.results.10.name=EmailDomainValidation&fraudResult.results.11.accountScore=100&fraudResult.results.11.checkId=20&fraudResult.results.11.name=AVSAuthResultCheck&fraudResult.results.12.accountScore=0&fraudResult.results.12.checkId=25&fraudResult.results.12.name=CVCAuthResultCheck&pspReference=8814591938804745&refusalReason=FRAUD-CANCELLED&resultCode=Cancelled&authCode=3115'
  end

  def validation_error_response
    'errorType=validation&errorCode=702&message=Internal+error&status=500'
  end

  def configuration_error_response
    'errorType=configuration&errorCode=905&message=Payment+details+are+not+supported&pspReference=4315391674762857&status=500'
  end

  def transcript
    %(
    opening connection to pal-test.barclaycardsmartpay.com:443...
    opened
    starting SSL for pal-test.barclaycardsmartpay.com:443...
    SSL established
    <- "POST /pal/servlet/Payment/v12/authorise HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded; charset=utf-8\r\nAuthorization: Basic d3NAQ29tcGFueS5QbHVzNTAwQ1k6UVpiWWd3Z2pDejNiZEdiNEhqYXk=\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: pal-test.barclaycardsmartpay.com\r\nContent-Length: 466\r\n\r\n"
    <- "merchantAccount=Plus500CYEcom&reference=1&shopperEmail=long%40bob.com&shopperReference=Longbob+Longsen&amount.currency=EUR&amount.value=100&card.cvc=737&card.expiryMonth=06&card.expiryYear=2016&card.holderName=Longbob+Longsen&card.number=4111111111111111&billingAddress.city=Ottawa&billingAddress.street=My+Street+Apt&billingAddress.houseNumberOrName=456+1&billingAddress.postalCode=K1C2N6&billingAddress.stateOrProvince=ON&billingAddress.country=CA&action=authorise"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Date: Thu, 28 Jan 2016 21:32:16 GMT\r\n"
    -> "Server: Apache\r\n"
    -> "Set-Cookie: JSESSIONID=69398C80F6B1CBB04AA98B1D1895898B.test4e; Path=/pal/; Secure; HttpOnly\r\n"
    -> "pspReference: 8614540167365201\r\n"
    -> "Content-Length: 66\r\n"
    -> "Connection: close\r\n"
    -> "Content-Type: application/x-www-form-urlencoded;charset=utf-8\r\n"
    -> "\r\n"
    reading 66 bytes...
    -> ""
    -> "pspReference=8614540167365201&resultCode=Authorised&authCode=33683"
    read 66 bytes
    Conn close
    opening connection to pal-test.barclaycardsmartpay.com:443...
    opened
    starting SSL for pal-test.barclaycardsmartpay.com:443...
    SSL established
    <- "POST /pal/servlet/Payment/v12/capture HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded; charset=utf-8\r\nAuthorization: Basic d3NAQ29tcGFueS5QbHVzNTAwQ1k6UVpiWWd3Z2pDejNiZEdiNEhqYXk=\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: pal-test.barclaycardsmartpay.com\r\nContent-Length: 140\r\n\r\n"
    <- "merchantAccount=Plus500CYEcom&originalReference=8614540167365201&modificationAmount.currency=EUR&modificationAmount.value=100&action=capture"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Date: Thu, 28 Jan 2016 21:32:18 GMT\r\n"
    -> "Server: Apache\r\n"
    -> "Set-Cookie: JSESSIONID=951837A566ED97C5869AA7C9DF91B608.test104e; Path=/pal/; Secure; HttpOnly\r\n"
    -> "pspReference: 7914540167387121\r\n"
    -> "Content-Length: 61\r\n"
    -> "Connection: close\r\n"
    -> "Content-Type: application/x-www-form-urlencoded;charset=utf-8\r\n"
    -> "\r\n"
    reading 61 bytes...
    -> ""
    -> "pspReference=7914540167387121&response=%5Bcapture-received%5D"
    read 61 bytes
    Conn close
    )
  end

  def scrubbed_transcript
    %(
    opening connection to pal-test.barclaycardsmartpay.com:443...
    opened
    starting SSL for pal-test.barclaycardsmartpay.com:443...
    SSL established
    <- "POST /pal/servlet/Payment/v12/authorise HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded; charset=utf-8\r\nAuthorization: Basic [FILTERED]Accept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: pal-test.barclaycardsmartpay.com\r\nContent-Length: 466\r\n\r\n"
    <- "merchantAccount=Plus500CYEcom&reference=1&shopperEmail=long%40bob.com&shopperReference=Longbob+Longsen&amount.currency=EUR&amount.value=100&card.cvc=[FILTERED]&card.expiryMonth=06&card.expiryYear=2016&card.holderName=Longbob+Longsen&card.number=[FILTERED]&billingAddress.city=Ottawa&billingAddress.street=My+Street+Apt&billingAddress.houseNumberOrName=456+1&billingAddress.postalCode=K1C2N6&billingAddress.stateOrProvince=ON&billingAddress.country=CA&action=authorise"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Date: Thu, 28 Jan 2016 21:32:16 GMT\r\n"
    -> "Server: Apache\r\n"
    -> "Set-Cookie: JSESSIONID=69398C80F6B1CBB04AA98B1D1895898B.test4e; Path=/pal/; Secure; HttpOnly\r\n"
    -> "pspReference: 8614540167365201\r\n"
    -> "Content-Length: 66\r\n"
    -> "Connection: close\r\n"
    -> "Content-Type: application/x-www-form-urlencoded;charset=utf-8\r\n"
    -> "\r\n"
    reading 66 bytes...
    -> ""
    -> "pspReference=8614540167365201&resultCode=Authorised&authCode=33683"
    read 66 bytes
    Conn close
    opening connection to pal-test.barclaycardsmartpay.com:443...
    opened
    starting SSL for pal-test.barclaycardsmartpay.com:443...
    SSL established
    <- "POST /pal/servlet/Payment/v12/capture HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded; charset=utf-8\r\nAuthorization: Basic [FILTERED]Accept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: pal-test.barclaycardsmartpay.com\r\nContent-Length: 140\r\n\r\n"
    <- "merchantAccount=Plus500CYEcom&originalReference=8614540167365201&modificationAmount.currency=EUR&modificationAmount.value=100&action=capture"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Date: Thu, 28 Jan 2016 21:32:18 GMT\r\n"
    -> "Server: Apache\r\n"
    -> "Set-Cookie: JSESSIONID=951837A566ED97C5869AA7C9DF91B608.test104e; Path=/pal/; Secure; HttpOnly\r\n"
    -> "pspReference: 7914540167387121\r\n"
    -> "Content-Length: 61\r\n"
    -> "Connection: close\r\n"
    -> "Content-Type: application/x-www-form-urlencoded;charset=utf-8\r\n"
    -> "\r\n"
    reading 61 bytes...
    -> ""
    -> "pspReference=7914540167387121&response=%5Bcapture-received%5D"
    read 61 bytes
    Conn close
    )
  end

end
