require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::WebhookNotification do
  describe "self.sample_notification" do
    it "builds a sample notification and signature given an identifier and kind" do
      sample_notification = Braintree::WebhookTesting.sample_notification(
        Braintree::WebhookNotification::Kind::SubscriptionWentPastDue,
        "my_id"
      )

      notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])

      notification.kind.should == Braintree::WebhookNotification::Kind::SubscriptionWentPastDue
      notification.subscription.id.should == "my_id"
      notification.timestamp.should be_within(10).of(Time.now.utc)
    end

    it "builds a sample notification for a partner merchant connected webhook" do
      sample_notification = Braintree::WebhookTesting.sample_notification(
        Braintree::WebhookNotification::Kind::PartnerMerchantConnected,
        "my_id"
      )

      notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])

      notification.kind.should == Braintree::WebhookNotification::Kind::PartnerMerchantConnected
      notification.partner_merchant.merchant_public_id.should == "public_id"
      notification.partner_merchant.public_key.should == "public_key"
      notification.partner_merchant.private_key.should == "private_key"
      notification.partner_merchant.partner_merchant_id.should == "abc123"
      notification.partner_merchant.client_side_encryption_key.should == "cse_key"
      notification.timestamp.should be_within(10).of(Time.now.utc)
    end

    it "builds a sample notification for a partner merchant disconnected webhook" do
      sample_notification = Braintree::WebhookTesting.sample_notification(
        Braintree::WebhookNotification::Kind::PartnerMerchantDisconnected,
        "my_id"
      )

      notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])

      notification.kind.should == Braintree::WebhookNotification::Kind::PartnerMerchantDisconnected
      notification.partner_merchant.partner_merchant_id.should == "abc123"
      notification.timestamp.should be_within(10).of(Time.now.utc)
    end

    it "builds a sample notification for a partner merchant declined webhook" do
      sample_notification = Braintree::WebhookTesting.sample_notification(
        Braintree::WebhookNotification::Kind::PartnerMerchantDeclined,
        "my_id"
      )

      notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])

      notification.kind.should == Braintree::WebhookNotification::Kind::PartnerMerchantDeclined
      notification.partner_merchant.partner_merchant_id.should == "abc123"
      notification.timestamp.should be_within(10).of(Time.now.utc)
    end

    it "builds a sample notification with a source merchant ID" do
      sample_notification = Braintree::WebhookTesting.sample_notification(
        Braintree::WebhookNotification::Kind::SubscriptionWentPastDue,
        "my_id",
        "my_source_merchant_id"
      )

      notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])

      notification.source_merchant_id.should == "my_source_merchant_id"
    end

    it "doesn't include source merchant IDs if not supplied" do
      sample_notification = Braintree::WebhookTesting.sample_notification(
        Braintree::WebhookNotification::Kind::PartnerMerchantDeclined,
        "my_id"
      )

      notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])

      notification.source_merchant_id.should be_nil
    end

    context "auth" do
      it "builds a sample notification for a status transitioned webhook" do
        sample_notification = Braintree::WebhookTesting.sample_notification(
          Braintree::WebhookNotification::Kind::ConnectedMerchantStatusTransitioned,
          "my_id"
        )

        notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])

        notification.kind.should == Braintree::WebhookNotification::Kind::ConnectedMerchantStatusTransitioned

        status_transitioned = notification.connected_merchant_status_transitioned
        status_transitioned.merchant_public_id.should == "my_id"
        status_transitioned.merchant_id.should == "my_id"
        status_transitioned.oauth_application_client_id.should == "oauth_application_client_id"
        status_transitioned.status.should == "new_status"
      end

      it "builds a sample notification for a paypal status changed webhook" do
        sample_notification = Braintree::WebhookTesting.sample_notification(
          Braintree::WebhookNotification::Kind::ConnectedMerchantPayPalStatusChanged,
          "my_id"
        )

        notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])

        notification.kind.should == Braintree::WebhookNotification::Kind::ConnectedMerchantPayPalStatusChanged

        paypal_status_changed = notification.connected_merchant_paypal_status_changed
        paypal_status_changed.merchant_public_id.should == "my_id"
        paypal_status_changed.merchant_id.should == "my_id"
        paypal_status_changed.oauth_application_client_id.should == "oauth_application_client_id"
        paypal_status_changed.action.should == "link"
      end

      it 'builds a sample notification for OAuth application revocation' do
        sample_notification = Braintree::WebhookTesting.sample_notification(
          Braintree::WebhookNotification::Kind::OAuthAccessRevoked,
          'my_id'
        )

        notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])

        notification.kind.should == Braintree::WebhookNotification::Kind::OAuthAccessRevoked
        notification.oauth_access_revocation.merchant_id.should == "my_id"
        notification.oauth_access_revocation.oauth_application_client_id.should == "oauth_application_client_id"
        notification.timestamp.should be_within(10).of(Time.now.utc)
      end

    end

    context "disputes" do
      let(:dispute_id) { "my_id" }

      shared_examples "dispute webhooks" do
        it "builds a sample notification for a dispute opened webhook" do
          sample_notification = Braintree::WebhookTesting.sample_notification(
            Braintree::WebhookNotification::Kind::DisputeOpened,
            dispute_id
          )

          notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])

          notification.kind.should == Braintree::WebhookNotification::Kind::DisputeOpened

          dispute = notification.dispute
          dispute.status.should == Braintree::Dispute::Status::Open
          dispute.id.should == dispute_id
          dispute.kind.should == Braintree::Dispute::Kind::Chargeback
        end

        it "builds a sample notification for a dispute lost webhook" do
          sample_notification = Braintree::WebhookTesting.sample_notification(
            Braintree::WebhookNotification::Kind::DisputeLost,
            dispute_id
          )

          notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])

          notification.kind.should == Braintree::WebhookNotification::Kind::DisputeLost

          dispute = notification.dispute
          dispute.status.should == Braintree::Dispute::Status::Lost
          dispute.id.should == dispute_id
          dispute.kind.should == Braintree::Dispute::Kind::Chargeback
        end

        it "builds a sample notification for a dispute won webhook" do
          sample_notification = Braintree::WebhookTesting.sample_notification(
            Braintree::WebhookNotification::Kind::DisputeWon,
            dispute_id
          )

          notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])

          notification.kind.should == Braintree::WebhookNotification::Kind::DisputeWon

          dispute = notification.dispute
          dispute.status.should == Braintree::Dispute::Status::Won
          dispute.id.should == dispute_id
          dispute.kind.should == Braintree::Dispute::Kind::Chargeback
        end

        it "builds a sample notification for a dispute accepted webhook" do
          sample_notification = Braintree::WebhookTesting.sample_notification(
            Braintree::WebhookNotification::Kind::DisputeAccepted,
            dispute_id
          )

          notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])

          notification.kind.should == Braintree::WebhookNotification::Kind::DisputeAccepted

          dispute = notification.dispute
          dispute.status.should == Braintree::Dispute::Status::Accepted
          dispute.id.should == dispute_id
          dispute.kind.should == Braintree::Dispute::Kind::Chargeback
        end

        it "builds a sample notification for a dispute disputed webhook" do
          sample_notification = Braintree::WebhookTesting.sample_notification(
            Braintree::WebhookNotification::Kind::DisputeDisputed,
            dispute_id
          )

          notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])

          notification.kind.should == Braintree::WebhookNotification::Kind::DisputeDisputed

          dispute = notification.dispute
          dispute.status.should == Braintree::Dispute::Status::Disputed
          dispute.id.should == dispute_id
          dispute.kind.should == Braintree::Dispute::Kind::Chargeback
        end

        it "builds a sample notification for a dispute expired webhook" do
          sample_notification = Braintree::WebhookTesting.sample_notification(
            Braintree::WebhookNotification::Kind::DisputeExpired,
            dispute_id
          )

          notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])

          notification.kind.should == Braintree::WebhookNotification::Kind::DisputeExpired

          dispute = notification.dispute
          dispute.status.should == Braintree::Dispute::Status::Expired
          dispute.id.should == dispute_id
          dispute.kind.should == Braintree::Dispute::Kind::Chargeback
        end

        it "is compatible with the previous dispute won webhook interface" do
          sample_notification = Braintree::WebhookTesting.sample_notification(
            Braintree::WebhookNotification::Kind::DisputeWon,
            dispute_id
          )

          notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])

          notification.kind.should == Braintree::WebhookNotification::Kind::DisputeWon

          dispute = notification.dispute
          dispute.amount.should == 100.00
          dispute.id.should == dispute_id
          dispute.date_opened.should == Date.new(2014, 3, 21)
          dispute.date_won.should == Date.new(2014, 3, 22)
          dispute.transaction_details.amount.should == 100.00
          dispute.transaction_details.id.should == dispute_id
        end
      end

      context "older webhooks" do
        let(:dispute_id) { "legacy_dispute_id" }

        include_examples "dispute webhooks"
      end

      context "newer webhooks" do
        include_examples "dispute webhooks"
      end
    end

    context "disbursement" do
      it "builds a sample notification for a transaction disbursed webhook" do
        sample_notification = Braintree::WebhookTesting.sample_notification(
          Braintree::WebhookNotification::Kind::TransactionDisbursed,
          "my_id"
        )

        notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])

        notification.kind.should == Braintree::WebhookNotification::Kind::TransactionDisbursed
        notification.transaction.id.should == "my_id"
        notification.transaction.amount.should == 1_00
        notification.transaction.disbursement_details.disbursement_date.should == "2013-07-09"
      end

      it "builds a sample notification for a disbursement_exception webhook" do
        sample_notification = Braintree::WebhookTesting.sample_notification(
          Braintree::WebhookNotification::Kind::DisbursementException,
          "my_id"
        )

        notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])

        notification.kind.should == Braintree::WebhookNotification::Kind::DisbursementException
        notification.disbursement.id.should == "my_id"
        notification.disbursement.transaction_ids.should == %W{ afv56j kj8hjk }
        notification.disbursement.retry.should be(false)
        notification.disbursement.success.should be(false)
        notification.disbursement.exception_message.should == "bank_rejected"
        notification.disbursement.disbursement_date.should == Date.parse("2014-02-10")
        notification.disbursement.follow_up_action.should == "update_funding_information"
        notification.disbursement.merchant_account.id.should == "merchant_account_token"
      end

      it "builds a sample notification for a disbursement webhook" do
        sample_notification = Braintree::WebhookTesting.sample_notification(
          Braintree::WebhookNotification::Kind::Disbursement,
          "my_id"
        )

        notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])

        notification.kind.should == Braintree::WebhookNotification::Kind::Disbursement
        notification.disbursement.id.should == "my_id"
        notification.disbursement.transaction_ids.should == %W{ afv56j kj8hjk }
        notification.disbursement.retry.should be(false)
        notification.disbursement.success.should be(true)
        notification.disbursement.exception_message.should be_nil
        notification.disbursement.disbursement_date.should == Date.parse("2014-02-10")
        notification.disbursement.follow_up_action.should be_nil
        notification.disbursement.merchant_account.id.should == "merchant_account_token"
      end
    end

    context "us bank account transactions" do
      it "builds a sample notification for a settlement webhook" do
        sample_notification = Braintree::WebhookTesting.sample_notification(
          Braintree::WebhookNotification::Kind::TransactionSettled,
          "my_id"
        )

        notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])

        notification.kind.should == Braintree::WebhookNotification::Kind::TransactionSettled

        notification.transaction.status.should == "settled"
        notification.transaction.us_bank_account_details.account_type.should == "checking"
        notification.transaction.us_bank_account_details.account_holder_name.should == "Dan Schulman"
        notification.transaction.us_bank_account_details.routing_number.should == "123456789"
        notification.transaction.us_bank_account_details.last_4.should == "1234"
      end

      it "builds a sample notification for a settlement declined webhook" do
        sample_notification = Braintree::WebhookTesting.sample_notification(
          Braintree::WebhookNotification::Kind::TransactionSettlementDeclined,
          "my_id"
        )

        notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])

        notification.kind.should == Braintree::WebhookNotification::Kind::TransactionSettlementDeclined

        notification.transaction.status.should == "settlement_declined"
        notification.transaction.us_bank_account_details.account_type.should == "checking"
        notification.transaction.us_bank_account_details.account_holder_name.should == "Dan Schulman"
        notification.transaction.us_bank_account_details.routing_number.should == "123456789"
        notification.transaction.us_bank_account_details.last_4.should == "1234"
      end
    end

    context "merchant account" do
      it "builds a sample notification for a merchant account approved webhook" do
        sample_notification = Braintree::WebhookTesting.sample_notification(
          Braintree::WebhookNotification::Kind::SubMerchantAccountApproved,
          "my_id"
        )

        notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])

        notification.kind.should == Braintree::WebhookNotification::Kind::SubMerchantAccountApproved
        notification.merchant_account.id.should == "my_id"
        notification.merchant_account.status.should == Braintree::MerchantAccount::Status::Active
        notification.merchant_account.master_merchant_account.id.should == "master_ma_for_my_id"
        notification.merchant_account.master_merchant_account.status.should == Braintree::MerchantAccount::Status::Active
      end

      it "builds a sample notification for a merchant account declined webhook" do
        sample_notification = Braintree::WebhookTesting.sample_notification(
          Braintree::WebhookNotification::Kind::SubMerchantAccountDeclined,
          "my_id"
        )

        notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])

        notification.kind.should == Braintree::WebhookNotification::Kind::SubMerchantAccountDeclined
        notification.merchant_account.id.should == "my_id"
        notification.merchant_account.status.should == Braintree::MerchantAccount::Status::Suspended
        notification.merchant_account.master_merchant_account.id.should == "master_ma_for_my_id"
        notification.merchant_account.master_merchant_account.status.should == Braintree::MerchantAccount::Status::Suspended
        notification.message.should == "Credit score is too low"
        notification.errors.for(:merchant_account).on(:base).first.code.should == Braintree::ErrorCodes::MerchantAccount::DeclinedOFAC
      end
    end

    context "subscription" do
      it "builds a sample notification for a subscription charged successfully webhook" do
        sample_notification = Braintree::WebhookTesting.sample_notification(
          Braintree::WebhookNotification::Kind::SubscriptionChargedSuccessfully,
          "my_id"
        )

        notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])

        notification.kind.should == Braintree::WebhookNotification::Kind::SubscriptionChargedSuccessfully
        notification.subscription.id.should == "my_id"
        notification.subscription.transactions.size.should == 1
        notification.subscription.transactions.first.status.should == Braintree::Transaction::Status::SubmittedForSettlement
        notification.subscription.transactions.first.amount.should == BigDecimal("49.99")
      end

      it "builds a sample notification for a subscription charged unsuccessfully webhook" do
        sample_notification = Braintree::WebhookTesting.sample_notification(
          Braintree::WebhookNotification::Kind::SubscriptionChargedUnsuccessfully,
          "my_id"
        )

        notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])

        notification.kind.should == Braintree::WebhookNotification::Kind::SubscriptionChargedUnsuccessfully
        notification.subscription.id.should == "my_id"
        notification.subscription.transactions.size.should == 1
        notification.subscription.transactions.first.status.should == Braintree::Transaction::Status::Failed
        notification.subscription.transactions.first.amount.should == BigDecimal("49.99")
      end
    end

    it "includes a valid signature" do
      sample_notification = Braintree::WebhookTesting.sample_notification(
        Braintree::WebhookNotification::Kind::SubscriptionWentPastDue,
        "my_id"
      )
      expected_signature = Braintree::Digest.hexdigest(Braintree::Configuration.private_key, sample_notification[:bt_payload])

      sample_notification[:bt_signature].should == "#{Braintree::Configuration.public_key}|#{expected_signature}"
    end
  end

  context "account_updater_daily_report" do
    it "builds a sample notification for an account_updater_daily_report webhook" do
      sample_notification = Braintree::WebhookTesting.sample_notification(
        Braintree::WebhookNotification::Kind::AccountUpdaterDailyReport,
        "my_id"
      )

      notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])

      notification.kind.should == Braintree::WebhookNotification::Kind::AccountUpdaterDailyReport
      notification.account_updater_daily_report.report_url.should == "link-to-csv-report"
      notification.account_updater_daily_report.report_date.should == Date.parse("2016-01-14")
    end
  end

  context "granted_payment_instrument_update" do
    it "builds a sample notification for a GrantorUpdatedGrantedPaymentMethod webhook" do
      sample_notification = Braintree::WebhookTesting.sample_notification(
        Braintree::WebhookNotification::Kind::GrantorUpdatedGrantedPaymentMethod,
        "my_id"
      )

      notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])
      update = notification.granted_payment_instrument_update

      notification.kind.should == Braintree::WebhookNotification::Kind::GrantorUpdatedGrantedPaymentMethod
      update.grant_owner_merchant_id.should == 'vczo7jqrpwrsi2px'
      update.grant_recipient_merchant_id.should == 'cf0i8wgarszuy6hc'
      update.payment_method_nonce.should == 'ee257d98-de40-47e8-96b3-a6954ea7a9a4'
      update.token.should == 'abc123z'
      update.updated_fields.should == ['expiration-month', 'expiration-year']
    end

    it "builds a sample notification for a RecipientUpdatedGrantedPaymentMethod webhook" do
      sample_notification = Braintree::WebhookTesting.sample_notification(
        Braintree::WebhookNotification::Kind::RecipientUpdatedGrantedPaymentMethod,
        "my_id"
      )

      notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])
      update = notification.granted_payment_instrument_update

      notification.kind.should == Braintree::WebhookNotification::Kind::RecipientUpdatedGrantedPaymentMethod
      update.grant_owner_merchant_id.should == 'vczo7jqrpwrsi2px'
      update.grant_recipient_merchant_id.should == 'cf0i8wgarszuy6hc'
      update.payment_method_nonce.should == 'ee257d98-de40-47e8-96b3-a6954ea7a9a4'
      update.token.should == 'abc123z'
      update.updated_fields.should == ['expiration-month', 'expiration-year']
    end
  end

  context "granted_payment_instrument_revoked" do
    let(:gateway) do
      config = Braintree::Configuration.new(
        :merchant_id => 'merchant_id',
        :public_key => 'wrong_public_key',
        :private_key => 'wrong_private_key'
      )
      Braintree::Gateway.new(config)
    end

    describe "credit cards" do
      it "builds a webhook notification for a granted_payment_instrument_revoked webhook" do
        webhook_xml_response = <<-XML
        <notification>
          <source-merchant-id>12345</source-merchant-id>
          <timestamp type="datetime">2018-10-10T22:46:41Z</timestamp>
          <kind>granted_payment_instrument_revoked</kind>
          <subject>
            <credit-card>
              <bin>555555</bin>
              <card-type>MasterCard</card-type>
              <cardholder-name>Amber Ankunding</cardholder-name>
              <commercial>Unknown</commercial>
              <country-of-issuance>Unknown</country-of-issuance>
              <created-at type="datetime">2018-10-10T22:46:41Z</created-at>
              <customer-id>credit_card_customer_id</customer-id>
              <customer-location>US</customer-location>
              <debit>Unknown</debit>
              <default type="boolean">true</default>
              <durbin-regulated>Unknown</durbin-regulated>
              <expiration-month>06</expiration-month>
              <expiration-year>2020</expiration-year>
              <expired type="boolean">false</expired>
              <global-id>cGF5bWVudG1ldGhvZF8zcHQ2d2hz</global-id>
              <healthcare>Unknown</healthcare>
              <image-url>https://assets.braintreegateway.com/payment_method_logo/mastercard.png?environment=test</image-url>
              <issuing-bank>Unknown</issuing-bank>
              <last-4>4444</last-4>
              <payroll>Unknown</payroll>
              <prepaid>Unknown</prepaid>
              <product-id>Unknown</product-id>
              <subscriptions type="array"/>
              <token>credit_card_token</token>
              <unique-number-identifier>08199d188e37460163207f714faf074a</unique-number-identifier>
              <updated-at type="datetime">2018-10-10T22:46:41Z</updated-at>
              <venmo-sdk type="boolean">false</venmo-sdk>
              <verifications type="array"/>
            </credit-card>
          </subject>
        </notification>
        XML
        attributes = Braintree::Xml.hash_from_xml(webhook_xml_response)
        notification = Braintree::WebhookNotification._new(gateway, attributes[:notification])
        metadata = notification.revoked_payment_method_metadata

        notification.kind.should == Braintree::WebhookNotification::Kind::GrantedPaymentInstrumentRevoked
        metadata.customer_id.should == "credit_card_customer_id"
        metadata.token.should == "credit_card_token"
        metadata.revoked_payment_method.class.should == Braintree::CreditCard
      end
    end

    describe "paypal accounts" do
      it "builds a webhook notification for a granted_payment_instrument_revoked webhook" do
        webhook_xml_response = <<-XML
        <notification>
          <source-merchant-id>12345</source-merchant-id>
          <timestamp type="datetime">2018-10-10T22:46:41Z</timestamp>
          <kind>granted_payment_instrument_revoked</kind>
          <subject>
            <paypal-account>
              <billing-agreement-id>billing_agreement_id</billing-agreement-id>
              <created-at type="dateTime">2018-10-11T21:10:33Z</created-at>
              <customer-id>paypal_customer_id</customer-id>
              <default type="boolean">true</default>
              <email>johndoe@example.com</email>
              <global-id>cGF5bWVudG1ldGhvZF9wYXlwYWxfdG9rZW4</global-id>
              <image-url>https://jsdk.bt.local:9000/payment_method_logo/paypal.png?environment=test://assets.braintreegateway.com/payment_method_logo/paypal.png?environment=test</image-url>
              <subscriptions type="array"></subscriptions>
              <token>paypal_token</token>
              <updated-at type="dateTime">2018-10-11T21:10:33Z</updated-at>
              <payer-id>a6a8e1a4</payer-id>
            </paypal-account>
          </subject>
        </notification>
        XML
        attributes = Braintree::Xml.hash_from_xml(webhook_xml_response)
        notification = Braintree::WebhookNotification._new(gateway, attributes[:notification])
        metadata = notification.revoked_payment_method_metadata

        notification.kind.should == Braintree::WebhookNotification::Kind::GrantedPaymentInstrumentRevoked
        metadata.customer_id.should == "paypal_customer_id"
        metadata.token.should == "paypal_token"
        metadata.revoked_payment_method.class.should == Braintree::PayPalAccount
      end
    end

    describe "venmo accounts" do
      it "builds a webhook notification for a granted_payment_instrument_revoked webhook" do
        webhook_xml_response = <<-XML
        <notification>
          <source-merchant-id>12345</source-merchant-id>
          <timestamp type="datetime">2018-10-10T22:46:41Z</timestamp>
          <kind>granted_payment_instrument_revoked</kind>
          <subject>
            <venmo-account>
              <created-at type="dateTime">2018-10-11T21:28:37Z</created-at>
              <updated-at type="dateTime">2018-10-11T21:28:37Z</updated-at>
              <default type="boolean">true</default>
              <image-url>https://assets.braintreegateway.com/payment_method_logo/venmo.png?environment=test</image-url>
              <token>venmo_token</token>
              <source-description>Venmo Account: venmojoe</source-description>
              <username>venmojoe</username>
              <venmo-user-id>456</venmo-user-id>
              <subscriptions type="array"/>
              <customer-id>venmo_customer_id</customer-id>
              <global-id>cGF5bWVudG1ldGhvZF92ZW5tb2FjY291bnQ</global-id>
            </venmo-account>
          </subject>
        </notification>
        XML
        attributes = Braintree::Xml.hash_from_xml(webhook_xml_response)
        notification = Braintree::WebhookNotification._new(gateway, attributes[:notification])
        metadata = notification.revoked_payment_method_metadata

        notification.kind.should == Braintree::WebhookNotification::Kind::GrantedPaymentInstrumentRevoked
        metadata.customer_id.should == "venmo_customer_id"
        metadata.token.should == "venmo_token"
        metadata.revoked_payment_method.class.should == Braintree::VenmoAccount
      end
    end
  end

  context "payment_method_revoked_by_customer" do
    it "builds a sample notification for a payment_method_revoked_by_customer webhook" do
      sample_notification = Braintree::WebhookTesting.sample_notification(
        Braintree::WebhookNotification::Kind::PaymentMethodRevokedByCustomer,
        "my_payment_method_token"
      )

      notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])
      notification.kind.should == Braintree::WebhookNotification::Kind::PaymentMethodRevokedByCustomer

      metadata = notification.revoked_payment_method_metadata
      metadata.token.should == "my_payment_method_token"
      metadata.revoked_payment_method.class.should == Braintree::PayPalAccount
      metadata.revoked_payment_method.revoked_at.should_not be_nil
    end
  end

  context "local_payment_completed" do
    it "builds a sample notification for a local_payment webhook" do
      sample_notification = Braintree::WebhookTesting.sample_notification(
        Braintree::WebhookNotification::Kind::LocalPaymentCompleted,
        "my_id"
      )

      notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])
      notification.kind.should == Braintree::WebhookNotification::Kind::LocalPaymentCompleted

      local_payment_completed = notification.local_payment_completed
      local_payment_completed.payment_id.should == "PAY-XYZ123"
      local_payment_completed.payer_id.should == "ABCPAYER"
      local_payment_completed.payment_method_nonce.should == "ee257d98-de40-47e8-96b3-a6954ea7a9a4"
      local_payment_completed.transaction.id.should == "my_id"
      local_payment_completed.transaction.status.should == Braintree::Transaction::Status::Authorized
      local_payment_completed.transaction.amount.should == 49.99
      local_payment_completed.transaction.order_id.should == "order4567"
    end
  end

  describe "parse" do
    it "raises InvalidSignature error when the signature is nil" do
      expect do
        Braintree::WebhookNotification.parse(nil, "payload")
      end.to raise_error(Braintree::InvalidSignature, "signature cannot be nil")
    end

    it "raises InvalidSignature error when the payload is nil" do
      expect do
        Braintree::WebhookNotification.parse("signature", nil)
      end.to raise_error(Braintree::InvalidSignature, "payload cannot be nil")
    end

    it "raises InvalidSignature error when the signature is completely invalid" do
      sample_notification = Braintree::WebhookTesting.sample_notification(
        Braintree::WebhookNotification::Kind::SubscriptionWentPastDue,
        "my_id"
      )

      expect do
        Braintree::WebhookNotification.parse("not a valid signature", sample_notification[:bt_payload])
      end.to raise_error(Braintree::InvalidSignature)
    end

    it "raises InvalidSignature error with a message when the public key is not found" do
      sample_notification = Braintree::WebhookTesting.sample_notification(
        Braintree::WebhookNotification::Kind::SubscriptionWentPastDue,
        "my_id"
      )

      config = Braintree::Configuration.new(
        :merchant_id => 'merchant_id',
        :public_key => 'wrong_public_key',
        :private_key => 'wrong_private_key'
      )
      gateway = Braintree::Gateway.new(config)

      expect do
        gateway.webhook_notification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])
      end.to raise_error(Braintree::InvalidSignature, /no matching public key/)
    end

    it "raises InvalidSignature error if the payload has been changed" do
      sample_notification = Braintree::WebhookTesting.sample_notification(
        Braintree::WebhookNotification::Kind::SubscriptionWentPastDue,
        "my_id"
      )

      expect do
        Braintree::WebhookNotification.parse(sample_notification[:bt_signature], "badstuff" + sample_notification[:bt_payload])
      end.to raise_error(Braintree::InvalidSignature, /signature does not match payload - one has been modified/)
    end

    it "raises InvalidSignature error with a message complaining about invalid characters" do
      sample_notification = Braintree::WebhookTesting.sample_notification(
        Braintree::WebhookNotification::Kind::SubscriptionWentPastDue,
        "my_id"
      )

      expect do
        Braintree::WebhookNotification.parse(sample_notification[:bt_signature], "^& bad ,* chars @!" + sample_notification[:bt_payload])
      end.to raise_error(Braintree::InvalidSignature, /payload contains illegal characters/)
    end

    it "allows all valid characters" do
      sample_notification = Braintree::WebhookTesting.sample_notification(
        Braintree::WebhookNotification::Kind::SubscriptionWentPastDue,
        "my_id"
      )

      sample_notification[:bt_payload] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+=/\n"

      begin
        Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload])
      rescue Braintree::InvalidSignature => e
        exception = e
      end

      exception.message.should_not match(/payload contains illegal characters/)
    end

    it "retries a payload with a newline" do
      sample_notification = Braintree::WebhookTesting.sample_notification(
        Braintree::WebhookNotification::Kind::SubscriptionWentPastDue,
        "my_id"
      )

      notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload].rstrip)

      notification.kind.should == Braintree::WebhookNotification::Kind::SubscriptionWentPastDue
      notification.subscription.id.should == "my_id"
      notification.timestamp.should be_within(10).of(Time.now.utc)
    end
  end

  describe "check?" do
    it "returns true for check webhook kinds" do
      sample_notification = Braintree::WebhookTesting.sample_notification(
        Braintree::WebhookNotification::Kind::Check,
        nil
      )

      notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload].rstrip)

      notification.check?.should == true
    end

    it "returns false for non-check webhook kinds" do
      sample_notification = Braintree::WebhookTesting.sample_notification(
        Braintree::WebhookNotification::Kind::SubscriptionWentPastDue,
        nil
      )

      notification = Braintree::WebhookNotification.parse(sample_notification[:bt_signature], sample_notification[:bt_payload].rstrip)

      notification.check?.should == false
    end
  end

  describe "self.verify" do
    it "creates a verification string" do
      response = Braintree::WebhookNotification.verify("20f9f8ed05f77439fe955c977e4c8a53")
      response.should == "integration_public_key|d9b899556c966b3f06945ec21311865d35df3ce4"
    end

    it "raises InvalidChallenge error with a message complaining about invalid characters" do
      challenge = "bad challenge"

      expect do
        Braintree::WebhookNotification.verify(challenge)
      end.to raise_error(Braintree::InvalidChallenge, /challenge contains non-hex characters/)
    end
  end
end
