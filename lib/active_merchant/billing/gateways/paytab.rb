module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaytabGateway < Gateway

      self.test_url = 'https://www.paytabs.com/apiv2/'                   # Test url if any
      self.live_url = 'https://www.paytabs.com/apiv2/'                   # Live api url
      self.supported_countries = ['US']                               # set country support like 'US''UK' etc
      self.default_currency = 'BHR'                                   # set default current if any
      self.supported_cardtypes = [:visa, :master, :american_express, :discover] # supported cards types
      self.homepage_url = 'https://www.paytabs.com/'                     # Gateway site url
      self.display_name = 'PayTabs'                                    # Gateway Name to be display


      Thread.new{                                                     # Create current execution thread
        Thread.current['result'] = PaytabGateway.new(options)        # store api key
        Thread.current['response'] = PaytabGateway.new(options)       # store all api call response
      }

      def initialize(options)                                         # set merchant id and password to access
       requires!(options, :secret_key, :merchant_email)           # make required merchant id and password
               @merchant_id = options[:merchant_id]
               @merchant_password = options[:merchant_password]
               @secret_key = options[:secret_key]
               @merchant_email = options[:merchant_email]

       super
      end

      def purchase(money, options)                                    # main api call
        Authentication()                                              # generate api key
        requires!(options, :cc_first_name, :cc_last_name,:cc_phone_number,:products_per_title ,:unit_price,:phone_number,:other_charges,:quantity, :billing_address, :city, :state, :postal_code, :country,
                    :email,:amount,:discount,:reference_no,:currency,:title,:ip_customer,:ip_merchant,:return_url,:postal_code,:shipping_first_name,:shipping_last_name,:address_shipping,:city_shipping,
                    :state_shipping,:postal_code_shipping,:country_shipping,:msg_lang,:cms_with_version)
        if Thread.current['result'] != "invalid"                        # check api key is null or not
      #    options[:secret_key] = Thread.current['api_key']               # set param api key
          commit('create_pay_page', options)                          # call create pay page and return response to controller
        else
           Thread.current['response']                                 # return the result
        end
      end

      #def redirect_to_pay(options)
       # options
      #end

      def Authentication()                                            # Authentication api call to generate api key
         options[:merchant_email] = @merchant_email                   # set param merchant id
         options[:secret_key] = @secret_key                           # set param merchant password
         response = commit("validate_secret_key",options)                  # Make api call
         Thread.current['response'] = response                        # store api response
         if response["result"].to_s == 'valid'                      # check access either granted or denied
           Thread.current['result'] = response["result"].to_s       # store api key value
         else
           Thread.current['result'] = "invalid"                         # set api key = null when access denied
         end
      end

      def Verify_Payment(options)                                     # Verify payment

        if Thread.current['result'] != "invalid"                        # check if api key is null
              response = commit('verify_payment', options)            # verify payment call
              Thread.current['response'] = response
            #  Logout()                                                # logout session
              return Thread.current['response']                                         # return the final response to Application
        else
              Authentication()                                        # if key is null then go for new api key
              response = commit('verify_payment', options)            # verify payment
              Thread.current['response'] = response
              Logout()                                                # Logout session
              return Thread.current['response']
        end

      end

      def authorize(money, payment, options={})                       # not in use
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('authonly', post)
      end

      def capture(money, authorization, options={})                   # not in use
        commit('capture', post)
      end

      def refund(money, authorization, options={})                    # not in use
        commit('refund', post)
      end

      def void(authorization, options={})
        commit('void', post)
      end

      def verify(credit_card, options={})                             # not in use
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      private

      def add_customer_data(post, options)                            # not in use
      end

      def add_address(post, creditcard, options)                      # not in use
      end

      def add_invoice(post, money, options)                           # not in use
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_payment(post, payment)                                  # not in use
      end

      def parse(response)                                             # To parse the api response
          JSON.parse(response)
      end

      def commit(action, parameters)                                  # To make api calling and get response
        url = self.live_url + action                                  # set url for api calling
        data = post_data(action,parameters)                           # set all the params
        response = parse(ssl_post(url, data))                         # make an api call and get response
      end

      def success_from(response)                                      # not in use
      end

      def message_from(response)                                      # not in use
      end

      def authorization_from(response)                                # not in use
      end

      def post_data(action, parameters = {})                          # Post_data to arrange params in query form
        parameters.to_query
      end

    end
  end
end
