require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::ValidationErrorCollection do

  context "blue response" do
    describe "initialize" do
      it "builds an error object given an array of hashes" do
        hash = {:errors => [{ :attribute => "some model attribute", :code => 1, :message => "bad juju" }]}
        collection = Braintree::ValidationErrorCollection.new(hash)
        error = collection[0]
        error.attribute.should == "some model attribute"
        error.code.should == 1
        error.message.should == "bad juju"
      end
    end

    describe "for" do
      it "provides access to nested errors" do
        hash = {
          :errors => [{ :attribute => "some model attribute", :code => 1, :message => "bad juju" }],
          :nested => {
            :errors => [{ :attribute => "number", :code => 2, :message => "badder juju"}]
          }
        }
        errors = Braintree::ValidationErrorCollection.new(hash)
        errors.for(:nested).on(:number)[0].code.should == 2
        errors.for(:nested).on(:number)[0].message.should == "badder juju"
        errors.for(:nested).on(:number)[0].attribute.should == "number"
      end
    end

    describe "inspect" do
      it "shows the errors at the current level" do
        errors = Braintree::ValidationErrorCollection.new(:errors => [
          {:attribute => "name", :code => "code1", :message => "message1"},
          {:attribute => "name", :code => "code2", :message => "message2"}
        ])
        errors.inspect.should == "#<Braintree::ValidationErrorCollection errors:[(code1) message1, (code2) message2]>"
      end

      it "shows errors 1 level deep" do
        errors = Braintree::ValidationErrorCollection.new(
          :errors => [
            {:attribute => "name", :code => "code1", :message => "message1"},
          ],
          :level1 => {
            :errors => [{:attribute => "name", :code => "code2", :message => "message2"}]
          }
        )
        errors.inspect.should == "#<Braintree::ValidationErrorCollection errors:[(code1) message1], level1:[(code2) message2]>"
      end

      it "shows errors 2 levels deep" do
        errors = Braintree::ValidationErrorCollection.new(
          :errors => [
            {:attribute => "name", :code => "code1", :message => "message1"},
          ],
          :level1 => {
            :errors => [{:attribute => "name", :code => "code2", :message => "message2"}],
            :level2 => {
              :errors => [{:attribute => "name", :code => "code3", :message => "message3"}],
            }
          }
        )
        errors.inspect.should == "#<Braintree::ValidationErrorCollection errors:[(code1) message1], level1:[(code2) message2], level1/level2:[(code3) message3]>"
      end
    end

    describe "on" do
      it "returns an array of errors on the given attribute" do
        errors = Braintree::ValidationErrorCollection.new(:errors => [
          {:attribute => "name", :code => 1, :message => "is too long"},
          {:attribute => "name", :code => 2, :message => "contains invalid chars"},
          {:attribute => "not name", :code => 3, :message => "is invalid"}
        ])
        errors.on("name").size.should == 2
        errors.on("name").map{ |e| e.code }.should == [1, 2]
      end

      it "has indifferent access" do
        errors = Braintree::ValidationErrorCollection.new(:errors => [
          { :attribute => "name", :code => 3, :message => "is too long" },
        ])
        errors.on(:name).size.should == 1
        errors.on(:name)[0].code.should == 3

      end
    end

    describe "deep_size" do
      it "returns the size for a non-nested collection" do
        errors = Braintree::ValidationErrorCollection.new(:errors => [
          {:attribute => "one", :code => 1, :message => "is too long"},
          {:attribute => "two", :code => 2, :message => "contains invalid chars"},
          {:attribute => "thr", :code => 3, :message => "is invalid"}
        ])
        errors.deep_size.should == 3
      end

      it "returns the size of nested errors as well" do
        errors = Braintree::ValidationErrorCollection.new(
          :errors => [{ :attribute => "some model attribute", :code => 1, :message => "bad juju" }],
          :nested => {
            :errors => [{ :attribute => "number", :code => 2, :message => "badder juju"}]
          }
        )
        errors.deep_size.should == 2
      end

      it "returns the size of multiple nestings of errors" do
        errors = Braintree::ValidationErrorCollection.new(
          :errors => [
            { :attribute => "one", :code => 1, :message => "bad juju" },
            { :attribute => "two", :code => 1, :message => "bad juju" }],
          :nested => {
            :errors => [{ :attribute => "three", :code => 2, :message => "badder juju"}],
            :nested_again => {
              :errors => [{ :attribute => "four", :code => 2, :message => "badder juju"}]
            }
          },
          :same_level => {
            :errors => [{ :attribute => "five", :code => 2, :message => "badder juju"}],
          }
        )
        errors.deep_size.should == 5
      end
    end

    describe "deep_errors" do
      it "returns errors from all levels" do
        errors = Braintree::ValidationErrorCollection.new(
          :errors => [
            { :attribute => "one", :code => 1, :message => "bad juju" },
            { :attribute => "two", :code => 2, :message => "bad juju" }],
          :nested => {
            :errors => [{ :attribute => "three", :code => 3, :message => "badder juju"}],
            :nested_again => {
              :errors => [{ :attribute => "four", :code => 4, :message => "badder juju"}]
            }
          },
          :same_level => {
            :errors => [{ :attribute => "five", :code => 5, :message => "badder juju"}],
          }
        )
        errors.deep_errors.map { |e| e.code }.sort.should == [1, 2, 3, 4, 5]
      end
    end

    describe "shallow_errors" do
      it "returns errors on one level" do
        errors = Braintree::ValidationErrorCollection.new(
          :errors => [
            { :attribute => "one", :code => 1, :message => "bad juju" },
            { :attribute => "two", :code => 2, :message => "bad juju" }],
          :nested => {
            :errors => [{ :attribute => "three", :code => 3, :message => "badder juju"}],
            :nested_again => {
              :errors => [{ :attribute => "four", :code => 4, :message => "badder juju"}]
            }
          }
        )
        errors.shallow_errors.map {|e| e.code}.should == [1, 2]
        errors.for(:nested).shallow_errors.map {|e| e.code}.should == [3]
      end

      it "returns an clone of the real array" do
        errors = Braintree::ValidationErrorCollection.new(
          :errors => [
            { :attribute => "one", :code => 1, :message => "bad juju" },
            { :attribute => "two", :code => 2, :message => "bad juju" }]
        )
        errors.shallow_errors.pop
        errors.shallow_errors.map {|e| e.code}.should == [1, 2]
      end
    end
  end

  context "graphql response" do
    describe "initialize" do
      it "builds an error object given an array of hashes" do
        hash = {:errors => [{
                  :message => "bad juju",
                  :untracked_param => "don't look",
                  :path=>["one", "two"],
                  :extensions=> {:errorClass=>"VALIDATION", :legacyCode=>"1"}
                }]}
        collection = Braintree::ValidationErrorCollection.new(hash)
        error = collection[0]
        error.attribute.should == "two"
        error.code.should == 1
        error.message.should == "bad juju"
        !error.respond_to? :untracked_param
      end
    end

    describe "for" do
      it "provides access to nested errors" do
        hash = {
          :errors => [{
            :message => "bad juju",
            :path=>["one", "two"],
            :extensions=> {:errorClass=>"VALIDATION", :legacyCode=>"1"}
          }],
          :nested => {
            :errors => [{
              :message => "badder juju",
              :path=>["nested_attribute"],
              :extensions=> {:errorClass=>"VALIDATION", :legacyCode=>"2"}
            }]
          }
        }
        errors = Braintree::ValidationErrorCollection.new(hash)
        errors.for(:nested).on(:nested_attribute)[0].code.should == 2
        errors.for(:nested).on(:nested_attribute)[0].message.should == "badder juju"
        errors.for(:nested).on(:nested_attribute)[0].attribute.should == "nested_attribute"
      end
    end

    describe "deep_size" do
      it "returns the size for a non-nested collection" do
        hash = {
          :errors => [{
            :message => "bad juju",
            :path=>["one", "two"],
            :extensions=> {:errorClass=>"VALIDATION", :legacyCode=>"1"}
          },{
            :message => "bad juju 2",
            :path=>["three", "four"],
            :extensions=> {:errorClass=>"VALIDATION", :legacyCode=>"2"}
          },{
            :message => "bad juju 3",
            :path=>["five", "six"],
            :extensions=> {:errorClass=>"VALIDATION", :legacyCode=>"2"}
          }],
        }
        errors = Braintree::ValidationErrorCollection.new(hash)
        errors.deep_size.should == 3
      end

      it "returns the size of nested errors as well" do
        hash = {
          :errors => [{
            :message => "bad juju",
            :path=>["one", "two"],
            :extensions=> {:errorClass=>"VALIDATION", :legacyCode=>"1"}
          }],
          :nested => {
            :errors => [{
              :message => "badder juju",
              :path=>["nested_attribute"],
              :extensions=> {:errorClass=>"VALIDATION", :legacyCode=>"2"}
            }]
          }
        }
        errors = Braintree::ValidationErrorCollection.new(hash)
        errors.deep_size.should == 2
      end

      it "returns the size of multiple nestings of errors" do
        hash = {
          :errors => [{
            :message => "bad juju",
            :path=>["attribute1"],
            :extensions=> {:errorClass=>"VALIDATION", :legacyCode=>"1"}
          }],
          :nested => {
            :errors => [{
              :message => "bad juju",
              :path=>["attribute2"],
              :extensions=> {:errorClass=>"VALIDATION", :legacyCode=>"2"}
            },{
              :message => "bad juju",
              :path=>["attribute3"],
              :extensions=> {:errorClass=>"VALIDATION", :legacyCode=>"3"}
            }],
            :deeply_nested => {
              :errors => [{
                :message => "bad juju",
                :path=>["attribute4"],
                :extensions=> {:errorClass=>"VALIDATION", :legacyCode=>"4"}
              }]
            }
          },
          :nested_again => {
            :errors => [{
              :message => "bad juju",
              :path=>["attribute5"],
              :extensions=> {:errorClass=>"VALIDATION", :legacyCode=>"5"}
            }]
          }
        }
        errors = Braintree::ValidationErrorCollection.new(hash)
        errors.deep_size.should == 5
      end
    end

    describe "deep_errors" do
      it "returns errors from all levels" do
        hash = {
          :errors => [{
            :message => "bad juju",
            :path=>["attribute1"],
            :extensions=> {:errorClass=>"VALIDATION", :legacyCode=>"1"}
          }],
          :nested => {
            :errors => [{
              :message => "bad juju",
              :path=>["attribute2"],
              :extensions=> {:errorClass=>"VALIDATION", :legacyCode=>"2"}
            },{
              :message => "bad juju",
              :path=>["attribute3"],
              :extensions=> {:errorClass=>"VALIDATION", :legacyCode=>"3"}
            }],
            :deeply_nested => {
              :errors => [{
                :message => "bad juju",
                :path=>["attribute4"],
                :extensions=> {:errorClass=>"VALIDATION", :legacyCode=>"4"}
              }]
            }
          },
          :nested_again => {
            :errors => [{
              :message => "bad juju",
              :path=>["attribute5"],
              :extensions=> {:errorClass=>"VALIDATION", :legacyCode=>"5"}
            }]
          }
        }
        errors = Braintree::ValidationErrorCollection.new(hash)
        errors.deep_errors.map { |e| e.code }.sort.should == [1, 2, 3, 4, 5]
      end
    end

    describe "shallow_errors" do
      it "returns errors on one level" do
        hash = {
          :errors => [{
            :message => "bad juju",
            :path=>["attribute1"],
            :extensions=> {:errorClass=>"VALIDATION", :legacyCode=>"1"}
          }],
          :nested => {
            :errors => [{
              :message => "bad juju",
              :path=>["attribute2"],
              :extensions=> {:errorClass=>"VALIDATION", :legacyCode=>"2"}
            },{
              :message => "bad juju",
              :path=>["attribute3"],
              :extensions=> {:errorClass=>"VALIDATION", :legacyCode=>"3"}
            }],
            :deeply_nested => {
              :errors => [{
                :message => "bad juju",
                :path=>["attribute4"],
                :extensions=> {:errorClass=>"VALIDATION", :legacyCode=>"4"}
              }]
            }
          },
          :nested_again => {
            :errors => [{
              :message => "bad juju",
              :path=>["attribute5"],
              :extensions=> {:errorClass=>"VALIDATION", :legacyCode=>"5"}
            }]
          }
        }
        errors = Braintree::ValidationErrorCollection.new(hash)
        errors.shallow_errors.map {|e| e.code}.should == [1]
        errors.for(:nested).shallow_errors.map {|e| e.code}.should == [2,3]
        errors.for(:nested).for(:deeply_nested).shallow_errors.map {|e| e.code}.should == [4]
        errors.for(:nested_again).shallow_errors.map {|e| e.code}.should == [5]
      end
    end
  end
end
