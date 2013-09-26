# encoding: utf-8

require 'test_helper'

class NetaxeptTest < Test::Unit::TestCase
  def setup
    @gateway = NetaxeptGateway.new(
                 :login => 'login',
                 :password => 'password'
               )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1'
    }
  end

  def test_successful_purchase
    s = sequence("request")
    @gateway.expects(:ssl_get).returns(successful_purchase_response[0]).in_sequence(s)
    @gateway.expects(:ssl_get).returns(successful_purchase_response[1]).in_sequence(s)
    @gateway.expects(:ssl_get).returns(successful_purchase_response[2]).in_sequence(s)
    @gateway.expects(:ssl_get).returns(successful_purchase_response[3]).in_sequence(s)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '24ec55519f34457ea42f4c5251d7ec45', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    s = sequence("request")
    @gateway.expects(:ssl_get).returns(successful_purchase_response[0]).in_sequence(s)
    @gateway.expects(:ssl_get).returns(successful_purchase_response[1]).in_sequence(s)
    @gateway.expects(:ssl_get).returns(failed_purchase_response).in_sequence(s)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response

    assert_equal '24ec55519f34457ea42f4c5251d7ec45', response.authorization
    assert response.test?
  end

  def test_requires_order_id
    assert_raise(ArgumentError) do
      response = @gateway.purchase(@amount, @credit_card, {})
    end
  end

  def test_handles_currency_with_money
    s = sequence("request")
    @gateway.expects(:ssl_get).with(regexp_matches(/currencyCode=USD/)).returns(successful_purchase_response[0]).in_sequence(s)
    @gateway.expects(:ssl_get).returns(successful_purchase_response[1]).in_sequence(s)
    @gateway.expects(:ssl_get).returns(successful_purchase_response[2]).in_sequence(s)
    @gateway.expects(:ssl_get).returns(successful_purchase_response[3]).in_sequence(s)

    assert_success @gateway.purchase(100, @credit_card, @options.merge(:currency => 'USD'))
  end

  def test_handles_currency_with_option
    s = sequence("request")
    @gateway.expects(:ssl_get).with(regexp_matches(/currencyCode=USD/)).returns(successful_purchase_response[0]).in_sequence(s)
    @gateway.expects(:ssl_get).returns(successful_purchase_response[1]).in_sequence(s)
    @gateway.expects(:ssl_get).returns(successful_purchase_response[2]).in_sequence(s)
    @gateway.expects(:ssl_get).returns(successful_purchase_response[3]).in_sequence(s)

    assert_success @gateway.purchase(@amount, @credit_card, @options.merge(:currency => 'USD'))
  end

  def test_handles_setup_transaction_error
    @gateway.expects(:ssl_get).returns(error_purchase_response[0])
    @gateway.expects(:ssl_get).never

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_handles_query_error
    s = sequence("request")
    @gateway.expects(:ssl_get).returns(successful_purchase_response[0]).in_sequence(s)
    @gateway.expects(:ssl_get).returns(successful_purchase_response[1]).in_sequence(s)
    @gateway.expects(:ssl_get).returns(error_purchase_response[2]).in_sequence(s)

    assert response = @gateway.purchase(@amount, credit_card(''), @options)
    assert_failure response
    assert_equal 'Unable to find transaction', response.message
  end

  def test_url_escape_password
    @gateway = NetaxeptGateway.new(:login => 'login', :password => '1a=W+Yr2')

    s = sequence("request")
    @gateway.expects(:ssl_get).with(regexp_matches(/token=1a%3DW%2BYr2/)).returns(successful_purchase_response[0]).in_sequence(s)
    @gateway.expects(:ssl_get).returns(successful_purchase_response[1]).in_sequence(s)
    @gateway.expects(:ssl_get).returns(successful_purchase_response[2]).in_sequence(s)
    @gateway.expects(:ssl_get).returns(successful_purchase_response[3]).in_sequence(s)

    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_using_credit_card_transaction_service_type
    s = sequence("request")
    @gateway.expects(:ssl_get).with(regexp_matches(/serviceType=M/)).returns(successful_purchase_response[0]).in_sequence(s)
    @gateway.expects(:ssl_get).returns(successful_purchase_response[1]).in_sequence(s)
    @gateway.expects(:ssl_get).returns(successful_purchase_response[2]).in_sequence(s)
    @gateway.expects(:ssl_get).returns(successful_purchase_response[3]).in_sequence(s)

    @gateway.purchase(@amount, @credit_card, @options)
  end

  private

  # Place raw successful response from gateway here
  def successful_purchase_response
    [
      %(<?xml version="1.0" encoding="utf-8"?>
        <RegisterResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <TransactionId>005c6f8316284b4690d1ef759e41d86c</TransactionId>
        </RegisterResponse>),
      %(<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

        <html xmlns="http://www.w3.org/1999/xhtml">

            <head><title>
          NETS Netaxept
        </title><link href="StyleSheet.css" rel="stylesheet" type="text/css" /><link rel="SHORTCUT ICON" href="Images/favicon.ico" />
                <script src="scripts/jquery-1.4.2.min.js" type="text/javascript"></script>
                <script type="text/javascript">

                    $(document).ready(function () {

                        $("#okButton").click(function () {
                            $("#toolbarButtons").hide();
                            $("#progressImage").show();
                        });

                        $("#cancelButton").click(function () {
                            $("#toolbarButtons").hide();
                            $("#progressImage").show();
                        });

                        $("#cardNo").keypress(function (e) {
                            if (e.which == 0 || e.which == 8 || e.which == 13)
                                return true;
                            else if (e.which < 48 || e.which > 57)
                                return false;
                        });

                        $("#securityCode").keypress(function (e) {
                            if (e.which == 0 || e.which == 8 || e.which == 13)
                                return true;
                            else if (e.which < 48 || e.which > 57)
                                return false;
                        });

                        $("a[id$='issuerLink']").each(function () {
                            $(this).click(function () {
                                $(this).siblings(":radio").attr("checked", "checked");
                            });
                        });

                        $('form').submit(function () {
                            $('input[type=submit]').click(function (event) {
                                event.preventDefault();
                            });
                        });

                    });

                </script>

                <style type="text/css">a { color: black; } td.lineTop { border-top: solid 1px black; } div.lineBottom { border-bottom: solid 1px black; }</style></head>

            <body id="body" style="">
                <form name="form1" method="post" action="default.aspx?merchantId=10000243&amp;transactionId=92291dcc29b345b291bc42e0fbcf6ebf&amp;pan=4925000000000004&amp;expiryDate=0914&amp;securityCode=123" id="form1">
        <input type="hidden" name="__VIEWSTATE" id="__VIEWSTATE" value="/wEPDwULLTE3NzA5Njk1NjYPFgIeDWVwYXlTZXNzaW9uSWQFIDUwOTIyNjg3NmRiNzRjYmU4MmE4NDAzODYwMDNlYTZlFgICAw8WAh4Fc3R5bGVlFgICAQ9kFgICAQ9kFgICAw8WAh8BBSVib3JkZXI6c29saWQgMnB4ICM3ZjdiN2I7Y29sb3I6YmxhY2s7FgICAw9kFgwCAQ9kFhRmDw8WAh4HVmlzaWJsZWhkZAICD2QWBAIBDw8WAh4EVGV4dAULQnJ1a2Vyc3RlZDpkZAIDDw8WAh8DBSNBbnNhdHQgU2hvcCA2LCBCQlMgbmV0dGVybWluYWwgdGVzdGRkAgQPFgIfAmhkAgYPZBYEZg9kFgICAQ8PFgIfAwUHQmVsw7hwOmRkAgEPZBYCAgEPDxYCHwMFDWtyIDEsMDAgKE5PSylkZAIIDxYCHwJoFgJmD2QWAgIBDw8WAh8DBQZHZWJ5cjpkZAIKDxYCHwJoFgJmD2QWAgIBDw8WAh8DBRBNVkEgKGlua2x1ZGVydCk6ZGQCDA8WAh8CaBYCZg9kFgICAQ8PFgIfAwUOVG90YWx0IGJlbMO4cDpkZAIOD2QWBAIBDw8WAh8DBQxPcmRyZW51bW1lcjpkZAIDDw8WAh8DBSBlMDY3ZjFlNmMzNDA4MmQ4YjQ0YjJjMGU1ZjE0MmIyMGRkAhAPFgIfAmgWAgIDDw8WAh8DZWRkAhIPFgIfAmgWBAIBDw8WAh8DBQxCZXNrcml2ZWxzZTpkZAIDDw8WAh8DBQEgZGQCAw9kFgJmDw9kFgIfAQUTbWFyZ2luLWJvdHRvbToxMHB4OxYIAgEPZBYCAgEPDxYCHwNlZGQCAw9kFgICAQ8PFgIfA2VkZAIFD2QWAgIBDw8WAh8DZWRkAgcPDxYCHwJnZBYCAgEPDxYCHwMFHlRyYW5zYWtzam9uZW4gZXIgZ2plbm5vbWbDuHJ0LmRkAgUPFgIfAmgWAgIBDw8WAh8DBSRWZWxnIGJldGFsaW5nc23DpXRlIG9nIHRyeWtrICdOZXN0ZSdkZAIHDxYCHwJoZAIJDxYCHwJoZAILDxYCHwJoFggCAQ8PFgQfAwUJPCBUaWxiYWtlHwJoZGQCAg8PFgIfAwUGQXZicnl0ZGQCAw8PFgIfAwUHTmVzdGUgPmRkAgQPDxYCHwJoZGRkaw2vvpPOLgxeS7xU9Bepos56lZSH3vYn0dn2T/6XeyA=" />


                    <div id="bbsHostedContent">




                        <div id="content" class="content" style="border:solid 2px #7f7b7b;color:black;">

                            <img id="topImage" src="Images/TopLedge.png" border="0" />

                            <div id="contentPadding" class="contentPadding">





        <div id="merchantInformation_merchantRow" style="word-break: break-all;">
            <span id="merchantInformation_merchantLabel"><b>Brukersted:</b></span>&nbsp;<span id="merchantInformation_merchantName">Ansatt Shop 6, BBS netterminal test</span>
        </div>

        <table style="margin-top: 10px;" cellpadding="0" cellspacing="0">

            <tr id="merchantInformation_amountRow">
          <td style="padding-right: 5px">
                    <span id="merchantInformation_amountLabel"><b>BelÃ¸p:</b></span>
                </td>
          <td>
                    <span id="merchantInformation_amount">kr 1,00 (NOK)</span>
                </td>
        </tr>




        </table>

        <div id="merchantInformation_orderNumberDiv" style="margin-top: 10px; word-break: break-all;">
            <span id="merchantInformation_orderNumberLabel"><b>Ordrenummer:</b></span>&nbsp;<span id="merchantInformation_orderNumber">e067f1e6c34082d8b44b2c0e5f142b20</span>
        </div>





        <div class="lineBottom" style="margin-bottom: 10px; padding-bottom: 10px;"></div>
                                <div id="status_margins" style="margin-bottom:10px;">








            <div id="status_okPanel" class="okPanel">

                <span id="status_okText">Transaksjonen er gjennomfÃ¸rt.</span>

          </div>


        </div>







                            </div>
                        </div>



                    </div>



                </form>
            </body>

        </html>),
      %(<?xml version="1.0" encoding="utf-8"?>
        <PaymentInfo xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <MerchantId>10000243</MerchantId>
          <TransactionId>24ec55519f34457ea42f4c5251d7ec45</TransactionId>
          <QueryFinished>2013-04-04T23:53:01.763769+02:00</QueryFinished>
          <OrderInformation>
            <Amount>100</Amount>
            <Currency>NOK</Currency>
            <OrderNumber>62bbafc2d04534b2002227a6fb94191d</OrderNumber>
            <OrderDescription> </OrderDescription>
            <Fee>0</Fee>
            <Total>100</Total>
            <Timestamp>2013-04-04T23:52:57.853</Timestamp>
          </OrderInformation>
          <Summary>
            <AmountCaptured>0</AmountCaptured>
            <AmountCredited>0</AmountCredited>
            <Annulled>false</Annulled>
            <Annuled>false</Annuled>
            <Authorized>true</Authorized>
            <AuthorizationId>025205</AuthorizationId>
          </Summary>
          <TerminalInformation>
            <CustomerEntered>2013-04-04T23:52:59.443</CustomerEntered>
            <Browser>Unknown-Ruby</Browser>
          </TerminalInformation>
          <CustomerInformation>
            <Email />
            <IP>96.10.242.104</IP>
            <PhoneNumber />
            <CustomerNumber />
            <FirstName />
            <LastName />
            <Address1 />
            <Address2 />
            <Postcode />
            <Town />
            <Country />
            <SocialSecurityNumber />
            <CompanyName />
            <CompanyRegistrationNumber />
          </CustomerInformation>
          <CardInformation>
            <Issuer>Visa</Issuer>
            <IssuerCountry>NO</IssuerCountry>
            <MaskedPAN>492500******0004</MaskedPAN>
            <PaymentMethod>Visa</PaymentMethod>
            <ExpiryDate>1409</ExpiryDate>
          </CardInformation>
          <AuthenticationInformation />
          <History>
            <TransactionLogLine>
              <DateTime>2013-04-04T23:52:57.853</DateTime>
              <Description />
              <Operation>Register</Operation>
              <TransactionReconRef />
            </TransactionLogLine>
            <TransactionLogLine>
              <DateTime>2013-04-04T23:53:00.547</DateTime>
              <Description>192.168.138.12: Auto AUTH</Description>
              <Operation>Auth</Operation>
              <BatchNumber />
              <TransactionReconRef>250</TransactionReconRef>
            </TransactionLogLine>
          </History>
          <ErrorLog />
          <AvtaleGiroInformation />
          <SecurityInformation>
            <CustomerIPCountry>US</CustomerIPCountry>
            <IPCountryMatchesIssuingCountry>false</IPCountryMatchesIssuingCountry>
          </SecurityInformation>
        </PaymentInfo>),
      %(<?xml version="1.0" encoding="utf-8"?>
        <ProcessResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <Operation>CAPTURE</Operation>
          <ResponseCode>OK</ResponseCode>
          <TransactionId>24ec55519f34457ea42f4c5251d7ec45</TransactionId>
          <ExecutionTime>2013-04-04T23:53:02.9893032+02:00</ExecutionTime>
          <MerchantId>10000243</MerchantId>
          <BatchNumber>250</BatchNumber>
        </ProcessResponse>),
    ]
  end

  def error_purchase_response
    [
      %(<Exception xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <Error xsi:type="GenericError">
            <Message>Unable to translate supermerchant to submerchant, please check currency code and merchant ID</Message>
          </Error>
        </Exception>),
      nil,
      %(<Exception xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <Error xsi:type="QueryException">
            <Message>Unable to find transaction</Message>
          </Error>
        </Exception>),
    ]
  end

  def failed_purchase_response
    %(<PaymentInfo xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <MerchantId>10000243</MerchantId>
        <TransactionId>24ec55519f34457ea42f4c5251d7ec45</TransactionId>
        <QueryFinished>2013-04-04T23:56:54.3582371+02:00</QueryFinished>
        <OrderInformation>
          <Amount>100</Amount>
          <Currency>NOK</Currency>
          <OrderNumber>950daad6f6b2a2c6687e8854a234983e</OrderNumber>
          <OrderDescription> </OrderDescription>
          <Fee>0</Fee>
          <Total>100</Total>
          <Timestamp>2013-04-04T23:56:51.533</Timestamp>
        </OrderInformation>
        <Summary>
          <AmountCaptured>0</AmountCaptured>
          <AmountCredited>0</AmountCredited>
          <Annulled>false</Annulled>
          <Annuled>false</Annuled>
          <Authorized>false</Authorized>
        </Summary>
        <TerminalInformation>
          <CustomerEntered>2013-04-04T23:56:52.500</CustomerEntered>
          <Browser>Unknown-Ruby</Browser>
        </TerminalInformation>
        <CustomerInformation>
          <Email />
          <IP>96.10.242.104</IP>
          <PhoneNumber />
          <CustomerNumber />
          <FirstName />
          <LastName />
          <Address1 />
          <Address2 />
          <Postcode />
          <Town />
          <Country />
          <SocialSecurityNumber />
          <CompanyName />
          <CompanyRegistrationNumber />
        </CustomerInformation>
        <CardInformation>
          <Issuer>Visa</Issuer>
          <IssuerCountry>NO</IssuerCountry>
          <MaskedPAN>492500******0087</MaskedPAN>
          <PaymentMethod>Visa</PaymentMethod>
          <ExpiryDate>1409</ExpiryDate>
        </CardInformation>
        <AuthenticationInformation />
        <History>
          <TransactionLogLine>
            <DateTime>2013-04-04T23:56:51.533</DateTime>
            <Description />
            <Operation>Register</Operation>
            <TransactionReconRef />
          </TransactionLogLine>
        </History>
        <ErrorLog>
          <PaymentError>
            <DateTime>2013-04-04T23:56:53.47</DateTime>
            <Operation>Auth</Operation>
            <ResponseCode>99</ResponseCode>
            <ResponseSource>Netaxept</ResponseSource>
            <ResponseText>Auth Reg Comp Failure (4925000000000087)</ResponseText>
          </PaymentError>
        </ErrorLog>
        <AvtaleGiroInformation />
        <Error>
          <DateTime>2013-04-04T23:56:53.47</DateTime>
          <Operation>Auth</Operation>
          <ResponseCode>99</ResponseCode>
          <ResponseSource>Netaxept</ResponseSource>
          <ResponseText>Auth Reg Comp Failure (4925000000000087)</ResponseText>
        </Error>
        <SecurityInformation>
          <CustomerIPCountry>US</CustomerIPCountry>
          <IPCountryMatchesIssuingCountry>false</IPCountryMatchesIssuingCountry>
        </SecurityInformation>
      </PaymentInfo>)
  end
end
