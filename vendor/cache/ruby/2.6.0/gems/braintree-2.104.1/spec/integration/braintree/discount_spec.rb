require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::Discount do
  describe "self.all" do
    it "gets all discounts" do
      id = rand(36**8).to_s(36)

      expected = {
        :amount => "100.00",
        :description => "some description",
        :id => id,
        :kind => "discount",
        :name => "ruby_discount",
        :never_expires => false,
        :number_of_billing_cycles => 1
      }

      create_modification_for_tests(expected)

      discounts = Braintree::Discount.all
      discount = discounts.select { |discount| discount.id == id }.first

      discount.should_not be_nil
      discount.amount.should == BigDecimal(expected[:amount])
      discount.created_at.should_not be_nil
      discount.description.should == expected[:description]
      discount.kind.should == expected[:kind]
      discount.name.should == expected[:name]
      discount.never_expires.should == expected[:never_expires]
      discount.number_of_billing_cycles.should == expected[:number_of_billing_cycles]
      discount.updated_at.should_not be_nil
    end
  end
end
