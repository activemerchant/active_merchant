require 'test_helper'

class EzidebitTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = EzidebitGateway.new(digital_key: 'login')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '82a01ca3-0907-4252-a862-6d473259c51c',
      billing_address: address,
      description: 'Store Purchase'
    }

    @store_options = @options.merge(
      first_name: 'Longbob',
      last_name: 'Longsen'
    )
    @recurring_options = @store_options.merge(
      start_date: '2018-01-19',
      scheduler_period_type: 'M',
      day_of_month: 15
    )
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '5372343|6745860', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_store
    response = stub_comms do
      @gateway.store(@credit_card, @options)
    end.respond_with(successful_add_customer_response, successful_add_card_to_customer_response)
    assert_success response
    assert_equal '782943', response.authorization
  end

  def test_successful_recurring
    response = stub_comms do
      @gateway.recurring(@amount, @credit_card, @recurring_options)
    end.respond_with(successful_add_customer_response, successful_add_card_to_customer_response, successful_create_schedule_response)
    assert_success response
    assert_equal '782943', response.authorization
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<-XML
opening connection to api.demo.ezidebit.com.au:443...
opened
starting SSL for api.demo.ezidebit.com.au:443...
SSL established
<- "POST /v3-5/pci HTTP/1.1\r\nContent-Type: text/xml\r\nSoapaction: https://px.ezidebit.com.au/IPCIService/ProcessRealtimeCreditCardPayment\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.demo.ezidebit.com.au\r\nContent-Length: 895\r\n\r\n"
<- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:px=\"https://px.ezidebit.com.au/\">\n  <soapenv:Header/>\n  <soapenv:Body>\n    <px:ProcessRealtimeCreditCardPayment>\n      <px:DigitalKey>52F2BCEE-E582-4396-AF8E-898DDD7C44FE</px:DigitalKey>\n      <px:CreditCardNumber>4987654321098769</px:CreditCardNumber>\n      <px:CreditCardExpiryMonth>05</px:CreditCardExpiryMonth>\n      <px:CreditCardExpiryYear>2021</px:CreditCardExpiryYear>\n      <px:CreditCardCCV>454</px:CreditCardCCV>\n      <px:NameOnCreditCard>Longbob Longsen</px:NameOnCreditCard>\n      <px:PaymentAmountInCents>100</px:PaymentAmountInCents>\n      <px:PaymentReference>203e8a50-b480-4c85-82d6-ecafc1154640</px:PaymentReference>\n      <px:CustomerName>Longsen Longbob</px:CustomerName>\n    </px:ProcessRealtimeCreditCardPayment>\n  </soapenv:Body>\n</soapenv:Envelope>\n"
-> "HTTP/1.1 200 OK\r\n"
-> "Cache-Control: private\r\n"
-> "Content-Type: text/xml; charset=utf-8\r\n"
-> "Server: Microsoft-IIS/10.0\r\n"
-> "X-AspNet-Version: 4.0.30319\r\n"
-> "Content-Length: 609\r\n"
-> "Date: Thu, 11 Jan 2018 22:39:29 GMT\r\n"
-> "Connection: close\r\n"
-> "Set-Cookie: ASP.NET_SessionId=kf51kjsndazux1l0vjlec5jw; path=/; HttpOnly\r\n"
-> "Set-Cookie: LTc5ySHAICXLdsZiATio=!vGIV3zyy8xE33IyFXo69uc0nq5wdI8msxxq3M+4Qc+tzzIFoGnvBdEB+8ngO3zidOQLhfo6mqAhsn4o=; path=/; Httponly; Secure\r\n"
-> "Set-Cookie: f5avrbbbbbbbbbbbbbbbb=AHLDFKMNEKADJKFMEPHKCGFKAGEPDLKDKPICKGLLONEBGKJLDAOLBJLEEPOLJLLDKLIDDJMIFHMGLIPLHBEACAJCFOEPFCLIPADKGOFEMKFCEOAFMNIOGDDLDBGNNBOI; HttpOnly; secure\r\n"
-> "\r\n"
reading 609 bytes...
-> "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\"><s:Body><ProcessRealtimeCreditCardPaymentResponse xmlns=\"https://px.ezidebit.com.au/\"><ProcessRealtimeCreditCardPaymentResult xmlns:i=\"http://www.w3.org/2001/XMLSchema-instance\"><Data><BankReceiptID>5372343</BankReceiptID><ExchangePaymentID>6745860</ExchangePaymentID><PaymentResult>A</PaymentResult><PaymentResultCode>00</PaymentResultCode><PaymentResultText>APPROVED</PaymentResultText></Data><Error>0</Error><ErrorMessage i:nil=\"true\"/></ProcessRealtimeCreditCardPaymentResult></ProcessRealtimeCreditCardPaymentResponse></s:Body></s:Envelope>"
read 609 bytes
Conn close
    XML
  end

  def post_scrubbed
    <<-XML
