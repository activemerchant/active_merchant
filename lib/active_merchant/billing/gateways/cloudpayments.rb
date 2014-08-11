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
        commit('payments/void', {:TransactionId => transaction_id})
      end

      def subscribe(token, amount, options={})
        options.merge!(:Token => token, :Amount => amount)
        commit('subscriptions/create', options)
      end

      def get_subscription(subscription_id)
        commit('subscriptions/get', {:Id => subscription_id})
      end

      def void_subscription(subscription_id)
        commit('subscriptions/cancel', {:Id => subscription_id})
      end

      def check_3ds(transaction_id, pa_res)
        commit('payments/post3ds', {:TransactionId => transaction_id, :PaRes => pa_res})
      end

      private

      def commit(path, parameters)
        parameters = parameters.present? ? parameters.to_query : nil
        response = parse(ssl_post(live_url + path, parameters, headers) )
        model = response['Model']

        auth  = if success?(response)
                  model.present? ? model['TransactionId'] || model['Id'] : 'success'
                else
                  model.present? ? model['TransactionId'] : 'failure'
                end

        msg = if success?(response)
                'Transaction approved'
              else
                if response['Message'].blank?
                  if model['CardHolderMessage'].present?
                    model['CardHolderMessage']
                  elsif model['Reason'].present?
                    model['Reason']
                  elsif model['PaReq'].present?
                    '3ds needed'
                  end
                else
                  response['Message']
                end
              end

        Response.new(success?(response),
          msg,
          model,
          authorization: auth,
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
          "Authorization" => "Basic " + Base64.strict_encode64("#{options[:public_id]}:#{options[:api_secret]}")
        }
      end

    end
  end
end
