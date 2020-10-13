require File.expand_path(File.dirname(__FILE__) + "/../../spec_helper")

DEPRECATED_APPLICATION_PARAMS = {
  :applicant_details => {
    :first_name => "Joe",
    :last_name => "Bloggs",
    :email => "joe@bloggs.com",
    :phone => "3125551234",
    :address => {
      :street_address => "123 Credibility St.",
      :postal_code => "60606",
      :locality => "Chicago",
      :region => "IL",
    },
    :date_of_birth => "10/9/1980",
    :ssn => "123-00-1234",
    :routing_number => "011103093",
    :account_number => "43759348798",
    :tax_id => "111223333",
    :company_name => "Joe's Junkyard"
  },
  :tos_accepted => true,
  :master_merchant_account_id => "sandbox_master_merchant_account"
}

VALID_APPLICATION_PARAMS = {
  :individual => {
    :first_name => "Joe",
    :last_name => "Bloggs",
    :email => "joe@bloggs.com",
    :phone => "3125551234",
    :address => {
      :street_address => "123 Credibility St.",
      :postal_code => "60606",
      :locality => "Chicago",
      :region => "IL",
    },
    :date_of_birth => "10/9/1980",
    :ssn => "123-00-1234",
  },
  :business => {
    :legal_name => "Joe's Bloggs",
    :dba_name => "Joe's Junkyard",
    :tax_id => "123456789",
    :address => {
      :street_address => "456 Fake St",
      :postal_code => "48104",
      :locality => "Ann Arbor",
      :region => "MI",
    }
  },
  :funding => {
    :destination => Braintree::MerchantAccount::FundingDestination::Bank,
    :routing_number => "011103093",
    :account_number => "43759348798",
    :descriptor => "Joes Bloggs MI",
  },
  :tos_accepted => true,
  :master_merchant_account_id => "sandbox_master_merchant_account"
}

