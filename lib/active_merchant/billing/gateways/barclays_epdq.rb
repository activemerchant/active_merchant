module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BarclaysEpdqGateway < Gateway
      self.test_url = 'https://secure2.mde.epdq.co.uk:11500'
      self.live_url = 'https://secure2.epdq.co.uk:11500'

      self.supported_countries = ['GB']
      self.default_currency = 'GBP'
      self.supported_cardtypes = [:visa, :master, :american_express, :maestro, :switch ]
      self.money_format = :cents
      self.homepage_url = 'http://www.barclaycard.co.uk/business/accepting-payments/epdq-mpi/'
      self.display_name = 'Barclays ePDQ MPI'

      def initialize(options = {})
        requires!(options, :login, :password, :client_id)
        super
      end

      def authorize(money, creditcard, options = {})
        document = Document.new(self, @options) do
          add_order_form(options[:order_id]) do
            add_consumer(options) do
              add_creditcard(creditcard)
            end
            add_transaction(:PreAuth, money)
          end
        end

        commit(document)
      end

      def purchase(money, creditcard, options = {})
        # disable fraud checks if this is a repeat order:
        if options[:payment_number] && (options[:payment_number] > 1)
          no_fraud = true
        else
          no_fraud = options[:no_fraud]
        end
        document = Document.new(self, @options, :no_fraud => no_fraud) do
          add_order_form(options[:order_id], options[:group_id]) do
            add_consumer(options) do
              add_creditcard(creditcard)
            end
            add_transaction(:Auth, money, options)
          end
        end
        commit(document)
      end

      # authorization is your unique order ID, not the authorization
      # code returned by ePDQ
      def capture(money, authorization, options = {})
        document = Document.new(self, @options) do
          add_order_form(authorization) do
            add_transaction(:PostAuth, money)
          end
        end

        commit(document)
      end

      # authorization is your unique order ID, not the authorization
      # code returned by ePDQ
      def credit(money, creditcard_or_authorization, options = {})
        if creditcard_or_authorization.is_a?(String)
          deprecated CREDIT_DEPRECATION_MESSAGE
          refund(money, creditcard_or_authorization, options)
        else
          credit_new_order(money, creditcard_or_authorization, options)
        end
      end

      def refund(money, authorization, options = {})
        credit_existing_order(money, authorization, options)
      end

      def void(authorization, options = {})
        document = Document.new(self, @options) do
          add_order_form(authorization) do
            add_transaction(:Void)
          end
        end

        commit(document)
      end

      private
      def credit_new_order(money, creditcard, options)
        document = Document.new(self, @options) do
          add_order_form do
            add_consumer(options) do
              add_creditcard(creditcard)
            end
            add_transaction(:Credit, money)
          end
        end

        commit(document)
      end

      def credit_existing_order(money, authorization, options)
        order_id, _ = authorization.split(":")
        document = Document.new(self, @options) do
          add_order_form(order_id) do
            add_transaction(:Credit, money)
          end
        end

        commit(document)
      end

      def parse(body)
        parser = Parser.new(body)
        response = parser.parse
        Response.new(response[:success], response[:message], response,
          :test => test?,
          :authorization => response[:authorization],
          :avs_result => response[:avsresponse],
          :cvv_result => response[:cvv_result],
          :order_id => response[:order_id],
          :raw_response => response[:raw_response]
        )
      end

      def commit(document)
        url = (test? ? self.test_url : self.live_url)
        data = ssl_post(url, document.to_xml)
        parse(data)
      end

      class Parser
        def initialize(response)
          @response = response
        end

        def parse
          require 'iconv' unless String.method_defined?(:encode)
          if String.method_defined?(:encode)
            doc = REXML::Document.new(@response.encode("UTF-8", "ISO-8859-1"))
          else
            ic = Iconv.new('UTF-8', 'ISO-8859-1')
            doc = REXML::Document.new(ic.iconv(@response))
          end

          auth_type = find(doc, "//Transaction/Type").to_s

          message = find(doc, "//Message/Text")
          if message.blank?
            message = find(doc, "//Transaction/CardProcResp/CcReturnMsg")
          end

          case auth_type
          when 'Credit', 'Void'
            success = find(doc, "//CcReturnMsg") == "Approved."
          else
            success = find(doc, "//Transaction/AuthCode").present?
          end

          {
            :success => success,
            :message => message,
            :transaction_id => find(doc, "//Transaction/Id"),
            :avs_result => find(doc, "//Transaction/AvsRespCode"),
            :cvv_result => find(doc, "//Transaction/Cvv2Resp"),
            :authorization => find(doc, "//OrderFormDoc/Id"),
            :raw_response => @response
          }
        end

        def find(doc, xpath)
          REXML::XPath.first(doc, xpath).try(:text)
        end
      end

      class Document
        attr_reader :type, :xml

        PAYMENT_INTERVALS = {
          :days => 'D',
          :months => 'M'
        }

        EPDQ_CARD_TYPES = {
          :visa => 1,
          :master => 2,
          :switch => 9,
          :maestro => 10,
        }

        def initialize(gateway, options = {}, document_options = {}, &block)
          @gateway = gateway
          @options = options
          @document_options = document_options
          @xml = Builder::XmlMarkup.new(:indent => 2)
          build(&block)
        end

        def to_xml
          @xml.target!
        end

        def build(&block)
          xml.instruct!(:xml, :version => '1.0')
          xml.EngineDocList do
            xml.DocVersion "1.0"
            xml.EngineDoc do
              xml.ContentType "OrderFormDoc"
              xml.User do
                xml.Name(@options[:login])
                xml.Password(@options[:password])
                xml.ClientId({ :DataType => "S32" }, @options[:client_id])
              end
              xml.Instructions do
                if @document_options[:no_fraud]
                  xml.Pipeline "PaymentNoFraud"
                else
                  xml.Pipeline "Payment"
                end
              end
              instance_eval(&block)
            end
          end
        end

        def add_order_form(order_id=nil, group_id=nil, &block)
          xml.OrderFormDoc do
            xml.Mode 'P'
            xml.Id(order_id) if order_id
            xml.GroupId(group_id) if group_id
            instance_eval(&block)
          end
        end

        def add_consumer(options=nil, &block)
          xml.Consumer do
            if options
              xml.Email(options[:email]) if options[:email]
              billing_address = options[:billing_address] || options[:address]
              if billing_address
                xml.BillTo do
                  xml.Location do
                    xml.Address do
                      xml.Street1 billing_address[:address1]
                      xml.Street2 billing_address[:address2]
                      xml.City billing_address[:city]
                      xml.StateProv billing_address[:state]
                      xml.PostalCode billing_address[:zip]
                      xml.Country billing_address[:country_code]
                    end
                  end
                end
              end
            end
            instance_eval(&block)
          end
        end

        def add_creditcard(creditcard)
          xml.PaymentMech do
            xml.CreditCard do
              xml.Type({ :DataType => 'S32' }, EPDQ_CARD_TYPES[creditcard.brand.to_sym])
              xml.Number creditcard.number
              xml.Expires({ :DataType => 'ExpirationDate', :Locale => 826 }, format_expiry_date(creditcard))
              if creditcard.verification_value.present?
                xml.Cvv2Indicator 1
                xml.Cvv2Val creditcard.verification_value
              else
                xml.Cvv2Indicator 5
              end
              xml.IssueNum(creditcard.issue_number) if creditcard.issue_number.present?
            end
          end
        end

        def add_transaction(auth_type, amount = nil, options = {})
          @auth_type = auth_type
          xml.Transaction do
            xml.Type @auth_type.to_s
            if options[:payment_number] && options[:payment_number] > 1
              xml.CardholderPresentCode({ :DataType => 'S32' }, 8)
            else
              xml.CardholderPresentCode({ :DataType => 'S32' }, 7)
            end
            if options[:payment_number]
              xml.PaymentNumber({ :DataType => 'S32' }, options[:payment_number])
            end
            if options[:total_payments]
              xml.TotalNumberPayments({ :DataType => 'S32' }, options[:total_payments])
            end
            if amount
              xml.CurrentTotals do
                xml.Totals do
                  xml.Total({ :DataType => 'Money', :Currency => 826 }, amount)
                end
              end
            end
          end
        end

        # date must be formatted MM/YY
        def format_expiry_date(creditcard)
          month_str = "%02d" % creditcard.month
          if match = creditcard.year.to_s.match(/^\d{2}(\d{2})$/)
            year_str = "%02d" % match[1].to_i
          else
            year_str = "%02d" % creditcard.year
          end
          "#{month_str}/#{year_str}"
        end
      end
    end
  end
end

