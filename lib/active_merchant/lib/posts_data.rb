module ActiveMerchant #:nodoc:
  class ConnectionError < ActiveMerchantError
  end
  
  class RetriableConnectionError < ConnectionError
  end
  
  module PostsData  #:nodoc:
    MAX_RETRIES = 3
    OPEN_TIMEOUT = 60
    READ_TIMEOUT = 60
    
    def self.included(base)
      base.superclass_delegating_accessor :ssl_strict
      base.ssl_strict = true
      
      base.class_inheritable_accessor :pem_password
      base.pem_password = false
      
      base.class_inheritable_accessor :retry_safe
      base.retry_safe = false

      base.superclass_delegating_accessor :open_timeout
      base.open_timeout = OPEN_TIMEOUT

      base.superclass_delegating_accessor :read_timeout
      base.read_timeout = READ_TIMEOUT
    end
    
    def ssl_get(url, headers={})
      ssl_request(:get, url, nil, headers)
    end
    
    def ssl_post(url, data, headers = {})
      ssl_request(:post, url, data, headers)
    end
    
    private
    def retry_exceptions
      retries = MAX_RETRIES
      begin
        yield
      rescue RetriableConnectionError => e
        retries -= 1
        retry unless retries.zero?
        raise ConnectionError, e.message
      rescue ConnectionError
        retries -= 1
        retry if retry_safe && !retries.zero?
        raise
      end
    end
    
    def ssl_request(method, url, data, headers = {})
      if method == :post
        # Ruby 1.8.4 doesn't automatically set this header
        headers['Content-Type'] ||= "application/x-www-form-urlencoded"
      end
      
      uri   = URI.parse(url)

      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = self.class.open_timeout
      http.read_timeout = self.class.read_timeout
      
      if uri.scheme == "https"
        http.use_ssl = true
        
        if ssl_strict
          http.verify_mode    = OpenSSL::SSL::VERIFY_PEER
          http.ca_file        = File.dirname(__FILE__) + '/../../certs/cacert.pem'
        else
          http.verify_mode    = OpenSSL::SSL::VERIFY_NONE
        end
      
        if @options && !@options[:pem].blank?
          http.cert           = OpenSSL::X509::Certificate.new(@options[:pem])
        
          if pem_password
            raise ArgumentError, "The private key requires a password" if @options[:pem_password].blank?
            http.key            = OpenSSL::PKey::RSA.new(@options[:pem], @options[:pem_password])
          else
            http.key            = OpenSSL::PKey::RSA.new(@options[:pem])
          end
        end
      end

      retry_exceptions do 
        begin
          case method
          when :get
            http.get(uri.request_uri, headers).body
          when :post
            http.post(uri.request_uri, data, headers).body
          end
        rescue EOFError => e
          raise ConnectionError, "The remote server dropped the connection"
        rescue Errno::ECONNRESET => e
          raise ConnectionError, "The remote server reset the connection"
        rescue Errno::ECONNREFUSED => e
          raise RetriableConnectionError, "The remote server refused the connection"
        rescue Timeout::Error, Errno::ETIMEDOUT => e
          raise ConnectionError, "The connection to the remote server timed out"
        end
      end
    end
    
  end
end