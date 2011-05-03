require 'rexml/document'
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # Eurobank ProxyPay integration.
    #
    # Ported from https://github.com/akDeveloper/Aktive-Merchant
    #
    # @author : Nikos Dimitrakopoulos
    # @copyright : Fraudpointer.com
    class EurobankGateway < Gateway
      TEST_URL = 'https://eptest.eurocommerce.gr/proxypay/apacsonline'
      LIVE_URL = 'https://ep.eurocommerce.gr/proxypay/apacsonline'
      
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['GR']
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      
      # The homepage URL of the gateway
      self.homepage_url = 'http://www.eurobank.gr/online/home/generic.aspx?id=79&mid=635'
      
      # The name of the gateway
      self.display_name = 'Eurobank Euro-Commerce'

      # The money format of the gateway
      self.money_format = :cents

      # The default currency of the gateway
      self.default_currency = 'EUR'

      ACTIONS = {
        :authorize => "PreAuth",
        :capture   => "Capture",
        :credit    => "Refund",
        :void      => "Cancel"
      }

      CURRENCY_MAPPINGS = {
        'USD' => 840,
        'GRD' => 300,
        'EUR' => 978
      }

      ERROR_CODE_DESCRIPTIONS = {
        '0' => 'Transaction completed successfully',
        '30' => 'Payment Failed',
        '40' => 'Data received from server but details could not be parsed from XML message',
        '50' => 'Malformed XML message, JProxyPayLink element missing',
        '51' => 'Malformed XML message, message element missing',
        '52' => 'Malformed XML message, type element missing',
        '53' => 'Error in XML parsing',
        '54' => 'Malformed XML message, OrderInfo element missing',
        '55' => 'Malformed XML message, amount element missing',
        '56' => 'Malformed XML message, merchantRef element missing',
        '57' => 'Malformed XML message, merchantDesc element missing',
        '58' => 'Malformed XML message, Currency element missing',
        '59' => 'Malformed XML message, CustomerEmail element missing',
        '60' => 'Malformed XML message, Var1 element missing',
        '61' => 'Malformed XML message, Var2 element missing',
        '62' => 'Malformed XML message, Var3 element missing',
        '63' => 'Malformed XML message, Var4 element missing',
        '64' => 'Malformed XML message, Var5 element missing',
        '65' => 'Malformed XML message, Var6 element missing',
        '66' => 'Malformed XML message, Var7 element missing',
        '67' => 'Malformed XML message, Var8 element missing',
        '68' => 'Malformed XML message, Var9 element missing',
        '69' => 'Malformed XML message, PaymentInfo element missing',
        '70' => 'Malformed XML message, CreditCard Number element missing',
        '71' => 'Malformed XML message, Expiry Date element missing',
        '72' => 'Malformed XML message, CVCCVV element missing',
        '73' => 'Malformed XML message, InstallmentOffset element missing',
        '74' => 'Malformed XML message, InstallmentPeriod element missing',
        '75' => 'Malformed XML message, Amount Invalid contents',
        '76' => 'Malformed XML message, CCN Invalid Length',
        '77' => 'Malformed XML message, CCN Invalid Contents',
        '78' => 'Malformed XML message, Expiry Date Invalid Length',
        '79' => 'Malformed XML message, Expiry Date Invalid Contents',
        '80' => 'Malformed XML message, element missing authentication',
        '81' => 'Malformed XML message, element missing merchant id',
        '82' => 'Malformed XML message, CVCCVV / Currency Invalid length',
        '83' => 'Malformed XML message, CVCCVV / Currency Invalid Contents',
        '84' => 'Malformed XML message, Invalid Instalment Period',
        '85' => 'Malformed XML message, Invalid Offset Period',
        '86' => 'Malformed XML message, Invalid Instalment/Offset Combo',
        '100' => 'Unknown merchant',
        '101' => 'Password not matching',
        '102' => 'Sequence number not in sync',
        '500' => 'Malformed XML message, merchantid elementmissing',
        '501' => 'Malformed XML message, password element missing',
        '502' => 'Malformed XML message, sequence number elementmissing',
        '503' => 'Malformed XML message, type element missing',
        '504' => 'Malformed XML message, reference element missing',
        '505' => 'Malformed XML message, amount element missing',
        '506' => 'Malformed XML message, currency element missing',
        '550' => 'Malformed XML message, syntax error',
        '1000' => 'No connection could be made with server',
        '1001' => 'Transaction with this reference not known',
        '1002' => 'Amount requested does not match amount in database',
        '1003' => 'Currency requested does not match currency in DB',
        '1004' => 'Invalid Amount',
        '1005' => 'Invalid Transaction State',
        '1100' => 'To many attempts, online transaction interface has been shut down for this merchant',
        '2000' => 'Transaction rejected by host (with errorcode 0-999). Errorcode – 2000 = host-errorcode',
        '10000' => 'Unspecified failure, contact bank',
      }

      # Creates a new +EurobankGateway+
      #
      # The gateway requires that a valid login, password, and name be passed
      # in the +options+ hash.
      #
      # ==== Parameters
      #
      # * <tt>options</tt>
      #   * <tt>:login</tt> - The merchant id.
      #   * <tt>:password</tt> - The encrypted password.
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end

      # Authorize a credit card for a given amount.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> - The amount to be authorized as an Integer value in cents.
      # * <tt>credit_card</tt> - The CreditCard details for the transaction.
      # * <tt>options</tt>
      #   * <tt>:order_id</tt> - A unique reference for this order (required).
      #   * <tt>:email</tt> - The customer email (optional).
      #   * <tt>:description</tt> - A description for this order (optional).
      #   * <tt>:variables</tt> - An +Array+ of additional data that will be sent to the getaway in 'VarX' elements. Maximum length of +Array+ is 9.
      def authorize(money, creditcard, options = {})
        requires!(options, :order_id)
        commit(:authorize, {:money => money,
                          :creditcard => creditcard}.merge!(options))
      end

      # Capture a previously authorized amount.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> - The amount that was previously authorized.
      # * <tt>authorization</tt> - The original order_id that was given to the authorization request.
      # * <tt>options</tt>
      def capture(money, authorization, options = {})
        commit(:capture, {:money => money,
                          :order_id => authorization}.merge!(options))
      end

      # Credit/Refund an amount.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> - The amount of the transaction.
      # * <tt>identification</tt> -
      # * <tt>options</tt>
      def credit(money, identification, options = {})
        commit(:credit, {:money => money,
                         :order_id => identification}.merge!(options))
      end

      # Cancel/Void a transaction.
      #
      # ==== Parameters
      #
      # * <tt>identification</tt> - The original order_id that was given to the authorization request.
      # * <tt>options</tt>
      def void(identification, options = {})
        commit(:void, {:money => 0, :order_id => identification}.merge!(options))
      end

      #######
      private
      #######

      def commit(action, parameters)
        response = parse(ssl_post(test? ? TEST_URL : LIVE_URL, 'APACScommand=NewRequest&Data=' + build_xml(action, parameters)))
        Response.new(success?(response),
                     message_from(response),
                     response,
                     :authorization => authorization_from(response),
                     :test => test?)
      end

      def success?(response)
        response[:errorcode] == "0"
      end

      def message_from(response)
        response[:errormessage] || ERROR_CODE_DESCRIPTIONS[response[:errorcode]]
      end

      def authorization_from(response)
        response[:reference]
      end

      def build_xml(action, parameters)
        xml = <<XML
