module ActiveMerchant #:nodoc:
  module PostsData  #:nodoc:
    
    def included?(base)
      base.class_eval do
        attr_accessor :ssl_strict
      end
    end
      
    def ssl_post(url, data, headers = {})
      uri   = URI.parse(url)

      http = Net::HTTP.new(uri.host, uri.port) 

      http.verify_mode    = OpenSSL::SSL::VERIFY_NONE unless @ssl_strict
      http.use_ssl        = true

      http.post(uri.path, data, headers).body      
    end    
  end
end
