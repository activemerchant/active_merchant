require 'test_helper'

class PaywayTest < Test::Unit::TestCase

  def setup
    @gateway = PaywayGateway.new(
      :username => '12341234',
      :password => 'abcdabcd',
      :pem      => certificate
    )

    @amount = 1000

    @credit_card = ActiveMerchant::Billing::CreditCard.new(
      :number             => 4564710000000004,
      :month              => 2,
      :year               => 2019,
      :first_name         => 'Bob',
      :last_name          => 'Smith',
      :verification_value => '847',
      :brand              => 'visa'
    )

    @options = {
      :order_id => 'abc'
    }
  end

  def test_successful_purchase_visa
    @gateway.stubs(:ssl_post).returns(successful_response_visa)

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_instance_of Response, response
    assert_success response

    assert_match '0', response.params['summary_code']
    assert_match '08', response.params['response_code']
    assert_match 'VISA', response.params['card_scheme_name']
  end

  def test_succesful_purchase_visa_from_register_user
    @gateway.stubs(:ssl_post).returns(successful_response_visa)

    response = @gateway.purchase(@amount, 123456789, @options)

    assert_instance_of Response, response
    assert_success response

    assert_match '0', response.params['summary_code']
    assert_match '08', response.params['response_code']
    assert_match 'VISA', response.params['card_scheme_name']

  end

  def test_successful_purchase_master_card
    @gateway.stubs(:ssl_post).returns(successful_response_master_card)

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_instance_of Response, response
    assert_success response

    assert_match '0', response.params['summary_code']
    assert_match '08', response.params['response_code']
    assert_match 'MASTERCARD', response.params['card_scheme_name']
  end

  def test_successful_authorize_visa
    @gateway.stubs(:ssl_post).returns(successful_response_visa)

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_instance_of Response, response
    assert_success response

    assert_match '0', response.params['summary_code']
    assert_match '08', response.params['response_code']
    assert_match 'VISA', response.params['card_scheme_name']
  end

  def test_successful_authorize_master_card
    @gateway.stubs(:ssl_post).returns(successful_response_master_card)

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_instance_of Response, response
    assert_success response

    assert_match '0', response.params['summary_code']
    assert_match '08', response.params['response_code']
    assert_match 'MASTERCARD', response.params['card_scheme_name']
  end

  def test_successful_capture_visa
    @gateway.stubs(:ssl_post).returns(successful_response_visa)

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_instance_of Response, response
    assert_success response

    assert_match '0', response.params['summary_code']
    assert_match '08', response.params['response_code']
    assert_match 'VISA', response.params['card_scheme_name']
  end

  def test_successful_capture_master_card
    @gateway.stubs(:ssl_post).returns(successful_response_master_card)

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_instance_of Response, response
    assert_success response

    assert_match '0', response.params['summary_code']
    assert_match '08', response.params['response_code']
    assert_match 'MASTERCARD', response.params['card_scheme_name']
  end

  def test_successful_credit_visa
    @gateway.stubs(:ssl_post).returns(successful_response_visa)

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_instance_of Response, response
    assert_success response

    assert_match '0', response.params['summary_code']
    assert_match '08', response.params['response_code']
    assert_match 'VISA', response.params['card_scheme_name']
  end

  def test_successful_credit_master_card
    @gateway.stubs(:ssl_post).returns(successful_response_master_card)

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_instance_of Response, response
    assert_success response

    assert_match '0', response.params['summary_code']
    assert_match '08', response.params['response_code']
    assert_match 'MASTERCARD', response.params['card_scheme_name']
  end

  def test_purchase_with_invalid_credit_card
    @gateway.stubs(:ssl_post).returns(purchase_with_invalid_credit_card_response)

    credit_card.number = 4444333322221111

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_instance_of Response, response
    assert_failure response

    assert_match '1', response.params['summary_code']
    assert_match '14', response.params['response_code']
  end

  def test_purchase_with_expired_credit_card
    @gateway.stubs(:ssl_post).returns(purchase_with_expired_credit_card_response)

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_instance_of Response, response
    assert_failure response

    assert_match '1', response.params['summary_code']
    assert_match '54', response.params['response_code']
  end

  def test_purchase_with_invalid_month
    @gateway.stubs(:ssl_post).returns(purchase_with_invalid_month_response)
    @credit_card.month = 13

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_instance_of Response, response
    assert_failure response

    assert_match '3', response.params['summary_code']
    assert_match 'QA', response.params['response_code']
  end

  def test_bad_login
    @gateway.stubs(:ssl_post).returns(bad_login_response)

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_instance_of Response, response
    assert_failure response

    assert_match '3', response.params['summary_code']
    assert_match 'QH', response.params['response_code']
  end

  def test_bad_merchant
    @gateway.stubs(:ssl_post).returns(bad_merchant_response)

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_instance_of Response, response
    assert_failure response

    assert_match '3', response.params['summary_code']
    assert_match 'QK', response.params['response_code']
  end

  def test_store
    @gateway.stubs(:ssl_post).returns(successful_response_store)

    response = @gateway.store(@credit_card, :billing_id => 84517)

    assert_instance_of Response, response
    assert_success response

    assert_match '00', response.params['response_code']
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  private

    def successful_response_store
      "response.responseCode=00"
    end

    def successful_response_visa
      "response.summaryCode=0&response.responseCode=08&response.cardSchemeName=VISA"
    end

    def successful_response_master_card
      "response.summaryCode=0&response.responseCode=08&response.cardSchemeName=MASTERCARD"
    end

    def purchase_with_invalid_credit_card_response
      "response.summaryCode=1&response.responseCode=14"
    end

    def purchase_with_expired_credit_card_response
      "response.summaryCode=1&response.responseCode=54"
    end

    def purchase_with_invalid_month_response
      "response.summaryCode=3&response.responseCode=QA"
    end

    def bad_login_response
      "response.summaryCode=3&response.responseCode=QH"
    end

    def bad_merchant_response
      "response.summaryCode=3&response.responseCode=QK"
    end

    def certificate
      '------BEGIN CERTIFICATE-----
 -MIIDeDCCAmCgAwIBAgIBATANBgkqhkiG9w0BAQUFADBBMRMwEQYDVQQDDApjb2R5
 -ZmF1c2VyMRUwEwYKCZImiZPyLGQBGRYFZ21haWwxEzARBgoJkiaJk/IsZAEZFgNj
 -b20wHhcNMTMxMTEzMTk1NjE2WhcNMTQxMTEzMTk1NjE2WjBBMRMwEQYDVQQDDApj
 -b2R5ZmF1c2VyMRUwEwYKCZImiZPyLGQBGRYFZ21haWwxEzARBgoJkiaJk/IsZAEZ
 -FgNjb20wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC6T4Iqt5iWvAlU
 -iXI6L8UO0URQhIC65X/gJ9hL/x4lwSl/ckVm/R/bPrJGmifT+YooFv824N3y/TIX
 -25o/lZtRj1TUZJK4OCb0aVzosQVxBHSe6rLmxO8cItNTMOM9wn3thaITFrTa1DOQ
 -O3wqEjvW2L6VMozVfK1MfjL9IGgy0rCnl+2g4Gh4jDDpkLfnMG5CWI6cTCf3C1ye
 -ytOpWgi0XpOEy8nQWcFmt/KCQ/kFfzBo4QxqJi54b80842EyvzWT9OB7Oew/CXZG
 -F2yIHtiYxonz6N09vvSzq4CvEuisoUFLKZnktndxMEBKwJU3XeSHAbuS7ix40OKO
 -WKuI54fHAgMBAAGjezB5MAkGA1UdEwQCMAAwCwYDVR0PBAQDAgSwMB0GA1UdDgQW
 -BBR9QQpefI3oDCAxiqJW/3Gg6jI6qjAfBgNVHREEGDAWgRRjb2R5ZmF1c2VyQGdt
 -YWlsLmNvbTAfBgNVHRIEGDAWgRRjb2R5ZmF1c2VyQGdtYWlsLmNvbTANBgkqhkiG
 -9w0BAQUFAAOCAQEAYJgMj+RlvKSOcks29P76WE+Lexvq3eZBDxxgFHatACdq5Fis
 -MUEGiiHeLkR1KRTkvkXCos6CtZVUBVUsftueHmKA7adO2yhrjv4YhPTb/WZxWmQC
 -L59lMhnp9UcFJ0H7TkAiU1TvvXewdQPseX8Ayl0zRwD70RfhGh0LfFsKN0JGR4ZS
 -yZvtu7hS26h9KwIyo5N3nw7cKSLzT7KsV+s1C+rTjVCb3/JJA9yOe/SCj/Xyc+JW
 -ZJB9YPQZG+vWBdDSca3sUMtvFxpLUFwdKF5APSPOVnhbFJ3vSXY1ulP/R6XW9vnw
 -6kkQi2fHhU20ugMzp881Eixr+TjC0RvUerLG7g==
 ------END CERTIFICATE-----'
    end

    def transcript
      %(
opening connection to ccapi.client.qvalent.com:443...
opened
starting SSL for ccapi.client.qvalent.com:443...
SSL established
<- "POST /payway/ccapi HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: ccapi.client.qvalent.com\r\nContent-Length: 300\r\n\r\n"
<- "card.cardHolderName=Longbob+Longsen&card.PAN=4564710000000004&card.CVN=847&card.expiryYear=19&card.expiryMonth=02&order.ECI=SSL&order.amount=1100&card.currency=AUD&customer.orderNumber=eb3028119b1b5e9ced54&customer.username=foo&customer.password=bar&customer.merchant=TEST&order.type=capture"
-> "HTTP/1.1 200 OK\r\n"
-> "X-Server-Shutdown: false\r\n"
-> "Content-Type: text/plain;charset=ISO-8859-1\r\n"
-> "Content-Length: 278\r\n"
-> "Date: Sun, 22 Jan 2017 22:04:48 GMT\r\n"
-> "Connection: close\r\n"
-> "Set-Cookie: TS019af3e9=016fc1dd2354ed655d391e1f1a0ab78b43858a2e03c14636ed86388c87c993d65730349f0a; Path=/; Secure; HTTPOnly\r\n"
-> "\r\n"
reading 278 bytes...
-> "response.summaryCode=0&response.responseCode=08&response.text=Honour with identification&response.receiptNo=967370806&response.settlementDate=20170123&response.transactionDate=23-JAN-2017 09:04:47&response.cardSchemeName=VISA&response.creditGroup=VI/BC/MC&response.cvnResponse=M"
read 278 bytes
Conn close
      )
    end

    def scrubbed_transcript
      %(
opening connection to ccapi.client.qvalent.com:443...
opened
starting SSL for ccapi.client.qvalent.com:443...
SSL established
<- "POST /payway/ccapi HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: ccapi.client.qvalent.com\r\nContent-Length: 300\r\n\r\n"
<- "card.cardHolderName=Longbob+Longsen&card.PAN=[FILTERED]&card.CVN=[FILTERED]&card.expiryYear=19&card.expiryMonth=02&order.ECI=SSL&order.amount=1100&card.currency=AUD&customer.orderNumber=eb3028119b1b5e9ced54&customer.username=foo&customer.password=[FILTERED]&customer.merchant=TEST&order.type=capture"
-> "HTTP/1.1 200 OK\r\n"
-> "X-Server-Shutdown: false\r\n"
-> "Content-Type: text/plain;charset=ISO-8859-1\r\n"
-> "Content-Length: 278\r\n"
-> "Date: Sun, 22 Jan 2017 22:04:48 GMT\r\n"
-> "Connection: close\r\n"
-> "Set-Cookie: TS019af3e9=016fc1dd2354ed655d391e1f1a0ab78b43858a2e03c14636ed86388c87c993d65730349f0a; Path=/; Secure; HTTPOnly\r\n"
-> "\r\n"
reading 278 bytes...
-> "response.summaryCode=0&response.responseCode=08&response.text=Honour with identification&response.receiptNo=967370806&response.settlementDate=20170123&response.transactionDate=23-JAN-2017 09:04:47&response.cardSchemeName=VISA&response.creditGroup=VI/BC/MC&response.cvnResponse=M"
read 278 bytes
Conn close
      )
    end
end
