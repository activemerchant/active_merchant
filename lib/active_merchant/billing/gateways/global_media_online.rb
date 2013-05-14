module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class GlobalMediaOnlineGateway < Gateway
      self.live_url = 'https://kt01.mul-pay.jp'
      self.test_url = 'https://kt01.mul-pay.jp'

      self.supported_countries = ['JP']
      self.default_currency = 'JPY'
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :jcb, :diners_club]

      self.homepage_url = 'http://www.gmo-pg.com/'
      self.display_name = 'GMO-PG'

      ENDPOINT = {
        "AUTH"    => self.live_url + '/payment/ExecTran.idPass',
        "CAPTURE" => self.live_url + '/payment/ExecTran.idPass',
        "SALES"   => self.live_url + '/payment/AlterTran.idPass',
        "VOID"    => self.live_url + '/payment/AlterTran.idPass'
      }

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def authorize(money, creditcard, options = {})
        authorize_or_purchase('AUTH', money, creditcard, options)
      end

      def purchase(money, creditcard, options = {})
        authorize_or_purchase('CAPTURE', money, creditcard, options)
      end

      def capture(money, authorization, options = {})
        capture_or_void('SALES', money, authorization, options)
      end

      def void(money, authorization, options = {})
        capture_or_void('VOID', money, authorization, options)
      end

      private

      def authorize_or_purchase(action, money, creditcard, options = {})
        requires!(options, :order_id)

        params = {}
        add_invoice(params, options)
        add_amount(params, money)
        get_authorization(params, action)

        add_creditcard(params, creditcard)
        params["Method"] = 1

        commit(action, money, params)
      end

      def capture_or_void(action, money, authorization, options = {})
        params = {}
        params["Authorization"] = authorization
        add_amount(params, money)

        commit(action, money, params)
      end

      def commit(action, money, params)
        authorization = params["Authorization"]

        parse_authorization(params)

        data = ssl_post( ENDPOINT[action], post_data(action, params) )
        response = parse(data)

        Response.new(success?(response), nil, response, authorization: authorization)
      end

      def add_invoice(params, options)
        params["OrderID"] = options[:order_id]
      end

      def add_amount(params, money)
        params["Amount"] = amount(money)
      end

      def add_creditcard(params, creditcard)
        params["CardNo"] = creditcard.number
        params["Expire"] = expdate(creditcard)
      end

      def parse_authorization(params)
        authorizations = parse(params["Authorization"])
        params.delete("Authorization")
        params.update(authorizations)
      end

      def get_authorization(params, action)
        params["Authorization"] = entry(action, params)
        params
      end

      def entry(action, params)
        endpoint = self.test_url + '/payment/EntryTran.idPass'
        ssl_post(endpoint, post_data(action, params))
      end

#      def add_customer_data(post, options)
#      end

#      def add_address(post, creditcard, options)
#      end

      def parse(body)
        params = {}
        body.split("&").each do |param|
          param = param.split("=")
          params[param[0]] = param[1]
        end
        params
      end

#     def message_from(response)
#     end

      def post_data(action, params = {})
        post = {}

        post["ShopID"]   = @options[:login]
        post["ShopPass"] = @options[:password]
        post["JobCd"]    = action

        request = post.merge(params).map{|key, value| "#{key}=#{value}" }.join("&")
        request
      end

      def expdate(creditcard)
        year, month  = sprintf("%.4i", creditcard.year), sprintf("%.2i", creditcard.month)
        "#{year[-2..-1]}#{month}"
      end

      def success?(response)
        response["ErrCode"].nil?
      end
    end
  end
end

