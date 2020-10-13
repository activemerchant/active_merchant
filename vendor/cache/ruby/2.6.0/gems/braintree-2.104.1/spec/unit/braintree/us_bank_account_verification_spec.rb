require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::UsBankAccountVerification do
  describe "inspect" do
    let(:verification) do
      Braintree::UsBankAccountVerification._new(
        :id => "some_verification_id",
        :status => Braintree::UsBankAccountVerification::Status::Verified,
        :verification_method => Braintree::UsBankAccountVerification::VerificationMethod::IndependentCheck,
        :verification_determined_at => "2018-02-28T12:01:01Z",
      )
    end

    it "has a status" do
      verification.status.should == Braintree::UsBankAccountVerification::Status::Verified
    end
  end

  describe "self.confirm_micro_transfer_amounts" do
    it "raises error if passed empty string" do
      expect do
        Braintree::UsBankAccountVerification.confirm_micro_transfer_amounts("", [])
      end.to raise_error(ArgumentError)
    end

    it "raises error if passed empty string wth space" do
      expect do
        Braintree::UsBankAccountVerification.confirm_micro_transfer_amounts(" ", [])
      end.to raise_error(ArgumentError)
    end

    it "raises error if passed nil" do
      expect do
        Braintree::UsBankAccountVerification.confirm_micro_transfer_amounts(nil, [])
      end.to raise_error(ArgumentError)
    end

    it "raises error if passed non-array" do
      expect do
        Braintree::UsBankAccountVerification.confirm_micro_transfer_amounts(999, 123)
      end.to raise_error(ArgumentError)
    end
  end

  describe "self.find" do
    it "raises error if passed empty string" do
      expect do
        Braintree::UsBankAccountVerification.find("")
      end.to raise_error(ArgumentError)
    end

    it "raises error if passed empty string wth space" do
      expect do
        Braintree::UsBankAccountVerification.find(" ")
      end.to raise_error(ArgumentError)
    end

    it "raises error if passed nil" do
      expect do
        Braintree::UsBankAccountVerification.find(nil)
      end.to raise_error(ArgumentError)
    end
  end

  describe "==" do
    it "returns true for verifications with the same id" do
      first = Braintree::UsBankAccountVerification._new(:id => "123")
      second = Braintree::UsBankAccountVerification._new(:id => "123")

      first.should == second
      second.should == first
    end

    it "returns false for verifications with different ids" do
      first = Braintree::UsBankAccountVerification._new(:id => "123")
      second = Braintree::UsBankAccountVerification._new(:id => "124")

      first.should_not == second
      second.should_not == first
    end

    it "returns false when comparing to nil" do
      Braintree::UsBankAccountVerification._new({}).should_not == nil
    end

    it "returns false when comparing to non-verifications" do
      same_id_different_object = Object.new
      def same_id_different_object.id; "123"; end
      verification = Braintree::UsBankAccountVerification._new(:id => "123")
      verification.should_not == same_id_different_object
    end
  end
end
