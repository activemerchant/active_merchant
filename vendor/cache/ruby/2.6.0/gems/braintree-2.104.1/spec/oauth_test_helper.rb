module Braintree
  class OAuthTestHelper
    def self.create_grant(gateway, params)
      response = gateway.config.http.post("/oauth_testing/grants", {
        :grant => params
      })
      response[:grant][:code]
    end

    def self.create_token(gateway, params)
      code = create_grant(gateway, params)
      gateway.oauth.create_token_from_code(
        :code => code
      )
    end
  end
end
