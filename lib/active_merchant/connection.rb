require 'uri'
require 'net/http'
require 'net/https'
require 'benchmark'

module ActiveMerchant
  class Connection
    using NetHttpSslConnection
    include NetworkConnectionRetries

    MAX_RETRIES = 3
    OPEN_TIMEOUT = 60
    READ_TIMEOUT = 60
    VERIFY_PEER = true
    CA_FILE = File.expand_path('../certs/cacert.pem', File.dirname(__FILE__))
    CA_PATH = nil
    MIN_VERSION = :TLS1_1
    RETRY_SAFE = false
    RUBY_184_POST_HEADERS = { 'Content-Type' => 'application/x-www-form-urlencoded' }

    attr_accessor :endpoint
    attr_accessor :open_timeout
    attr_accessor :read_timeout
    attr_accessor :verify_peer
    attr_accessor :ssl_version
    if Net::HTTP.instance_methods.include?(:min_version=)
      attr_accessor :min_version
      attr_accessor :max_version
    end
    attr_reader :ssl_connection
    attr_accessor :ca_file
    attr_accessor :ca_path
    attr_accessor :pem
    attr_accessor :pem_password
    attr_reader :wiredump_device
    attr_accessor :logger
    attr_accessor :tag
    attr_accessor :ignore_http_status
    attr_accessor :max_retries
    attr_accessor :proxy_address
    attr_accessor :proxy_port

    def initialize(endpoint)
      @endpoint     = endpoint.is_a?(URI) ? endpoint : URI.parse(endpoint)
      @open_timeout = OPEN_TIMEOUT
      @read_timeout = READ_TIMEOUT
      @retry_safe   = RETRY_SAFE
      @verify_peer  = VERIFY_PEER
      @ca_file      = CA_FILE
      @ca_path      = CA_PATH
      @max_retries  = MAX_RETRIES
      @ignore_http_status = false
      @ssl_version = nil
      if Net::HTTP.instance_methods.include?(:min_version=)
        @min_version = MIN_VERSION
        @max_version = nil
      end
      @ssl_connection = {}
      @proxy_address = :ENV
      @proxy_port = nil
    end

    def wiredump_device=(device)
      raise ArgumentError, "can't wiredump to frozen #{device.class}" if device&.frozen?

      @wiredump_device = device
    end

    def request(method, body, headers = {})
      request_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      headers = headers.dup
      headers['connection'] ||= 'close'

      retry_exceptions(max_retries: max_retries, logger: logger, tag: tag) do
        info "connection_http_method=#{method.to_s.upcase} connection_uri=#{endpoint}", tag

        result = nil

        realtime = Benchmark.realtime do
          http.start unless http.started?
          @ssl_connection = http.ssl_connection
          info "connection_ssl_version=#{ssl_connection[:version]} connection_ssl_cipher=#{ssl_connection[:cipher]}", tag

          result =
            case method
            when :get
              raise ArgumentError, 'GET requests do not support a request body' if body

              http.get(endpoint.request_uri, headers)
            when :post
              debug body
              http.post(endpoint.request_uri, body, RUBY_184_POST_HEADERS.merge(headers))
            when :put
              debug body
              http.put(endpoint.request_uri, body, headers)
            when :patch
              debug body
              http.patch(endpoint.request_uri, body, headers)
            when :delete
              # It's kind of ambiguous whether the RFC allows bodies
              # for DELETE requests. But Net::HTTP's delete method
              # very unambiguously does not.
              if body
                debug body
                req = Net::HTTP::Delete.new(endpoint.request_uri, headers)
                req.body = body
                http.request(req)
              else
                http.delete(endpoint.request_uri, headers)
              end
            else
              raise ArgumentError, "Unsupported request method #{method.to_s.upcase}"
            end
        end

        info '--> %d %s (%d %.4fs)' % [result.code, result.message, result.body ? result.body.length : 0, realtime], tag
        debug result.body
        result
      end
    ensure
      info 'connection_request_total_time=%.4fs' % [Process.clock_gettime(Process::CLOCK_MONOTONIC) - request_start], tag
      http.finish if http.started?
    end

    private

    def http
      @http ||= begin
        http = Net::HTTP.new(endpoint.host, endpoint.port, proxy_address, proxy_port)
        configure_debugging(http)
        configure_timeouts(http)
        configure_ssl(http)
        configure_cert(http)
        http
      end
    end

    def configure_debugging(http)
      http.set_debug_output(wiredump_device)
    end

    def configure_timeouts(http)
      http.open_timeout = open_timeout
      http.read_timeout = read_timeout
    end

    def configure_ssl(http)
      return unless endpoint.scheme == 'https'

      http.use_ssl = true
      http.ssl_version = ssl_version if ssl_version
      if http.respond_to?(:min_version=)
        http.min_version = min_version if min_version
        http.max_version = max_version if max_version
      end

      if verify_peer
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.ca_file     = ca_file
        http.ca_path     = ca_path
      else
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
    end

    def configure_cert(http)
      return if pem.blank?

      http.cert = OpenSSL::X509::Certificate.new(pem)

      if pem_password
        http.key = OpenSSL::PKey::RSA.new(pem, pem_password)
      else
        http.key = OpenSSL::PKey::RSA.new(pem)
      end
    end

    def debug(message, tag = nil)
      log(:debug, message, tag)
    end

    def info(message, tag = nil)
      log(:info, message, tag)
    end

    def error(message, tag = nil)
      log(:error, message, tag)
    end

    def log(level, message, tag)
      message = "[#{tag}] #{message}" if tag
      logger&.send(level, message)
    end
  end
end
