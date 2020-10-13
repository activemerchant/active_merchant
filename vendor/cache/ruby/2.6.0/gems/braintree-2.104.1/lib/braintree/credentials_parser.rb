module Braintree
  class CredentialsParser
    attr_reader :access_token
    attr_reader :client_id
    attr_reader :client_secret
    attr_reader :environment
    attr_reader :merchant_id

    def parse_client_credentials(client_id, client_secret)
      raise ConfigurationError.new("Missing client_id when constructing Braintree::Gateway") if client_id.nil?
      raise ConfigurationError.new("Value passed for client_id is not a client_id") unless client_id.start_with?("client_id")

      raise ConfigurationError.new("Missing client_secret when constructing Braintree::Gateway") if client_secret.nil?
      raise ConfigurationError.new("Value passed for client_secret is not a client_secret") unless client_secret.start_with?("client_secret")
      client_id_environment = parse_environment(client_id)
      client_secret_environment = parse_environment(client_secret)

      if client_id_environment != client_secret_environment
        raise ConfigurationError.new("Mismatched credential environments: client_id environment is #{client_id_environment} and client_secret environment is #{client_secret_environment}")
      end

      @client_id = client_id
      @client_secret = client_secret
      @environment = client_id_environment
    end

    def parse_access_token(access_token)
      raise ConfigurationError.new("Missing access_token when constructing Braintree::Gateway") if access_token.nil?
      raise ConfigurationError.new("Value passed for access_token is not a valid access_token") unless access_token.start_with?("access_token")

      @access_token = access_token
      @environment = parse_environment(access_token)
      @merchant_id = parse_merchant_id(access_token)
    end

    def parse_environment(credential)
      credential.split("$")[1].to_sym
    end

    def parse_merchant_id(access_token)
      access_token.split("$")[2]
    end
  end
end
