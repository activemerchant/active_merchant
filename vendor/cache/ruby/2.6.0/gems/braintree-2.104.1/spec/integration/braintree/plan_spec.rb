require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::Plan do

  describe "self.all" do
    it "gets all plans" do
      plan_token = "test_plan_#{rand(36**8).to_s(36)}"
      attributes = {
        :id => plan_token,
        :billing_day_of_month => 1,
        :billing_frequency => 1,
        :currency_iso_code => "USD",
        :description => "some description",
        :name => "ruby_test plan",
        :number_of_billing_cycles => 1,
        :price => "1.00",
        :trial_period => false,
      }
      create_plan_for_tests(attributes)

      add_on_name = "ruby_add_on"
      discount_name = "ruby_discount"
      create_modification_for_tests(:kind => "add_on", :plan_id => plan_token, :amount => "1.00", :name => add_on_name)
      create_modification_for_tests(:kind => "discount", :plan_id => plan_token, :amount => "1.00", :name => discount_name)

      plans = Braintree::Plan.all
      plan = plans.select { |plan| plan.id == plan_token }.first
      plan.should_not be_nil
      plan.id.should == attributes[:id]
      plan.billing_day_of_month.should == attributes[:billing_day_of_month]
      plan.billing_frequency.should == attributes[:billing_frequency]
      plan.currency_iso_code.should == attributes[:currency_iso_code]
      plan.description.should == attributes[:description]
      plan.name.should == attributes[:name]
      plan.number_of_billing_cycles.should == attributes[:number_of_billing_cycles]
      plan.price.should == Braintree::Util.to_big_decimal("1.00")
      plan.trial_period.should == attributes[:trial_period]
      plan.created_at.should_not be_nil
      plan.updated_at.should_not be_nil
      plan.add_ons.first.name.should == add_on_name
      plan.discounts.first.name.should == discount_name
    end

    it "returns an empty array if there are no plans" do
      gateway = Braintree::Gateway.new(SpecHelper::TestMerchantConfig)
      plans = gateway.plan.all
      plans.should == []
    end
  end

  def create_plan_for_tests(attributes)
    config = Braintree::Configuration.gateway.config
    config.http.post("#{config.base_merchant_path}/plans/create_plan_for_tests", :plan => attributes)
  end
end
