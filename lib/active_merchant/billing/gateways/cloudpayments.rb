module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CloudpaymentsGateway < Gateway

      self.live_url             = 'https://api.cloudpayments.ru/'
      self.default_currency     = 'RUB'
      self.supported_countries  = ['RU']
      self.homepage_url         = 'http://cloudpayments.ru/'
      self.display_name         = 'CloudPayments'
      self.supported_cardtypes  = [:visa, :master, :american_express, :diners_club, :jcb]


      def initialize(options = {})
        requires!(options, :public_id, :api_secret)
        super
      end

      def authorize_with_token(token, amount, options={})
        options.merge!(:Token => token, :Amount => amount)
        commit("payments/tokens/auth", options)
      end

      def authorize_with_cryptogram(cryptogram, amount, options={})
        options.merge!(:CardCryptogramPacket => cryptogram, :Amount => amount)
        commit("payments/cards/auth", options)
      end

      def charge_with_token(token, amount, options={})
        options.merge!(:Token => token, :Amount => amount)
        commit("payments/tokens/charge", options)
      end

      def charge_with_cryptogram(cryptogram, amount, options={})
        options.merge!(:CardCryptogramPacket => cryptogram, :Amount => amount)
        commit("payments/cards/charge", options)
      end

      def confirm(amount, transaction_id)
        commit("payments/confirm", {:TransactionId => transaction_id, :Amount => amount})
      end

      def refund(amount, transaction_id)
        commit('payments/refund', {:TransactionId => transaction_id, :Amount => amount})
      end

      def void(transaction_id)
        commit('payments/void', {:TrasactionId => transaction_id})
      end

      def subscribe(token, amount, options={})
        options.merge!(:Token => token, :Amount => amount)
        commit('subscriptions/create', options)
      end

      def cancel_subscription(subscription_id)
        commit('subscriptions/cancel', {:Id => subscription_id})
      end

      private

      def commit(path, parameters)
        parameters = parameters.present? ? parameters.to_query : nil
        response = parse(ssl_post(live_url + path, parameters, headers) )

        auth  = if success?(response)
                  response['Model'].present? ? response['Model']['Token'] : {}
                else
                  response['Model'].present? ? response['Model']['Reason'] || response['Model']['PaReq'] : {}
                end
        Response.new(
          success?(response),
          response['Message'],
          response['Model'],
          :authorization => auth,
          test: test?
        )
      end

      def success?(response)
        response['Success']
      end

      def parse(body)
        JSON.parse(body)
      end

      def message_from(message)
        return 'Unspecified error' if message.blank?
        message.gsub(/[^\w]/, ' ').split.join(" ").capitalize
      end

      def headers
        {
          "Authorization" => "Basic " + Base64.encode64("#{options[:public_id]}:#{options[:api_secret]}"),
          "Content-Type" => 'application/json'
        }
      end

    end
  end
end
