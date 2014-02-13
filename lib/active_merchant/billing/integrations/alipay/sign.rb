require 'digest/md5'
require 'cgi'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Alipay
        module Sign
          def verify_sign
            sign_type = @params.delete("sign_type")
            sign = @params.delete("sign")

            md5_string = @params.sort.collect do |s|
              unless s[0] == "notify_id"
                s[0]+"="+CGI.unescape(s[1])
              else
                s[0]+"="+s[1]
              end
            end
            Digest::MD5.hexdigest(md5_string.join("&")+KEY) == sign.downcase
          end
        end
      end
    end
  end
end
