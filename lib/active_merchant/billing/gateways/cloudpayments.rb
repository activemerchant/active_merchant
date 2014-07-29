module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CloudpaymentsGateway < Gateway

      self.live_url = 'https://api.cloudpayments.ru'

      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club, :jcb]

      def initialize(options = {})
        requires!(options, :public_id, :api_secret)
        super
      end

      def purchase(money, creditcard, options = {})

      end

      def check

      end

      def purchase_by_token(money, token, options = {})

      end

      private

      def commit(action, parameters)
        parameters = parameters.present? ? parameters.to_query : nil
        response = parse(ssl_request(action, live_url + url, parameters, headers) )
      end

      def success?(response)
        response['Success']
      end

      def parse(body)
        return {} unless body
        JSON.parse(body)
      end

      def message_from(message)
        return 'Unspecified error' if message.blank?
        message.gsub(/[^\w]/, ' ').split.join(" ").capitalize
      end

      def headers
        {
          "Authorization" => "Basic " + Base64.encode64("#{options[:public_id]}:#{options[:api_secret]}"),
        }
      end

    end
  end
end
