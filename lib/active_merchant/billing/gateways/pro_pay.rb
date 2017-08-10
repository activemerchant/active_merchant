require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class ProPayGateway < Gateway
      self.test_url = 'https://xmltest.propay.com/API/PropayAPI.aspx'
      self.live_url = 'https://epay.propay.com/api/propayapi.aspx'

      self.supported_countries = ['US', 'CA']
      self.default_currency = 'USD'
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'https://www.propay.com/'
      self.display_name = 'ProPay'

      STATUS_RESPONSE_CODES = {
        "00" => "Success",
        "20" => "Invalid username",
        "21" => "Invalid transType",
        "22" => "Invalid Currency Code",
        "23" => "Invalid accountType",
        "24" => "Invalid sourceEmail",
        "25" => "Invalid firstName",
        "26" => "Invalid mInitial",
        "27" => "Invalid lastName",
        "28" => "Invalid billAddr",
        "29" => "Invalid aptNum",
        "30" => "Invalid city",
        "31" => "Invalid state",
        "32" => "Invalid billZip",
        "33" => "Invalid mailAddr",
        "34" => "Invalid mailApt",
        "35" => "Invalid mailCity",
        "36" => "Invalid mailState",
        "37" => "Invalid mailZip",
        "38" => "Invalid dayPhone",
        "39" => "Invalid evenPhone",
        "40" => "Invalid ssn",
        "41" => "Invalid dob",
        "42" => "Invalid recEmail",
        "43" => "Invalid knownAccount",
        "44" => "Invalid amount",
        "45" => "Invalid invNum",
        "46" => "Invalid rtNum",
        "47" => "Invalid accntNum",
        "48" => "Invalid ccNum",
        "49" => "Invalid expDate",
        "50" => "Invalid cvv2",
        "51" => "Invalid transNum and/or Unable to act perform actions on transNum due to funding",
        "52" => "Invalid splitNum",
        "53" => "A ProPay account with this email address already exists AND/OR User has no account number",
        "54" => "A ProPay account with this social security number already exists",
        "55" => "The email address provided does not correspond to a ProPay account.",
        "56" => "Recipient’s email address shouldn’t have a ProPay account and does",
        "57" => "Cannot settle transaction because it already expired",
        "58" => "Credit card declined",
        "59" => "Invalid Credential or IP address not allowed",
        "60" => "Credit card authorization timed out; retry at a later time",
        "61" => "Amount exceeds single transaction limit",
        "62" => "Amount exceeds monthly volume limit",
        "63" => "Insufficient funds in account",
        "64" => "Over credit card use limit",
        "65" => "Miscellaneous error",
        "66" => "Denied a ProPay account",
        "67" => "Unauthorized service requested",
        "68" => "Account not affiliated",
        "69" => "Duplicate invoice number (The same card was charged for the same amount with the same invoice number (including blank invoices) in a 1 minute period. Details about the original transaction are included whenever a 69 response is returned. These details include a repeat of the auth code, the original AVS response, and the original CVV response.)",
        "70" => "Duplicate external ID",
        "71" => "Account previously set up, but problem affiliating it with partner",
        "72" => "The ProPay Account has already been upgraded to a Premium Account",
        "73" => "Invalid Destination Account",
        "74" => "Account or Trans Error",
        "75" => "Money already pulled",
        "76" => "Not Premium (used only for push/pull transactions)",
        "77" => "Empty results",
        "78" => "Invalid Authentication",
        "79" => "Generic account status error",
        "80" => "Invalid Password",
        "81" => "Account Expired",
        "82" => "InvalidUserID",
        "83" => "BatchTransCountError",
        "84" => "InvalidBeginDate",
        "85" => "InvalidEndDate",
        "86" => "InvalidExternalID",
        "87" => "DuplicateUserID",
        "88" => "Invalid track 1",
        "89" => "Invalid track 2",
        "90" => "Transaction already refunded",
        "91" => "Duplicate Batch ID"
      }

      TRANSACTION_RESPONSE_CODES = {
        "00" => "Success",
        "1" => "Transaction blocked by issuer",
        "4" => "Pick up card and deny transaction",
        "5" => "Problem with the account",
        "6" => "Customer requested stop to recurring payment",
        "7" => "Customer requested stop to all recurring payments",
        "8" => "Honor with ID only",
        "9" => "Unpaid items on customer account",
        "12" => "Invalid transaction",
        "13" => "Amount Error",
        "14" => "Invalid card number",
        "15" => "No such issuer. Could not route transaction",
        "16" => "Refund error",
        "17" => "Over limit",
        "19" => "Reenter transaction or the merchant account may be boarded incorrectly",
        "25" => "Invalid terminal 41 Lost card",
        "43" => "Stolen card",
        "51" => "Insufficient funds",
        "52" => "No such account",
        "54" => "Expired card",
        "55" => "Incorrect PIN",
        "57" => "Bank does not allow this type of purchase",
        "58" => "Credit card network does not allow this type of purchase for your merchant account.",
        "61" => "Exceeds issuer withdrawal limit",
        "62" => "Issuer does not allow this card to be charged for your business.",
        "63" => "Security Violation",
        "65" => "Activity limit exceeded",
        "75" => "PIN tries exceeded",
        "76" => "Unable to locate account",
        "78" => "Account not recognized",
        "80" => "Invalid Date",
        "82" => "Invalid CVV2",
        "83" => "Cannot verify the PIN",
        "85" => "Service not supported for this card",
        "93" => "Cannot complete transaction. Customer should call 800 number.",
        "95" => "Misc Error Transaction failure",
        "96" => "Issuer system malfunction or timeout.",
        "97" => "Approved for a lesser amount. ProPay will not settle and consider this a decline.",
        "98" => "Failure HV",
        "99" => "Generic decline or unable to parse issuer response code"
      }

      def initialize(options={})
        requires!(options, :cert_str)
        super
      end

      def purchase(money, payment, options={})
        request = build_xml_request do |xml|
          add_invoice(xml, money, options)
          add_payment(xml, payment, options)
          add_address(xml, options)
          add_account(xml, options)
          add_recurring(xml, options)
          xml.transType "04"
        end

        commit(request)
      end

      def authorize(money, payment, options={})
        request = build_xml_request do |xml|
          add_invoice(xml, money, options)
          add_payment(xml, payment, options)
          add_address(xml, options)
          add_account(xml, options)
          add_recurring(xml, options)
          xml.transType "05"
        end

        commit(request)
      end

      def capture(money, authorization, options={})
        request = build_xml_request do |xml|
          add_invoice(xml, money, options)
          add_account(xml, options)
          xml.transNum authorization
          xml.transType "06"
        end

        commit(request)
      end

      def refund(money, authorization, options={})
        request = build_xml_request do |xml|
          add_invoice(xml, money, options)
          add_account(xml, options)
          xml.transNum authorization
          xml.transType "07"
        end

        commit(request)
      end

      def void(authorization, options={})
        refund(nil, authorization, options)
      end

      def credit(money, payment, options={})
        request = build_xml_request do |xml|
          add_invoice(xml, money, options)
          add_payment(xml, payment, options)
          add_account(xml, options)
          xml.transType "35"
        end

        commit(request)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((<certStr>).+(</certStr>)), '\1[FILTERED]\2').
          gsub(%r((<ccNum>).+(</ccNum>)), '\1[FILTERED]\2').
          gsub(%r((<CVV2>).+(</CVV2>)), '\1[FILTERED]\2')
      end

      private

      def add_payment(xml, payment, options)
        xml.ccNum payment.number
        xml.expDate "#{format(payment.month, :two_digits)}#{format(payment.year, :two_digits)}"
        xml.CVV2 payment.verification_value
        xml.cardholderName payment.name
      end

      def add_address(xml, options)
        if address = options[:billing_address] || options[:address]
          xml.addr address[:address1]
          xml.aptNum address[:address2]
          xml.city address[:city]
          xml.state address[:state]
          xml.zip address[:zip]
        end
      end

      def add_account(xml, options)
        xml.accountNum options[:account_num]
      end

      def add_invoice(xml, money, options)
        xml.amount amount(money)
        xml.currencyCode options[:currency] || currency(money)
        xml.invNum options[:order_id] || SecureRandom.hex(25)
      end

      def add_recurring(xml, options)
        xml.recurringPayment options[:recurring_payment]
      end

      def parse(body)
        results  = {}
        xml = Nokogiri::XML(body)
        resp = xml.xpath("//XMLResponse/XMLTrans")
        resp.children.each do |element|
          results[element.name.underscore.downcase.to_sym] = element.text
        end
        results
      end

      def commit(parameters)
        url = (test? ? test_url : live_url)
        response = parse(ssl_post(url, parameters))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response[:avs]),
          cvv_result: CVVResult.new(response[:cvv2_resp]),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        response[:status] == "00"
      end

      def message_from(response)
        return "Success" if success_from(response)
        message = STATUS_RESPONSE_CODES[response[:status]]
        message += " - #{TRANSACTION_RESPONSE_CODES[response[:response_code]]}" if response[:response_code]

        message
      end

      def authorization_from(response)
        response[:trans_num]
      end

      def error_code_from(response)
        unless success_from(response)
          response[:status]
        end
      end

      def build_xml_request
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.XMLRequest do
            xml.certStr @options[:cert_str]
            xml.class_ "partner"
            xml.XMLTrans do
              yield(xml)
            end
          end
        end

        builder.to_xml
      end
    end

    def underscore(camel_cased_word)
      camel_cased_word.to_s.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase
    end
  end
end
