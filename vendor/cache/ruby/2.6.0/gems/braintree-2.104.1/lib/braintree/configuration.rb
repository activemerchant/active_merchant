module Braintree
  class Configuration
    API_VERSION = "5" # :nodoc:
    DEFAULT_ENDPOINT = "api" # :nodoc:
    GRAPHQL_API_VERSION = "2018-09-10" # :nodoc:

    READABLE_ATTRIBUTES = [
      :merchant_id,
      :public_key,
      :private_key,
      :client_id,
      :client_secret,
      :access_token,
      :environment
    ]

    NON_REQUIRED_READABLE_ATTRIBUTES = [
      :proxy_address,
      :proxy_port,
      :proxy_user,
      :proxy_pass,
      :ssl_version
    ]

    WRITABLE_ATTRIBUTES = [
      :custom_user_agent,
      :endpoint,
      :http_open_timeout,
      :http_read_timeout,
      :logger,
      :merchant_id,
      :public_key,
      :private_key,
      :environment,
      :proxy_address,
      :proxy_port,
      :proxy_user,
      :proxy_pass,
      :ssl_version
    ]

    class << self
      attr_writer *WRITABLE_ATTRIBUTES
      attr_reader *NON_REQUIRED_READABLE_ATTRIBUTES
    end
    attr_reader *READABLE_ATTRIBUTES
    attr_reader *NON_REQUIRED_READABLE_ATTRIBUTES
    attr_writer *WRITABLE_ATTRIBUTES

    def self.expectant_reader(*attributes) # :nodoc:
      attributes.each do |attribute|
        (class << self; self; end).send(:define_method, attribute) do
          attribute_value = instance_variable_get("@#{attribute}")
          raise ConfigurationError.new("Braintree::Configuration.#{attribute.to_s} needs to be set") if attribute_value.nil? || attribute_value.to_s.empty?
          attribute_value
        end
      end
    end
    expectant_reader *READABLE_ATTRIBUTES

    # Sets the Braintree environment to use. Valid values are <tt>:sandbox</tt> and <tt>:production</tt>
    def self.environment=(env)
      env = env.to_sym
      unless [:development, :qa, :sandbox, :production].include?(env)
        raise ArgumentError, "#{env.inspect} is not a valid environment"
      end
      @environment = env
    end

    def self.gateway # :nodoc:
      Braintree::Gateway.new(instantiate)
    end

    def self.instantiate # :nodoc:
      config = new(
        :custom_user_agent => @custom_user_agent,
        :endpoint => @endpoint,
        :environment => environment,
        :http_open_timeout => http_open_timeout,
        :http_read_timeout => http_read_timeout,
        :logger => logger,
        :merchant_id => merchant_id,
        :private_key => private_key,
        :public_key => public_key,
        :proxy_address => proxy_address,
        :proxy_port => proxy_port,
        :proxy_user => proxy_user,
        :proxy_pass => proxy_pass,
        :ssl_version => ssl_version
      )
    end

    def self.http_open_timeout
      @http_open_timeout ||= 60
    end

    def self.http_read_timeout
      @http_read_timeout ||= 60
    end

    def self.logger
      @logger ||= _default_logger
    end

    def self.signature_service
      instantiate.signature_service
    end

    def self.sha256_signature_service
      instantiate.sha256_signature_service
    end

    def initialize(options = {})
      WRITABLE_ATTRIBUTES.each do |attr|
        instance_variable_set "@#{attr}", options[attr]
      end

      @environment = @environment.to_sym if @environment

      _check_for_mixed_credentials(options)

      parser = Braintree::CredentialsParser.new
      if options[:client_id] || options[:client_secret]
        parser.parse_client_credentials(options[:client_id], options[:client_secret])
        @client_id = parser.client_id
        @client_secret = parser.client_secret
        @environment = parser.environment
      elsif options[:access_token]
        parser.parse_access_token(options[:access_token])

        _check_for_mixed_environment(options[:environment], parser.environment)

        @access_token = parser.access_token
        @environment = parser.environment
        @merchant_id = parser.merchant_id
      else
        @merchant_id = options[:merchant_id] || options[:partner_id]
      end
    end

    def _check_for_mixed_credentials(options)
      if (options[:client_id] || options[:client_secret]) && (options[:public_key] || options[:private_key])
        raise ConfigurationError.new("Braintree::Gateway cannot be initialized with mixed credential types: client_id and client_secret mixed with public_key and private_key.")
      end

      if (options[:client_id] || options[:client_secret]) && (options[:access_token])
        raise ConfigurationError.new("Braintree::Gateway cannot be initialized with mixed credential types: client_id and client_secret mixed with access_token.")
      end

      if (options[:public_key] || options[:private_key]) && (options[:access_token])
        raise ConfigurationError.new("Braintree::Gateway cannot be initialized with mixed credential types: public_key and private_key mixed with access_token.")
      end
    end

    def _check_for_mixed_environment(options_environment, token_environment)
      if options_environment && options_environment.to_sym != token_environment.to_sym
        warn "Braintree::Gateway should not be initialized with mixed environments: environment parameter and access_token do not match, environment from access_token is used."
      end
    end

    def api_version # :nodoc:
      API_VERSION
    end

    def graphql_api_version # :nodoc:
      GRAPHQL_API_VERSION
    end

    def base_merchant_path # :nodoc:
      "/merchants/#{merchant_id}"
    end

    def base_url
      "#{protocol}://#{server}:#{port}"
    end

    def graphql_base_url
      "#{protocol}://#{graphql_server}:#{graphql_port}/graphql"
    end

    def base_merchant_url # :nodoc:
      "#{base_url}#{base_merchant_path}"
    end

    def ca_file # :nodoc:
      File.expand_path(File.join(File.dirname(__FILE__), "..", "ssl", "api_braintreegateway_com.ca.crt"))
    end

    def endpoint
      @endpoint || DEFAULT_ENDPOINT
    end

    def http # :nodoc:
      Http.new(self)
    end

    def graphql_client
      GraphQLClient.new(self)
    end

    def logger
      @logger ||= self.class._default_logger
    end

    def port # :nodoc:
      case @environment
      when :development, :integration
        ENV['GATEWAY_PORT'] || 3000
      when :production, :qa, :sandbox
        443
      end
    end

    def graphql_port # :nodoc:
      case @environment
      when :development, :integration
        ENV['GRAPHQL_PORT'] || 8080
      when :production, :qa, :sandbox
        443
      end
    end

    def protocol # :nodoc:
      ssl? ? "https" : "http"
    end

    def http_open_timeout
      @http_open_timeout
    end

    def http_read_timeout
      @http_read_timeout
    end

    def server # :nodoc:
      case @environment
      when :development, :integration
        ENV['GATEWAY_HOST'] || "localhost"
      when :production
        "#{endpoint}.braintreegateway.com"
      when :qa
        "gateway.qa.braintreepayments.com"
      when :sandbox
        "api.sandbox.braintreegateway.com"
      end
    end

    def graphql_server # :nodoc:
      case @environment
      when :development, :integration
        ENV['GRAPHQL_HOST'] || "graphql.bt.local"
      when :production
        "payments.braintree-api.com"
      when :qa
        "payments-qa.dev.braintree-api.com"
      when :sandbox
        "payments.sandbox.braintree-api.com"
      end
    end

    def auth_url
      case @environment
      when :development, :integration
        "http://auth.venmo.dev:9292"
      when :production
        "https://auth.venmo.com"
      when :qa
        "https://auth.venmo.qa2.braintreegateway.com"
      when :sandbox
        "https://auth.venmo.sandbox.braintreegateway.com"
      end
    end

    def ssl? # :nodoc:
      case @environment
      when :development, :integration
        false
      when :production, :qa, :sandbox
        true
      end
    end

    def user_agent # :nodoc:
      base_user_agent = "Braintree Ruby Gem #{Braintree::Version::String}"
      @custom_user_agent ? "#{base_user_agent} (#{@custom_user_agent})" : base_user_agent
    end

    def self._default_logger # :nodoc:
      logger = Logger.new(STDOUT)
      logger.level = Logger::INFO
      logger
    end

    def inspect
      super.gsub(/@private_key=\".*\"/, '@private_key="[FILTERED]"')
    end

    def client_credentials?
      !client_id.nil?
    end

    def assert_has_client_credentials
      if client_id.nil? || client_secret.nil?
        raise ConfigurationError.new("Braintree::Gateway client_id and client_secret are required.")
      end
    end

    def assert_has_access_token_or_keys
      if (public_key.nil? || private_key.nil?) && access_token.nil?
        raise ConfigurationError.new("Braintree::Gateway access_token or public_key and private_key are required.")
      end
    end

    def signature_service
      @signature_service ||= SignatureService.new(@private_key)
    end

    def sha256_signature_service
      @sha256_signature_service ||= SignatureService.new(@private_key, SHA256Digest)
    end
  end
end
