require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")
require File.expand_path(File.dirname(__FILE__) + "/client_api/spec_helper")

describe Braintree::Dispute, "search" do
  let(:customer) do
    result = Braintree::Customer.create(
      :first_name => "Jen",
      :last_name => "Smith",
      :company => "Braintree",
      :email => "jen@example.com",
      :phone => "312.555.1234",
      :fax => "614.555.5678",
      :website => "www.example.com",
    )

    result.customer
  end

  let(:transaction) do
    result = Braintree::Transaction.sale(
      :amount => '10.00',
      :credit_card => {
        :expiration_date => '01/2020',
        :number => Braintree::Test::CreditCardNumbers::Disputes::Chargeback,
      },
      :customer_id => customer.id,
      :merchant_account_id => "14LaddersLLC_instant",
      :options => {
        :submit_for_settlement => true,
      }
    )

    result.transaction
  end

  context "advanced" do
    it "correctly returns a result with no matches" do
      collection = Braintree::Dispute.search do |search|
        search.id.is "non_existent_dispute"
      end

      expect(collection.disputes.count).to eq(0)
    end

    it "correctly returns a single dispute by id" do
      collection = Braintree::Dispute.search do |search|
        search.id.is "open_dispute"
      end

      expect(collection.disputes.count).to eq(1)
      dispute = collection.disputes.first

      expect(dispute.id).to eq("open_dispute")
      expect(dispute.status).to eq(Braintree::Dispute::Status::Open)
    end

    it "correctly returns a single dispute by customer_id" do
      collection = Braintree::Dispute.search do |search|
        search.customer_id.is transaction.customer_details.id
      end

      expect(collection.disputes.count).to eq(1)
      dispute = collection.disputes.first

      expect(dispute.id).to eq(transaction.disputes.first.id)
      expect(dispute.status).to eq(Braintree::Dispute::Status::Open)
    end

    it "correctly returns disputes by multiple reasons" do
      collection = Braintree::Dispute.search do |search|
        search.reason.in [
          Braintree::Dispute::Reason::ProductUnsatisfactory,
          Braintree::Dispute::Reason::Retrieval
        ]
      end

      expect(collection.disputes.count).to be >= 2
      dispute = collection.disputes.first
    end

    it "correctly returns disputes by effective_date range" do
      effective_date = transaction.disputes.first.status_history.first.effective_date

      collection = Braintree::Dispute.search do |search|
        search.effective_date.between(effective_date, Date.parse(effective_date).next_day.to_s)
      end

      expect(collection.disputes.count).to be >= 1

      dispute_ids = collection.disputes.map { |d| d.id }
      expect(dispute_ids).to include(transaction.disputes.first.id)
    end

    it "correctly returns disputes by disbursement_date range" do
      disbursement_date = transaction.disputes.first.status_history.first.disbursement_date

      collection = Braintree::Dispute.search do |search|
        search.disbursement_date.between(disbursement_date, Date.parse(disbursement_date).next_day.to_s)
      end

      expect(collection.disputes.count).to be >= 1

      dispute_ids = collection.disputes.map { |d| d.id }
      expect(dispute_ids).to include(transaction.disputes.first.id)
    end

    it "correctly returns disputes by received_date range" do
      collection = Braintree::Dispute.search do |search|
        search.received_date.between("03/03/2014", "03/05/2014")
      end

      expect(collection.disputes.count).to eq(1)
      dispute = collection.disputes.first

      expect(dispute.received_date).to eq(Date.new(2014, 3, 4))
    end

    it "correctly returns disputes by reply_by_date range" do
      reply_by_date = transaction.disputes.first.reply_by_date

      collection = Braintree::Dispute.search do |search|
        search.reply_by_date.between(reply_by_date, reply_by_date + 1)
      end

      dispute_ids = collection.disputes.map { |d| d.id }
      expect(dispute_ids).to include(transaction.disputes.first.id)
    end
  end
end
