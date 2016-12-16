module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class RecurlyGateway < Gateway
      include Empty

      API_VERSION = '2.4'.freeze

      self.default_currency = 'USD'
      self.money_format = :cents
      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]
      self.homepage_url = 'https://recurly.com/'
      self.display_name = 'Recurly'

      def initialize(options = {})
        requires!(options, :subdomain, :api_key, :public_key)
        super
      end

      def purchase(amount, payment_method, options={})
        post = {}
        add_amount(post, amount, options)
        add_payment_method(post, payment_method, options)
        add_customer_data(post, options)
        type = subscription?(options) ? 'subscriptions' : 'transactions'
        commit(type, post)
      end

      def verify_credentials
        response = void("0")
        response.message != "Authentication Failed"
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((password=)\w+), '\1[FILTERED]').
          gsub(%r((number=)\d+), '\1[FILTERED]').
          gsub(%r((cvv=)\d+), '\1[FILTERED]').
          gsub(%r((verification_value=)\d+), '\1[FILTERED]')
      end

      private

      def add_amount(post, money, options)
        if subscription?(options)
          post[:plan_code] = options[:plan_code]
        else
          post[:amount_in_cents] = amount(money) unless subscription?(options)
        end
        post[:currency] = options[:currency] || currency(money)
      end

      def add_customer_data(post, options)
        %i(account_code first_name last_name email).each do |option|
          post[:account][option] = options[option] if options[option].present?
        end
        if(billing_address = options[:billing_address] || options[:address])
          post[:account][:billing_info].merge!(billing_address)
          post[:account][:billing_info][:phone] = options[:phone] if options[:phone].present?
        end
        if(shipping_address = options[:shipping_address])
          post[:shipping_address] = billing_address
        end
      end

      def add_payment_method(post, payment_method, options)
        post[:account] = {}
        post[:account][:billing_info] = {}
        post[:description] = options[:description] if options[:description].present?
        if(payment_method.is_a?(String))
          post[:account][:billing_info][:token_id] ||= payment_method
        else
          post[:account][:billing_info][:number] = payment_method.number
          post[:account][:billing_info][:month] = payment_method.month
          post[:account][:billing_info][:year] = payment_method.year
          unless empty?(payment_method.verification_value)
            post[:account][:billing_info][:verification_value] = payment_method.verification_value
          end
        end
      end

      #
      # Adds tags to xml recursive
      #
      def add_tag_recursive(xml, data)
        data.each do |key, value|
          if data[key].is_a?(Hash)
            xml.tag!(key) do
              add_tag_recursive(xml, data[key])
            end
          else
            xml.tag!(key, value)
          end
        end
      end

      def authorization_from(response)
        response[:uuid]
      end

      def build_xml_request(action, data)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct!
        xml.tag!(action.to_sym) do
          add_tag_recursive(xml, data)
        end
      end

      def commit(endpoint, params = {})
        response = parse(ssl_post(url + endpoint, build_xml_request(endpoint.singularize, params), headers))
        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?
        )
      end

      def headers
        {
          'Authorization' => 'Basic ' + Base64.encode64(@options[:api_key]),
          'Content-Type'  => 'application/xml; charset=utf-8',
          'Accept' => 'application/xml',
          'X-Api-Version' => API_VERSION
        }
      end

      def message_from(response)
        response[:status]
      end

      def parse(body)
        return {} if body.blank?
        xml = REXML::Document.new(body)

        response = {}
        xml.root.elements.to_a.each do |node|
          parse_element(response, node)
        end
        response
      end

      def parse_element(response, node)
        if node.has_attributes?
          node.attributes.each{|name, value| response["#{node.name}_#{name}".underscore.to_sym] = value }
        end

        if node.has_elements?
          node.elements.each{|element| parse_element(response, element) }
        else
          response[node.name.underscore.to_sym] = node.text
        end
      end

      def subscription?(options)
        options[:plan_code].present?
      end

      def success_from(response)
        response[:uuid].present?
      end

      def url
        "https://#{@options[:subdomain]}.recurly.com/v2/"
      end
    end
  end
end
