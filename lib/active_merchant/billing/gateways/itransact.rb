require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # iTransact, Inc. is an authorized reseller of the PaymentClearing gateway. If your merchant service provider uses PaymentClearing.com to process payments, you can use this module.
    #
    #
    # Please note, the username and API Access Key are not what you use to log into the Merchant Control Panel.
    #
    # ==== How to get your GatewayID and API Access Key
    #
    # 1. If you don't already have a Gateway Account, go to http://www.itransact.com/merchant/test.html to sign up.
    # 2. Go to http://support.paymentclearing.com and login or register, if necessary.
    # 3. Click on "Submit a Ticket."
    # 4. Select "Merchant Support" as the department and click "Next"
    # 5. Enter *both* your company name and GatewayID. Put "API Access Key" in the subject.  In the body, you can request a username, but it may already be in use.
    #
    # ==== Initialization
    #
    # Once you have the username, API Access Key, and your GatewayId, you're ready
    # to begin.  You initialize the Gateway like so:
    #
    #   gateway = ActiveMerchant::Billing::ItransactGateway.new(
    #     :login => "#{THE_USERNAME}",
    #     :password => "#{THE_API_ACCESS_KEY}",
    #     :gateway_id => "#{THE_GATEWAY_ID}"
    #   )
    #
    # ==== Important Notes
    # 1. Recurring is not implemented
    # 1. CreditTransactions are not implemented (these are credits not related to a previously run transaction).
    # 1. TransactionStatus is not implemented
    #
    class ItransactGateway < Gateway
      self.live_url = self.test_url = 'https://secure.paymentclearing.com/cgi-bin/rc/xmltrans2.cgi'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.itransact.com/'

      # The name of the gateway
      self.display_name = 'iTransact'

      #
      # Creates a new instance of the iTransact Gateway.
      #
      # ==== Parameters
      # * <tt>options</tt> - A Hash of options
      # 
      # ==== Options Hash
      # * <tt>:login</tt> - A String containing your PaymentClearing assigned API Access Username
      # * <tt>:password</tt> - A String containing your PaymentClearing assigned API Access Key
      # * <tt>:gateway_id</tt> - A String containing your PaymentClearing assigned GatewayID
      # * <tt>:test_mode</tt> - <tt>true</tt> or <tt>false</tt>. Run *all* transactions with the 'TestMode' element set to 'TRUE'.
      #
      def initialize(options = {})
        requires!(options, :login, :password, :gateway_id)
        @options = options
        super
      end

      # Performs an authorize transaction.  In PaymentClearing's documentation
      # this is known as a "PreAuth" transaction.
      #
      # ==== Parameters
      # * <tt>money</tt> - The amount to be captured. Should be an Integer amount in cents.
      # * <tt>creditcard</tt> - The CreditCard details for the transaction
      # * <tt>options</tt> - A Hash of options
      #
      # ==== Options Hash
      # The standard options apply here (:order_id, :ip, :customer, :invoice, :merchant, :description, :email, :currency, :address, :billing_address, :shipping_address), as well as:
      # * <tt>:order_items</tt> - An Array of Hash objects with the keys <tt>:description</tt>, <tt>:cost</tt> (in cents!), and <tt>:quantity</tt>.  If this is provided, <tt>:description</tt> and <tt>money</tt> will be ignored.
      # * <tt>:vendor_data</tt> - An Array of Hash objects with the keys being the name of the VendorData element and value being the value.
      # * <tt>:send_customer_email</tt> - <tt>true</tt> or <tt>false</tt>. Runs the transaction with the 'SendCustomerEmail' element set to 'TRUE' or 'FALSE'.
      # * <tt>:send_merchant_email</tt> - <tt>true</tt> or <tt>false</tt>. Runs the transaction with the 'SendMerchantEmail' element set to 'TRUE' or 'FALSE'.
      # * <tt>:email_text</tt> - An Array of (up to ten (10)) String objects to be included in emails
      # * <tt>:test_mode</tt> - <tt>true</tt> or <tt>false</tt>. Runs the transaction with the 'TestMode' element set to 'TRUE' or 'FALSE'.
      #
      # ==== Examples
      #  response = gateway.authorize(1000, creditcard,
      #    :order_id => '1212', :address => {...}, :email => 'test@test.com',
      #    :order_items => [
      #      {:description => 'Line Item 1', :cost => '8.98', :quantity => '6'},
      #      {:description => 'Line Item 2', :cost => '6.99', :quantity => '4'}
      #    ],
      #    :vendor_data => [{'repId' => '1234567'}, {'customerId' => '9886'}],
      #    :send_customer_email => true,
      #    :send_merchant_email => true,
      #    :email_text => ['line1', 'line2', 'line3'],
      #    :test_mode => true
      #  )
      #
      def authorize(money, payment_source, options = {})
        payload = Nokogiri::XML::Builder.new do |xml|
          xml.AuthTransaction {
            xml.Preauth
            add_customer_data(xml, payment_source, options)
            add_invoice(xml, money, options)
            add_payment_source(xml, payment_source)
            add_transaction_control(xml, options)
            add_vendor_data(xml, options)
          }
        end.doc

        commit(payload)
      end

      # Performs an authorize and capture in single transaction. In PaymentClearing's
      # documentation this is known as an "Auth" or a "Sale" transaction
      #
      # ==== Parameters
      # * <tt>money</tt> - The amount to be captured. Should be <tt>nil</tt> or an Integer amount in cents.
      # * <tt>creditcard</tt> - The CreditCard details for the transaction
      # * <tt>options</tt> - A Hash of options
      #
      # ==== Options Hash
      # The standard options apply here (:order_id, :ip, :customer, :invoice, :merchant, :description, :email, :currency, :address, :billing_address, :shipping_address), as well as:
      # * <tt>:order_items</tt> - An Array of Hash objects with the keys <tt>:description</tt>, <tt>:cost</tt> (in cents!), and <tt>:quantity</tt>.  If this is provided, <tt>:description</tt> and <tt>money</tt> will be ignored.
      # * <tt>:vendor_data</tt> - An Array of Hash objects with the keys being the name of the VendorData element and value being the value.
      # * <tt>:send_customer_email</tt> - <tt>true</tt> or <tt>false</tt>. Runs the transaction with the 'SendCustomerEmail' element set to 'TRUE' or 'FALSE'.
      # * <tt>:send_merchant_email</tt> - <tt>true</tt> or <tt>false</tt>. Runs the transaction with the 'SendMerchantEmail' element set to 'TRUE' or 'FALSE'.
      # * <tt>:email_text</tt> - An Array of (up to ten (10)) String objects to be included in emails
      # * <tt>:test_mode</tt> - <tt>true</tt> or <tt>false</tt>. Runs the transaction with the 'TestMode' element set to 'TRUE' or 'FALSE'.
      #
      # ==== Examples
      #  response = gateway.purchase(1000, creditcard,
      #    :order_id => '1212', :address => {...}, :email => 'test@test.com',
      #    :order_items => [
      #      {:description => 'Line Item 1', :cost => '8.98', :quantity => '6'},
      #      {:description => 'Line Item 2', :cost => '6.99', :quantity => '4'}
      #    ],
      #    :vendor_data => [{'repId' => '1234567'}, {'customerId' => '9886'}],
      #    :send_customer_email => true,
      #    :send_merchant_email => true,
      #    :email_text => ['line1', 'line2', 'line3'],
      #    :test_mode => true
      #  )
      #
      def purchase(money, payment_source, options = {})
        payload = Nokogiri::XML::Builder.new do |xml|
          xml.AuthTransaction {
            add_customer_data(xml, payment_source, options)
            add_invoice(xml, money, options)
            add_payment_source(xml, payment_source)
            add_transaction_control(xml, options)
            add_vendor_data(xml, options)
          }
        end.doc

        commit(payload)
      end

      # Captures the funds from an authorize transaction.  In PaymentClearing's
      # documentation this is known as a "PostAuth" transaction.
      #
      # ==== Parameters
      # * <tt>money</tt> - The amount to be captured. Should be an Integer amount in cents
      # * <tt>authorization</tt> - The authorization returned from the previous capture or purchase request
      # * <tt>options</tt> - A Hash of options, all are optional.
      #
      # ==== Options Hash
      # The standard options apply here (:order_id, :ip, :customer, :invoice, :merchant, :description, :email, :currency, :address, :billing_address, :shipping_address), as well as:
      # * <tt>:vendor_data</tt> - An Array of Hash objects with the keys being the name of the VendorData element and value being the value.
      # * <tt>:send_customer_email</tt> - <tt>true</tt> or <tt>false</tt>. Runs the transaction with the 'SendCustomerEmail' element set to 'TRUE' or 'FALSE'.
      # * <tt>:send_merchant_email</tt> - <tt>true</tt> or <tt>false</tt>. Runs the transaction with the 'SendMerchantEmail' element set to 'TRUE' or 'FALSE'.
      # * <tt>:email_text</tt> - An Array of (up to ten (10)) String objects to be included in emails
      # * <tt>:test_mode</tt> - <tt>true</tt> or <tt>false</tt>. Runs the transaction with the 'TestMode' element set to 'TRUE' or 'FALSE'.
      #
      # ==== Examples
      #  response = gateway.capture(1000, creditcard,
      #    :vendor_data => [{'repId' => '1234567'}, {'customerId' => '9886'}],
      #    :send_customer_email => true,
      #    :send_merchant_email => true,
      #    :email_text => ['line1', 'line2', 'line3'],
      #    :test_mode => true
      #  )
      #
      def capture(money, authorization, options = {})
        payload = Nokogiri::XML::Builder.new do |xml|
          xml.PostAuthTransaction {
            xml.OperationXID(authorization)
            add_invoice(xml, money, options)
            add_transaction_control(xml, options)
            add_vendor_data(xml, options)
          }
        end.doc

        commit(payload)
      end

      # This will reverse a previously run transaction which *has* *not* settled.
      #
      # ==== Parameters
      # * <tt>authorization</tt> - The authorization returned from the previous capture or purchase request
      # * <tt>options</tt> - A Hash of options, all are optional
      #
      # ==== Options Hash
      # The standard options (:order_id, :ip, :customer, :invoice, :merchant, :description, :email, :currency, :address, :billing_address, :shipping_address) are ignored.
      # * <tt>:vendor_data</tt> - An Array of Hash objects with the keys being the name of the VendorData element and value being the value.
      # * <tt>:send_customer_email</tt> - <tt>true</tt> or <tt>false</tt>. Runs the transaction with the 'SendCustomerEmail' element set to 'TRUE' or 'FALSE'.
      # * <tt>:send_merchant_email</tt> - <tt>true</tt> or <tt>false</tt>. Runs the transaction with the 'SendMerchantEmail' element set to 'TRUE' or 'FALSE'.
      # * <tt>:email_text</tt> - An Array of (up to ten (10)) String objects to be included in emails
      # * <tt>:test_mode</tt> - <tt>true</tt> or <tt>false</tt>. Runs the transaction with the 'TestMode' element set to 'TRUE' or 'FALSE'.
      #
      # ==== Examples
      #  response = gateway.void('9999999999',
      #    :vendor_data => [{'repId' => '1234567'}, {'customerId' => '9886'}],
      #    :send_customer_email => true,
      #    :send_merchant_email => true,
      #    :email_text => ['line1', 'line2', 'line3'],
      #    :test_mode => true
      #  )
      #
      def void(authorization, options = {})
        payload = Nokogiri::XML::Builder.new do |xml|
          xml.VoidTransaction {
            xml.OperationXID(authorization)
            add_transaction_control(xml, options)
            add_vendor_data(xml, options)
          }
        end.doc

        commit(payload)
      end

      # This will reverse a previously run transaction which *has* settled.
      #
      # ==== Parameters
      # * <tt>money</tt> - The amount to be credited. Should be an Integer amount in cents
      # * <tt>authorization</tt> - The authorization returned from the previous capture or purchase request
      # * <tt>options</tt> - A Hash of options, all are optional
      #
      # ==== Options Hash
      # The standard options (:order_id, :ip, :customer, :invoice, :merchant, :description, :email, :currency, :address, :billing_address, :shipping_address) are ignored.
      # * <tt>:vendor_data</tt> - An Array of Hash objects with the keys being the name of the VendorData element and value being the value.
      # * <tt>:send_customer_email</tt> - <tt>true</tt> or <tt>false</tt>. Runs the transaction with the 'SendCustomerEmail' element set to 'TRUE' or 'FALSE'.
      # * <tt>:send_merchant_email</tt> - <tt>true</tt> or <tt>false</tt>. Runs the transaction with the 'SendMerchantEmail' element set to 'TRUE' or 'FALSE'.
      # * <tt>:email_text</tt> - An Array of (up to ten (10)) String objects to be included in emails
      # * <tt>:test_mode</tt> - <tt>true</tt> or <tt>false</tt>. Runs the transaction with the 'TestMode' element set to 'TRUE' or 'FALSE'.
      #
      # ==== Examples
      #  response = gateway.refund(555, '9999999999',
      #    :vendor_data => [{'repId' => '1234567'}, {'customerId' => '9886'}],
      #    :send_customer_email => true,
      #    :send_merchant_email => true,
      #    :email_text => ['line1', 'line2', 'line3'],
      #    :test_mode => true
      #  )
      #
      def refund(money, authorization, options = {})
        payload = Nokogiri::XML::Builder.new do |xml|
          xml.TranCredTransaction {
            xml.OperationXID(authorization)
            add_invoice(xml, money, options)
            add_transaction_control(xml, options)
            add_vendor_data(xml, options)
          }
        end.doc

        commit(payload)
      end

      private

      def add_customer_data(xml, payment_source, options)
        billing_address = options[:billing_address] || options[:address]
        shipping_address = options[:shipping_address] || options[:address]

        xml.CustomerData {
          xml.Email(options[:email]) unless options[:email].blank?
          xml.CustId(options[:order_id]) unless options[:order_id].blank?
          xml.BillingAddress {
            xml.FirstName(payment_source.first_name || parse_first_name(billing_address[:name]))
            xml.LastName(payment_source.last_name || parse_last_name(billing_address[:name]))
            xml.Address1(billing_address[:address1])
            xml.Address2(billing_address[:address2]) unless billing_address[:address2].blank?
            xml.City(billing_address[:city])
            xml.State(billing_address[:state])
            xml.Zip(billing_address[:zip])
            xml.Country(billing_address[:country])
            xml.Phone(billing_address[:phone])
          }
          xml.ShippingAddress {
            xml.FirstName(payment_source.first_name || parse_first_name(shipping_address[:name]))
            xml.LastName(payment_source.last_name || parse_last_name(shipping_address[:name]))
            xml.Address1(shipping_address[:address1])
            xml.Address2(shipping_address[:address2]) unless shipping_address[:address2].blank?
            xml.City(shipping_address[:city])
            xml.State(shipping_address[:state])
            xml.Zip(shipping_address[:zip])
            xml.Country(shipping_address[:country])
            xml.Phone(shipping_address[:phone])
          } unless shipping_address.blank?
        }
      end

      def add_invoice(xml, money, options)
        xml.AuthCode options[:force] if options[:force]
        if options[:order_items].blank?
          xml.Total(amount(money)) unless(money.nil? || money < 0.01)
          xml.Description(options[:description]) unless( options[:description].blank?)
        else
          xml.OrderItems {
            options[:order_items].each do |item|
              xml.Item {
                xml.Description(item[:description])
                xml.Cost(amount(item[:cost]))
                xml.Qty(item[:quantity].to_s)
              }
            end
          }
        end
      end

      def add_payment_source(xml, source)
        case determine_funding_source(source)
        when :credit_card then add_creditcard(xml, source)
        when :check       then add_check(xml, source)
        end
      end

      def determine_funding_source(payment_source)
        case payment_source
        when ActiveMerchant::Billing::CreditCard
          :credit_card
        when ActiveMerchant::Billing::Check
          :check
        end
      end

      def add_creditcard(xml, creditcard)
        xml.AccountInfo {
          xml.CardAccount {
            xml.AccountNumber(creditcard.number.to_s)
            xml.ExpirationMonth(creditcard.month.to_s.rjust(2,'0'))
            xml.ExpirationYear(creditcard.year.to_s)
            xml.CVVNumber(creditcard.verification_value.to_s) unless creditcard.verification_value.blank?
          }
        }
      end

      def add_check(xml, check)
        xml.AccountInfo {
          xml.ABA(check.routing_number.to_s)
          xml.AccountNumber(check.account_number.to_s)
          xml.AccountSource(check.account_type.to_s)
          xml.AccountType(check.account_holder_type.to_s)
          xml.CheckNumber(check.number.to_s)
        }
      end

      def add_transaction_control(xml, options)
        xml.TransactionControl {
          # if there was a 'global' option set...
          xml.TestMode(@options[:test_mode].upcase) if !@options[:test_mode].blank?
          # allow the global option to be overridden...
          xml.TestMode(options[:test_mode].upcase) if !options[:test_mode].blank?
          xml.SendCustomerEmail(options[:send_customer_email].upcase) unless options[:send_customer_email].blank?
          xml.SendMerchantEmail(options[:send_merchant_email].upcase) unless options[:send_merchant_email].blank?
          xml.EmailText {
            options[:email_text].each do |item|
              xml.EmailTextItem(item)
            end
          } if options[:email_text]
        }
      end

      def add_vendor_data(xml, options)
        return if options[:vendor_data].blank?
        xml.VendorData {
          options[:vendor_data].each do |k,v|
            xml.Element {
              xml.Name(k)
              xml.Key(v)
            }
          end
        }
      end

      def commit(payload)
        # Set the Content-Type header -- otherwise the URL decoding messes up
        # the Base64 encoded payload signature!
        response = parse(ssl_post(self.live_url, post_data(payload), 'Content-Type' => 'text/xml'))

        Response.new(successful?(response), response[:error_message], response,
          :test => test?,
          :authorization => response[:xid],
          :avs_result => { :code => response[:avs_response] },
          :cvv_result => response[:cvv_response])
      end

      def post_data(payload)
        payload_xml = payload.root.to_xml(:indent => 0)

        payload_signature = sign_payload(payload_xml)

        request = Nokogiri::XML::Builder.new do |xml|
          xml.GatewayInterface {
            xml.APICredentials {
              xml.Username(@options[:login])
              xml.PayloadSignature(payload_signature)
              xml.TargetGateway(@options[:gateway_id])
            }
          }
        end.doc

        request.root.children.first.after payload.root
        request.to_xml(:indent => 0)
      end

      def parse(raw_xml)
        doc = REXML::Document.new(raw_xml)
        response = Hash.new
        transaction_result = doc.root.get_elements('TransactionResponse/TransactionResult/*')
        transaction_result.each do |e|
          response[e.name.to_s.underscore.to_sym] = e.text unless e.text.blank?
        end
        response
      end

      def successful?(response)
        # Turns out the PaymentClearing gateway is not consistent...
        response[:status].downcase =='ok'
      end

      def test_mode?(response)
        # The '1' is a legacy thing; most of the time it should be 'TRUE'...
        response[:test_mode] == 'TRUE' || response[:test_mode] == '1'
      end

      def message_from(response)
        response[:error_message]
      end

      def sign_payload(payload)
        key = @options[:password].to_s
        digest=OpenSSL::HMAC.digest(OpenSSL::Digest::SHA1.new(key), key, payload)
        signature = Base64.encode64(digest)
        signature.chomp!
      end
    end
  end
end

