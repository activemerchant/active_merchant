module ActiveMerchant #:nodoc:
  module PostsData  #:nodoc:

    def self.included(base)
      base.superclass_delegating_accessor :ssl_strict
      base.ssl_strict = true
      
      base.class_inheritable_accessor :retry_safe
      base.retry_safe = false

      base.superclass_delegating_accessor :open_timeout
      base.open_timeout = 60

      base.superclass_delegating_accessor :read_timeout
      base.read_timeout = 60
      
      base.superclass_delegating_accessor :logger
      base.superclass_delegating_accessor :wiredump_device
    end
    
    def ssl_get(endpoint, headers={})
      ssl_request(:get, endpoint, nil, headers)
    end
    
    def ssl_post(endpoint, data, headers = {})
      ssl_request(:post, endpoint, data, headers)
    end

    def ssl_request(method, endpoint, data, headers)
      handle_response(raw_ssl_request(method, endpoint, data, headers))
    end

    def raw_ssl_request(method, endpoint, data, headers = {})
      connection = Connection.new(endpoint)
      connection.open_timeout = open_timeout
      connection.read_timeout = read_timeout
      connection.retry_safe   = retry_safe
      connection.verify_peer  = ssl_strict
      connection.logger       = logger
      connection.tag          = self.class.name
      connection.wiredump_device = wiredump_device
      
      connection.pem          = @options[:pem] if @options
      connection.pem_password = @options[:pem_password] if @options
      
      connection.request(method, data, headers)
    end

    private

    def handle_response(response)
      case response.code.to_i
      when 200...300
        response.body
      else
        raise ResponseError.new(response)
      end
    end
    
  end
end
