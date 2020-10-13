require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe "OAuth" do
  before(:each) do
    @gateway = Braintree::Gateway.new(
      :client_id => "client_id$#{Braintree::Configuration.environment}$integration_client_id",
      :client_secret => "client_secret$#{Braintree::Configuration.environment}$integration_client_secret",
      :logger => Logger.new("/dev/null")
    )
  end

  describe "create_token_from_code" do
    it "creates an access token given a grant code" do
      code = Braintree::OAuthTestHelper.create_grant(@gateway, {
        :merchant_public_id => "integration_merchant_id",
        :scope => "read_write"
      })

      result = @gateway.oauth.create_token_from_code(
        :code => code,
        :scope => "read_write"
      )

      result.should be_success
      credentials = result.credentials
      credentials.access_token.should_not be_nil
      credentials.refresh_token.should_not be_nil
      credentials.expires_at.should_not be_nil
      credentials.token_type.should == "bearer"
    end

    it "returns validation errors for bad params" do
      result = @gateway.oauth.create_token_from_code(
        :code => "bad_code",
        :scope => "read_write"
      )

      result.should_not be_success
      errors = result.errors.for(:credentials).on(:code)[0].code.should == Braintree::ErrorCodes::OAuth::InvalidGrant
      result.message.should =~ /Invalid grant: code not found/
    end

    it "raises with a helpful error if client_id and client_secret are not set" do
      gateway = Braintree::Gateway.new(
        :access_token => "access_token$development$integration_merchant_id$fb27c79dd",
        :logger => Logger.new("/dev/null")
      )

      expect do
        gateway.oauth.create_token_from_code(
          :code => "some code",
          :scope => "read_write"
        )
      end.to raise_error(Braintree::ConfigurationError, /client_id and client_secret are required/);
    end
  end

  describe "create_token_from_refresh_token" do
    it "creates an access token given a refresh token" do
      code = Braintree::OAuthTestHelper.create_grant(@gateway, {
        :merchant_public_id => "integration_merchant_id",
        :scope => "read_write"
      })
      refresh_token = @gateway.oauth.create_token_from_code(
        :code => code,
        :scope => "read_write"
      ).credentials.refresh_token

      result = @gateway.oauth.create_token_from_refresh_token(
        :refresh_token => refresh_token,
        :scope => "read_write"
      )

      result.should be_success
      credentials = result.credentials
      credentials.access_token.should_not be_nil
      credentials.refresh_token.should_not be_nil
      credentials.expires_at.should_not be_nil
      credentials.token_type.should == "bearer"
    end
  end

  describe "revoke_access_token" do
    it "revokes an access token" do
      code = Braintree::OAuthTestHelper.create_grant(@gateway, {
        :merchant_public_id => "integration_merchant_id",
        :scope => "read_write"
      })
      access_token = @gateway.oauth.create_token_from_code(
        :code => code,
        :scope => "read_write"
      ).credentials.access_token

      result = @gateway.oauth.revoke_access_token(access_token)
      result.should be_success

      gateway = Braintree::Gateway.new(
        :access_token => access_token,
        :logger => Logger.new("/dev/null")
      )

      expect do
        gateway.customer.create
      end.to raise_error(Braintree::AuthenticationError)
    end
  end

  describe "connect_url" do
    it "builds a connect url" do
      url = @gateway.oauth.connect_url(
        :merchant_id => "integration_merchant_id",
        :redirect_uri => "http://bar.example.com",
        :scope => "read_write",
        :state => "baz_state",
        :landing_page => "signup",
        :login_only => false,
        :user => {
          :country => "USA",
          :email => "foo@example.com",
          :first_name => "Bob",
          :last_name => "Jones",
          :phone => "555-555-5555",
          :dob_year => "1970",
          :dob_month => "01",
          :dob_day => "01",
          :street_address => "222 W Merchandise Mart",
          :locality => "Chicago",
          :region => "IL",
          :postal_code => "60606"
        },
        :business => {
          :name => "14 Ladders",
          :registered_as => "14.0 Ladders",
          :industry => "Ladders",
          :description => "We sell the best ladders",
          :street_address => "111 N Canal",
          :locality => "Chicago",
          :region => "IL",
          :postal_code => "60606",
          :country => "USA",
          :annual_volume_amount => "1000000",
          :average_transaction_amount => "100",
          :maximum_transaction_amount => "10000",
          :ship_physical_goods => true,
          :fulfillment_completed_in => 7,
          :currency => "USD",
          :website => "http://example.com"
        },
        :payment_methods => ["credit_card", "paypal"]
      )

      uri = URI.parse(url)
      uri.host.should == Braintree::Configuration.instantiate.server
      uri.path.should == "/oauth/connect"

      query = CGI.parse(uri.query)
      query["merchant_id"].should == ["integration_merchant_id"]
      query["client_id"].should == ["client_id$#{Braintree::Configuration.environment}$integration_client_id"]
      query["redirect_uri"].should == ["http://bar.example.com"]
      query["scope"].should == ["read_write"]
      query["state"].should == ["baz_state"]
      query["landing_page"].should == ["signup"]
      query["login_only"].should == ["false"]

      query["user[country]"].should == ["USA"]
      query["business[name]"].should == ["14 Ladders"]

      query["user[email]"].should == ["foo@example.com"]
      query["user[first_name]"].should == ["Bob"]
      query["user[last_name]"].should == ["Jones"]
      query["user[phone]"].should == ["555-555-5555"]
      query["user[dob_year]"].should == ["1970"]
      query["user[dob_month]"].should == ["01"]
      query["user[dob_day]"].should == ["01"]
      query["user[street_address]"].should == ["222 W Merchandise Mart"]
      query["user[locality]"].should == ["Chicago"]
      query["user[region]"].should == ["IL"]
      query["user[postal_code]"].should == ["60606"]

      query["business[name]"].should == ["14 Ladders"]
      query["business[registered_as]"].should == ["14.0 Ladders"]
      query["business[industry]"].should == ["Ladders"]
      query["business[description]"].should == ["We sell the best ladders"]
      query["business[street_address]"].should == ["111 N Canal"]
      query["business[locality]"].should == ["Chicago"]
      query["business[region]"].should == ["IL"]
      query["business[postal_code]"].should == ["60606"]
      query["business[country]"].should == ["USA"]
      query["business[annual_volume_amount]"].should == ["1000000"]
      query["business[average_transaction_amount]"].should == ["100"]
      query["business[maximum_transaction_amount]"].should == ["10000"]
      query["business[ship_physical_goods]"].should == ["true"]
      query["business[fulfillment_completed_in]"].should == ["7"]
      query["business[currency]"].should == ["USD"]
      query["business[website]"].should == ["http://example.com"]
    end

    it "builds the query string with multiple payment_methods" do
      url = @gateway.oauth.connect_url(
        :merchant_id => "integration_merchant_id",
        :redirect_uri => "http://bar.example.com",
        :scope => "read_write",
        :state => "baz_state",
        :payment_methods => ["credit_card", "paypal"]
      )

      uri = URI.parse(url)
      uri.host.should == Braintree::Configuration.instantiate.server
      uri.path.should == "/oauth/connect"

      query = CGI.parse(CGI.unescape(uri.query))
      query["payment_methods[]"].length.should == 2
      query["payment_methods[]"].should include("paypal")
      query["payment_methods[]"].should include("credit_card")
    end

    it "doesn't mutate the options" do
      params = {:payment_methods => ["credit_card"]}

      @gateway.oauth.connect_url(params)

      params.should == {:payment_methods => ["credit_card"]}
    end
  end
end
