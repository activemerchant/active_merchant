require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::Subscription do
  def default_params
    {
      :add_ons => [],
      :discounts => [],
      :transactions => []
    }
  end

  context "price" do
    it "accepts price as either a String or a BigDecimal" do
      Braintree::Subscription._new(:gateway, default_params.merge(:price => "12.34")).price.should == BigDecimal("12.34")
      Braintree::Subscription._new(:gateway, default_params.merge(:price => BigDecimal("12.34"))).price.should == BigDecimal("12.34")
    end

    it "blows up if price is not a string or BigDecimal" do
      expect {
        Braintree::Subscription._new(:gateway, default_params.merge(:price => 12.34))
      }.to raise_error(/Argument must be a String or BigDecimal/)
    end
  end

  describe "self.find" do
    it "raises error if passed empty string" do
      expect do
        Braintree::Subscription.find("")
      end.to raise_error(ArgumentError)
    end

    it "raises error if passed empty string wth space" do
      expect do
        Braintree::Subscription.find(" ")
      end.to raise_error(ArgumentError)
    end

    it "raises error if passed nil" do
      expect do
        Braintree::Subscription.find(nil)
      end.to raise_error(ArgumentError)
    end

    it "does not raise an error if subscription id does not respond to strip" do
      Braintree::Http.stub(:new).and_return double(:get => {:subscription => default_params})
      expect do
        Braintree::Subscription.find(8675309)
      end.to_not raise_error
    end
  end

  describe "self.search" do
    it "only allows specified values for status" do
      lambda do
        Braintree::Subscription.search do |search|
          search.status.in "Hammer"
        end
      end.should raise_error(ArgumentError)
    end
  end

  describe "==" do
    it "returns true for subscriptions with the same id" do
      subscription1 = Braintree::Subscription._new(:gateway, default_params.merge(:id => "123"))
      subscription2 = Braintree::Subscription._new(:gateway, default_params.merge(:id => "123"))
      subscription1.should == subscription2
    end

    it "returns false for subscriptions with different ids" do
      subscription1 = Braintree::Subscription._new(:gateway, default_params.merge(:id => "123"))
      subscription2 = Braintree::Subscription._new(:gateway, default_params.merge(:id => "not_123"))
      subscription1.should_not == subscription2
    end

    it "returns false if not comparing to a subscription" do
      subscription = Braintree::Subscription._new(:gateway, default_params.merge(:id => "123"))
      subscription.should_not == "not a subscription"
    end
  end
end
