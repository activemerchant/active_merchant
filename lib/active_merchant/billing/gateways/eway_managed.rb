module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class EwayManagedGateway < Gateway
      self.test_url = 'https://www.eway.com.au/gateway/ManagedPaymentService/test/managedCreditCardPayment.asmx'
      self.live_url = 'https://www.eway.com.au/gateway/ManagedPaymentService/managedCreditCardPayment.asmx'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['AU']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master]

      self.default_currency = 'AUD'

      #accepted money format
      self.money_format = :cents

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.eway.com.au/'

      # The name of the gateway
      self.display_name = 'eWay Managed Payments'

      def initialize(options = {})
        requires!(options, :login, :username, :password)

        # eWay returns 500 code for faults, which AM snaffles.
        # So, we tell it to allow them.
        options[:ignore_http_status] = true
        super
      end

      # add a new customer CC to your eway account and return unique ManagedCustomerID
      # supports storing details required by eway see "add_creditcard" and "add_address"
      def store(creditcard, options = {})
        post = {}

        # Handle our required fields
        requires!(options, :billing_address)

        # Handle eWay specific required fields.
        billing_address = options[:billing_address]
        eway_requires!(billing_address)

        add_creditcard(post, creditcard)
        add_address(post, billing_address)
        add_misc_fields(post, options)

        commit("CreateCustomer", post)
      end

      def update(billing_id, creditcard, options={})
        post = {}

        # Handle our required fields
        requires!(options, :billing_address)

        # Handle eWay specific required fields.
        billing_address = options[:billing_address]
        eway_requires!(billing_address)

        post[:managedCustomerID]=billing_id
        add_creditcard(post, creditcard)
        add_address(post, billing_address)
        add_misc_fields(post, options)

        commit("UpdateCustomer", post)
      end

      # Process a payment in the given amount against the stored credit card given by billing_id
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be purchased as an Integer value in cents.
      # * <tt>billing_id</tt> -- The eWay provided card/customer token to charge (managedCustomerID)
      # * <tt>options</tt> -- A hash of optional parameters.
      #
      # ==== Options
      #
      # * <tt>:order_id</tt> -- The order number, passed to eWay as the "Invoice Reference"
      # * <tt>:invoice</tt> -- The invoice number, passed to eWay as the "Invoice Reference" unless :order_id is also given
      # * <tt>:description</tt> -- A description of the payment, passed to eWay as the "Invoice Description"
      def purchase(money, billing_id, options={})
        post = {}
        post[:managedCustomerID] = billing_id.to_s
        post[:amount]=money
        add_invoice(post, options)

        commit("ProcessPayment", post)
      end

      # Get customer's stored credit card details given by billing_id
      #
      # ==== Parameters
      #
      # * <tt>billing_id</tt> -- The eWay provided card/customer token to charge (managedCustomerID)
      def retrieve(billing_id)
        post = {}
        post[:managedCustomerID] = billing_id.to_s

        commit("QueryCustomer", post)
      end

      # TODO: eWay API also provides QueryPayment

      private

      def eway_requires!(hash)
        raise ArgumentError.new("Missing eWay required parameter in `billing_address`: title") unless hash.has_key?(:title)
        raise ArgumentError.new("Missing eWay required parameter in `billing_address`: country") unless hash.has_key?(:country)
      end

      def add_address(post, address)
        post[:Address]  = address[:address1].to_s
        post[:Phone]    = address[:phone].to_s
        post[:PostCode] = address[:zip].to_s
        post[:Suburb]   = address[:city].to_s
        post[:Country]  = address[:country].to_s.downcase
        post[:State]    = address[:state].to_s
        post[:Mobile]   = address[:mobile].to_s
        post[:Fax]      = address[:fax].to_s
      end

      def add_misc_fields(post, options)
        post[:CustomerRef]=options[:billing_address][:customer_ref] || options[:customer]
        post[:Title]=options[:billing_address][:title]
        post[:Company]=options[:billing_address][:company]
        post[:JobDesc]=options[:billing_address][:job_desc]
        post[:Email]=options[:billing_address][:email] || options[:email]
        post[:URL]=options[:billing_address][:url]
        post[:Comments]=options[:description]
      end

      def add_invoice(post, options)
        post[:invoiceReference] = options[:order_id] || options[:invoice]
        post[:invoiceDescription] = options[:description]
      end


      # add credit card details to be stored by eway. NOTE eway requires "title" field
      def add_creditcard(post, creditcard)
        post[:CCNumber]  = creditcard.number
        post[:CCExpiryMonth]  = sprintf("%.2i", creditcard.month)
        post[:CCExpiryYear] = sprintf("%.4i", creditcard.year)[-2..-1]
        post[:CCNameOnCard] = creditcard.name
        post[:FirstName] = creditcard.first_name
        post[:LastName]  = creditcard.last_name
      end

      def parse(body)
        reply = {}
        xml = REXML::Document.new(body)
         if root = REXML::XPath.first(xml, "//soap:Fault") then
           reply=parse_fault(root)
        else
          if root = REXML::XPath.first(xml, '//ProcessPaymentResponse/ewayResponse') then
            # Successful payment
            reply=parse_purchase(root)
          else
            if root = REXML::XPath.first(xml, '//QueryCustomerResult') then
              reply=parse_query_customer(root)
            else
              if root = REXML::XPath.first(xml, '//CreateCustomerResult') then
                reply[:message]='OK'
                reply[:CreateCustomerResult]=root.text
                reply[:success]=true
              else
                if root = REXML::XPath.first(xml, '//UpdateCustomerResult') then
                  if root.text.downcase == 'true' then
                    reply[:message]='OK'
                    reply[:success]=true
                  else
                    # ERROR: This state should never occur. If there is a problem,
                    #        a soap:Fault will be returned. The presence of this
                    #        element always means a success.
                    raise StandardError, "Unexpected \"false\" in UpdateCustomerResult"
                  end
                else
                  # ERROR: This state should never occur currently. We have handled
                  #        responses for all the methods which we support.
                  raise StandardError, "Unexpected response"
                end
              end
            end
          end
        end
        return reply
      end

      def parse_fault(node)
        reply={}
        reply[:message]=REXML::XPath.first(node, '//soap:Reason/soap:Text').text
        reply[:success]=false
        reply
      end

      def parse_purchase(node)
        reply={}
        reply[:message]=REXML::XPath.first(node, '//ewayTrxnError').text
        reply[:success]=(REXML::XPath.first(node, '//ewayTrxnStatus').text == 'True')
        reply[:auth_code]=REXML::XPath.first(node, '//ewayAuthCode').text
        reply[:transaction_number]=REXML::XPath.first(node, '//ewayTrxnNumber').text
        reply
      end

      def parse_query_customer(node)
        reply={}
        reply[:message]='OK'
        reply[:success]=true
        reply[:CCNumber]=REXML::XPath.first(node, '//CCNumber').text
        reply[:CCName]=REXML::XPath.first(node, '//CCName').text
        reply[:CCExpiryMonth]=REXML::XPath.first(node, '//CCExpiryMonth').text
        reply[:CCExpiryYear]=REXML::XPath.first(node, '//CCExpiryYear').text
        reply
      end

      def commit(action, post)
        raw = begin
          ssl_post(test? ? self.test_url : self.live_url, soap_request(post, action), 'Content-Type' => 'application/soap+xml; charset=utf-8')
        rescue ResponseError => e
          e.response.body
        end
        response = parse(raw)

        EwayResponse.new(response[:success], response[:message], response,
          :test => test?,
          :authorization => response[:auth_code]
        )
      end

      # Where we build the full SOAP 1.2 request using builder
      def soap_request(arguments, action)
        # eWay demands all fields be sent, but contain an empty string if blank
        post = case action
                when 'QueryCustomer'
                  arguments
                when 'ProcessPayment'
                  default_payment_fields.merge(arguments)
                when 'CreateCustomer'
                  default_customer_fields.merge(arguments)
                when 'UpdateCustomer'
                  default_customer_fields.merge(arguments)
               end

        xml = Builder::XmlMarkup.new :indent => 2
          xml.instruct!
          xml.tag! 'soap12:Envelope', {'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema', 'xmlns:soap12' => 'http://www.w3.org/2003/05/soap-envelope'} do
            xml.tag! 'soap12:Header' do
              xml.tag! 'eWAYHeader', {'xmlns' => 'https://www.eway.com.au/gateway/managedpayment'} do
                xml.tag! 'eWAYCustomerID', @options[:login]
                xml.tag! 'Username', @options[:username]
                xml.tag! 'Password', @options[:password]
              end
            end
            xml.tag! 'soap12:Body' do |x|
              x.tag! "#{action}", {'xmlns' => 'https://www.eway.com.au/gateway/managedpayment'} do |y|
                post.each do |key, value|
                  y.tag! "#{key}", "#{value}"
                end
              end
            end
          end
        xml.target!
      end

      def default_customer_fields
        hash={}
        %w( CustomerRef Title FirstName LastName Company JobDesc Email Address Suburb State PostCode Country Phone Mobile Fax URL Comments CCNumber CCNameOnCard CCExpiryMonth CCExpiryYear ).each do |field|
          hash[field.to_sym]=''
        end
        return hash
      end

      def default_payment_fields
        hash={}
        %w( managedCustomerID amount invoiceReference invoiceDescription ).each do |field|
          hash[field.to_sym]=''
        end
        return hash
      end

      class EwayResponse < Response
        # add a method to response so we can easily get the eway token "ManagedCustomerID"
        def token
          @params['CreateCustomerResult']
        end
      end

    end
  end
end