describe Braintree::MerchantAccount do
  describe "all" do
    it "returns all merchant accounts" do
      gateway = Braintree::Gateway.new(
        :client_id => "client_id$#{Braintree::Configuration.environment}$integration_client_id",
        :client_secret => "client_secret$#{Braintree::Configuration.environment}$integration_client_secret",
        :logger => Logger.new("/dev/null")
      )

      code = Braintree::OAuthTestHelper.create_grant(gateway, {
        :merchant_public_id => "integration_merchant_id",
        :scope => "read_write"
      })

      result = gateway.oauth.create_token_from_code(
        :code => code,
        :scope => "read_write"
      )

      gateway = Braintree::Gateway.new(
        :access_token => result.credentials.access_token,
        :logger => Logger.new("/dev/null")
      )

      result = gateway.merchant_account.all
      result.should be_success
      result.merchant_accounts.count.should > 20
    end

    it "returns merchant account with correct attributes" do
      gateway = Braintree::Gateway.new(
        :client_id => "client_id$#{Braintree::Configuration.environment}$integration_client_id",
        :client_secret => "client_secret$#{Braintree::Configuration.environment}$integration_client_secret",
        :logger => Logger.new("/dev/null")
      )

      result = gateway.merchant.create(
        :email => "name@email.com",
        :country_code_alpha3 => "USA",
        :payment_methods => ["credit_card", "paypal"]
      )

      gateway = Braintree::Gateway.new(
        :access_token => result.credentials.access_token,
        :logger => Logger.new("/dev/null")
      )

      result = gateway.merchant_account.all
      result.should be_success
      result.merchant_accounts.count.should == 1
      result.merchant_accounts.first.currency_iso_code.should == "USD"
      result.merchant_accounts.first.status.should == "active"
      result.merchant_accounts.first.default.should == true
    end

    it "returns all merchant accounts for read_only scoped grants" do
      gateway = Braintree::Gateway.new(
        :client_id => "client_id$#{Braintree::Configuration.environment}$integration_client_id",
        :client_secret => "client_secret$#{Braintree::Configuration.environment}$integration_client_secret",
        :logger => Logger.new("/dev/null")
      )

      code = Braintree::OAuthTestHelper.create_grant(gateway, {
        :merchant_public_id => "integration_merchant_id",
        :scope => "read_only"
      })

      result = gateway.oauth.create_token_from_code(
        :code => code,
        :scope => "read_only"
      )

      gateway = Braintree::Gateway.new(
        :access_token => result.credentials.access_token,
        :logger => Logger.new("/dev/null")
      )

      result = gateway.merchant_account.all
      result.should be_success
      result.merchant_accounts.count.should > 20
    end
  end

  describe "create" do
    it "accepts the deprecated parameters" do
      result = Braintree::MerchantAccount.create(DEPRECATED_APPLICATION_PARAMS)

      result.should be_success
      result.merchant_account.status.should == Braintree::MerchantAccount::Status::Pending
      result.merchant_account.master_merchant_account.id.should == "sandbox_master_merchant_account"
    end

    it "creates a merchant account with the new parameters and doesn't require an id" do
      result = Braintree::MerchantAccount.create(VALID_APPLICATION_PARAMS)

      result.should be_success
      result.merchant_account.status.should == Braintree::MerchantAccount::Status::Pending
      result.merchant_account.master_merchant_account.id.should == "sandbox_master_merchant_account"
    end

    it "allows an id to be passed" do
      random_number = rand(10000)
      sub_merchant_account_id = "sub_merchant_account_id#{random_number}"
      result = Braintree::MerchantAccount.create(
        VALID_APPLICATION_PARAMS.merge(
          :id => sub_merchant_account_id
        )
      )

      result.should be_success
      result.merchant_account.status.should == Braintree::MerchantAccount::Status::Pending
      result.merchant_account.id.should == sub_merchant_account_id
      result.merchant_account.master_merchant_account.id.should == "sandbox_master_merchant_account"
    end

    it "handles unsuccessful results" do
      result = Braintree::MerchantAccount.create({})
      result.should_not be_success
      result.errors.for(:merchant_account).on(:master_merchant_account_id).first.code.should == Braintree::ErrorCodes::MerchantAccount::MasterMerchantAccountIdIsRequired
    end

    it "requires all fields" do
      result = Braintree::MerchantAccount.create(
        :master_merchant_account_id => "sandbox_master_merchant_account"
      )
      result.should_not be_success
      result.errors.for(:merchant_account).on(:tos_accepted).first.code.should == Braintree::ErrorCodes::MerchantAccount::TosAcceptedIsRequired
    end

    context "funding destination" do
      it "accepts a bank" do
        params = VALID_APPLICATION_PARAMS.dup
        params[:funding][:destination] = ::Braintree::MerchantAccount::FundingDestination::Bank
        result = Braintree::MerchantAccount.create(params)

        result.should be_success
      end

      it "accepts an email" do
        params = VALID_APPLICATION_PARAMS.dup
        params[:funding][:destination] = ::Braintree::MerchantAccount::FundingDestination::Email
        params[:funding][:email] = "joebloggs@compuserve.com"
        result = Braintree::MerchantAccount.create(params)

        result.should be_success
      end

      it "accepts a mobile_phone" do
        params = VALID_APPLICATION_PARAMS.dup
        params[:funding][:destination] = ::Braintree::MerchantAccount::FundingDestination::MobilePhone
        params[:funding][:mobile_phone] = "3125882300"
        result = Braintree::MerchantAccount.create(params)

        result.should be_success
      end
    end
  end

  describe "create!" do
    it "creates a merchant account with the new parameters and doesn't require an id" do
      merchant_account = Braintree::MerchantAccount.create!(VALID_APPLICATION_PARAMS)

      merchant_account.status.should == Braintree::MerchantAccount::Status::Pending
      merchant_account.master_merchant_account.id.should == "sandbox_master_merchant_account"
    end
  end

  describe "create_for_currency" do
    it "creates a new merchant account for currency" do
      result = SpecHelper::create_merchant
      result.should be_success

      gateway = Braintree::Gateway.new(
        :access_token => result.credentials.access_token,
        :logger => Logger.new("/dev/null")
      )

      result = gateway.merchant_account.create_for_currency(
        :currency => "JPY"
      )
      result.should be_success
      result.merchant_account.currency_iso_code.should == "JPY"
    end

    it "returns error if a merchant account already exists for that currency" do
      result = SpecHelper::create_merchant
      result.should be_success

      gateway = Braintree::Gateway.new(
        :access_token => result.credentials.access_token,
        :logger => Logger.new("/dev/null")
      )

      result = gateway.merchant_account.create_for_currency(
        :currency => "USD"
      )
      result.should be_success

      result = gateway.merchant_account.create_for_currency(
        :currency => "USD"
      )
      result.should_not be_success

      errors = result.errors.for(:merchant).on(:currency)
      errors[0].code.should == Braintree::ErrorCodes::Merchant::MerchantAccountExistsForCurrency
    end

    it "returns error if no currency is provided" do
      result = SpecHelper::create_merchant
      result.should be_success

      gateway = Braintree::Gateway.new(
        :access_token => result.credentials.access_token,
        :logger => Logger.new("/dev/null")
      )

      result = gateway.merchant_account.create_for_currency(
        :currency => nil
      )
      result.should_not be_success

      errors = result.errors.for(:merchant).on(:currency)
      errors[0].code.should == Braintree::ErrorCodes::Merchant::CurrencyIsRequired

      result = gateway.merchant_account.create_for_currency({})
      result.should_not be_success

      errors = result.errors.for(:merchant).on(:currency)
      errors[0].code.should == Braintree::ErrorCodes::Merchant::CurrencyIsRequired
    end

    it "returns error if a currency is not supported" do
      result = SpecHelper::create_merchant
      result.should be_success

      gateway = Braintree::Gateway.new(
        :access_token => result.credentials.access_token,
        :logger => Logger.new("/dev/null")
      )

      result = gateway.merchant_account.create_for_currency(
        :currency => "FAKE_CURRENCY"
      )
      result.should_not be_success

      errors = result.errors.for(:merchant).on(:currency)
      errors[0].code.should == Braintree::ErrorCodes::Merchant::CurrencyIsInvalid
    end

    it "returns error if id is passed and already taken" do
      result = SpecHelper::create_merchant
      result.should be_success

      gateway = Braintree::Gateway.new(
        :access_token => result.credentials.access_token,
        :logger => Logger.new("/dev/null")
      )

      merchant = result.merchant
      result = gateway.merchant_account.create_for_currency(
        :currency => "USD",
        :id => merchant.merchant_accounts.first.id
      )
      result.should_not be_success

      errors = result.errors.for(:merchant).on(:id)
      errors[0].code.should == Braintree::ErrorCodes::Merchant::MerchantAccountExistsForId
    end
  end

  describe "find" do
    it "finds the merchant account with the given token" do
      result = Braintree::MerchantAccount.create(VALID_APPLICATION_PARAMS)
      result.should be_success
      result.merchant_account.status.should == Braintree::MerchantAccount::Status::Pending

      id = result.merchant_account.id
      merchant_account = Braintree::MerchantAccount.find(id)

      merchant_account.status.should == Braintree::MerchantAccount::Status::Active
      merchant_account.individual_details.first_name.should == VALID_APPLICATION_PARAMS[:individual][:first_name]
      merchant_account.individual_details.last_name.should == VALID_APPLICATION_PARAMS[:individual][:last_name]
    end

    it "retrieves the currency iso code for an existing master merchant account" do
      merchant_account = Braintree::MerchantAccount.find("sandbox_master_merchant_account")

      merchant_account.currency_iso_code.should == "USD"
    end

    it "raises a NotFoundError exception if merchant account cannot be found" do
      expect do
        Braintree::MerchantAccount.find("non-existant")
      end.to raise_error(Braintree::NotFoundError, 'Merchant account with id non-existant not found')
    end
  end

  describe "update" do
    it "updates the Merchant Account info" do
      params = VALID_APPLICATION_PARAMS.clone
      params.delete(:tos_accepted)
      params.delete(:master_merchant_account_id)
      params[:individual][:first_name] = "John"
      params[:individual][:last_name] = "Doe"
      params[:individual][:email] = "john.doe@example.com"
      params[:individual][:date_of_birth] = "1970-01-01"
      params[:individual][:phone] = "3125551234"
      params[:individual][:address][:street_address] = "123 Fake St"
      params[:individual][:address][:locality] = "Chicago"
      params[:individual][:address][:region] = "IL"
      params[:individual][:address][:postal_code] = "60622"
      params[:business][:dba_name] = "James's Bloggs"
      params[:business][:legal_name] = "James's Bloggs Inc"
      params[:business][:tax_id] = "123456789"
      params[:business][:address][:street_address] = "999 Fake St"
      params[:business][:address][:locality] = "Miami"
      params[:business][:address][:region] = "FL"
      params[:business][:address][:postal_code] = "99999"
      params[:funding][:account_number] = "43759348798"
      params[:funding][:routing_number] = "071000013"
      params[:funding][:email] = "check@this.com"
      params[:funding][:mobile_phone] = "1234567890"
      params[:funding][:destination] = Braintree::MerchantAccount::FundingDestination::MobilePhone
      result = Braintree::MerchantAccount.update("sandbox_sub_merchant_account", params)
      result.should be_success
      result.merchant_account.status.should == "active"
      result.merchant_account.id.should == "sandbox_sub_merchant_account"
      result.merchant_account.master_merchant_account.id.should == "sandbox_master_merchant_account"
      result.merchant_account.individual_details.first_name.should == "John"
      result.merchant_account.individual_details.last_name.should == "Doe"
      result.merchant_account.individual_details.email.should == "john.doe@example.com"
      result.merchant_account.individual_details.date_of_birth.should == "1970-01-01"
      result.merchant_account.individual_details.phone.should == "3125551234"
      result.merchant_account.individual_details.address_details.street_address.should == "123 Fake St"
      result.merchant_account.individual_details.address_details.locality.should == "Chicago"
      result.merchant_account.individual_details.address_details.region.should == "IL"
      result.merchant_account.individual_details.address_details.postal_code.should == "60622"
      result.merchant_account.business_details.dba_name.should == "James's Bloggs"
      result.merchant_account.business_details.legal_name.should == "James's Bloggs Inc"
      result.merchant_account.business_details.tax_id.should == "123456789"
      result.merchant_account.business_details.address_details.street_address.should == "999 Fake St"
      result.merchant_account.business_details.address_details.locality.should == "Miami"
      result.merchant_account.business_details.address_details.region.should == "FL"
      result.merchant_account.business_details.address_details.postal_code.should == "99999"
      result.merchant_account.funding_details.account_number_last_4.should == "8798"
      result.merchant_account.funding_details.routing_number.should == "071000013"
      result.merchant_account.funding_details.email.should == "check@this.com"
      result.merchant_account.funding_details.mobile_phone.should == "1234567890"
      result.merchant_account.funding_details.destination.should == Braintree::MerchantAccount::FundingDestination::MobilePhone
      result.merchant_account.funding_details.descriptor.should == "Joes Bloggs MI"
    end

    it "does not require all fields" do
      result = Braintree::MerchantAccount.update("sandbox_sub_merchant_account", { :individual => { :first_name => "Jose" } })
      result.should be_success
    end

    it "handles validation errors for blank fields" do
      result = Braintree::MerchantAccount.update(
        "sandbox_sub_merchant_account", {
          :individual => {
            :first_name => "",
            :last_name => "",
            :email => "",
            :phone => "",
            :address => {
              :street_address => "",
              :postal_code => "",
              :locality => "",
              :region => "",
            },
            :date_of_birth => "",
            :ssn => "",
          },
          :business => {
            :legal_name => "",
            :dba_name => "",
            :tax_id => ""
          },
          :funding => {
            :destination => "",
            :routing_number => "",
            :account_number => ""
          },
        }
      )

      result.should_not be_success
      result.errors.for(:merchant_account).for(:individual).on(:first_name).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Individual::FirstNameIsRequired]
      result.errors.for(:merchant_account).for(:individual).on(:last_name).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Individual::LastNameIsRequired]
      result.errors.for(:merchant_account).for(:individual).on(:date_of_birth).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Individual::DateOfBirthIsRequired]
      result.errors.for(:merchant_account).for(:individual).on(:email).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Individual::EmailIsRequired]
      result.errors.for(:merchant_account).for(:individual).for(:address).on(:street_address).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Individual::Address::StreetAddressIsRequired]
      result.errors.for(:merchant_account).for(:individual).for(:address).on(:postal_code).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Individual::Address::PostalCodeIsRequired]
      result.errors.for(:merchant_account).for(:individual).for(:address).on(:locality).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Individual::Address::LocalityIsRequired]
      result.errors.for(:merchant_account).for(:individual).for(:address).on(:region).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Individual::Address::RegionIsRequired]
      result.errors.for(:merchant_account).for(:funding).on(:destination).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Funding::DestinationIsRequired]
      result.errors.for(:merchant_account).on(:base).should be_empty
    end

    it "handles validation errors for invalid fields" do
      result = Braintree::MerchantAccount.update(
        "sandbox_sub_merchant_account", {
          :individual => {
            :first_name => "<>",
            :last_name => "<>",
            :email => "bad",
            :phone => "999",
            :address => {
              :street_address => "nope",
              :postal_code => "1",
              :region => "QQ",
            },
            :date_of_birth => "hah",
            :ssn => "12345",
          },
          :business => {
            :legal_name => "``{}",
            :dba_name => "{}``",
            :tax_id => "bad",
            :address => {
              :street_address => "nope",
              :postal_code => "1",
              :region => "QQ",
            },
          },
          :funding => {
            :destination => "MY WALLET",
            :routing_number => "LEATHER",
            :account_number => "BACK POCKET",
            :email => "BILLFOLD",
            :mobile_phone => "TRIFOLD"
          },
        }
      )

      result.should_not be_success
      result.errors.for(:merchant_account).for(:individual).on(:first_name).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Individual::FirstNameIsInvalid]
      result.errors.for(:merchant_account).for(:individual).on(:last_name).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Individual::LastNameIsInvalid]
      result.errors.for(:merchant_account).for(:individual).on(:email).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Individual::EmailIsInvalid]
      result.errors.for(:merchant_account).for(:individual).on(:phone).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Individual::PhoneIsInvalid]
      result.errors.for(:merchant_account).for(:individual).for(:address).on(:street_address).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Individual::Address::StreetAddressIsInvalid]
      result.errors.for(:merchant_account).for(:individual).for(:address).on(:postal_code).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Individual::Address::PostalCodeIsInvalid]
      result.errors.for(:merchant_account).for(:individual).for(:address).on(:region).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Individual::Address::RegionIsInvalid]
      result.errors.for(:merchant_account).for(:individual).on(:ssn).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Individual::SsnIsInvalid]

      result.errors.for(:merchant_account).for(:business).on(:legal_name).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Business::LegalNameIsInvalid]
      result.errors.for(:merchant_account).for(:business).on(:dba_name).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Business::DbaNameIsInvalid]
      result.errors.for(:merchant_account).for(:business).on(:tax_id).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Business::TaxIdIsInvalid]
      result.errors.for(:merchant_account).for(:business).for(:address).on(:street_address).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Business::Address::StreetAddressIsInvalid]
      result.errors.for(:merchant_account).for(:business).for(:address).on(:postal_code).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Business::Address::PostalCodeIsInvalid]
      result.errors.for(:merchant_account).for(:business).for(:address).on(:region).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Business::Address::RegionIsInvalid]

      result.errors.for(:merchant_account).for(:funding).on(:destination).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Funding::DestinationIsInvalid]
      result.errors.for(:merchant_account).for(:funding).on(:routing_number).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Funding::RoutingNumberIsInvalid]
      result.errors.for(:merchant_account).for(:funding).on(:account_number).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Funding::AccountNumberIsInvalid]
      result.errors.for(:merchant_account).for(:funding).on(:email).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Funding::EmailIsInvalid]
      result.errors.for(:merchant_account).for(:funding).on(:mobile_phone).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Funding::MobilePhoneIsInvalid]

      result.errors.for(:merchant_account).on(:base).should be_empty
    end

    it "handles validation errors for business fields" do
      result = Braintree::MerchantAccount.update(
        "sandbox_sub_merchant_account", {
          :business => {
            :legal_name => "",
            :tax_id => "111223333",
          },
        }
      )

      result.should_not be_success
      result.errors.for(:merchant_account).for(:business).on(:legal_name).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Business::LegalNameIsRequiredWithTaxId]
      result.errors.for(:merchant_account).for(:business).on(:tax_id).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Business::TaxIdMustBeBlank]

      result = Braintree::MerchantAccount.update(
        "sandbox_sub_merchant_account", {
          :business => {
            :legal_name => "legal_name",
            :tax_id => "",
          },
        }
      )

      result.should_not be_success
      result.errors.for(:merchant_account).for(:business).on(:tax_id).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Business::TaxIdIsRequiredWithLegalName]
    end

    it "handles validation errors for funding fields" do
      result = Braintree::MerchantAccount.update(
        "sandbox_sub_merchant_account", {
          :funding => {
            :destination => Braintree::MerchantAccount::FundingDestination::Bank,
            :routing_number => "",
            :account_number => ""
          },
        }
      )

      result.should_not be_success
      result.errors.for(:merchant_account).for(:funding).on(:routing_number).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Funding::RoutingNumberIsRequired]
      result.errors.for(:merchant_account).for(:funding).on(:account_number).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Funding::AccountNumberIsRequired]

      result = Braintree::MerchantAccount.update(
        "sandbox_sub_merchant_account", {
          :funding => {
            :destination => Braintree::MerchantAccount::FundingDestination::Email,
            :email => ""
          },
        }
      )

      result.should_not be_success
      result.errors.for(:merchant_account).for(:funding).on(:email).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Funding::EmailIsRequired]

      result = Braintree::MerchantAccount.update(
        "sandbox_sub_merchant_account", {
          :funding => {
            :destination => Braintree::MerchantAccount::FundingDestination::MobilePhone,
            :mobile_phone => ""
          },
        }
      )

      result.should_not be_success
      result.errors.for(:merchant_account).for(:funding).on(:mobile_phone).map(&:code).should == [Braintree::ErrorCodes::MerchantAccount::Funding::MobilePhoneIsRequired]
    end
  end

  describe "update!" do
    it "updates the Merchant Account info" do
      params = VALID_APPLICATION_PARAMS.clone
      params.delete(:tos_accepted)
      params.delete(:master_merchant_account_id)
      params[:individual][:first_name] = "John"
      params[:individual][:last_name] = "Doe"
      merchant_account = Braintree::MerchantAccount.update!("sandbox_sub_merchant_account", params)
      merchant_account.individual_details.first_name.should == "John"
      merchant_account.individual_details.last_name.should == "Doe"
    end
  end
end
