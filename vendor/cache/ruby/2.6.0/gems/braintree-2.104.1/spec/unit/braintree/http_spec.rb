require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::Http do
  describe "self._format_and_sanitize_body_for_log" do
    it "adds [Braintree] before each line" do
      input_xml = <<-END
<customer>
  <first-name>Joe</first-name>
  <last-name>Doe</last-name>
</customer>
END
      expected_xml = <<-END
[Braintree] <customer>
[Braintree]   <first-name>Joe</first-name>
[Braintree]   <last-name>Doe</last-name>
[Braintree] </customer>
END
      Braintree::Http.new(:config)._format_and_sanitize_body_for_log(input_xml).should == expected_xml
    end

    it "sanitizes credit card number and cvv" do
      input_xml = <<-END
<customer>
  <first-name>Joe</first-name>
  <last-name>Doe</last-name>
  <number>1234560000001234</number>
  <cvv>123</cvv>
</customer>
      END

      expected_xml = <<-END
[Braintree] <customer>
[Braintree]   <first-name>Joe</first-name>
[Braintree]   <last-name>Doe</last-name>
[Braintree]   <number>123456******1234</number>
[Braintree]   <cvv>***</cvv>
[Braintree] </customer>
END
      Braintree::Http.new(:config)._format_and_sanitize_body_for_log(input_xml).should == expected_xml
    end

    it "sanitizes credit card number and cvv with newlines" do
      input_xml = <<-END
<customer>
  <first-name>Joe</first-name>
  <last-name>Doe</last-name>
  <number>123456000\n0001234</number>
  <cvv>1\n23</cvv>
</customer>
      END

      expected_xml = <<-END
[Braintree] <customer>
[Braintree]   <first-name>Joe</first-name>
[Braintree]   <last-name>Doe</last-name>
[Braintree]   <number>123456******1234</number>
[Braintree]   <cvv>***</cvv>
[Braintree] </customer>
END
      Braintree::Http.new(:config)._format_and_sanitize_body_for_log(input_xml).should == expected_xml
    end
  end

  describe "self._http_do" do
    it "connects when proxy address is specified" do
      config = Braintree::Configuration.new(
        :proxy_address => "localhost",
        :proxy_port => 8080,
        :proxy_user => "user",
        :proxy_pass => "test"
      )

      http = Braintree::Http.new(config)
      net_http_instance = instance_double(
        "Net::HTTP",
        :open_timeout= => nil,
        :read_timeout= => nil,
        :start => nil
      )

      Net::HTTP.should_receive(:new).with(nil, nil, "localhost", 8080, "user", "test").and_return(net_http_instance)

      http._http_do("GET", "/plans")
    end

    it "accepts a partially specified proxy" do
      config = Braintree::Configuration.new(
        :proxy_address => "localhost",
        :proxy_port => 8080
      )

      http = Braintree::Http.new(config)
      net_http_instance = instance_double(
        "Net::HTTP",
        :open_timeout= => nil,
        :read_timeout= => nil,
        :start => nil
      )

      Net::HTTP.should_receive(:new).with(nil, nil, "localhost", 8080, nil, nil).and_return(net_http_instance)

      http._http_do("GET", "/plans")
    end

    it "does not specify a proxy if proxy_address is not set" do
      config = Braintree::Configuration.new
      http = Braintree::Http.new(config)
      net_http_instance = instance_double(
        "Net::HTTP",
        :open_timeout= => nil,
        :read_timeout= => nil,
        :start => nil
      )

      Net::HTTP.should_receive(:new).with(nil, nil).and_return(net_http_instance)

      http._http_do("GET", "/plans")
    end
  end

  describe "_compose_headers" do
    before (:each) do
      config = Braintree::Configuration.new
      @http = Braintree::Http.new(config)
    end

    it "returns a hash of default headers" do
      default_headers = @http._compose_headers
      expect(default_headers["Accept"]).to eq("application/xml")
      expect(default_headers["Accept-Encoding"]).to eq("gzip")
      expect(default_headers["Content-Type"]).to eq("application/xml")
      expect(default_headers["User-Agent"]).to match(/Braintree Ruby Gem .*/)
      expect(default_headers["X-ApiVersion"]).to eq("5")
    end

    it "overwrites defaults with override headers" do
      override_headers = {
        "Accept" => "application/pdf",
        "Authorization" => "token"
      }
      headers = @http._compose_headers(override_headers)
      expect(headers["Accept"]).to eq("application/pdf")
      expect(headers["Accept-Encoding"]).to eq("gzip")
      expect(headers["Authorization"]).to eq("token")
      expect(headers["Content-Type"]).to eq("application/xml")
      expect(headers["User-Agent"]).to match(/Braintree Ruby Gem .*/)
      expect(headers["X-ApiVersion"]).to eq("5")
    end

    it "extends default headers when new headers are specified" do
      override_headers = {
        "New-Header" => "New Value"
      }
      headers = @http._compose_headers(override_headers)
      expect(headers["Accept"]).to eq("application/xml")
      expect(headers["Accept-Encoding"]).to eq("gzip")
      expect(headers["Content-Type"]).to eq("application/xml")
      expect(headers["User-Agent"]).to match(/Braintree Ruby Gem .*/)
      expect(headers["X-ApiVersion"]).to eq("5")
      expect(headers["New-Header"]).to eq("New Value")
    end
  end

  describe "_setup_connection" do
    it "creates a new Net::HTTP object using default server and port" do
      config = Braintree::Configuration.new
      http = Braintree::Http.new(config)

      connection = http._setup_connection
      expect(connection.address).to eq(nil)
      expect(connection.port).to eq(80)
    end

    it "overrides the default server and port when replacements are specified" do
      config = Braintree::Configuration.new
      http = Braintree::Http.new(config)

      connection = http._setup_connection("localhost", 3443)
      expect(connection.address).to eq("localhost")
      expect(connection.port).to eq(3443)
    end
  end

  describe "_build_query_string" do
    it "returns an empty string for empty query params" do
      Braintree::Http.new(:config)._build_query_string({}).should == ""
    end

    it "returns a proper query string for non-nested hashes" do
      query_params = {:one => 1, :two => 2}

      Braintree::Http.new(:config)._build_query_string(query_params).should =~ /^\?(one=1&two=2|two=2&one=1)$/
    end

    it "raises ArgumentError for nested hashes" do
      query_params = {:one => 1, :two => {:a => 2.1, :b => 2.2}}
      expect {
        Braintree::Http.new(:config)._build_query_string(query_params)
      }.to raise_error(ArgumentError, /nested hash/i)
    end
  end
end
