require "nokogiri"
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayexGateway < Gateway
      # NOTE: the PurchaseCC uses a different url for test transactions
      self.test_url = 'https://test-external.payex.com/'
      self.live_url = 'https://external.payex.com/'

      self.money_format = :cents
      self.supported_countries = ['SE', 'NO', 'DK']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = 'http://payex.com/'
      self.display_name = 'Payex'
      self.default_currency = "EUR"

      TRANSACTION_STATUS = {
        sale: '0',
        initialize: '1',
        credit: '2',
        authorize: '3',
        cancel: '4',
        failure: '5',
        capture: '6',
      }
      SOAP_ACTIONS = {
        initialize: { name: 'Initialize8', url: 'pxorder/pxorder.asmx', xmlns: 'http://external.payex.com/PxOrder/' },
        # add billing address details to a transaction (not implemented)
        add_order_address: { name: 'AddOrderAddress2', url: 'pxorder/pxorder.asmx', xmlns: 'http://external.payex.com/PxOrder/' },
        purchasecc: { name: 'PurchaseCC', url: 'pxconfined/pxorder.asmx', xmlns: 'http://confined.payex.com/PxOrder/', test_url: 'https://test-confined.payex.com/' },
        cancel: { name: 'Cancel2', url: 'pxorder/pxorder.asmx', xmlns: 'http://external.payex.com/PxOrder/' },
        capture: { name: 'Capture5', url: 'pxorder/pxorder.asmx', xmlns: 'http://external.payex.com/PxOrder/' },

        # void transaction
        credit: { name: 'Credit5', url: 'pxorder/pxorder.asmx', xmlns: 'http://external.payex.com/PxOrder/' },
        # store / unstore
        create_agreement: { name: 'CreateAgreement3', url: 'pxagreement/pxagreement.asmx', xmlns: 'http://external.payex.com/PxAgreement/' },
        delete_agreement: { name: 'DeleteAgreement', url: 'pxagreement/pxagreement.asmx', xmlns: 'http://external.payex.com/PxAgreement/' },
        autopay: { name: 'AutoPay3', url: 'pxagreement/pxagreement.asmx', xmlns: 'http://external.payex.com/PxAgreement/' },

        # Check the transaction status (not implemented)
        check_transaction: { name: 'Check2', url: 'pxorder/pxorder.asmx', xmlns: 'http://external.payex.com/PxOrder/' },

        # Check the agreement status (not implemented)
        check_agreement: { name: 'Check', url: 'pxagreement/pxagreement.asmx', xmlns: 'http://external.payex.com/PxAgreement/' },

      }

      def initialize(options = {})
        requires!(options, :account, :encryption_key)
        super
      end

      # Public: Send an authorize Payex request
      #
      # money          - The monetary amount of the transaction in cents.
      # creditcard     - The credit card
      # options        - A standard ActiveMerchant options hash:
      #                  :currency          - Three letter currency code for the transaction (default: "EUR")
      #                  :order_id          - The unique order ID for this transaction (required).
      #                  :product_number    - The merchant product number (required).
      #                  :description       - The merchant description for this product (required).
      #                  :client_ip_address - The client IP address (required).
      #                  :vat               - The vat amount (optional).
      #
      # Returns an ActiveMerchant::Billing::Response object
      def authorize(money, creditcard, options = {})
        MultiResponse.new.tap do |r|
          r.process {send_initialize(amount, false, options)}
          r.process {send_purchasecc(payment_method, r.params['orderref'])}
        end
      end

      # Public: Send a purchase Payex request
      #
      # amount         - The monetary amount of the transaction in cents.
      # payment_method - The Active Merchant payment method.
      # options        - A standard ActiveMerchant options hash:
      #                  :currency          - Three letter currency code for the transaction (default: "EUR")
      #                  :order_id          - The unique order ID for this transaction (required).
      #                  :product_number    - The merchant product number (required).
      #                  :description       - The merchant description for this product (required).
      #                  :client_ip_address - The client IP address (required).
      #                  :vat               - The vat amount (optional).
      #
      # Returns an ActiveMerchant::Billing::Response object
      def purchase(amount, payment_method, options = {})
        MultiResponse.new.tap do |r|
          r.process {send_initialize(amount, true, options)}
          r.process {send_purchasecc(payment_method, r.params['orderref'])}
        end
      end

      # Public: Capture money from a previously authorized transaction
      #
      # money - The amount to capture
      # authorization - The authorization token from the authorization request
      #
      # Returns an ActiveMerchant::Billing::Response object
      def capture(money, authorization, options = {})
        transaction_number, transaction_status = split_authorization(authorization)
        send_capture(amount(money), transaction_number)
      end

      # Public: Voids purchase and authorize transactions
      #
      # authorization - The authorization returned from the successful purchase or authorize transaction.
      #
      # Returns an ActiveMerchant::Billing::Response object
      def void(authorization, options={})
        # TODO
      end

      private

      def build_xml_request(soap_action, properties)
        builder = Nokogiri::XML::Builder.new
        builder.__send__('soap12:Envelope', {'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                                             'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
                                             'xmlns:soap12' => 'http://www.w3.org/2003/05/soap-envelope'}) do |root|
          root.__send__('soap12:Body') do |body|
            body.__send__(soap_action[:name], xmlns: soap_action[:xmlns]) do |doc|
              properties.each do |key, val|
                doc.send(key, val)
              end
            end
          end
        end
        builder.to_xml
      end

      # Sends a Payex Initialize8 request.
      #
      # amount      - The monetary amount of the transaction in cents.
      # is_purchase - Set to true for purchase requests, false for authorizations (2-phase)
      # options     - A standard ActiveMerchant options hash:
      #               :currency          - Three letter currency code for the transaction (default: "EUR")
      #               :order_id          - The unique order ID for this transaction (required).
      #               :product_number    - The merchant product number (required).
      #               :description       - The merchant description for this product (required).
      #               :client_ip_address - The client IP address (required).
      #               :vat               - The vat amount (optional).
      #
      # Returns an ActiveMerchant::Billing::Response object
      def send_initialize(amount, is_auth, options = {})
        requires!(options, :order_id, :product_number, :description, :client_ip_address)
        properties = {
          accountNumber: @options[:account],
          purchaseOperation: is_auth ? 'AUTHORIZATION' : 'SALE',
          price: amount,
          priceArgList: nil,
          currency: (options[:currency] || default_currency),
          vat: options[:vat],
          orderID: options[:order_id],
          productNumber: options[:product_number],
          description: options[:description],
          clientIPAddress: options[:client_ip_address],
          clientIdentifier: nil,
          additionalValues: nil,
          externalID: nil,
          returnUrl: 'http://example.net', # set to dummy value since this is not used but is required
          view: 'CREDITCARD',
          agreementRef: nil,
          cancelUrl: nil,
          clientLanguage: nil
        }
        hash_fields = [:accountNumber, :purchaseOperation, :price, :priceArgList, :currency, :vat, :orderID,
                       :productNumber, :description, :clientIPAddress, :clientIdentifier, :additionalValues,
                       :externalID, :returnUrl, :view, :agreementRef, :cancelUrl, :clientLanguage]
        add_request_hash(properties, hash_fields)
        soap_action = SOAP_ACTIONS[:initialize]
        request = build_xml_request(soap_action, properties)
        commit(soap_action, request)
      end

      # Send a Payex PurchaseCC request.
      #
      # payment_method - The Active Merchant payment method
      # order_ref      - The order reference received by the send_initialize response
      #
      # Returns an ActiveMerchant::Billing::Response object
      def send_purchasecc(payment_method, order_ref)
        properties = {
          accountNumber: @options[:account],
          orderRef: order_ref,
          transactionType: 1, # online payment
          cardNumber: payment_method.number,
          cardNumberExpireMonth: payment_method.month,
          cardNumberExpireYear: payment_method.year,
          cardHolderName: payment_method.name,
          cardNumberCVC: payment_method.verification_value
        }
        hash_fields = [:accountNumber, :orderRef, :transactionType, :cardNumber, :cardNumberExpireMonth,
                       :cardNumberExpireYear, :cardNumberCVC, :cardHolderName]
        add_request_hash(properties, hash_fields)

        soap_action = SOAP_ACTIONS[:purchasecc]
        request = build_xml_request(soap_action, properties)
        commit(soap_action, request)
      end

      # Send a Payex Capture request.
      #
      # amount             - The amount to capture
      # transaction_number - The transaction number of the authorization request
      # options            - A standard ActiveMerchant options hash:
      #                      :vat_amount - An optional VAT amount
      #
      # Returns an ActiveMerchant::Billing::Response object
      def send_capture(amount, transaction_number, options)
        properties = {
          accountNumber: @options[:account],
          transactionNumber: transaction_number,
          amount: amount,
          vatAmount: options[:vat_amount] || 0
        }
        hash_fields = [:accountNumber, :transactionNumber, :amount, :orderId, :vatAmount, :additionalValues]
        add_request_hash(properties, hash_fields)

        soap_action = SOAP_ACTIONS[:capture]
        request = build_xml_request(soap_action, properties)
        commit(soap_action, request)
      end

      # Send a Payex Credit (for purchases) request.
      #
      # transaction_number - The authorize transaction number to cancel
      # order_id           - The unique order id
      # options            - A standard ActiveMerchant options hash:
      #                      :vat_amount - An optional VAT amount
      #
      # Returns an ActiveMerchant::Billing::Response object
      def send_credit(transaction_number, amount, order_id, options)
        properties = {
          accountNumber: @options[:account],
          transactionNumber: transaction_number,
          amount: amount,
          orderId: order_id,
          vatAmount: options[:vat_amount] || 0,
        }
        hash_fields = [:accountNumber, :transactionNumber, :amount, :orderId, :vatAmount, :additionalValues]
        add_request_hash(properties, hash_fields)

        soap_action = SOAP_ACTIONS[:credit]
        request = build_xml_request(soap_action, properties)
        commit(soap_action, request)
      end

      # Send a Payex Cancel (for authorizations) request.
      #
      # transaction_number - The authorize transaction number to cancel
      #
      # Returns an ActiveMerchant::Billing::Response object
      def send_cancel(transaction_number)
        properties = {
          accountNumber: @options[:account],
          transactionNumber: transaction_number,
        }
        hash_fields = [:accountNumber, :transactionNumber]
        add_request_hash(properties, hash_fields)

        soap_action = SOAP_ACTIONS[:cancel]
        request = build_xml_request(soap_action, properties)
        commit(soap_action, request)
      end

      def url_for(soap_action)
        base_url = test? ? (soap_action[:test_url] || test_url) : live_url
        File.join(base_url, soap_action[:url])
      end

      # this will add a hash to the passed in properties as required by Payex requests
      def add_request_hash(properties, fields)
        data = fields.map { |e| properties[e] }
        data << @options[:encryption_key]
        properties['hash_'] = Digest::MD5.hexdigest(data.join(''))
      end

      def parse(xml)
        response = {}

        xmldoc = Nokogiri::XML(xml)
        body = xmldoc.xpath("//soap:Body/*[1]")[0].inner_text

        doc = Nokogiri::XML(body)

        doc.root.xpath("*").each do |node|
          if (node.elements.size == 0)
            response[node.name.downcase.to_sym] = node.text
          else
            node.elements.each do |childnode|
              name = "#{node.name.downcase}_#{childnode.name.downcase}"
              response[name.to_sym] = childnode.text
            end
          end
        end unless doc.root.nil?

        response
      end

      # Commits all requests to the Payex soap endpoint
      def commit(soap_action, request)
        url = url_for(soap_action)
        headers = {
          'Content-Type' => 'application/soap+xml; charset=utf-8',
          'Content-Length' => request.size.to_s
        }
        response = parse(ssl_post(url, request, headers))
        Response.new(success?(response),
                     response[:status_description],
                     response,
                     test: test?,
                     authorization: build_authorization(response)
                    )
      end

      def build_authorization
        parts = [response[:transactionnumber] || response[:agreementref]]
        parts << response[:transactionstatus]
        parts.compact.join(';')
      end

      def split_authorization(auth)
        auth.split(';')
      end

      def success?(response)
        response[:status_errorcode] == 'OK' && response[:transactionstatus] != TRANSACTION_STATUS[:failure]
      end

      def message_from(response)
      end

      def post_data(action, parameters = {})
      end
    end
  end
end

