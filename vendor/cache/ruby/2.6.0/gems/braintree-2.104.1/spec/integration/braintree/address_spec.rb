# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::Address do
  describe "self.create" do
    it "returns a successful result if valid" do
      customer = Braintree::Customer.create!(:last_name => "Wilson")
      result = Braintree::Address.create(
        :customer_id => customer.id,
        :first_name => "Ben",
        :last_name => "Moore",
        :company => "Moore Co.",
        :street_address => "1811 E Main St",
        :extended_address => "Suite 200",
        :locality => "Chicago",
        :region => "Illinois",
        :postal_code => "60622",
        :country_name => "United States of America"
      )
      result.success?.should == true
      result.address.customer_id.should == customer.id
      result.address.first_name.should == "Ben"
      result.address.last_name.should == "Moore"
      result.address.company.should == "Moore Co."
      result.address.street_address.should == "1811 E Main St"
      result.address.extended_address.should == "Suite 200"
      result.address.locality.should == "Chicago"
      result.address.region.should == "Illinois"
      result.address.postal_code.should == "60622"
      result.address.country_name.should == "United States of America"
      result.address.country_code_alpha2.should == "US"
      result.address.country_code_alpha3.should == "USA"
      result.address.country_code_numeric.should == "840"
    end

    it "accepts country_codes" do
      customer = Braintree::Customer.create!
      result = Braintree::Address.create(
        :customer_id => customer.id,
        :country_code_alpha2 => "AS",
        :country_code_alpha3 => "ASM",
        :country_code_numeric => "16"
      )
      result.success?.should == true
      result.address.country_name.should == "American Samoa"
      result.address.country_code_alpha2.should == "AS"
      result.address.country_code_alpha3.should == "ASM"
      result.address.country_code_numeric.should == "016"
    end

    it "accepts utf-8 country names" do
      customer = Braintree::Customer.create!
      result = Braintree::Address.create(
        :customer_id => customer.id,
        :country_name => "Åland"
      )
      result.success?.should == true
      result.address.country_name.should == "Åland"
    end

    it "returns an error response given inconsistent country codes" do
      customer = Braintree::Customer.create!
      result = Braintree::Address.create(
        :customer_id => customer.id,
        :country_code_alpha2 => "AS",
        :country_code_alpha3 => "USA"
      )
      result.success?.should == false
      result.errors.for(:address).on(:base).map {|e| e.code}.should include(Braintree::ErrorCodes::Address::InconsistentCountry)
    end

    it "returns an error response given an invalid country_code_alpha2" do
      customer = Braintree::Customer.create!
      result = Braintree::Address.create(
        :customer_id => customer.id,
        :country_code_alpha2 => "zz"
      )
      result.success?.should == false
      result.errors.for(:address).on(:country_code_alpha2).map {|e| e.code}.should include(Braintree::ErrorCodes::Address::CountryCodeAlpha2IsNotAccepted)
    end

    it "returns an error response given an invalid country_code_alpha3" do
      customer = Braintree::Customer.create!
      result = Braintree::Address.create(
        :customer_id => customer.id,
        :country_code_alpha3 => "zzz"
      )
      result.success?.should == false
      result.errors.for(:address).on(:country_code_alpha3).map {|e| e.code}.should include(Braintree::ErrorCodes::Address::CountryCodeAlpha3IsNotAccepted)
    end

    it "returns an error response given an invalid country_code_numeric" do
      customer = Braintree::Customer.create!
      result = Braintree::Address.create(
        :customer_id => customer.id,
        :country_code_numeric => "zz"
      )
      result.success?.should == false
      result.errors.for(:address).on(:country_code_numeric).map {|e| e.code}.should include(Braintree::ErrorCodes::Address::CountryCodeNumericIsNotAccepted)
    end

    it "returns an error response if invalid" do
      customer = Braintree::Customer.create!(:last_name => "Wilson")
      result = Braintree::Address.create(
        :customer_id => customer.id,
        :country_name => "United States of Invalid"
      )
      result.success?.should == false
      result.errors.for(:address).on(:country_name)[0].message.should == "Country name is not an accepted country."
    end

    it "allows -, _, A-Z, a-z, and 0-9 in customer_id without raising an ArgumentError" do
      expect do
        Braintree::Address.create(:customer_id => "hyphen-")
      end.to raise_error(Braintree::NotFoundError)
      expect do
        Braintree::Address.create(:customer_id => "underscore_")
      end.to raise_error(Braintree::NotFoundError)
      expect do
        Braintree::Address.create(:customer_id => "CAPS")
      end.to raise_error(Braintree::NotFoundError)
    end
  end

  describe "self.create!" do
    it "returns the address if valid" do
      customer = Braintree::Customer.create!(:last_name => "Miller")
      address = Braintree::Address.create!(
        :customer_id => customer.id,
        :street_address => "1812 E Main St",
        :extended_address => "Suite 201",
        :locality => "Bartlett",
        :region => "IL",
        :postal_code => "60623",
        :country_name => "United States of America"
      )
      address.customer_id.should == customer.id
      address.street_address.should == "1812 E Main St"
      address.extended_address.should == "Suite 201"
      address.locality.should == "Bartlett"
      address.region.should == "IL"
      address.postal_code.should == "60623"
      address.country_name.should == "United States of America"
    end

    it "raises a ValidationsFailed if invalid" do
      customer = Braintree::Customer.create!(:last_name => "Wilson")
      expect do
        Braintree::Address.create!(
          :customer_id => customer.id,
          :country_name => "United States of Invalid"
        )
      end.to raise_error(Braintree::ValidationsFailed)
    end
  end

  describe "self.delete" do
    it "deletes the address given a customer id and an address id" do
      customer = Braintree::Customer.create!(:last_name => "Wilson")
      address = Braintree::Address.create!(:customer_id => customer.id, :street_address => "123 E Main St")
      Braintree::Address.delete(customer.id, address.id).success?.should == true
      expect do
        Braintree::Address.find(customer.id, address.id)
      end.to raise_error(Braintree::NotFoundError)
    end

    it "deletes the address given a customer and an address id" do
      customer = Braintree::Customer.create!(:last_name => "Wilson")
      address = Braintree::Address.create!(:customer_id => customer.id, :street_address => "123 E Main St")
      Braintree::Address.delete(customer, address.id).success?.should == true
      expect do
        Braintree::Address.find(customer.id, address.id)
      end.to raise_error(Braintree::NotFoundError)
    end
  end

  describe "self.find" do
    it "finds the address given a customer and an address id" do
      customer = Braintree::Customer.create!(:last_name => "Wilson")
      address = Braintree::Address.create!(:customer_id => customer.id, :street_address => "123 E Main St")
      Braintree::Address.find(customer, address.id).should == address
    end

    it "finds the address given a customer id and an address id" do
      customer = Braintree::Customer.create!(:last_name => "Wilson")
      address = Braintree::Address.create!(:customer_id => customer.id, :street_address => "123 E Main St")
      Braintree::Address.find(customer.id, address.id).should == address
    end

    it "raises a NotFoundError if it cannot be found because of customer id" do
      customer = Braintree::Customer.create!(:last_name => "Wilson")
      address = Braintree::Address.create!(:customer_id => customer.id, :street_address => "123 E Main St")
      expect do
        Braintree::Address.find("invalid", address.id)
      end.to raise_error(
        Braintree::NotFoundError,
        "address for customer \"invalid\" with id #{address.id.inspect} not found")
    end

    it "raises a NotFoundError if it cannot be found because of address id" do
      customer = Braintree::Customer.create!(:last_name => "Wilson")
      address = Braintree::Address.create!(:customer_id => customer.id, :street_address => "123 E Main St")
      expect do
        Braintree::Address.find(customer, "invalid")
      end.to raise_error(
        Braintree::NotFoundError,
        "address for customer \"#{customer.id}\" with id \"invalid\" not found")
    end
  end

  describe "self.update" do
    it "raises NotFoundError if the address can't be found" do
      customer = Braintree::Customer.create!(:last_name => "Wilson")
      address = Braintree::Address.create!(:customer_id => customer.id, :street_address => "123 E Main St")
      expect do
        Braintree::Address.update(customer.id, "bad-id", {})
      end.to raise_error(Braintree::NotFoundError)
    end

    it "returns a success response with the updated address if valid" do
      customer = Braintree::Customer.create!(:last_name => "Miller")
      address = Braintree::Address.create!(
        :customer_id => customer.id,
        :street_address => "1812 E Old St",
        :extended_address => "Suite Old 201",
        :locality => "Old Chicago",
        :region => "IL",
        :postal_code => "60620",
        :country_name => "United States of America"
      )
      result = Braintree::Address.update(
        customer.id,
        address.id,
        :street_address => "123 E New St",
        :extended_address => "New Suite 3",
        :locality => "Chicago",
        :region => "Illinois",
        :postal_code => "60621",
        :country_name => "United States of America"
      )
      result.success?.should == true
      result.address.street_address.should == "123 E New St"
      result.address.extended_address.should == "New Suite 3"
      result.address.locality.should == "Chicago"
      result.address.region.should == "Illinois"
      result.address.postal_code.should == "60621"
      result.address.country_name.should == "United States of America"
      result.address.country_code_alpha2.should == "US"
      result.address.country_code_alpha3.should == "USA"
      result.address.country_code_numeric.should == "840"
    end

    it "accepts country_codes" do
      customer = Braintree::Customer.create!(:last_name => "Miller")
      address = Braintree::Address.create!(
        :customer_id => customer.id,
        :country_name => "Angola"
      )
      result = Braintree::Address.update(
        customer.id,
        address.id,
        :country_name => "Azerbaijan"
      )

      result.success?.should == true
      result.address.country_name.should == "Azerbaijan"
      result.address.country_code_alpha2.should == "AZ"
      result.address.country_code_alpha3.should == "AZE"
      result.address.country_code_numeric.should == "031"
    end

    it "returns an error response if invalid" do
      customer = Braintree::Customer.create!(:last_name => "Miller")
      address = Braintree::Address.create!(
        :customer_id => customer.id,
        :country_name => "United States of America"
      )
      result = Braintree::Address.update(
        customer.id,
        address.id,
        :street_address => "123 E New St",
        :country_name => "United States of Invalid"
      )
      result.success?.should == false
      result.errors.for(:address).on(:country_name)[0].message.should == "Country name is not an accepted country."
    end
  end

  describe "self.update!" do
    it "raises NotFoundError if the address can't be found" do
      customer = Braintree::Customer.create!(:last_name => "Wilson")
      address = Braintree::Address.create!(:customer_id => customer.id, :street_address => "123 E Main St")
      expect do
        Braintree::Address.update!(customer.id, "bad-id", {})
      end.to raise_error(Braintree::NotFoundError)
    end

    it "returns the updated address if valid" do
      customer = Braintree::Customer.create!(:last_name => "Miller")
      address = Braintree::Address.create!(
        :customer_id => customer.id,
        :street_address => "1812 E Old St",
        :extended_address => "Suite Old 201",
        :locality => "Old Chicago",
        :region => "IL",
        :postal_code => "60620",
        :country_name => "United States of America"
      )
      updated_address = Braintree::Address.update!(
        customer.id,
        address.id,
        :street_address => "123 E New St",
        :extended_address => "New Suite 3",
        :locality => "Chicago",
        :region => "Illinois",
        :postal_code => "60621",
        :country_name => "United States of America"
      )
      updated_address.should == address
      updated_address.street_address.should == "123 E New St"
      updated_address.extended_address.should == "New Suite 3"
      updated_address.locality.should == "Chicago"
      updated_address.region.should == "Illinois"
      updated_address.postal_code.should == "60621"
      updated_address.country_name.should == "United States of America"
    end

    it "raises a ValidationsFailed invalid" do
      customer = Braintree::Customer.create!(:last_name => "Miller")
      address = Braintree::Address.create!(
        :customer_id => customer.id,
        :country_name => "United States of America"
      )
      expect do
        Braintree::Address.update!(
          customer.id,
          address.id,
          :street_address => "123 E New St",
          :country_name => "United States of Invalid"
        )
      end.to raise_error(Braintree::ValidationsFailed)
    end
  end


  describe "delete" do
    it "deletes the address" do
      customer = Braintree::Customer.create!(:last_name => "Wilson")
      address = Braintree::Address.create!(:customer_id => customer.id, :street_address => "123 E Main St")
      address.delete.success?.should == true
      expect do
        Braintree::Address.find(customer.id, address.id)
      end.to raise_error(Braintree::NotFoundError)
    end
  end

  describe "update" do
    it "returns a success response and updates the address if valid" do
      customer = Braintree::Customer.create!(:last_name => "Miller")
      address = Braintree::Address.create!(
        :customer_id => customer.id,
        :street_address => "1812 E Old St",
        :extended_address => "Suite Old 201",
        :locality => "Old Chicago",
        :region => "IL",
        :postal_code => "60620",
        :country_name => "United States of America"
      )
      result = address.update(
        :street_address => "123 E New St",
        :extended_address => "New Suite 3",
        :locality => "Chicago",
        :region => "Illinois",
        :postal_code => "60621",
        :country_name => "United States of America"
      )
      result.success?.should == true
      result.address.should == address
      address.street_address.should == "123 E New St"
      address.extended_address.should == "New Suite 3"
      address.locality.should == "Chicago"
      address.region.should == "Illinois"
      address.postal_code.should == "60621"
      address.country_name.should == "United States of America"
    end

    it "returns an error response if invalid" do
      customer = Braintree::Customer.create!(:last_name => "Miller")
      address = Braintree::Address.create!(
        :customer_id => customer.id,
        :country_name => "United States of America"
      )
      result = address.update(
        :street_address => "123 E New St",
        :country_name => "United States of Invalid"
      )
      result.success?.should == false
      result.errors.for(:address).on(:country_name)[0].message.should == "Country name is not an accepted country."
    end
  end

  describe "update!" do
    it "returns true and updates the address if valid" do
      customer = Braintree::Customer.create!(:last_name => "Miller")
      address = Braintree::Address.create!(
        :customer_id => customer.id,
        :street_address => "1812 E Old St",
        :extended_address => "Suite Old 201",
        :locality => "Old Chicago",
        :region => "IL",
        :postal_code => "60620",
        :country_name => "United States of America"
      )
      address.update!(
        :street_address => "123 E New St",
        :extended_address => "New Suite 3",
        :locality => "Chicago",
        :region => "Illinois",
        :postal_code => "60621",
        :country_name => "United States of America"
      ).should == address
      address.street_address.should == "123 E New St"
      address.extended_address.should == "New Suite 3"
      address.locality.should == "Chicago"
      address.region.should == "Illinois"
      address.postal_code.should == "60621"
      address.country_name.should == "United States of America"
    end

    it "raises a ValidationsFailed invalid" do
      customer = Braintree::Customer.create!(:last_name => "Miller")
      address = Braintree::Address.create!(
        :customer_id => customer.id,
        :country_name => "United States of America"
      )
      expect do
        address.update!(
          :street_address => "123 E New St",
          :country_name => "United States of Invalid"
        )
      end.to raise_error(Braintree::ValidationsFailed)
    end
  end
end
