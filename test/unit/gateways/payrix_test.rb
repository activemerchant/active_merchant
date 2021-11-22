# @format

require 'test_helper'

class PayrixTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway =
      PayrixGateway.new(
        login: 'login',
        password: 'password',
        business_id: 1,
        service: :hpp
      )
    @amount = 100_00

    @options = {
      address: address,
      description: 'Store Purchase',
      ip: '127.0.0.1',
      return_url: 'https://example.net',
      transaction_reference: '1234'
    }
  end

  def test_failed_login
    @gateway.expects(:ssl_request).returns(failed_login_response)
    response = @gateway.setup_purchase(@amount, @options)

    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error],
                 response.error_code
  end

  def test_hpp_successful_purchase
    response =
      stub_comms { @gateway.setup_purchase(@amount, @options) }
        .check_request do |_verb, endpoint, _data, headers|
          unless endpoint =~ /login$/
            assert_equal 'Bearer ACCESS_TOKEN', headers['Authorization']
          end
        end
        .respond_with(successful_login_response, successful_hpp_response)

    assert_success response

    assert_equal 'TOKEN', response.token
    assert_match /sandbox\.hosted\.paymentsapi\.io/, response.redirect_url
    assert response.test?
  end

  def test_hpp_failed_purchase
    stub_response(failed_hpp_response)

    response = @gateway.setup_purchase(@amount, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error],
                 response.error_code
  end

  def test_hpp_successful_authorize
    response =
      stub_comms { @gateway.setup_authorize(@amount, @options) }
        .check_request do |_verb, endpoint, data, headers|
          unless endpoint =~ /login$/
            payload = JSON.parse(data)
            assert_equal 'PREAUTH', payload['Transaction']['ProcessType']
          end
        end
        .respond_with(successful_login_response, successful_hpp_response)

    assert_success response

    assert_equal 'TOKEN', response.token
    assert_match /sandbox\.hosted\.paymentsapi\.io/, response.redirect_url
    assert response.test?
  end

  def test_details_for_successful_token
    stub_response(successful_details_for_token_response)

    response = @gateway.details_for('TOKEN')

    assert_success response

    assert_equal 'TOKEN', response.token
    assert response.test?
  end

  def test_details_for_waiting_token
    stub_response(waiting_details_for_token_response)

    response = @gateway.details_for('TOKEN')

    assert_failure response

    assert 'Token URL not yet accessed', response.message
    assert_equal 'TOKEN', response.token
    assert response.test?
  end

  def test_details_for_failed_token
    stub_response(failed_details_for_token_response)

    response = @gateway.details_for('TOKEN')

    assert_failure response

    assert response.test?
    assert_equal 'TOKEN', response.token
    assert_equal 'PROCESSED_REJECTED', response.error_code
    assert_equal 'URL Opened, not completed and closed', response.message
  end

  def test_scrub
    assert_false @gateway.supports_scrubbing?
  end

  private

  def successful_login_response
    '{"access_token":"ACCESS_TOKEN","expires_in":3600,"token_type":"Bearer","scope":"integrapay.api.public"}'
  end

  def failed_login_response
    '{"errorCode":"BadRequest","errorMessage":"The Password field is required.","errorDetail":"Password"}'
  end

  def successful_hpp_response
    '{"token":"TOKEN","redirectToUrl":"https://sandbox.hosted.paymentsapi.io/ui/hpp/api/65026106-fd50-4c09-a43b-9c6bab4ab65f"}'
  end

  def failed_hpp_response
    '{"errorCode":"BadRequest","errorMessage":"Reference is required","errorDetail":"Transaction.Reference"}'
  end

  def successful_details_for_token_response
    '{"token":"TOKEN","type":"HPP","time":"2021-11-22T20:48:00+00:00","status":"PROCESSED_SUCCESSFUL","statusDescription":"PROCESSED_SUCCESSFUL","returnUrl":"https://app.black.test/public/client/e4xpJS48v/payment/success","redirectToUrl":"https://sandbox.hosted.paymentsapi.io/ui/hpp/api/TOKEN","template":"60357dc7-de7a-446a-a1c1-8d228eab89a0","templateName":"Basic","transaction":{"business":{"businessId":"90024","businessName":"Debtor Daddy Test"},"time":"2021-11-22T20:51:49.89+00:00","transactionId":"2272290","secondaryTransactionId":"RT732135","reference":"c76684ed583be031c58e1464819a6529","description":"Purchase","scheduleReference":null,"amount":61.87,"amountRequested":61.87,"amountRefunded":0.00,"currency":"AUD","type":"RT","typeDescription":"Realtime Payment - Website","statusCode":"S","subStatusCode":null,"statusDescription":"Settled","paymentMethod":"VISA","payer":null,"card":{"cardNumber":"411111xxxxxx1111","cardholderName":"TEST CARD","cardExpires":"2027-11-01T00:00:00","cardType":"Visa"},"bankAccount":null,"rejectionRecovery":null,"verification":null,"source":null,"recurringReference":null,"cardStorageType":null,"cardAuthorizationType":null,"cardAuthorizationReference":"TG-cd217b17-8278-4a3d-b1ab-5ff5b7118281","profile":null},"payer":null,"schedule":null,"requestHpp":{"returnUrl":"https://app.black.test/public/client/e4xpJS48v/payment/success","template":"Basic","transaction":{"processType":"COMPLETE","reference":"c76684ed583be031c58e1464819a6529","description":"Purchase","amount":61.87,"currencyCode":"USD"},"payer":{"savePayer":false,"uniqueReference":null,"groupReference":null,"familyOrBusinessName":null,"givenName":null,"email":null,"phone":"018005001","mobile":"017775001","address":null,"dateOfBirth":null,"extraInfo":null},"audit":null},"events":[{"event":"WAITING","time":"2021-11-22T20:48:00+00:00","description":null,"username":"API: ","ip":"120.136.2.157"},{"event":"VALIDATED","time":"2021-11-22T20:48:00+00:00","description":null,"username":null,"ip":""},{"event":"PROCESSED_SUCCESSFUL","time":"2021-11-22T20:52:00+00:00","description":null,"username":null,"ip":"120.136.2.157"},{"event":"EXPIRED","time":"2021-11-22T21:08:00+00:00","description":null,"username":null,"ip":null}]}'
  end

  def waiting_details_for_token_response
    '{"token":"TOKEN","type":"HPP","time":"2021-11-21T23:24:00+00:00","status":"WAITING","statusDescription":"WAITING","returnUrl":"https://app.black.test/payrix","redirectToUrl":"https://sandbox.hosted.paymentsapi.io/ui/hpp/api/TOKEN","template":"60357dc7-de7a-446a-a1c1-8d228eab89a0","templateName":"Basic","transaction":null,"payer":null,"schedule":null,"requestHpp":{"returnUrl":"https://app.black.test/payrix","template":"Basic","transaction":{"processType":"COMPLETE","reference":"030ec6d893dabcf48bad2859a61735b5","description":"Store Purchase","amount":100.00,"currencyCode":"USD"},"payer":{"savePayer":false,"uniqueReference":null,"groupReference":null,"familyOrBusinessName":null,"givenName":null,"email":"user@example.com","phone":null,"mobile":null,"address":{"line1":"456 My Street","line2":"Apt 1","suburb":null,"state":"ON","postCode":"K1C2N6","country":"CA"},"dateOfBirth":null,"extraInfo":null},"audit":null},"events":[{"event":"WAITING","time":"2021-11-21T23:24:00+00:00","description":null,"username":"API: ","ip":"120.136.2.157"}]}'
  end

  def failed_details_for_token_response
    '{"token":"TOKEN","type":"HPP","time":"2021-11-23T02:47:00+00:00","status":"PROCESSED_REJECTED","statusDescription":"PROCESSED_REJECTED","returnUrl":"https://app.black.test/payrix","redirectToUrl":"https://sandbox.hosted.paymentsapi.io/ui/hpp/api/TOKEN","template":"60357dc7-de7a-446a-a1c1-8d228eab89a0","templateName":"Basic","transaction":{"business":{"businessId":"90024","businessName":"Debtor Daddy Test"},"time":"2021-11-23T02:47:33.083+00:00","transactionId":"2272471","secondaryTransactionId":"RT732330","reference":"3632fa83cfcd4851137c2dec371717a8","description":"Store Purchase","scheduleReference":null,"amount":100.31,"amountRequested":100.31,"amountRefunded":0.00,"currency":"AUD","type":"RT","typeDescription":"Realtime Payment - Website","statusCode":"R","subStatusCode":"R3","statusDescription":"Rejected: Invalid Credit Card","paymentMethod":"VISA","payer":null,"card":{"cardNumber":"411111xxxxxx1111","cardholderName":"TEST CARD","cardExpires":"2027-03-01T00:00:00","cardType":"Visa"},"bankAccount":null,"rejectionRecovery":null,"verification":null,"source":null,"recurringReference":null,"cardStorageType":null,"cardAuthorizationType":null,"cardAuthorizationReference":"TG-491ea49f-ac45-43cb-a074-4305493e79c0","profile":null},"payer":null,"schedule":null,"requestHpp":{"returnUrl":"https://app.black.test/payrix","template":"Basic","transaction":{"processType":"COMPLETE","reference":"3632fa83cfcd4851137c2dec371717a8","description":"Store Purchase","amount":100.31,"currencyCode":"USD"},"payer":{"savePayer":false,"uniqueReference":null,"groupReference":null,"familyOrBusinessName":null,"givenName":null,"email":"user@example.com","phone":null,"mobile":null,"address":{"line1":"456 My Street","line2":"Apt 1","suburb":null,"state":"ON","postCode":"K1C2N6","country":"CA"},"dateOfBirth":null,"extraInfo":null},"audit":null},"events":[{"event":"WAITING","time":"2021-11-23T02:47:00+00:00","description":null,"username":"API: ","ip":"120.136.2.157"},{"event":"VALIDATED","time":"2021-11-23T02:47:00+00:00","description":null,"username":null,"ip":""},{"event":"PROCESSED_SUCCESSFUL","time":"2021-11-23T02:48:00+00:00","description":null,"username":null,"ip":"120.136.2.157"}]}'
  end

  def stub_comms(gateway = @gateway, method_to_stub = :ssl_request, &action)
    super
  end

  def stub_response(response)
    @gateway
      .expects(:ssl_request)
      .times(2)
      .returns(successful_login_response, response)
  end
end
