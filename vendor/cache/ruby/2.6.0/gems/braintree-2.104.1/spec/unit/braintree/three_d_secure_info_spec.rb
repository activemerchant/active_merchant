require File.expand_path(File.dirname(__FILE__) + "/../../spec_helper")

describe Braintree::ThreeDSecureInfo do
  let(:three_d_secure_info) {
    Braintree::ThreeDSecureInfo.new(
      :enrolled => "Y",
      :liability_shifted => true,
      :liability_shift_possible => true,
      :cavv => "cavvvalue",
      :xid => "xidvalue",
      :status => "authenticate_successful",
      :eci_flag => "06",
      :three_d_secure_version => "1.0.2",
      :ds_transaction_id => "dstrxid",
      :three_d_secure_authentication_id => "auth_id",
    )
  }

  describe "#initialize" do
    it "sets attributes" do
      three_d_secure_info.enrolled.should == "Y"
      three_d_secure_info.status.should == "authenticate_successful"
      three_d_secure_info.liability_shifted.should == true
      three_d_secure_info.liability_shift_possible.should == true
      three_d_secure_info.cavv.should == "cavvvalue"
      three_d_secure_info.xid.should == "xidvalue"
      three_d_secure_info.eci_flag.should == "06"
      three_d_secure_info.three_d_secure_version.should == "1.0.2"
      three_d_secure_info.ds_transaction_id.should == "dstrxid"
      three_d_secure_info.three_d_secure_authentication_id.should == "auth_id"
    end
  end

  describe "inspect" do
    it "prints the attributes" do
      three_d_secure_info.inspect.should == %(#<ThreeDSecureInfo enrolled: "Y", liability_shifted: true, liability_shift_possible: true, status: "authenticate_successful", cavv: "cavvvalue", xid: "xidvalue", eci_flag: "06", three_d_secure_version: "1.0.2", ds_transaction_id: "dstrxid", three_d_secure_authentication_id: "auth_id">)
    end
  end

  describe "liability_shifted" do
    it "is aliased to liability_shifted?" do
      three_d_secure_info.liability_shifted?.should == true
    end
  end

  describe "liability_shift_possible" do
    it "is aliased to liability_shift_possible?" do
      three_d_secure_info.liability_shift_possible?.should == true
    end
  end
end
