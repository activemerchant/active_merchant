require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::Errors do
  describe "for" do
    it "accesses errors for the given scope" do
      errors = Braintree::Errors.new(
        :level1 => {:errors => [{:code => "code1", :attribute => "attr", :message => "message"}]}
      )
      errors.for(:level1).size.should == 1
      errors.for(:level1)[0].code.should == "code1"
    end

    it "returns nil if there are no errors at the given scope" do
      errors = Braintree::Errors.new(
        :level1 => {:errors => [{:code => "code1", :attribute => "attr", :message => "message"}]}
      )
      errors.for(:no_errors_here).should == nil
    end
  end

  describe "inspect" do
    it "is better than the default inspect" do
      errors = Braintree::Errors.new(
        :level1 => {:errors => [{:code => "code1", :attribute => "attr", :message => "message"}]}
      )
      errors.inspect.should == "#<Braintree::Errors level1:[(code1) message]>"
    end

    it "shows errors 2 levels deep" do
      errors = Braintree::Errors.new(
        :level1 => {
          :errors => [{:code => "code1", :attribute => "attr", :message => "message"}],
          :level2 => {
            :errors => [{:code => "code2", :attribute => "attr2", :message => "message2"}],
          }
        }
      )
      errors.inspect.should == "#<Braintree::Errors level1:[(code1) message], level1/level2:[(code2) message2]>"
    end

    it "shows errors 3 levels deep" do
      errors = Braintree::Errors.new(
        :level1 => {
          :errors => [{:code => "code1", :attribute => "attr", :message => "message"}],
          :level2 => {
            :errors => [{:code => "code2", :attribute => "attr2", :message => "message2"}],
            :level3 => {
              :errors => [{:code => "code3", :attribute => "attr3", :message => "message3"}],
            }
          }
        }
      )
      errors.inspect.should == "#<Braintree::Errors level1:[(code1) message], level1/level2:[(code2) message2], level1/level2/level3:[(code3) message3]>"
    end
  end

  describe "each" do
    it "yields errors at all levels" do
      errors = Braintree::Errors.new(
        :level1 => {
          :errors => [{:code => "1", :attribute => "attr", :message => "message"}],
          :level2 => {
            :errors => [
              {:code => "2", :attribute => "attr2", :message => "message2"},
              {:code => "3", :attribute => "attr3", :message => "message3"}
            ],
          }
        }
      )
      errors.map { |e| e.code }.sort.should == %w[1 2 3]
    end
  end

  describe "size" do
    it "returns the number of validation errors at the first level if only has one level" do
      errors = Braintree::Errors.new(
        :level1 => {:errors => [{:code => "1", :attribute => "attr", :message => "message"}]}
      )
      errors.size.should == 1
    end

    it "returns the total number of validation errors in the hierarchy" do
      errors = Braintree::Errors.new(
        :level1 => {
          :errors => [{:code => "1", :attribute => "attr", :message => "message"}],
          :level2 => {
            :errors => [
              {:code => "2", :attribute => "attr2", :message => "message2"},
              {:code => "3", :attribute => "attr3", :message => "message3"}
            ],
          }
        }
      )
      errors.size.should == 3
    end
  end
end

