require 'uri'
require 'net/http'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Dengionline
        class BackgroundResponse
          
          include Common
          
          attr_reader :response, :status, :comment, :request, :payment_id, :data_for_user, :iframe_url, :errors
          
          def initialize(params, options = {})
            case params
            when Hash
              @data = params.to_query
            when String
              @data = params
            end
            
            @options = options
            @errors  = []
            
            self.service_url  = options[:service_url]
            self.pay_method   = options[:method]
            self.background   = :background
            
            send_request if background?
          end
          
          def request_success?
            @request_success
          end
          
          def request_fail?
            not @request_success
          end
          
          def success?
            @status == "success"
          end
          
          def fail?
            @status == "fail"
          end
          
          private
          
          def send_request
            url = URI.parse(service_url)
            http = Net::HTTP.new(url.hostname, url.port)
            r = http.post(url.path, @data)
            case r
            when Net::HTTPOK
              @request_success == true
              begin
                parse(r.body)
              rescue
                @errors << "parse error"
              end
            else
              @errors << "http request fail"
            end
          end
          
          def parse (xml)
            r = Hash.from_xml(xml)["response"]
            @response = r
            @status = r["status"] == "0" ? "success" : "fail"
            @comment = r["comment"]
            @request = r["request"]
            
            if success?
              if qiwi?
                url = Base64.decode64(r["iframeSRC"]) if r["iframeSRC"]
                @iframe_url = URI.parse(url) if url
                @payment_id = r["ODpaymentID"]
              elsif mobile? or alfaclick?
                @payment_id = r["ODpaymentID"]
              elsif remittance?
                d = r["ODpaymentData"]["DataForUser"] if r["ODpaymentData"].is_a? Hash
                case d
                when Hash
                  @data_for_user = [d]
                when Array
                  @data_for_user = d
                end
              elsif credit_card?
                p = r.dup
                p.delete("status")
                url = p.delete("iframeUrl")
                @iframe_url = URI.parse(url)
                @iframe_url.query = p.to_query
              end
            end
          end
          
        end
      end
    end
  end
end
