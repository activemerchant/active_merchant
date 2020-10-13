require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::SHA256Digest do
  describe "self.hexdigest" do
    it "returns the sha256 hmac of the input string (test case 6 from RFC 2202)" do
      key = "secret-key"
      message = "secret-message"
      Braintree::SHA256Digest.hexdigest(key, message).should == "68e7f2ecab71db67b1aca2a638f5122810315c3013f27c2196cd53e88709eecc"
    end
  end
end
