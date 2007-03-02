module ActiveMerchant #:nodoc:
  module PostsData  #:nodoc:
    def ssl_post(url, data, headers = {})
      uri   = URI.parse(url)

      http = Net::HTTP.new(uri.host, uri.port) 

      http.verify_mode    = OpenSSL::SSL::VERIFY_PEER
      http.ca_file        = File.dirname(__FILE__) + '/../../certs/cacert.pem'
      http.use_ssl        = true
      
      unless @options[:pem].blank?
        http.cert           = OpenSSL::X509::Certificate.new(@options[:pem])
        http.key            = OpenSSL::PKey::RSA.new(@options[:pem])
      end
      
      http.post(uri.path, data, headers).body      
    end    
  end
end
