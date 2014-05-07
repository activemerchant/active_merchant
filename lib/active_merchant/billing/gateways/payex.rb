require "nokogiri"
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayexGateway < Gateway
      self.live_url = 'https://external.payex.com/'
      self.test_url = 'https://test-external.payex.com/'

      self.money_format = :cents
      self.supported_countries = ['DK', 'FI', 'NO', 'SE']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = 'http://payex.com/'
      self.display_name = 'Payex'
      self.default_currency = "EUR"

      # NOTE: the PurchaseCC uses a different url for test transactions
      TEST_CONFINED_URL = 'https://test-confined.payex.com/'

      TRANSACTION_STATUS = {
        sale:       '0',
        initialize: '1',
        credit:     '2',
        authorize:  '3',
        cancel:     '4',
        failure:    '5',
        capture:    '6',
      }

      SOAP_ACTIONS = {
        initialize: { name: 'Initialize8', url: 'pxorder/pxorder.asmx', xmlns: 'http://external.payex.com/PxOrder/' },
        purchasecc: { name: 'PurchaseCC', url: 'pxconfined/pxorder.asmx', xmlns: 'http://confined.payex.com/PxOrder/', confined: true},
        cancel: { name: 'Cancel2', url: 'pxorder/pxorder.asmx', xmlns: 'http://external.payex.com/PxOrder/' },
        capture: { name: 'Capture5', url: 'pxorder/pxorder.asmx', xmlns: 'http://external.payex.com/PxOrder/' },
        credit: { name: 'Credit5', url: 'pxorder/pxorder.asmx', xmlns: 'http://external.payex.com/PxOrder/' },
        create_agreement: { name: 'CreateAgreement3', url: 'pxagreement/pxagreement.asmx', xmlns: 'http://external.payex.com/PxAgreement/' },
        delete_agreement: { name: 'DeleteAgreement', url: 'pxagreement/pxagreement.asmx', xmlns: 'http://external.payex.com/PxAgreement/' },
        autopay: { name: 'AutoPay3', url: 'pxagreement/pxagreement.asmx', xmlns: 'http://external.payex.com/PxAgreement/' },
      }

      def initialize(options = {})
        requires!(options, :account, :encryption_key)
        super
      end

      # Public: Send an authorize Payex request
      #
      # amount         - The monetary amount of the transaction in cents.
      # payment_method - The Active Merchant payment method or the +store+ authorization for stored transactions.
      # options        - A standard ActiveMerchant options hash:
      #                  :currency          - Three letter currency code for the transaction (default: "EUR")
      #                  :order_id          - The unique order ID for this transaction (required).
      #                  :product_number    - The merchant product number (default: '1').
      #                  :description       - The merchant description for this product (default: The :order_id).
      #                  :ip                - The client IP address (default: '127.0.0.1').
      #                  :vat               - The vat amount (optional).
      #
      # Returns an ActiveMerchant::Billing::Response object
      def authorize(amount, payment_method, options = {})
        requires!(options, :order_id)
        amount = amount(amount)
        if payment_method.respond_to?(:number)
          # credit card authorization
          MultiResponse.new.tap do |r|
            r.process {send_initialize(amount, true, options)}
            r.process {send_purchasecc(payment_method, r.params['orderref'])}
          end
        else
          # stored authorization
          send_autopay(amount, payment_method, true, options)
        end

      end

      # Public: Send a purchase Payex request
      #
      # amount         - The monetary amount of the transaction in cents.
      # payment_method - The Active Merchant payment method or the +store+ authorization for stored transactions.
      # options        - A standard ActiveMerchant options hash:
      #                  :currency          - Three letter currency code for the transaction (default: "EUR")
      #                  :order_id          - The unique order ID for this transaction (required).
      #                  :product_number    - The merchant product number (default: '1').
      #                  :description       - The merchant description for this product (default: The :order_id).
      #                  :ip                - The client IP address (default: '127.0.0.1').
      #                  :vat               - The vat amount (optional).
      #
      # Returns an ActiveMerchant::Billing::Response object
      def purchase(amount, payment_method, options = {})
        requires!(options, :order_id)
        amount = amount(amount)
        if payment_method.respond_to?(:number)
          # credit card purchase
          MultiResponse.new.tap do |r|
            r.process {send_initialize(amount, false, options)}
            r.process {send_purchasecc(payment_method, r.params['orderref'])}
          end
        else
          # stored purchase
          send_autopay(amount, payment_method, false, options)
        end
      end

      # Public: Capture money from a previously authorized transaction
      #
      # money - The amount to capture
      # authorization - The authorization token from the authorization request
      #
      # Returns an ActiveMerchant::Billing::Response object
      def capture(money, authorization, options = {})
        amount = amount(money)
        send_capture(amount, authorization)
      end

      # Public: Voids an authorize transaction
      #
      # authorization - The authorization returned from the successful authorize transaction.
      # options        - A standard ActiveMerchant options hash
      #
      # Returns an ActiveMerchant::Billing::Response object
      def void(authorization, options={})
        send_cancel(authorization)
      end

      # Public: Refunds a purchase transaction
      #
      # money - The amount to refund
      # authorization - The authorization token from the purchase request.
      # options        - A standard ActiveMerchant options hash:
      #                  :order_id          - The unique order ID for this transaction (required).
      #                  :vat_amount        - The vat amount (optional).
      #
      # Returns an ActiveMerchant::Billing::Response object
      def refund(money, authorization, options = {})
        requires!(options, :order_id)
        amount = amount(money)
        send_credit(authorization, amount, options)
      end

      # Public: Stores a credit card and creates a Payex agreement with a customer
      #
      # creditcard - The credit card to store.
      # options    - A standard ActiveMerchant options hash:
      #               :order_id          - The unique order ID for this transaction (required).
      #               :merchant_ref      - A reference that links this agreement to something the merchant takes money for (default: '1')
      #               :currency          - Three letter currency code for the transaction (default: "EUR")
      #               :product_number    - The merchant product number (default: '1').
      #               :description       - The merchant description for this product (default: The :order_id).
      #               :ip                - The client IP address (default: '127.0.0.1').
      #               :max_amount        - The maximum amount to allow to be charged (default: 100000).
      #               :vat               - The vat amount (optional).
      #
      # Returns an ActiveMerchant::Billing::Response object where the authorization is set to the agreement_ref which is used for stored payments.
      def store(creditcard, options = {})
        requires!(options, :order_id)
        amount = amount(1) # 1 cent for authorization
        MultiResponse.run(:first) do |r|
          r.process {send_create_agreement(options)}
          r.process {send_initialize(amount, true, options.merge({agreement_ref: r.authorization}))}
          order_ref = r.params['orderref']
          r.process {send_purchasecc(creditcard, order_ref)}
        end
      end

      # Public: Unstores a customer's credit card and deletes their Payex agreement.
      #
      # authorization - The authorization token from the store request.
      #
      # Returns an ActiveMerchant::Billing::Response object
      def unstore(authorization, options = {})
        send_delete_agreement(authorization)
      end

      private

      def send_initialize(amount, is_auth, options = {})
        properties = {
          accountNumber: @options[:account],
          purchaseOperation: is_auth ? 'AUTHORIZATION' : 'SALE',
          price: amount,
          priceArgList: nil,
          currency: (options[:currency] || default_currency),
          vat: options[:vat] || 0,
          orderID: options[:order_id],
          productNumber: options[:product_number] || '1',
          description: options[:description] || options[:order_id],
          clientIPAddress: options[:client_ip_address] || '127.0.0.1',
          clientIdentifier: nil,
          additionalValues: nil,
          externalID: nil,
          returnUrl: 'http://example.net', # set to dummy value since this is not used but is required
          view: 'CREDITCARD',
          agreementRef: options[:agreement_ref], # this is used to attach a stored agreement to a transaction as part of the store card
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

      def send_purchasecc(payment_method, order_ref)
        properties = {
          accountNumber: @options[:account],
          orderRef: order_ref,
          transactionType: 1, # online payment
          cardNumber: payment_method.number,
          cardNumberExpireMonth: "%02d" % payment_method.month,
          cardNumberExpireYear: "%02d" % payment_method.year,
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

      def send_autopay(amount, authorization, is_auth, options = {})
        properties = {
          accountNumber: @options[:account],
          agreementRef: authorization,
          price: amount,
          productNumber: options[:product_number] || '1',
          description: options[:description] || options[:order_id],
          orderId: options[:order_id],
          purchaseOperation: is_auth ? 'AUTHORIZATION' : 'SALE',
          currency: (options[:currency] || default_currency),
        }
        hash_fields = [:accountNumber, :agreementRef, :price, :productNumber, :description, :orderId, :purchaseOperation, :currency]
        add_request_hash(properties, hash_fields)

        soap_action = SOAP_ACTIONS[:autopay]
        request = build_xml_request(soap_action, properties)
        commit(soap_action, request)
      end

      def send_capture(amount, transaction_number, options = {})
        properties = {
          accountNumber: @options[:account],
          transactionNumber: transaction_number,
          amount: amount,
          orderId: options[:order_id] || '',
          vatAmount: options[:vat_amount] || 0,
          additionalValues: ''
        }
        hash_fields = [:accountNumber, :transactionNumber, :amount, :orderId, :vatAmount, :additionalValues]
        add_request_hash(properties, hash_fields)

        soap_action = SOAP_ACTIONS[:capture]
        request = build_xml_request(soap_action, properties)
        commit(soap_action, request)
      end

      def send_credit(transaction_number, amount, options = {})
        properties = {
          accountNumber: @options[:account],
          transactionNumber: transaction_number,
          amount: amount,
          orderId: options[:order_id],
          vatAmount: options[:vat_amount] || 0,
          additionalValues: ''
        }
        hash_fields = [:accountNumber, :transactionNumber, :amount, :orderId, :vatAmount, :additionalValues]
        add_request_hash(properties, hash_fields)

        soap_action = SOAP_ACTIONS[:credit]
        request = build_xml_request(soap_action, properties)
        commit(soap_action, request)
      end

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

      def send_create_agreement(options)
        properties = {
          accountNumber: @options[:account],
          merchantRef: options[:merchant_ref] || '1',
          description: options[:description] || options[:order_id],
          purchaseOperation: 'SALE',
          maxAmount: options[:max_amount] || 100000, # default to 1,000
          notifyUrl: '',
          startDate: options[:startDate] || '',
          stopDate: options[:stopDate] || ''
        }
        hash_fields = [:accountNumber, :merchantRef, :description, :purchaseOperation, :maxAmount, :notifyUrl, :startDate, :stopDate]
        add_request_hash(properties, hash_fields)

        soap_action = SOAP_ACTIONS[:create_agreement]
        request = build_xml_request(soap_action, properties)
        commit(soap_action, request)
      end

      def send_delete_agreement(authorization)
        properties = {
          accountNumber: @options[:account],
          agreementRef: authorization,
        }
        hash_fields = [:accountNumber, :agreementRef]
        add_request_hash(properties, hash_fields)

        soap_action = SOAP_ACTIONS[:delete_agreement]
        request = build_xml_request(soap_action, properties)
        commit(soap_action, request)
      end

      def url_for(soap_action)
        base_url = test? ? (soap_action[:confined] ? TEST_CONFINED_URL : test_url) : live_url
        File.join(base_url, soap_action[:url])
      end

      # this will add a hash to the passed in properties as required by Payex requests
      def add_request_hash(properties, fields)
        data = fields.map { |e| properties[e] }
        data << @options[:encryption_key]
        properties['hash_'] = Digest::MD5.hexdigest(data.join(''))
      end

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
                     message_from(response),
                     response,
                     test: test?,
                     authorization: build_authorization(response)
                    )
      end

      def build_authorization(response)
        # agreementref is for the store transaction, everything else gets transactionnumber
        response[:transactionnumber] || response[:agreementref]
      end

      def success?(response)
        response[:status_errorcode] == 'OK' && response[:transactionstatus] != TRANSACTION_STATUS[:failure]
      end

      def message_from(response)
        response[:status_description]
      end
    end
  end
end

