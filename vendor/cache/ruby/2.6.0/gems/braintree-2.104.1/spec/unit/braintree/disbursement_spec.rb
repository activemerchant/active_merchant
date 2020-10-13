require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::Disbursement do
  describe "new" do
    it "is protected" do
      expect do
        Braintree::Disbursement.new
      end.to raise_error(NoMethodError, /protected method .new/)
    end
  end

  describe "inspect" do
    it "prints attributes of disbursement object" do
      disbursement = Braintree::Disbursement._new(
        :gateway,
        :id => "123456",
        :merchant_account => {
          :id => "sandbox_sub_merchant_account",
          :master_merchant_account => {
            :id => "sandbox_master_merchant_account",
            :status => "active"
          },
          :status => "active"
        },
        :transaction_ids => ["sub_merchant_transaction"],
        :amount => "100.00",
        :disbursement_date => "2013-04-10",
        :exception_message => "invalid_account_number",
        :follow_up_action => "update",
        :retry => false,
        :success => false
      )

      disbursement.inspect.should include('id: "123456"')
      disbursement.inspect.should include('amount: "100.0"')
      disbursement.inspect.should include('exception_message: "invalid_account_number"')
      disbursement.inspect.should include('disbursement_date: 2013-04-10')
      disbursement.inspect.should include('follow_up_action: "update"')
      disbursement.inspect.should include('merchant_account: #<Braintree::MerchantAccount: ')
      disbursement.inspect.should include('transaction_ids: ["sub_merchant_transaction"]')
      disbursement.inspect.should include('retry: false')
      disbursement.inspect.should include('success: false')
    end
  end

  describe "success?" do
    it "is an alias of success" do
      disbursement = Braintree::Disbursement._new(
        :gateway,
        :merchant_account => {
          :id => "sandbox_sub_merchant_account",
          :master_merchant_account => {
            :id => "sandbox_master_merchant_account",
            :status => "active"
          },
          :status => "active"
        },
        :success => false,
        :disbursement_date => "2013-04-10"
      )
      disbursement.success?.should == false

      disbursement = Braintree::Disbursement._new(
        :gateway,
        :merchant_account => {
          :id => "sandbox_sub_merchant_account",
          :master_merchant_account => {
            :id => "sandbox_master_merchant_account",
            :status => "active"
          },
          :status => "active"
        },
        :success => true,
        :disbursement_date => "2013-04-10"
      )
      disbursement.success?.should == true
    end
  end

  describe "credit?" do
    subject do
      described_class._new(
        :gateway,
        merchant_account: {
          id: "sandbox_master_merchant_account",
          status: "active",
        },
        success: true,
        amount: "100.00",
        disbursement_type: type,
        disbursement_date: "2013-04-10",
      )
    end

    context "when the disbursement type is credit" do
      let(:type) { described_class::Types::Credit }
      it { is_expected.to be_credit }
    end

    context "when the disbursement type is not credit" do
      let(:type) { described_class::Types::Debit }
      it { is_expected.not_to be_credit }
    end
  end

  describe "debit?" do
    subject do
      described_class._new(
        :gateway,
        merchant_account: {
          id: "sandbox_master_merchant_account",
          status: "active",
        },
        success: true,
        amount: "100.00",
        disbursement_type: type,
        disbursement_date: "2013-04-10",
      )
    end

    context "when the disbursement type is debit" do
      let(:type) { described_class::Types::Debit }
      it { is_expected.to be_debit }
    end

    context "when the disbursement type is not debit" do
      let(:type) { described_class::Types::Credit }
      it { is_expected.not_to be_debit }
    end
  end
end
