require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::LocalPaymentCompleted do
  describe "self.new" do
    it "is protected" do
      expect do
        Braintree::LocalPaymentCompleted.new
      end.to raise_error(NoMethodError, /protected method .new/)
    end
  end

  describe "self._new" do
    it "initializes the object with the appropriate attributes set" do
      params = {
        payment_id: "a-payment-id",
        payer_id: "a-payer-id",
        payment_method_nonce: "a-nonce",
        transaction: {
          id: "a-transaction-id",
          amount: "31.00",
          order_id: "an-order-id",
          status: Braintree::Transaction::Status::Authorized,
        },
      }
      local_payment_completed = Braintree::LocalPaymentCompleted._new(params)

      local_payment_completed.payment_id.should eq("a-payment-id")
      local_payment_completed.payer_id.should eq("a-payer-id")
      local_payment_completed.payment_method_nonce.should eq("a-nonce")
      local_payment_completed.transaction.id.should eq("a-transaction-id")
      local_payment_completed.transaction.amount.should eq(31.0)
      local_payment_completed.transaction.order_id.should eq("an-order-id")
      local_payment_completed.transaction.status.should eq(Braintree::Transaction::Status::Authorized)
    end

    it "initializes the object with the appropriate attributes set if no transaction is provided" do
      params = {
        payment_id: "a-payment-id",
        payer_id: "a-payer-id",
        payment_method_nonce: "a-nonce",
      }
      local_payment_completed = Braintree::LocalPaymentCompleted._new(params)

      local_payment_completed.payment_id.should eq("a-payment-id")
      local_payment_completed.payer_id.should eq("a-payer-id")
      local_payment_completed.payment_method_nonce.should eq("a-nonce")
      local_payment_completed.transaction.should be_nil
    end
  end
end
