require "net/http"
require "uri"
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Veritrans
        class TokenRequest
          include ActiveMerchant::PostsData
          attr_reader :browser, :merchant, :errors
          def initialize _fields, _commodities
            @fields = _fields
            @commodities = _commodities
          end
          
          def commit
            main_params = post_data.to_query
            commodity_params = @commodities.collect{|commodity| _pd = PostData.new ; commodity.each{|key, value| _pd[key] = value} ; _pd.to_query }.join("&")
            uri           = URI.parse(Veritrans.token_url)
            http          = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl  = true
            request       = Net::HTTP::Post.new(uri.request_uri)
            request.body  = "#{main_params}&#{commodity_params}&REPEAT_LINE=#{@commodities.count}"
            response      = http.request(request)
            @response     = response.body

            build_response
            return self
          end

          def build_response
            success_response = @response.match /TOKEN_MERCHANT=(?<merchant>.*)\nTOKEN_BROWSER=(?<browser>.*)/i
            error_response  = @response.match /ERROR_MESSAGE=(?<errors>.*)/
            if success_response
              @browser  = success_response[:browser]
              @merchant = success_response[:merchant]
            end
            if error_response
              @errors   = error_response[:errors]
              raise StandardError.new @errors
            end
          end

          def post_data
            @post_data ||= build_post_data
          end

          private
          def build_post_data 
            _pd = PostData.new
            @fields.each{|key, value| _pd[key] = key =~ /PHONE/ ? sanitize_phone(value) : key =~ /ADDRESS/ ?  sanitize_address(value) : value }
            _pd
          end

          def sanitize_phone _phone
            _phone.strip.gsub(/\D/, '')
          end

          def sanitize_address _address
            _address.gsub(/\,/, '').strip.first(30)
          end

        end
      end
    end
  end
end
