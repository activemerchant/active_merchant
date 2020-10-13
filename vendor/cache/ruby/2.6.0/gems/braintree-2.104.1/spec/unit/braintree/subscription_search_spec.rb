require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

module Braintree
  describe SubscriptionSearch do
    context "status" do
      it "allows Active, Canceled, Expired, and PastDue" do
        search = SubscriptionSearch.new

        lambda do
          search.status.in(
            Subscription::Status::Active,
            Subscription::Status::Canceled,
            Subscription::Status::Expired,
            Subscription::Status::PastDue
          )
        end.should_not raise_error
      end
    end

    context "in_trial_period" do
      it "allows true" do
        search = SubscriptionSearch.new
        search.in_trial_period.is true

        search.to_hash.should == {:in_trial_period => [true]}
      end

      it "allows false" do
        search = SubscriptionSearch.new
        search.in_trial_period.is false

        search.to_hash.should == {:in_trial_period => [false]}
      end
    end

    context "days_past_due" do
      it "correctly builds a hash with the criteria" do
        search = SubscriptionSearch.new
        search.days_past_due.is "30"

        search.to_hash.should == {:days_past_due => {:is => "30"}}
      end

      it "coverts ints to strings" do
        search = SubscriptionSearch.new
        search.days_past_due.is 30

        search.to_hash.should == {:days_past_due => {:is => "30"}}
      end
    end

    context "merchant_account_id" do
      it "builds a hash using the in operator" do
        search = SubscriptionSearch.new
        search.merchant_account_id.in "ma_id1", "ma_id2"

        search.to_hash.should == {:merchant_account_id => ["ma_id1", "ma_id2"]}
      end
    end

    context "plan_id" do
      it "starts_with" do
        search = SubscriptionSearch.new
        search.plan_id.starts_with "plan_"

        search.to_hash.should == {:plan_id => {:starts_with => "plan_"}}
      end

      it "ends_with" do
        search = SubscriptionSearch.new
        search.plan_id.ends_with "_id"

        search.to_hash.should == {:plan_id => {:ends_with => "_id"}}
      end

      it "is" do
        search = SubscriptionSearch.new
        search.plan_id.is "p_id"

        search.to_hash.should == {:plan_id => {:is => "p_id"}}
      end

      it "is_not" do
        search = SubscriptionSearch.new
        search.plan_id.is_not "p_id"

        search.to_hash.should == {:plan_id => {:is_not => "p_id"}}
      end

      it "contains" do
        search = SubscriptionSearch.new
        search.plan_id.contains "p_id"

        search.to_hash.should == {:plan_id => {:contains => "p_id"}}
      end

      it "in" do
        search = SubscriptionSearch.new
        search.plan_id.in ["plan1", "plan2"]

        search.to_hash.should == {:plan_id => ["plan1", "plan2"]}
      end
    end

    context "days_past_due" do
      it "is a range node" do
        search = SubscriptionSearch.new
        search.days_past_due.should be_kind_of(Braintree::AdvancedSearch::RangeNode)
      end
    end

    context "billing_cycles_remaining" do
      it "is a range node" do
        search = SubscriptionSearch.new
        search.billing_cycles_remaining.should be_kind_of(Braintree::AdvancedSearch::RangeNode)
      end
    end

    context "created_at" do
      it "is a range node" do
        search = SubscriptionSearch.new
        search.created_at.should be_kind_of(Braintree::AdvancedSearch::RangeNode)
      end
    end

    context "id" do
      it "is" do
        search = SubscriptionSearch.new
        search.id.is "s_id"

        search.to_hash.should == {:id => {:is => "s_id"}}
      end
    end
  end
end
