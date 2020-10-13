# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")
require File.expand_path(File.dirname(__FILE__) + "/client_api/spec_helper")

describe Braintree::Dispute do
  let(:document_upload) do
    file = File.new("#{File.dirname(__FILE__)}/../../fixtures/files/bt_logo.png", "r")
    response = Braintree::DocumentUpload.create({:kind => Braintree::DocumentUpload::Kind::EvidenceDocument, :file => file})
    document_upload = response.document_upload
  end

  let(:transaction) do
    result = Braintree::Transaction.sale(
      :amount => '10.00',
      :credit_card => {
        :expiration_date => '01/2020',
        :number => Braintree::Test::CreditCardNumbers::Disputes::Chargeback
      },
      :options => {
        :submit_for_settlement => true
      }
    )

    result.transaction
  end

  let(:dispute) { transaction.disputes.first }

  describe "self.accept" do
    it "changes the dispute status to accepted" do
      result = Braintree::Dispute.accept(dispute.id)

      result.success?.should == true

      refreshed_dispute = Braintree::Dispute.find(dispute.id)
      refreshed_dispute.status.should == Braintree::Dispute::Status::Accepted

      dispute_from_transaction = Braintree::Transaction.find(dispute.transaction.id).disputes[0]
      dispute_from_transaction.status.should == Braintree::Dispute::Status::Accepted
    end

    it "returns an error response if the dispute is not in open status" do
      result = Braintree::Dispute.accept("wells_dispute")

      result.success?.should == false
      result.errors.for(:dispute)[0].code.should == Braintree::ErrorCodes::Dispute::CanOnlyAcceptOpenDispute
      result.errors.for(:dispute)[0].message.should == "Disputes can only be accepted when they are in an Open state"
    end

    it "raises a NotFound exception if the dispute cannot be found" do
      expect do
        Braintree::Dispute.accept("invalid-id")
      end.to raise_error(Braintree::NotFoundError, 'dispute with id invalid-id not found')
    end
  end

  describe "self.add_file_evidence" do
    it "creates file evidence for the dispute" do
      result = Braintree::Dispute.add_file_evidence(dispute.id, document_upload.id)

      result.success?.should == true
      result.evidence.category.should be_nil
      result.evidence.comment.should be_nil
      result.evidence.created_at.between?(Time.now - 10, Time.now).should == true
      result.evidence.id.should =~ /^\w{16,}$/
      result.evidence.sent_to_processor_at.should == nil
      result.evidence.url.should include("bt_logo.png")
    end

    it "returns a NotFoundError if the dispute doesn't exist" do
      expect do
        Braintree::Dispute.add_file_evidence("unknown_dispute_id", "b51927a6-4ed7-4a32-8404-df8ef892e1a3")
      end.to raise_error(Braintree::NotFoundError)
    end

    it "returns an error response if the dispute is not in open status" do
      Braintree::Dispute.accept(dispute.id)

      result = Braintree::Dispute.add_file_evidence(dispute.id, document_upload.id)
      result.success?.should == false
      result.errors.for(:dispute)[0].code.should == Braintree::ErrorCodes::Dispute::CanOnlyAddEvidenceToOpenDispute
      result.errors.for(:dispute)[0].message.should == "Evidence can only be attached to disputes that are in an Open state"
    end

    it "returns the new evidence record in subsequent dispute finds" do
      result = Braintree::Dispute.add_file_evidence(dispute.id, document_upload.id)
      refreshed_dispute = Braintree::Dispute.find(dispute.id)

      expected_evidence = refreshed_dispute.evidence.find { |e| e.id == result.evidence.id }
      expected_evidence.should_not == nil
      expected_evidence.comment.should be_nil
      expected_evidence.url.should include("bt_logo.png")
    end

    it "creates file evidence with a category when provided" do
      result = Braintree::Dispute.add_file_evidence(dispute.id, {category: "GENERAL", document_id: document_upload.id})

      result.success?.should == true
      result.evidence.category.should == "GENERAL"
      result.evidence.url.should include("bt_logo.png")
    end
  end

  describe "self.add_text_evidence" do
    it "creates text evidence for the dispute" do
      result = Braintree::Dispute.add_text_evidence(dispute.id, "text evidence")

      result.success?.should == true
      result.evidence.category.should == nil
      result.evidence.comment.should == "text evidence"
      result.evidence.created_at.between?(Time.now - 10, Time.now).should == true
      result.evidence.id.should =~ /^\w{16,}$/
      result.evidence.sent_to_processor_at.should == nil
      result.evidence.url.should == nil
      result.evidence.tag.should == nil
      result.evidence.sequence_number.should == nil
    end

    it "returns a NotFoundError if the dispute doesn't exist" do
      expect do
        Braintree::Dispute.add_text_evidence("unknown_dispute_id", "text evidence")
      end.to raise_error(Braintree::NotFoundError)
    end

    it "returns an error response if the dispute is not in open status" do
      Braintree::Dispute.accept(dispute.id)

      result = Braintree::Dispute.add_text_evidence(dispute.id, "text evidence")
      result.success?.should == false
      result.errors.for(:dispute)[0].code.should == Braintree::ErrorCodes::Dispute::CanOnlyAddEvidenceToOpenDispute
      result.errors.for(:dispute)[0].message.should == "Evidence can only be attached to disputes that are in an Open state"
    end

    it "returns the new evidence record in subsequent dispute finds" do
      result = Braintree::Dispute.add_text_evidence(dispute.id, "text evidence")
      refreshed_dispute = Braintree::Dispute.find(dispute.id)

      expected_evidence = refreshed_dispute.evidence.find { |e| e.id == result.evidence.id }
      expected_evidence.should_not == nil
      expected_evidence.comment.should == "text evidence"
    end

    it "creates text evidence for the dispute with optional parameters" do
      result = Braintree::Dispute.add_text_evidence(dispute.id, { content: "123456789", tag: "REFUND_ID", sequence_number: 7 })

      result.success?.should == true
      result.evidence.category.should == "REFUND_ID"
      result.evidence.comment.should == "123456789"
      result.evidence.created_at.between?(Time.now - 10, Time.now).should == true
      result.evidence.id.should =~ /^\w{16,}$/
      result.evidence.sent_to_processor_at.should == nil
      result.evidence.tag.should == "REFUND_ID"
      result.evidence.sequence_number.should == 7
    end
  end

  describe "self.finalize" do
    it "changes the dispute status to disputed" do
      result = Braintree::Dispute.finalize(dispute.id)

      result.success?.should == true

      refreshed_dispute = Braintree::Dispute.find(dispute.id)
      refreshed_dispute.status.should == Braintree::Dispute::Status::Disputed
    end

    it "returns an error response if the dispute is not in open status" do
      result = Braintree::Dispute.finalize("wells_dispute")

      result.success?.should == false
      result.errors.for(:dispute)[0].code.should == Braintree::ErrorCodes::Dispute::CanOnlyFinalizeOpenDispute
      result.errors.for(:dispute)[0].message.should == "Disputes can only be finalized when they are in an Open state"
    end

    it "raises a NotFound exception if the dispute cannot be found" do
      expect do
        Braintree::Dispute.finalize("invalid-id")
      end.to raise_error(Braintree::NotFoundError, 'dispute with id invalid-id not found')
    end
  end

  describe "self.find" do
    it "finds the dispute with the given id" do
      dispute = Braintree::Dispute.find("open_dispute")

      dispute.amount_disputed.should == 31.0
      dispute.amount_won.should == 0.0
      dispute.id.should == "open_dispute"
      dispute.graphql_id.should_not be_nil
      dispute.status.should == Braintree::Dispute::Status::Open
      dispute.transaction.amount.should == 31.0
      dispute.transaction.id.should == "open_disputed_transaction"
    end

    it "raises an ArgumentError if dispute_id is not a string" do
      expect do
        Braintree::Dispute.find(Object.new)
      end.to raise_error(ArgumentError, "dispute_id contains invalid characters")
    end

    it "raises an ArgumentError if dispute_id is blank" do
      expect do
        Braintree::Dispute.find("")
      end.to raise_error(ArgumentError, "dispute_id contains invalid characters")
    end

    it "raises a NotFoundError exception if the dispute cannot be found" do
      expect do
        Braintree::Dispute.find("invalid-id")
      end.to raise_error(Braintree::NotFoundError, "dispute with id invalid-id not found")
    end
  end

  describe "self.remove_evidence" do
    let(:evidence) { Braintree::Dispute.add_text_evidence(dispute.id, "text evidence").evidence }

    it "removes evidence from the dispute" do
      result = Braintree::Dispute.remove_evidence(dispute.id, evidence.id)

      result.success?.should == true
    end

    it "returns a NotFoundError if the dispute doesn't exist" do
      expect do
        Braintree::Dispute.remove_evidence("unknown_dispute_id", evidence.id)
      end.to raise_error(Braintree::NotFoundError, "evidence with id #{evidence.id} for dispute with id unknown_dispute_id not found")
    end

    it "returns a NotFoundError if the dispute doesn't exist" do
      expect do
        Braintree::Dispute.remove_evidence(dispute.id, "unknown_evidence_id")
      end.to raise_error(Braintree::NotFoundError, "evidence with id unknown_evidence_id for dispute with id #{dispute.id} not found")
    end

    it "returns an error response if the dispute is not in open status" do
      evidence = Braintree::Dispute.add_text_evidence(dispute.id, "text evidence").evidence
      Braintree::Dispute.accept(dispute.id)

      result = Braintree::Dispute.remove_evidence(dispute.id, evidence.id)
      result.success?.should == false
      result.errors.for(:dispute)[0].code.should == Braintree::ErrorCodes::Dispute::CanOnlyRemoveEvidenceFromOpenDispute
      result.errors.for(:dispute)[0].message.should == "Evidence can only be removed from disputes that are in an Open state"
    end
  end

  context "categorized evidence" do
    it "fails to create file evidence for an unsupported category" do
      result = Braintree::Dispute.add_file_evidence(dispute.id, {category: "NOTREALCATEGORY", document_id: document_upload.id})

      result.success?.should == false
      result.errors.for(:dispute)[0].code.should == Braintree::ErrorCodes::Dispute::CanOnlyCreateEvidenceWithValidCategory
    end

    it "fails to create text evidence for an unsupported category" do
      result = Braintree::Dispute.add_text_evidence(dispute.id, {category: "NOTREALCATEGORY", content: "evidence"})

      result.success?.should == false
      result.errors.for(:dispute)[0].code.should == Braintree::ErrorCodes::Dispute::CanOnlyCreateEvidenceWithValidCategory
    end

    it "fails to create text evidence for a file only category MERCHANT_WEBSITE_OR_APP_ACCESS" do
      result = Braintree::Dispute.add_text_evidence(dispute.id, {category: "MERCHANT_WEBSITE_OR_APP_ACCESS", content: "evidence"})

      result.success?.should == false
      result.errors.for(:dispute)[0].code.should == Braintree::ErrorCodes::Dispute::EvidenceCategoryDocumentOnly
    end

    it "fails to create file evidence for a text only category DEVICE_ID" do
      result = Braintree::Dispute.add_file_evidence(dispute.id, {category: "DEVICE_ID", document_id: document_upload.id})

      result.success?.should == false
      result.errors.for(:dispute)[0].code.should == Braintree::ErrorCodes::Dispute::EvidenceCategoryTextOnly
    end

    it "fails to create evidence with an invalid date time format" do
      result = Braintree::Dispute.add_text_evidence(dispute.id, {category: "DOWNLOAD_DATE_TIME", content: "baddate"})

      result.success?.should == false
      result.errors.for(:dispute)[0].code.should == Braintree::ErrorCodes::Dispute::EvidenceContentDateInvalid
    end

    it "successfully creates text evidence with an valid date time format" do
      result = Braintree::Dispute.add_text_evidence(dispute.id, {category: "DOWNLOAD_DATE_TIME", content: "2018-10-20T18:00:00-0500"})

      result.success?.should == true
    end

    it "fails to finalize a dispute with digital goods missing" do
      Braintree::Dispute.add_text_evidence(dispute.id, {category: "DEVICE_ID", content: "iphone_id"})
      result = Braintree::Dispute.finalize(dispute.id)

      result.success?.should == false
      error_codes = result.errors.for(:dispute).map(&:code)

      error_codes.should include(Braintree::ErrorCodes::Dispute::DigitalGoodsMissingDownloadDate)
      error_codes.should include(Braintree::ErrorCodes::Dispute::DigitalGoodsMissingEvidence)
    end

    it "fails to finalize a dispute with partial non-disputed transaction information provided" do
      Braintree::Dispute.add_text_evidence(dispute.id, {category: "PRIOR_NON_DISPUTED_TRANSACTION_ARN", content: "123"})
      result = Braintree::Dispute.finalize(dispute.id)

      result.success?.should == false
      result.errors.for(:dispute)[0].code.should == Braintree::ErrorCodes::Dispute::NonDisputedPriorTransactionEvidenceMissingDate
    end
  end
end
