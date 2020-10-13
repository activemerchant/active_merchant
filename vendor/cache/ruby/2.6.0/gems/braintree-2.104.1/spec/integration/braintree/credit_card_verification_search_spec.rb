require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::CreditCardVerification, "search" do
  it "correctly returns a result with no matches" do
    collection = Braintree::CreditCardVerification.search do |search|
      search.credit_card_cardholder_name.is "thisnameisnotreal"
    end

    collection.maximum_size.should == 0
  end

  it "can search on text fields" do
    unsuccessful_result = Braintree::Customer.create(
      :credit_card => {
      :cardholder_name => "Tom Smith",
      :expiration_date => "05/2012",
      :number => Braintree::Test::CreditCardNumbers::FailsSandboxVerification::Visa,
      :options => {
      :verify_card => true
    }
    })

    verification = unsuccessful_result.credit_card_verification

    search_criteria = {
      :credit_card_cardholder_name => "Tom Smith",
      :credit_card_expiration_date => "05/2012",
      :credit_card_number => Braintree::Test::CreditCardNumbers::FailsSandboxVerification::Visa
    }

    search_criteria.each do |criterion, value|
      collection = Braintree::CreditCardVerification.search do |search|
        search.id.is verification.id
        search.send(criterion).is value
      end
      collection.maximum_size.should == 1
      collection.first.id.should == verification.id

      collection = Braintree::CreditCardVerification.search do |search|
        search.id.is verification.id
        search.send(criterion).is("invalid_attribute")
      end
      collection.should be_empty
    end

    collection = Braintree::CreditCardVerification.search do |search|
      search.id.is verification.id
      search_criteria.each do |criterion, value|
        search.send(criterion).is value
      end
    end

    collection.maximum_size.should == 1
    collection.first.id.should == verification.id
  end

  describe "multiple value fields" do
    it "searches on ids" do
      unsuccessful_result1 = Braintree::Customer.create(
        :credit_card => {
        :cardholder_name => "Tom Smith",
        :expiration_date => "05/2012",
        :number => Braintree::Test::CreditCardNumbers::FailsSandboxVerification::Visa,
        :options => {
        :verify_card => true
      }
      })

      verification_id1 = unsuccessful_result1.credit_card_verification.id

      unsuccessful_result2 = Braintree::Customer.create(
        :credit_card => {
        :cardholder_name => "Tom Smith",
        :expiration_date => "05/2012",
        :number => Braintree::Test::CreditCardNumbers::FailsSandboxVerification::Visa,
        :options => {
        :verify_card => true
      }
      })

      verification_id2 = unsuccessful_result2.credit_card_verification.id

      collection = Braintree::CreditCardVerification.search do |search|
        search.ids.in verification_id1, verification_id2
      end

      collection.maximum_size.should == 2
    end
  end

  context "range fields" do
    it "searches on created_at" do
      unsuccessful_result = Braintree::Customer.create(
        :credit_card => {
        :cardholder_name => "Tom Smith",
        :expiration_date => "05/2012",
        :number => Braintree::Test::CreditCardNumbers::FailsSandboxVerification::Visa,
        :options => {
        :verify_card => true
      }
      })

      verification = unsuccessful_result.credit_card_verification

      created_at = verification.created_at

      collection = Braintree::CreditCardVerification.search do |search|
        search.id.is verification.id
        search.created_at.between(
          created_at - 60,
          created_at + 60
        )
      end

      collection.maximum_size.should == 1
      collection.first.id.should == verification.id

      collection = Braintree::CreditCardVerification.search do |search|
        search.id.is verification.id
        search.created_at >= created_at - 1
      end

      collection.maximum_size.should == 1
      collection.first.id.should == verification.id

      collection = Braintree::CreditCardVerification.search do |search|
        search.id.is verification.id
        search.created_at <= created_at + 1
      end

      collection.maximum_size.should == 1
      collection.first.id.should == verification.id

      collection = Braintree::CreditCardVerification.search do |search|
        search.id.is verification.id
        search.created_at.between(
          created_at - 300,
          created_at - 100
        )
      end

      collection.maximum_size.should == 0

      collection = Braintree::CreditCardVerification.search do |search|
        search.id.is verification.id
        search.created_at.is created_at
      end

      collection.maximum_size.should == 1
      collection.first.id.should == verification.id
    end
  end

  context "pagination" do
    it "is not affected by new results on the server" do
      cardholder_name = "Tom Smith #{rand(1_000_000)}"
      5.times do |index|
        Braintree::Customer.create(
          :credit_card => {
            :cardholder_name => "#{cardholder_name} #{index}",
            :expiration_date => "05/2012",
            :number => Braintree::Test::CreditCardNumbers::FailsSandboxVerification::Visa,
            :options => {
              :verify_card => true
            }
          })
      end

      collection = Braintree::CreditCardVerification.search do |search|
        search.credit_card_cardholder_name.starts_with cardholder_name
      end

      count_before_new_data = collection.instance_variable_get(:@ids).count

      new_cardholder_name = "#{cardholder_name} shouldn't be included"
      Braintree::Customer.create(
        :credit_card => {
          :cardholder_name => new_cardholder_name,
          :expiration_date => "05/2012",
          :number => Braintree::Test::CreditCardNumbers::FailsSandboxVerification::Visa,
          :options => {
            :verify_card => true
          }
        })

      verifications = collection.to_a
      expect(verifications.count).to eq(count_before_new_data)

      cardholder_names = verifications.map { |verification| verification.credit_card[:cardholder_name] }
      expect(cardholder_names).to_not include(new_cardholder_name)
    end
  end
end