<?xml version="1.0" encoding="UTF-8"?>
  <JProxyPayLink>
    <Message>
      <Type>#{ACTIONS[action]}</Type>
      <Authentication>
        <MerchantID>#{@options[:login]}</MerchantID>
        <Password>#{@options[:password]}</Password>
      </Authentication>
      <OrderInfo>
        <Amount>#{amount(parameters[:money])}</Amount>
        <MerchantRef>#{parameters[:order_id]}</MerchantRef>
        <MerchantDesc>#{parameters[:description]}</MerchantDesc>
        <Currency>#{CURRENCY_MAPPINGS[currency(parameters[:money])]}</Currency>
        <CustomerEmail>#{parameters[:email]}</CustomerEmail>
XML

        parameters[:variables] ||= []
        parameters[:variables].each_with_index do |v, i|
          xml << <<XML
        <Var#{i+1}>#{v}</Var#{i+1}>
XML
        end

        for i in (parameters[:variables].length + 1)..9
          xml << <<XML
        <Var#{i} />
XML
        end

        xml << <<XML
      </OrderInfo>
XML
        if parameters[:creditcard]
          xml << <<XML
      <PaymentInfo>
        <CCN>#{parameters[:creditcard].number}</CCN>
        <Expdate>#{format(parameters[:creditcard].month, :two_digits)}#{format(parameters[:creditcard].year, :two_digits)}</Expdate>
        <CVCCVV>#{parameters[:creditcard].verification_value}</CVCCVV>
        <InstallmentOffset>0</InstallmentOffset>
        <InstallmentPeriod>0</InstallmentPeriod>
      </PaymentInfo>
XML
        end

        xml << <<XML
    </Message>
  </JProxyPayLink>
XML

        puts xml

        xml
      end

      def parse(xml)
        response = {}
        xml = REXML::Document.new(xml)
        xml.root.elements.each do |node|
          response[node.name.underscore.to_sym] = node.text
        end unless xml.root.nil?
        response
      end
    end
  end
end

