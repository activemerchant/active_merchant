require 'uri'
require 'net/http'
require 'openssl'
require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Dengionline
        class Status
          
          attr_reader :errors, :service_url, :response
          
          HEADER_ACCOUNT = "X-DOL-Project"
          HEADER_AUTH    = "X-DOL-Sign"
          HMAC_DIGEST    = "sha1"
          SERVICE_URL    = "https://www.onlinedengi.ru/api/dol/payment/get/"
          
          def initialize(order, account, options = {})
            @errors = []
            @response_hash = {}
            
            @account = account.to_s
            
            @service_url = options[:service_url] || SERVICE_URL
            
            @secret = options[:secret].to_s
            payment = options[:payment]
            
            @request_params = {}
            @request_params[:payment] = payment.to_s if payment
            @request_params[:order]   = order.to_s   if order
            
            send_request
          end
          
          def request_success?
            @request_success
          end
          
          def request_fail?
            not @request_success
          end
          
          def to_hash
            @response_hash
          end
          
          private
          
          def send_request
            @request_success = false
            
            if @request_params.size == 0
              @errors << "order_or_payment"
            elsif @secret.empty?
              @errors << "secret"
            elsif @account.empty?
              @errors << "account"
            else
              data = @request_params.to_json
              auth_hash = OpenSSL::HMAC.hexdigest(HMAC_DIGEST, @secret, data)
              
              url = URI.parse(service_url)
              http = Net::HTTP.new(url.hostname, url.port)
              
              http.use_ssl = true
              http.verify_mode = OpenSSL::SSL::VERIFY_NONE
              
              headers = {}
              headers[HEADER_ACCOUNT] = @account
              headers[HEADER_AUTH] = auth_hash
              
              r = http.post(url.path, data, headers)
              case r
              when Net::HTTPOK
                @response = r.body
                parse(@response)
                @request_success = true
              else
                @response = r.body
                @errors << "request_fail"
              end
            end
          end
          
          def parse(json)
            j = nil
            begin
              j = JSON.parse(json)
            rescue
              @errors << "parse_error"
            end
            
            if j and j.is_a? Array and j[0].is_a? Hash
              @response_hash = j[0]
            end
          end
          
          def method_missing(method_id, *args)
            @response_hash[method_id.to_s]
          end
          
        end
      end
    end
  end
end
