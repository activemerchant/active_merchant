require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::Digest do
  describe "self.hexdigest" do
    it "returns the sha1 hmac of the input string (test case 6 from RFC 2202)" do
      original_key = Braintree::Configuration.private_key
      private_key = "\xaa" * 80
      data = "Test Using Larger Than Block-Size Key - Hash Key First"
      Braintree::Digest.hexdigest(private_key, data).should == "aa4ae5e15272d00e95705637ce8a3b55ed402112"
    end

    it "returns the sha1 hmac of the input string (test case 7 from RFC 2202)" do
      private_key = "\xaa" * 80
      data = "Test Using Larger Than Block-Size Key and Larger Than One Block-Size Data"
      Braintree::Digest.hexdigest(private_key, data).should == "e8e99d0f45237d786d6bbaa7965c7808bbff1a91"
    end

    it "doesn't blow up if message is nil" do
      expect { Braintree::Digest.hexdigest("key", nil) }.to_not raise_error
    end
  end

  describe "self.secure_compare" do
    it "returns true if two strings are equal" do
      Braintree::Digest.secure_compare("A_string", "A_string").should be(true)
    end

    it "returns false if two strings are different and the same length" do
      Braintree::Digest.secure_compare("A_string", "A_strong").should be(false)
    end

    it "returns false if one is a prefix of the other" do
      Braintree::Digest.secure_compare("A_string", "A_string_that_is_longer").should be(false)
    end
  end
end

