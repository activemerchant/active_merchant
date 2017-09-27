require "nokogiri"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class TransFirstTransactionExpressGateway < Gateway
      self.display_name = "TransFirst Transaction Express"
      self.homepage_url = "http://transactionexpress.com/"

      self.test_url = "https://ws.cert.transactionexpress.com/portal/merchantframework/MerchantWebServices-v1?wsdl"
      self.live_url = "https://ws.transactionexpress.com/portal/merchantframework/MerchantWebServices-v1?wsdl"

      self.supported_countries = ["US"]
      self.default_currency = "USD"
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club]

      V1_NAMESPACE = "http://postilion/realtime/merchantframework/xsd/v1/"
      SOAPENV_NAMESPACE = "http://schemas.xmlsoap.org/soap/envelope/"
      AUTHORIZATION_FIELD_SEPARATOR = "|"

      APPROVAL_CODES = %w(00 10)

      RESPONSE_MESSAGES = {
        "00" => "Approved",
        "01" => "Refer to card issuer",
        "02" => "Refer to card issuer, special condition",
        "03" => "Invalid merchant",
        "04" => "Pick-up card",
        "05" => "Do not honor",
        "06" => "Error",
        "07" => "Pick-up card, special condition",
        "08" => "Honor with identification",
        "09" => "Request in progress",
        "10" => "Approved, partial authorization",
        "11" => "VIP Approval",
        "12" => "Invalid transaction",
        "13" => "Invalid amount",
        "14" => "Invalid card number",
        "15" => "No such issuer",
        "16" => "Approved, update track 3",
        "17" => "Customer cancellation",
        "18" => "Customer dispute",
        "19" => "Re-enter transaction",
        "20" => "Invalid response",
        "21" => "No action taken",
        "22" => "Suspected malfunction",
        "23" => "Unacceptable transaction fee",
        "24" => "File update not supported",
        "25" => "Unable to locate record",
        "26" => "Duplicate record",
        "27" => "File update field edit error",
        "28" => "File update file locked",
        "29" => "File update failed",
        "30" => "Format error",
        "31" => "Bank not supported",
        "33" => "Expired card, pick-up",
        "34" => "Suspected fraud, pick-up",
        "35" => "Contact acquirer, pick-up",
        "36" => "Restricted card, pick-up",
        "37" => "Call acquirer security, pick-up",
        "38" => "PIN tries exceeded, pick-up",
        "39" => "No credit account",
        "40" => "Function not supported",
        "41" => "Lost card, pick-up",
        "42" => "No universal account",
        "43" => "Stolen card, pick-up",
        "44" => "No investment account",
        "45" => "Account closed",
        "46" => "Identification required",
        "47" => "Identification cross-check required",
        "48" => "No customer record",
        "49" => "Reserved for future Realtime use",
        "50" => "Reserved for future Realtime use",
        "51" => "Not sufficient funds",
        "52" => "No checking account",
        "53" => "No savings account",
        "54" => "Expired card",
        "55" => "Incorrect PIN",
        "56" => "No card record",
        "57" => "Transaction not permitted to cardholder",
        "58" => "Transaction not permitted on terminal",
        "59" => "Suspected fraud",
        "60" => "Contact acquirer",
        "61" => "Exceeds withdrawal limit",
        "62" => "Restricted card",
        "63" => "Security violation",
        "64" => "Original amount incorrect",
        "65" => "Exceeds withdrawal frequency",
        "66" => "Call acquirer security",
        "67" => "Hard capture",
        "68" => "Response received too late",
        "69" => "Advice received too late (the response from a request was received too late )",
        "70" => "Reserved for future use",
        "71" => "Reserved for future Realtime use",
        "72" => "Reserved for future Realtime use",
        "73" => "Reserved for future Realtime use",
        "74" => "Reserved for future Realtime use",
        "75" => "PIN tries exceeded",
        "76" => "Reversal: Unable to locate previous message (no match on Retrieval Reference Number)/ Reserved for future Realtime use",
        "77" => "Previous message located for a repeat or reversal, but repeat or reversal data is inconsistent with original message/ Intervene, bank approval required",
        "78" => "Invalid/non-existent account – Decline (MasterCard specific)/ Intervene, bank approval required for partial amount",
        "79" => "Already reversed (by Switch)/ Reserved for client-specific use (declined)",
        "80" => "No financial Impact (Reserved for declined debit)/ Reserved for client-specific use (declined)",
        "81" => "PIN cryptographic error found by the Visa security module during PIN decryption/ Reserved for client-specific use (declined)",
        "82" => "Incorrect CVV/ Reserved for client-specific use (declined)",
        "83" => "Unable to verify PIN/ Reserved for client-specific use (declined)",
        "84" => "Invalid Authorization Life Cycle – Decline (MasterCard) or Duplicate Transaction Detected (Visa)/ Reserved for client-specific use (declined)",
        "85" => "No reason to decline a request for Account Number Verification or Address Verification/ Reserved for client-specific use (declined)",
        "86" => "Cannot verify PIN/ Reserved for client-specific use (declined)",
        "87" => "Reserved for client-specific use (declined)",
        "88" => "Reserved for client-specific use (declined)",
        "89" => "Reserved for client-specific use (declined)",
        "90" => "Cut-off in progress",
        "91" => "Issuer or switch inoperative",
        "92" => "Routing error",
        "93" => "Violation of law",
        "94" => "Duplicate Transmission (Integrated Debit and MasterCard)",
        "95" => "Reconcile error",
        "96" => "System malfunction",
        "97" => "Reserved for future Realtime use",
        "98" => "Exceeds cash limit",
        "99" => "Reserved for future Realtime use",
        "1106" => "Reserved for future Realtime use",
        "0A" => "Reserved for future Realtime use",
        "A0" => "Reserved for future Realtime use",
        "A1" => "ATC not incremented",
        "A2" => "ATC limit exceeded",
        "A3" => "ATC configuration error",
        "A4" => "CVR check failure",
        "A5" => "CVR configuration error",
        "A6" => "TVR check failure",
        "A7" => "TVR configuration error",
        "A8" => "Reserved for future Realtime use",
        "B1" => "Surcharge amount not permitted on Visa cards or EBT Food Stamps/ Reserved for future Realtime use",
        "B2" => "Surcharge amount not supported by debit network issuer/ Reserved for future Realtime use",
        "C1" => "Unacceptable PIN",
        "C2" => "PIN Change failed",
        "C3" => "PIN Unblock failed",
        "D1" => "MAC Error",
        "E1" => "Prepay error",
        "N1" => "Network Error within the TXP platform",
        "N0" => "Force STIP/ Reserved for client-specific use (declined)",
        "N3" => "Cash service not available/ Reserved for client-specific use (declined)",
        "N4" => "Cash request exceeds Issuer limit/ Reserved for client-specific use (declined)",
        "N5" => "Ineligible for re-submission/ Reserved for client-specific use (declined)",
        "N7" => "Decline for CVV2 failure/ Reserved for client-specific use (declined)",
        "N8" => "Transaction amount exceeds preauthorized approval amount/ Reserved for client-specific use (declined)",
        "P0" => "Approved; PVID code is missing, invalid, or has expired",
        "P1" => "Declined; PVID code is missing, invalid, or has expired/ Reserved for client-specific use (declined)",
        "P2" => "Invalid biller Information/ Reserved for client-specific use (declined)/ Reserved for client-specific use (declined)",
        "R0" => "The transaction was declined or returned, because the cardholder requested that payment of a specific recurring or installment payment transaction be stopped/ Reserved for client-specific use (declined)",
        "R1" => "The transaction was declined or returned, because the cardholder requested that payment of all recurring or installment payment transactions for a specific merchant account be stopped/ Reserved for client-specific use (declined)",
        "Q1" => "Card Authentication failed/ Reserved for client-specific use (declined)",
        "XA" => "Forward to Issuer/ Reserved for client-specific use (declined)",
        "XD" => "Forward to Issuer/ Reserved for client-specific use (declined)",
      }

      EXTENDED_RESPONSE_MESSAGES = {
        "B40K" => "Declined Post – Credit linked to unextracted settle transaction"
      }

      TRANSACTION_CODES = {
        authorize: 0,
        void_authorize: 2,

        purchase: 1,
        capture: 3,
        void_purchase: 6,
        void_capture: 6,

        refund: 4,
        credit: 5,
        void_refund: 13,
        void_credit: 13,

        verify: 9,

        purchase_echeck: 11,
        refund_echeck: 16,
        void_echeck: 16,

        wallet_sale: 14,
      }

      def initialize(options={})
        requires!(options, :gateway_id, :reg_key)
        super
      end

      def purchase(amount, payment_method, options={})
        if credit_card?(payment_method)
          action = :purchase
          request = build_xml_transaction_request do |doc|
            add_credit_card(doc, payment_method)
            add_contact(doc, payment_method.name, options)
            add_amount(doc, amount)
            add_order_number(doc, options)
          end
        elsif echeck?(payment_method)
          action = :purchase_echeck
          request = build_xml_transaction_request do |doc|
            add_echeck(doc, payment_method)
            add_contact(doc, payment_method.name, options)
            add_amount(doc, amount)
            add_order_number(doc, options)
          end
        else
          action = :wallet_sale
          wallet_id = split_authorization(payment_method).last
          request = build_xml_transaction_request do |doc|
            add_amount(doc, amount)
            add_wallet_id(doc, wallet_id)
          end
        end

        commit(action, request)
      end

      def authorize(amount, payment_method, options={})
        if credit_card?(payment_method)
          request = build_xml_transaction_request do |doc|
            add_credit_card(doc, payment_method)
            add_contact(doc, payment_method.name, options)
            add_amount(doc, amount)
          end
        else
          wallet_id = split_authorization(payment_method).last
          request = build_xml_transaction_request do |doc|
            add_amount(doc, amount)
            add_wallet_id(doc, wallet_id)
          end
        end

        commit(:authorize, request)
      end

      def capture(amount, authorization, options={})
        transaction_id = split_authorization(authorization)[1]
        request = build_xml_transaction_request do |doc|
          add_amount(doc, amount)
          add_original_transaction_data(doc, transaction_id)
        end

        commit(:capture, request)
      end

      def void(authorization, options={})
        action, transaction_id = split_authorization(authorization)

        request = build_xml_transaction_request do |doc|
          add_original_transaction_data(doc, transaction_id)
        end

        commit(void_type(action), request)
      end

      def refund(amount, authorization, options={})
        action, transaction_id = split_authorization(authorization)

        request = build_xml_transaction_request do |doc|
          add_amount(doc, amount) unless action == 'purchase_echeck'
          add_original_transaction_data(doc, transaction_id)
        end

        commit(refund_type(action), request)
      end

      def credit(amount, payment_method, options={})
        request = build_xml_transaction_request do |doc|
          add_pan(doc, payment_method)
          add_amount(doc, amount)
        end

        commit(:credit, request)
      end

      def verify(credit_card, options={})
        request = build_xml_transaction_request do |doc|
          add_credit_card(doc, credit_card)
          add_contact(doc, credit_card.name, options)
        end

        commit(:verify, request)
      end

      def store(payment_method, options={})
        store_customer_request = build_xml_payment_storage_request do |doc|
          store_customer_details(doc, payment_method.name, options)
        end

        MultiResponse.run do |r|
          r.process { commit(:store, store_customer_request) }
          return r unless r.success? && r.params["custId"]
          customer_id = r.params["custId"]

          store_payment_method_request = build_xml_payment_storage_request do |doc|
            doc["v1"].cust do
              add_customer_id(doc, customer_id)
              doc["v1"].pmt do
                doc["v1"].type 0 # add
                add_credit_card(doc, payment_method)
              end
            end
          end

          r.process { commit(:store, store_payment_method_request) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((<[^>]+pan>)[^<]+(<))i, '\1[FILTERED]\2').
          gsub(%r((<[^>]+sec>)[^<]+(<))i, '\1[FILTERED]\2').
          gsub(%r((<[^>]+id>)[^<]+(<))i, '\1[FILTERED]\2').
          gsub(%r((<[^>]+regKey>)[^<]+(<))i, '\1[FILTERED]\2')
      end

      private

      CURRENCY_CODES = Hash.new{|h,k| raise ArgumentError.new("Unsupported currency: #{k}")}
      CURRENCY_CODES["USD"] = "840"

      def headers
        {
          "Content-Type" => "text/xml"
        }
      end

      def commit(action, request)
        request = add_transaction_code_to_request(request, action)

        raw_response = begin
          ssl_post(url, request, headers)
        rescue ActiveMerchant::ResponseError => e
          e.response.body
        end

        response = parse(raw_response)

        succeeded = success_from(response)

        Response.new(
          succeeded,
          message_from(succeeded, response),
          response,
          error_code: error_code_from(succeeded, response),
          authorization: authorization_from(action, response),
          avs_result: AVSResult.new(code: response["avsRslt"]),
          cvv_result: CVVResult.new(response["secRslt"]),
          test: test?
        )
      end

      def url
        test? ? test_url : live_url
      end

      def parse(xml)
        response = {}
        doc = Nokogiri::XML(xml).remove_namespaces!

        doc.css("Envelope Body *").each do |node|
          # node.name is more readable, but uniq_name is occasionally necessary
          uniq_name = [node.parent.name, node.name].join('_')
          response[uniq_name] = node.text
          response[node.name] = node.text
        end

        response
      end

      def success_from(response)
        fault = response["Fault"]
        approved_transaction = APPROVAL_CODES.include?(response["rspCode"])
        found_contact = response["FndRecurrProfResponse"]

        return !fault && (approved_transaction || found_contact)
      end

      def error_code_from(succeeded, response)
        return if succeeded
        response["errorCode"] || response["rspCode"]
      end

      def message_from(succeeded, response)
        return "Succeeded" if succeeded

        if response["rspCode"]
          code = response["rspCode"]
          extended_code = response["extRspCode"]

          message = RESPONSE_MESSAGES[code]
          extended = EXTENDED_RESPONSE_MESSAGES[extended_code]
          ach_response = response["achResponse"]

          [message, extended, ach_response].compact.join('. ')
        else
          response["faultstring"]
        end
      end

      def authorization_from(action, response)
        authorization = response["tranNr"] || response["pmtId"]

        # guard so we don't return something like "purchase|"
        return unless authorization

        [action, authorization].join(AUTHORIZATION_FIELD_SEPARATOR)
      end

      # -- helper methods ----------------------------------------------------
      def credit_card?(payment_method)
        payment_method.respond_to?(:verification_value)
      end

      def echeck?(payment_method)
        payment_method.respond_to?(:routing_number)
      end

      def split_authorization(authorization)
        authorization.split(AUTHORIZATION_FIELD_SEPARATOR)
      end

      def void_type(action)
        action == 'purchase_echeck' ? :void_echeck : :"void_#{action}"
      end

      def refund_type(action)
        action == 'purchase_echeck' ? :refund_echeck : :refund
      end

      # -- request methods ---------------------------------------------------
      def build_xml_transaction_request
        build_xml_request("SendTranRequest") do |doc|
          yield doc
        end
      end

      def build_xml_payment_storage_request
        build_xml_request("UpdtRecurrProfRequest") do |doc|
          yield doc
        end
      end

      def build_xml_payment_update_request
        merchant_product_type = 5 # credit card
        build_xml_request("UpdtRecurrProfRequest", merchant_product_type) do |doc|
          yield doc
        end
      end

      def build_xml_payment_search_request
        build_xml_request("FndRecurrProfRequest") do |doc|
          yield doc
        end
      end

      def build_xml_request(wrapper, merchant_product_type=nil)
        Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
          xml["soapenv"].Envelope("xmlns:soapenv" => SOAPENV_NAMESPACE) do
            xml["soapenv"].Body do
              xml["v1"].send(wrapper, "xmlns:v1" => V1_NAMESPACE) do
                add_merchant(xml)
                yield(xml)
              end
            end
          end
        end.doc.root.to_xml
      end

      def add_transaction_code_to_request(request, action)
        # store requests don't get a transaction code
        return request if action == :store

        doc = Nokogiri::XML::Document.parse(request)
        merc_nodeset = doc.xpath('//v1:merc', 'v1' => V1_NAMESPACE)
        merc_nodeset.after "<tranCode>#{TRANSACTION_CODES[action]}</tranCode>"
        doc.root.to_xml
      end

      def add_merchant(doc, product_type=nil)
        doc["v1"].merc do
          doc["v1"].id @options[:gateway_id]
          doc["v1"].regKey @options[:reg_key]
          doc["v1"].inType "1"
          doc["v1"].prodType product_type if product_type
        end
      end

      def add_amount(doc, money)
        doc["v1"].reqAmt amount(money)
      end

      def add_order_number(doc, options)
        return unless options[:order_id]

        doc["v1"].authReq {
          doc["v1"].ordNr options[:order_id]
        }
      end

      def add_credit_card(doc, payment_method)
        doc["v1"].card {
          doc["v1"].pan payment_method.number
          doc["v1"].sec payment_method.verification_value if payment_method.verification_value?
          doc["v1"].xprDt expiration_date(payment_method)
        }
      end

      def add_echeck(doc, payment_method)
        doc["v1"].achEcheck {
          doc["v1"].bankRtNr payment_method.routing_number
          doc["v1"].acctNr payment_method.account_number
        }
      end

      def expiration_date(payment_method)
        yy = format(payment_method.year, :two_digits)
        mm = format(payment_method.month, :two_digits)
        yy + mm
      end

      def add_pan(doc, payment_method)
        doc["v1"].card do
          doc["v1"].pan payment_method.number
        end
      end

      def add_contact(doc, fullname, options)
        doc["v1"].contact do
          doc["v1"].fullName fullname
          doc["v1"].coName options[:company_name] if options[:company_name]
          doc["v1"].title options[:title] if options[:title]

          if (billing_address = options[:billing_address])
            if billing_address[:phone]
              doc["v1"].phone do
                doc["v1"].type (options[:phone_number_type] || "4")
                doc["v1"].nr billing_address[:phone].gsub(/\D/, '')
              end
            end
            doc["v1"].addrLn1 billing_address[:address1] if billing_address[:address1]
            doc["v1"].addrLn2 billing_address[:address2] if billing_address[:address2]
            doc["v1"].city billing_address[:city] if billing_address[:city]
            doc["v1"].state billing_address[:state] if billing_address[:state]
            doc["v1"].zipCode billing_address[:zip] if billing_address[:zip]
            doc["v1"].ctry "US"
          end

          doc["v1"].email options[:email] if options[:email]
          doc["v1"].type options[:contact_type] if options[:contact_type]
          doc["v1"].stat options[:contact_stat] if options[:contact_stat]

          if (shipping_address = options[:shipping_address])
            doc["v1"].ship do
              doc["v1"].fullName fullname
              doc["v1"].addrLn1 shipping_address[:address1] if shipping_address[:address1]
              doc["v1"].addrLn2 shipping_address[:address2] if shipping_address[:address2]
              doc["v1"].city shipping_address[:city] if shipping_address[:city]
              doc["v1"].state shipping_address[:state] if shipping_address[:state]
              doc["v1"].zipCode shipping_address[:zip] if shipping_address[:zip]
              doc["v1"].phone shipping_address[:phone].gsub(/\D/, '') if shipping_address[:phone]
              doc["v1"].email shipping_address[:email] if shipping_address[:email]
            end
          end
        end
      end

      def add_name(doc, payment_method)
        doc["v1"].contact do
          doc["v1"].fullName payment_method.name
        end
      end

      def add_original_transaction_data(doc, authorization)
        doc["v1"].origTranData do
          doc["v1"].tranNr authorization
        end
      end

      def store_customer_details(doc, fullname, options)
        options[:contact_type] = 1 # recurring
        options[:contact_stat] = 1 # active

        doc["v1"].cust do
          doc["v1"].type 0 # add
          add_contact(doc, fullname, options)
        end
      end

      def add_customer_id(doc, customer_id)
        doc["v1"].contact do
          doc["v1"].id customer_id
        end
      end

      def add_wallet_id(doc, wallet_id)
        doc["v1"].recurMan do
          doc["v1"].id wallet_id
        end
      end
    end
  end
end
