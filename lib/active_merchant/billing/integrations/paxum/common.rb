module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Paxum
        module Common
          def generate_signature_string
            @raw_post.slice!(0) if @raw_post.starts_with?("&")
            @raw_post = CGI.unescape(@raw_post)
            @raw_post = "&#{@raw_post}" unless @raw_post.starts_with?("&")
            arr = @raw_post.split('&')
            arr.delete(arr.last)
            data = arr.join('&')

            (data + secret)
          end

          def generate_signature
            Digest::MD5.hexdigest(generate_signature_string)
          end
        end
      end
    end
  end
end