opening connection to api.demo.ezidebit.com.au:443...
opened
starting SSL for api.demo.ezidebit.com.au:443...
SSL established
<- "POST /v3-5/pci HTTP/1.1\r\nContent-Type: text/xml\r\nSoapaction: https://px.ezidebit.com.au/IPCIService/ProcessRealtimeCreditCardPayment\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.demo.ezidebit.com.au\r\nContent-Length: 895\r\n\r\n"
<- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:px=\"https://px.ezidebit.com.au/\">\n  <soapenv:Header/>\n  <soapenv:Body>\n    <px:ProcessRealtimeCreditCardPayment>\n      <px:DigitalKey>[FILTERED]</px:DigitalKey>\n      <px:CreditCardNumber>[FILTERED]</px:CreditCardNumber>\n      <px:CreditCardExpiryMonth>05</px:CreditCardExpiryMonth>\n      <px:CreditCardExpiryYear>2021</px:CreditCardExpiryYear>\n      <px:CreditCardCCV>[FILTERED]</px:CreditCardCCV>\n      <px:NameOnCreditCard>Longbob Longsen</px:NameOnCreditCard>\n      <px:PaymentAmountInCents>100</px:PaymentAmountInCents>\n      <px:PaymentReference>203e8a50-b480-4c85-82d6-ecafc1154640</px:PaymentReference>\n      <px:CustomerName>Longsen Longbob</px:CustomerName>\n    </px:ProcessRealtimeCreditCardPayment>\n  </soapenv:Body>\n</soapenv:Envelope>\n"
-> "HTTP/1.1 200 OK\r\n"
-> "Cache-Control: private\r\n"
-> "Content-Type: text/xml; charset=utf-8\r\n"
-> "Server: Microsoft-IIS/10.0\r\n"
-> "X-AspNet-Version: 4.0.30319\r\n"
-> "Content-Length: 609\r\n"
-> "Date: Thu, 11 Jan 2018 22:39:29 GMT\r\n"
-> "Connection: close\r\n"
-> "Set-Cookie: ASP.NET_SessionId=kf51kjsndazux1l0vjlec5jw; path=/; HttpOnly\r\n"
-> "Set-Cookie: LTc5ySHAICXLdsZiATio=!vGIV3zyy8xE33IyFXo69uc0nq5wdI8msxxq3M+4Qc+tzzIFoGnvBdEB+8ngO3zidOQLhfo6mqAhsn4o=; path=/; Httponly; Secure\r\n"
-> "Set-Cookie: f5avrbbbbbbbbbbbbbbbb=AHLDFKMNEKADJKFMEPHKCGFKAGEPDLKDKPICKGLLONEBGKJLDAOLBJLEEPOLJLLDKLIDDJMIFHMGLIPLHBEACAJCFOEPFCLIPADKGOFEMKFCEOAFMNIOGDDLDBGNNBOI; HttpOnly; secure\r\n"
-> "\r\n"
reading 609 bytes...
-> "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\"><s:Body><ProcessRealtimeCreditCardPaymentResponse xmlns=\"https://px.ezidebit.com.au/\"><ProcessRealtimeCreditCardPaymentResult xmlns:i=\"http://www.w3.org/2001/XMLSchema-instance\"><Data><BankReceiptID>5372343</BankReceiptID><ExchangePaymentID>6745860</ExchangePaymentID><PaymentResult>A</PaymentResult><PaymentResultCode>00</PaymentResultCode><PaymentResultText>APPROVED</PaymentResultText></Data><Error>0</Error><ErrorMessage i:nil=\"true\"/></ProcessRealtimeCreditCardPaymentResult></ProcessRealtimeCreditCardPaymentResponse></s:Body></s:Envelope>"
read 609 bytes
Conn close
    XML
  end

  def successful_purchase_response
    <<-XML
      <s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\">
        <s:Body>
          <ProcessRealtimeCreditCardPaymentResponse xmlns=\"https://px.ezidebit.com.au/\">
            <ProcessRealtimeCreditCardPaymentResult xmlns:i=\"http://www.w3.org/2001/XMLSchema-instance\">
              <Data>
                <BankReceiptID>5372343</BankReceiptID>
                <ExchangePaymentID>6745860</ExchangePaymentID>
                <PaymentResult>A</PaymentResult>
                <PaymentResultCode>00</PaymentResultCode>
                <PaymentResultText>APPROVED</PaymentResultText>
              </Data>
              <Error>0</Error>
              <ErrorMessage i:nil=\"true\"/>
            </ProcessRealtimeCreditCardPaymentResult>
          </ProcessRealtimeCreditCardPaymentResponse>
        </s:Body>
      </s:Envelope>
    XML
  end

  def failed_purchase_response
    <<-XML
      <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
        <s:Body>
          <ProcessRealtimeCreditCardPaymentResponse xmlns="https://px.ezidebit.com.au/">
            <ProcessRealtimeCreditCardPaymentResult xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
              <Data>
                <BankReceiptID>5372344</BankReceiptID>
                <ExchangePaymentID>6745864</ExchangePaymentID>
                <PaymentResult>F</PaymentResult>
                <PaymentResultCode>05</PaymentResultCode>
                <PaymentResultText>DECLINED</PaymentResultText>
              </Data>
              <Error>0</Error>
              <ErrorMessage>Declined</ErrorMessage>
            </ProcessRealtimeCreditCardPaymentResult>
          </ProcessRealtimeCreditCardPaymentResponse>
        </s:Body>
      </s:Envelope>
    XML
  end

  def successful_add_customer_response
    <<-XML
      <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
        <s:Body>
          <AddCustomerResponse xmlns="https://px.ezidebit.com.au/">
            <AddCustomerResult xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
              <Data xmlns:a="http://schemas.datacontract.org/2004/07/Ezidebit.PaymentExchange.V3_3.DataContracts">
                <a:CustomerRef>782943</a:CustomerRef>
              </Data>
              <Error>0</Error>
              <ErrorMessage i:nil="true"/>
            </AddCustomerResult>
          </AddCustomerResponse>
        </s:Body>
      </s:Envelope>
    XML
  end

  def successful_add_card_to_customer_response
    <<-XML
      <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
        <s:Body xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
          <EditCustomerCreditCardResponse xmlns="https://px.ezidebit.com.au/">
            <EditCustomerCreditCardResult>
              <Error>0</Error>
              <Data>S</Data>
            </EditCustomerCreditCardResult>
          </EditCustomerCreditCardResponse>
        </s:Body>
      </s:Envelope>
    XML
  end

  def successful_create_schedule_response
    <<-XML
      <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
        <s:Body>
          <CreateScheduleResponse xmlns="https://px.ezidebit.com.au/">
            <CreateScheduleResult xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
              <Data>S</Data>
              <Error>0</Error>
              <ErrorMessage i:nil="true"/>
            </CreateScheduleResult>
          </CreateScheduleResponse>
        </s:Body>
      </s:Envelope>
    XML
  end
end
