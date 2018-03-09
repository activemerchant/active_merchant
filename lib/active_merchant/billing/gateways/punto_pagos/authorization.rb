module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module PuntoPagos #:nodoc:
      class Authorization
        def initialize(params)
          @key = params[:key]
          @secret = params[:secret]
          raise ArgumentError.new("Invalid key") if @key.blank?
          raise ArgumentError.new("Invalid secret") if @secret.blank?
        end

        def sign(*message)
          digest = OpenSSL::HMAC.digest('sha1', @secret, message.join("\n"))
          encoded_string = Base64.encode64(digest).chomp
          "PP " + @key + ":" + encoded_string
        end
      end
    end
  end
end
