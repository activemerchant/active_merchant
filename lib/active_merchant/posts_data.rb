module ActiveMerchant #:nodoc:
  module PostsData  #:nodoc:

    def self.included(base)
      base.superclass_delegating_accessor :ssl_strict
      base.ssl_strict = true

      base.superclass_delegating_accessor :ssl_version
      base.ssl_version = nil

      base.class_attribute :retry_safe
      base.retry_safe = false

      base.superclass_delegating_accessor :open_timeout
      base.open_timeout = 60

      base.superclass_delegating_accessor :read_timeout
      base.read_timeout = 60

      base.superclass_delegating_accessor :max_retries
      base.max_retries = Connection::MAX_RETRIES

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
      logger.warn "#{self.class} using ssl_strict=false, which is insecure" if logger unless ssl_strict

      connection = new_connection(endpoint)
      connection.open_timeout = open_timeout
      connection.read_timeout = read_timeout
      connection.retry_safe   = retry_safe
      connection.verify_peer  = ssl_strict
      connection.ssl_version  = ssl_version
      connection.logger       = logger
      connection.max_retries  = max_retries
      connection.tag          = self.class.name
      connection.wiredump_device = wiredump_device

      connection.pem          = @options[:pem] if @options
      connection.pem_password = @options[:pem_password] if @options

      connection.ignore_http_status = @options[:ignore_http_status] if @options

      connection.request(method, data, headers)
    end

    private

    def new_connection(endpoint)
      Connection.new(endpoint)
    end

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
