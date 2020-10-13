module Braintree
  class WebhookTestingGateway # :nodoc:
    def initialize(gateway)
      @gateway = gateway
      @config = gateway.config
      @config.assert_has_access_token_or_keys
    end

    def sample_notification(kind, id, source_merchant_id=nil)
      payload = Base64.encode64(_sample_xml(kind, id, source_merchant_id))
      signature_string = "#{@config.public_key}|#{Braintree::Digest.hexdigest(@config.private_key, payload)}"

      return {:bt_signature => signature_string, :bt_payload => payload}
    end

    def _sample_xml(kind, data, source_merchant_id=nil)
      unless source_merchant_id.nil?
        source_merchant_xml = "<source-merchant-id>#{source_merchant_id}</source-merchant-id>"
      end

      <<-XML
        <notification>
          <timestamp type="datetime">#{Time.now.utc.iso8601}</timestamp>
          <kind>#{kind}</kind>
          #{source_merchant_xml}
          <subject>
            #{_subject_sample_xml(kind, data)}
          </subject>
        </notification>
      XML
    end

    def _subject_sample_xml(kind, id)
      case kind
      when Braintree::WebhookNotification::Kind::Check
        _check
      when Braintree::WebhookNotification::Kind::DisputeOpened
        _dispute_opened_sample_xml(id)
      when Braintree::WebhookNotification::Kind::DisputeLost
        _dispute_lost_sample_xml(id)
      when Braintree::WebhookNotification::Kind::DisputeWon
        _dispute_won_sample_xml(id)
      when Braintree::WebhookNotification::Kind::DisputeAccepted
        _dispute_accepted_sample_xml(id)
      when Braintree::WebhookNotification::Kind::DisputeDisputed
        _dispute_disputed_sample_xml(id)
      when Braintree::WebhookNotification::Kind::DisputeExpired
        _dispute_expired_sample_xml(id)
      when Braintree::WebhookNotification::Kind::PartnerMerchantConnected
        _partner_merchant_connected_sample_xml(id)
      when Braintree::WebhookNotification::Kind::PartnerMerchantDisconnected
        _partner_merchant_disconnected_sample_xml(id)
      when Braintree::WebhookNotification::Kind::PartnerMerchantDeclined
        _partner_merchant_declined_sample_xml(id)
      when Braintree::WebhookNotification::Kind::OAuthAccessRevoked
        _oauth_access_revoked_sample_xml(id)
      when Braintree::WebhookNotification::Kind::SubMerchantAccountApproved
        _merchant_account_approved_sample_xml(id)
      when Braintree::WebhookNotification::Kind::SubMerchantAccountDeclined
        _merchant_account_declined_sample_xml(id)
      when Braintree::WebhookNotification::Kind::TransactionDisbursed
        _transaction_disbursed_sample_xml(id)
      when Braintree::WebhookNotification::Kind::TransactionSettled
        _transaction_settled_sample_xml(id)
      when Braintree::WebhookNotification::Kind::TransactionSettlementDeclined
        _transaction_settlement_declined_sample_xml(id)
      when Braintree::WebhookNotification::Kind::DisbursementException
        _disbursement_exception_sample_xml(id)
      when Braintree::WebhookNotification::Kind::Disbursement
        _disbursement_sample_xml(id)
      when Braintree::WebhookNotification::Kind::SubscriptionChargedSuccessfully
        _subscription_charged_successfully(id)
      when Braintree::WebhookNotification::Kind::SubscriptionChargedUnsuccessfully
        _subscription_charged_unsuccessfully(id)
      when Braintree::WebhookNotification::Kind::AccountUpdaterDailyReport
        _account_updater_daily_report_sample_xml(id)
      when Braintree::WebhookNotification::Kind::ConnectedMerchantStatusTransitioned
        _auth_status_transitioned_sample_xml(id)
      when Braintree::WebhookNotification::Kind::ConnectedMerchantPayPalStatusChanged
        _auth_paypal_status_changed_sample_xml(id)
        # NEXT_MAJOR_VERSION Remove this class as legacy Ideal has been removed/disabled in the Braintree Gateway
        # DEPRECATED If you're looking to accept iDEAL as a payment method contact accounts@braintreepayments.com for a solution.
      when Braintree::WebhookNotification::Kind::IdealPaymentComplete
        _ideal_payment_complete_sample_xml(id)
        # NEXT_MAJOR_VERSION Remove this class as legacy Ideal has been removed/disabled in the Braintree Gateway
        # DEPRECATED If you're looking to accept iDEAL as a payment method contact accounts@braintreepayments.com for a solution.
      when Braintree::WebhookNotification::Kind::IdealPaymentFailed
        _ideal_payment_failed_sample_xml(id)
      # NEXT_MAJOR_VERSION remove GrantedPaymentInstrumentUpdate
      when Braintree::WebhookNotification::Kind::GrantedPaymentInstrumentUpdate
        _granted_payment_instrument_update_sample_xml(id)
      when Braintree::WebhookNotification::Kind::GrantorUpdatedGrantedPaymentMethod
        _granted_payment_instrument_update_sample_xml(id)
      when Braintree::WebhookNotification::Kind::RecipientUpdatedGrantedPaymentMethod
        _granted_payment_instrument_update_sample_xml(id)
      when Braintree::WebhookNotification::Kind::PaymentMethodRevokedByCustomer
        _payment_method_revoked_by_customer_sample_xml(id)
      when Braintree::WebhookNotification::Kind::LocalPaymentCompleted
        _local_payment_completed_sample_xml(id)
      else
        _subscription_sample_xml(id)
      end
    end

    def _check

      <<-XML
        <check type="boolean">true</check>
      XML
    end

    def _subscription_charged_successfully(id)

      <<-XML
        <subscription>
          <id>#{id}</id>
          <transactions type="array">
            <transaction>
              <id>#{id}</id>
              <status>submitted_for_settlement</status>
              <amount>49.99</amount>
            </transaction>
          </transactions>
          <add_ons type="array">
          </add_ons>
          <discounts type="array">
          </discounts>
        </subscription>
      XML
    end

    def _subscription_charged_unsuccessfully(id)

      <<-XML
        <subscription>
          <id>#{id}</id>
          <transactions type="array">
            <transaction>
              <id>#{id}</id>
              <status>failed</status>
              <amount>49.99</amount>
            </transaction>
          </transactions>
          <add_ons type="array">
          </add_ons>
          <discounts type="array">
          </discounts>
        </subscription>
      XML
    end

    def _subscription_sample_xml(id)

      <<-XML
        <subscription>
          <id>#{id}</id>
          <transactions type="array">
          </transactions>
          <add_ons type="array">
          </add_ons>
          <discounts type="array">
          </discounts>
        </subscription>
      XML
    end

    def _partner_merchant_connected_sample_xml(data)

      <<-XML
        <partner-merchant>
          <merchant-public-id>public_id</merchant-public-id>
          <public-key>public_key</public-key>
          <private-key>private_key</private-key>
          <partner-merchant-id>abc123</partner-merchant-id>
          <client-side-encryption-key>cse_key</client-side-encryption-key>
        </partner-merchant>
      XML
    end

    def _partner_merchant_disconnected_sample_xml(data)

      <<-XML
        <partner-merchant>
          <partner-merchant-id>abc123</partner-merchant-id>
        </partner-merchant>
      XML
    end

    def _partner_merchant_declined_sample_xml(data)

      <<-XML
        <partner-merchant>
          <partner-merchant-id>abc123</partner-merchant-id>
        </partner-merchant>
      XML
    end

    def _merchant_account_approved_sample_xml(id)

      <<-XML
        <merchant_account>
          <id>#{id}</id>
          <master_merchant_account>
            <id>master_ma_for_#{id}</id>
            <status>active</status>
          </master_merchant_account>
          <status>active</status>
        </merchant_account>
      XML
    end

    def _merchant_account_declined_sample_xml(id)

      <<-XML
          <api-error-response>
              <message>Credit score is too low</message>
              <errors>
                  <errors type="array"/>
                      <merchant-account>
                          <errors type="array">
                              <error>
                                  <code>82621</code>
                                  <message>Credit score is too low</message>
                                  <attribute type="symbol">base</attribute>
                              </error>
                          </errors>
                      </merchant-account>
                  </errors>
                  <merchant-account>
                      <id>#{id}</id>
                      <status>suspended</status>
                      <master-merchant-account>
                          <id>master_ma_for_#{id}</id>
                          <status>suspended</status>
                      </master-merchant-account>
                  </merchant-account>
          </api-error-response>
      XML
    end

    def _transaction_disbursed_sample_xml(id)

      <<-XML
        <transaction>
          <id>#{id}</id>
          <amount>100</amount>
          <disbursement-details>
            <disbursement-date type="date">2013-07-09</disbursement-date>
          </disbursement-details>
        </transaction>
      XML
    end

    def _transaction_settled_sample_xml(id)
      <<-XML
        <transaction>
          <id>#{id}</id>
          <status>settled</status>
          <type>sale</type>
          <currency-iso-code>USD</currency-iso-code>
          <amount>100.00</amount>
          <merchant-account-id>ogaotkivejpfayqfeaimuktty</merchant-account-id>
          <payment-instrument-type>us_bank_account</payment-instrument-type>
          <us-bank-account>
            <routing-number>123456789</routing-number>
            <last-4>1234</last-4>
            <account-type>checking</account-type>
            <account-holder-name>Dan Schulman</account-holder-name>
          </us-bank-account>
        </transaction>
      XML
    end

    def _transaction_settlement_declined_sample_xml(id)
      <<-XML
        <transaction>
          <id>#{id}</id>
          <status>settlement_declined</status>
          <type>sale</type>
          <currency-iso-code>USD</currency-iso-code>
          <amount>100.00</amount>
          <merchant-account-id>ogaotkivejpfayqfeaimuktty</merchant-account-id>
          <payment-instrument-type>us_bank_account</payment-instrument-type>
          <us-bank-account>
            <routing-number>123456789</routing-number>
            <last-4>1234</last-4>
            <account-type>checking</account-type>
            <account-holder-name>Dan Schulman</account-holder-name>
          </us-bank-account>
        </transaction>
      XML
    end

    def _dispute_opened_sample_xml(id)
      if id == "legacy_dispute_id"
        _old_dispute_opened_sample_xml(id)
      else
        _new_dispute_opened_sample_xml(id)
      end
    end

    def _dispute_lost_sample_xml(id)
      if id == "legacy_dispute_id"
        _old_dispute_lost_sample_xml(id)
      else
        _new_dispute_lost_sample_xml(id)
      end
    end

    def _dispute_won_sample_xml(id)
      if id == "legacy_dispute_id"
        _old_dispute_won_sample_xml(id)
      else
        _new_dispute_won_sample_xml(id)
      end
    end

    def _dispute_accepted_sample_xml(id)
      if id == "legacy_dispute_id"
        _old_dispute_accepted_sample_xml(id)
      else
        _new_dispute_accepted_sample_xml(id)
      end
    end

    def _dispute_disputed_sample_xml(id)
      if id == "legacy_dispute_id"
        _old_dispute_disputed_sample_xml(id)
      else
        _new_dispute_disputed_sample_xml(id)
      end
    end

    def _dispute_expired_sample_xml(id)
      if id == "legacy_dispute_id"
        _old_dispute_expired_sample_xml(id)
      else
        _new_dispute_expired_sample_xml(id)
      end
    end

    def _old_dispute_opened_sample_xml(id)
      <<-XML
        <dispute>
          <amount>100.00</amount>
          <currency-iso-code>USD</currency-iso-code>
          <received-date type="date">2014-03-01</received-date>
          <reply-by-date type="date">2014-03-21</reply-by-date>
          <kind>chargeback</kind>
          <status>open</status>
          <reason>fraud</reason>
          <id>#{id}</id>
          <transaction>
            <id>#{id}</id>
            <amount>100.00</amount>
          </transaction>
          <date-opened type=\"date\">2014-03-21</date-opened>
        </dispute>
      XML
    end

    def _old_dispute_lost_sample_xml(id)
      <<-XML
        <dispute>
          <amount>100.00</amount>
          <currency-iso-code>USD</currency-iso-code>
          <received-date type="date">2014-03-01</received-date>
          <reply-by-date type="date">2014-03-21</reply-by-date>
          <kind>chargeback</kind>
          <status>lost</status>
          <reason>fraud</reason>
          <id>#{id}</id>
          <transaction>
            <id>#{id}</id>
            <amount>100.00</amount>
          </transaction>
          <date-opened type=\"date\">2014-03-21</date-opened>
        </dispute>
      XML
    end

    def _old_dispute_won_sample_xml(id)
      <<-XML
        <dispute>
          <amount>100.00</amount>
          <currency-iso-code>USD</currency-iso-code>
          <received-date type="date">2014-03-01</received-date>
          <reply-by-date type="date">2014-03-21</reply-by-date>
          <kind>chargeback</kind>
          <status>won</status>
          <reason>fraud</reason>
          <id>#{id}</id>
          <transaction>
            <id>#{id}</id>
            <amount>100.00</amount>
          </transaction>
          <date-opened type=\"date\">2014-03-21</date-opened>
          <date-won type=\"date\">2014-03-22</date-won>
        </dispute>
      XML
    end

    def _old_dispute_accepted_sample_xml(id)
      <<-XML
        <dispute>
          <amount>100.00</amount>
          <currency-iso-code>USD</currency-iso-code>
          <received-date type="date">2014-03-01</received-date>
          <reply-by-date type="date">2014-03-21</reply-by-date>
          <kind>chargeback</kind>
          <status>accepted</status>
          <reason>fraud</reason>
          <id>#{id}</id>
          <transaction>
            <id>#{id}</id>
            <amount>100.00</amount>
          </transaction>
          <date-opened type=\"date\">2014-03-21</date-opened>
        </dispute>
      XML
    end

    def _old_dispute_disputed_sample_xml(id)
      <<-XML
        <dispute>
          <amount>100.00</amount>
          <currency-iso-code>USD</currency-iso-code>
          <received-date type="date">2014-03-01</received-date>
          <reply-by-date type="date">2014-03-21</reply-by-date>
          <kind>chargeback</kind>
          <status>disputed</status>
          <reason>fraud</reason>
          <id>#{id}</id>
          <transaction>
            <id>#{id}</id>
            <amount>100.00</amount>
          </transaction>
          <date-opened type=\"date\">2014-03-21</date-opened>
        </dispute>
      XML
    end

    def _old_dispute_expired_sample_xml(id)
      <<-XML
        <dispute>
          <amount>100.00</amount>
          <currency-iso-code>USD</currency-iso-code>
          <received-date type="date">2014-03-01</received-date>
          <reply-by-date type="date">2014-03-21</reply-by-date>
          <kind>chargeback</kind>
          <status>expired</status>
          <reason>fraud</reason>
          <id>#{id}</id>
          <transaction>
            <id>#{id}</id>
            <amount>100.00</amount>
          </transaction>
          <date-opened type=\"date\">2014-03-21</date-opened>
        </dispute>
      XML
    end

    def _new_dispute_opened_sample_xml(id)
      <<-XML
        <dispute>
          <id>#{id}</id>
          <amount>100.00</amount>
          <amount-disputed>100.00</amount-disputed>
          <amount-won>95.00</amount-won>
          <case-number>CASE-12345</case-number>
          <created-at type="datetime">2017-06-16T20:44:41Z</created-at>
          <currency-iso-code>USD</currency-iso-code>
          <forwarded-comments nil="true"/>
          <kind>chargeback</kind>
          <merchant-account-id>ytnlulaloidoqwvzxjrdqputg</merchant-account-id>
          <reason>fraud</reason>
          <reason-code nil="true"/>
          <reason-description nil="true"/>
          <received-date type="date">2016-02-15</received-date>
          <reference-number>REF-9876</reference-number>
          <reply-by-date type="date">2016-02-22</reply-by-date>
          <status>open</status>
          <updated-at type="datetime">2017-06-16T20:44:41Z</updated-at>
          <original-dispute-id>9qde5qgp</original-dispute-id>
          <status-history type="array">
            <status-history>
              <status>open</status>
              <timestamp type="datetime">2017-06-16T20:44:41Z</timestamp>
            </status-history>
          </status-history>
          <evidence type="array"/>
          <transaction>
            <id>#{id}</id>
            <amount>100.00</amount>
            <created-at>2017-06-21T20:44:41Z</created-at>
            <order-id nil="true"/>
            <purchase-order-number nil="true"/>
            <payment-instrument-subtype>Visa</payment-instrument-subtype>
          </transaction>
          <date-opened type=\"date\">2014-03-21</date-opened>
        </dispute>
      XML
    end

    def _new_dispute_lost_sample_xml(id)
      <<-XML
        <dispute>
          <id>#{id}</id>
          <amount>100.00</amount>
          <amount-disputed>100.00</amount-disputed>
          <amount-won>95.00</amount-won>
          <case-number>CASE-12345</case-number>
          <created-at type="datetime">2017-06-16T20:44:41Z</created-at>
          <currency-iso-code>USD</currency-iso-code>
          <forwarded-comments nil="true"/>
          <kind>chargeback</kind>
          <merchant-account-id>ytnlulaloidoqwvzxjrdqputg</merchant-account-id>
          <reason>fraud</reason>
          <reason-code nil="true"/>
          <reason-description nil="true"/>
          <received-date type="date">2016-02-15</received-date>
          <reference-number>REF-9876</reference-number>
          <reply-by-date type="date">2016-02-22</reply-by-date>
          <status>lost</status>
          <updated-at type="datetime">2017-06-21T20:44:41Z</updated-at>
          <original-dispute-id>9qde5qgp</original-dispute-id>
          <status-history type="array">
            <status-history>
              <status>open</status>
              <timestamp type="datetime">2017-06-16T20:44:41Z</timestamp>
            </status-history>
            <status-history>
              <status>lost</status>
              <timestamp type="datetime">2017-06-25T20:50:55Z</timestamp>
            </status-history>
          </status-history>
          <evidence type="array">
            <evidence>
              <id>rxtngk9j5j93tsrq</id>
              <comments nil="true"/>
              <created-at type="datetime">2017-06-21T20:44:42Z</created-at>
              <sent-to-processor-at nil="true"/>
              <url>s3.amazonaws.com/foo.jpg</url>
            </evidence>
            <evidence>
              <id>88cfb8dd</id>
              <comments>text evidence</comments>
              <created-at type="datetime">2017-06-21T20:44:42Z</created-at>
              <sent-to-processor-at nil="true"/>
              <url nil="true"/>
            </evidence>
          </evidence>
          <transaction>
            <id>#{id}</id>
            <amount>100.00</amount>
            <created-at>2017-06-21T20:44:41Z</created-at>
            <order-id nil="true"/>
            <purchase-order-number nil="true"/>
            <payment-instrument-subtype>Visa</payment-instrument-subtype>
          </transaction>
          <date-opened type=\"date\">2014-03-21</date-opened>
        </dispute>
      XML
    end

    def _new_dispute_won_sample_xml(id)
      <<-XML
        <dispute>
          <id>#{id}</id>
          <amount>100.00</amount>
          <amount-disputed>100.00</amount-disputed>
          <amount-won>95.00</amount-won>
          <case-number>CASE-12345</case-number>
          <created-at type="datetime">2017-06-16T20:44:41Z</created-at>
          <currency-iso-code>USD</currency-iso-code>
          <forwarded-comments nil="true"/>
          <kind>chargeback</kind>
          <merchant-account-id>ytnlulaloidoqwvzxjrdqputg</merchant-account-id>
          <reason>fraud</reason>
          <reason-code nil="true"/>
          <reason-description nil="true"/>
          <received-date type="date">2016-02-15</received-date>
          <reference-number>REF-9876</reference-number>
          <reply-by-date type="date">2016-02-22</reply-by-date>
          <status>won</status>
          <updated-at type="datetime">2017-06-21T20:44:41Z</updated-at>
          <original-dispute-id>9qde5qgp</original-dispute-id>
          <status-history type="array">
            <status-history>
              <status>open</status>
              <timestamp type="datetime">2017-06-16T20:44:41Z</timestamp>
            </status-history>
            <status-history>
              <status>won</status>
              <timestamp type="datetime">2017-06-25T20:50:55Z</timestamp>
            </status-history>
          </status-history>
          <evidence type="array">
            <evidence>
              <id>rxtngk9j5j93tsrq</id>
              <comments nil="true"/>
              <created-at type="datetime">2017-06-21T20:44:42Z</created-at>
              <sent-to-processor-at nil="true"/>
              <url>s3.amazonaws.com/foo.jpg</url>
            </evidence>
            <evidence>
              <id>88cfb8dd</id>
              <comments>text evidence</comments>
              <created-at type="datetime">2017-06-21T20:44:42Z</created-at>
              <sent-to-processor-at nil="true"/>
              <url nil="true"/>
            </evidence>
          </evidence>
          <transaction>
            <id>#{id}</id>
            <amount>100.00</amount>
            <created-at>2017-06-21T20:44:41Z</created-at>
            <order-id nil="true"/>
            <purchase-order-number nil="true"/>
            <payment-instrument-subtype>Visa</payment-instrument-subtype>
          </transaction>
          <date-opened type=\"date\">2014-03-21</date-opened>
          <date-won type=\"date\">2014-03-22</date-won>
        </dispute>
      XML
    end

    def _new_dispute_accepted_sample_xml(id)
      <<-XML
        <dispute>
          <id>#{id}</id>
          <amount>100.00</amount>
          <amount-disputed>100.00</amount-disputed>
          <amount-won>95.00</amount-won>
          <case-number>CASE-12345</case-number>
          <created-at type="datetime">2017-06-16T20:44:41Z</created-at>
          <currency-iso-code>USD</currency-iso-code>
          <forwarded-comments nil="true"/>
          <kind>chargeback</kind>
          <merchant-account-id>ytnlulaloidoqwvzxjrdqputg</merchant-account-id>
          <reason>fraud</reason>
          <reason-code nil="true"/>
          <reason-description nil="true"/>
          <received-date type="date">2016-02-15</received-date>
          <reference-number>REF-9876</reference-number>
          <reply-by-date type="date">2016-02-22</reply-by-date>
          <status>accepted</status>
          <updated-at type="datetime">2017-06-16T20:44:41Z</updated-at>
          <original-dispute-id>9qde5qgp</original-dispute-id>
          <status-history type="array">
            <status-history>
              <status>open</status>
              <timestamp type="datetime">2017-06-16T20:44:41Z</timestamp>
            </status-history>
            <status-history>
              <status>accepted</status>
              <timestamp type="datetime">2017-06-25T20:50:55Z</timestamp>
            </status-history>
          </status-history>
          <evidence type="array"/>
          <transaction>
            <id>#{id}</id>
            <amount>100.00</amount>
            <created-at>2017-06-21T20:44:41Z</created-at>
            <order-id nil="true"/>
            <purchase-order-number nil="true"/>
            <payment-instrument-subtype>Visa</payment-instrument-subtype>
          </transaction>
          <date-opened type=\"date\">2014-03-21</date-opened>
        </dispute>
      XML
    end

    def _new_dispute_disputed_sample_xml(id)
      <<-XML
        <dispute>
          <id>#{id}</id>
          <amount>100.00</amount>
          <amount-disputed>100.00</amount-disputed>
          <amount-won>95.00</amount-won>
          <case-number>CASE-12345</case-number>
          <created-at type="datetime">2017-06-16T20:44:41Z</created-at>
          <currency-iso-code>USD</currency-iso-code>
          <forwarded-comments nil="true"/>
          <kind>chargeback</kind>
          <merchant-account-id>ytnlulaloidoqwvzxjrdqputg</merchant-account-id>
          <reason>fraud</reason>
          <reason-code nil="true"/>
          <reason-description nil="true"/>
          <received-date type="date">2016-02-15</received-date>
          <reference-number>REF-9876</reference-number>
          <reply-by-date type="date">2016-02-22</reply-by-date>
          <status>disputed</status>
          <updated-at type="datetime">2017-06-21T20:44:41Z</updated-at>
          <original-dispute-id>9qde5qgp</original-dispute-id>
          <status-history type="array">
            <status-history>
              <status>open</status>
              <timestamp type="datetime">2017-06-16T20:44:41Z</timestamp>
            </status-history>
            <status-history>
              <status>disputed</status>
              <timestamp type="datetime">2017-06-25T20:50:55Z</timestamp>
            </status-history>
          </status-history>
          <evidence type="array">
            <evidence>
              <id>rxtngk9j5j93tsrq</id>
              <comments nil="true"/>
              <created-at type="datetime">2017-06-21T20:44:42Z</created-at>
              <sent-to-processor-at nil="true"/>
              <url>s3.amazonaws.com/foo.jpg</url>
            </evidence>
            <evidence>
              <id>88cfb8dd</id>
              <comments>text evidence</comments>
              <created-at type="datetime">2017-06-21T20:44:42Z</created-at>
              <sent-to-processor-at nil="true"/>
              <url nil="true"/>
            </evidence>
          </evidence>
          <transaction>
            <id>#{id}</id>
            <amount>100.00</amount>
            <created-at>2017-06-21T20:44:41Z</created-at>
            <order-id nil="true"/>
            <purchase-order-number nil="true"/>
            <payment-instrument-subtype>Visa</payment-instrument-subtype>
          </transaction>
          <date-opened type=\"date\">2014-03-21</date-opened>
        </dispute>
      XML
    end

    def _new_dispute_expired_sample_xml(id)
      <<-XML
        <dispute>
          <id>#{id}</id>
          <amount>100.00</amount>
          <amount-disputed>100.00</amount-disputed>
          <amount-won>95.00</amount-won>
          <case-number>CASE-12345</case-number>
          <created-at type="datetime">2017-06-16T20:44:41Z</created-at>
          <currency-iso-code>USD</currency-iso-code>
          <forwarded-comments nil="true"/>
          <kind>chargeback</kind>
          <merchant-account-id>ytnlulaloidoqwvzxjrdqputg</merchant-account-id>
          <reason>fraud</reason>
          <reason-code nil="true"/>
          <reason-description nil="true"/>
          <received-date type="date">2016-02-15</received-date>
          <reference-number>REF-9876</reference-number>
          <reply-by-date type="date">2016-02-22</reply-by-date>
          <status>expired</status>
          <updated-at type="datetime">2017-06-16T20:44:41Z</updated-at>
          <original-dispute-id>9qde5qgp</original-dispute-id>
          <status-history type="array">
            <status-history>
              <status>open</status>
              <timestamp type="datetime">2017-06-16T20:44:41Z</timestamp>
            </status-history>
            <status-history>
              <status>expired</status>
              <timestamp type="datetime">2017-06-25T20:50:55Z</timestamp>
            </status-history>
          </status-history>
          <evidence type="array"/>
          <transaction>
            <id>#{id}</id>
            <amount>100.00</amount>
            <created-at>2017-06-21T20:44:41Z</created-at>
            <order-id nil="true"/>
            <purchase-order-number nil="true"/>
            <payment-instrument-subtype>Visa</payment-instrument-subtype>
          </transaction>
          <date-opened type=\"date\">2014-03-21</date-opened>
        </dispute>
      XML
    end

    def _disbursement_exception_sample_xml(id)

      <<-XML
        <disbursement>
          <id>#{id}</id>
          <transaction-ids type="array">
            <item>afv56j</item>
            <item>kj8hjk</item>
          </transaction-ids>
          <success type="boolean">false</success>
          <retry type="boolean">false</retry>
          <merchant-account>
            <id>merchant_account_token</id>
            <currency-iso-code>USD</currency-iso-code>
            <sub-merchant-account type="boolean">false</sub-merchant-account>
            <status>active</status>
          </merchant-account>
          <amount>100.00</amount>
          <disbursement-date type="date">2014-02-10</disbursement-date>
          <exception-message>bank_rejected</exception-message>
          <follow-up-action>update_funding_information</follow-up-action>
        </disbursement>
      XML
    end

    def _disbursement_sample_xml(id)

      <<-XML
        <disbursement>
          <id>#{id}</id>
          <transaction-ids type="array">
            <item>afv56j</item>
            <item>kj8hjk</item>
          </transaction-ids>
          <success type="boolean">true</success>
          <retry type="boolean">false</retry>
          <merchant-account>
            <id>merchant_account_token</id>
            <currency-iso-code>USD</currency-iso-code>
            <sub-merchant-account type="boolean">false</sub-merchant-account>
            <status>active</status>
          </merchant-account>
          <amount>100.00</amount>
          <disbursement-date type="date">2014-02-10</disbursement-date>
          <exception-message nil="true"/>
          <follow-up-action nil="true"/>
        </disbursement>
      XML
    end

    def _account_updater_daily_report_sample_xml(id)

      <<-XML
        <account-updater-daily-report>
          <report-date type="date">2016-01-14</report-date>
          <report-url>link-to-csv-report</report-url>
        </account-updater-daily-report>
      XML
    end

    def _auth_status_transitioned_sample_xml(id)
      <<-XML
        <connected-merchant-status-transitioned>
          <merchant-public-id>#{id}</merchant-public-id>
          <status>new_status</status>
          <oauth-application-client-id>oauth_application_client_id</oauth-application-client-id>
        </connected-merchant-status-transitioned>
      XML
    end

    def _auth_paypal_status_changed_sample_xml(id)
      <<-XML
        <connected-merchant-paypal-status-changed>
          <oauth-application-client-id>oauth_application_client_id</oauth-application-client-id>
          <merchant-public-id>#{id}</merchant-public-id>
          <action>link</action>
        </connected-merchant-paypal-status-changed>
        XML
    end

    def _oauth_access_revoked_sample_xml(id)
      <<-XML
        <oauth-application-revocation>
          <merchant-id>#{id}</merchant-id>
          <oauth-application-client-id>oauth_application_client_id</oauth-application-client-id>
        </oauth-application-revocation>
      XML
    end

    def _ideal_payment_complete_sample_xml(id)
      <<-XML
        <ideal-payment>
          <id>#{id}</id>
          <status>COMPLETE</status>
          <issuer>ABCISSUER</issuer>
          <order-id>ORDERABC</order-id>
          <currency>EUR</currency>
          <amount>10.00</amount>
          <created-at>2016-11-29T23:27:34.547Z</created-at>
          <approval-url>https://example.com</approval-url>
          <ideal-transaction-id>1234567890</ideal-transaction-id>
        </ideal-payment>
      XML
    end

    def _ideal_payment_failed_sample_xml(id)
      <<-XML
        <ideal-payment>
          <id>#{id}</id>
          <status>FAILED</status>
          <issuer>ABCISSUER</issuer>
          <order-id>ORDERABC</order-id>
          <currency>EUR</currency>
          <amount>10.00</amount>
          <created-at>2016-11-29T23:27:34.547Z</created-at>
          <approval-url>https://example.com</approval-url>
          <ideal-transaction-id>1234567890</ideal-transaction-id>
        </ideal-payment>
      XML
    end

    def _granted_payment_instrument_update_sample_xml(id)
      <<-XML
        <granted-payment-instrument-update>
          <grant-owner-merchant-id>vczo7jqrpwrsi2px</grant-owner-merchant-id>
          <grant-recipient-merchant-id>cf0i8wgarszuy6hc</grant-recipient-merchant-id>
          <payment-method-nonce>
            <nonce>ee257d98-de40-47e8-96b3-a6954ea7a9a4</nonce>
            <consumed type="boolean">false</consumed>
            <locked type="boolean">false</locked>
          </payment-method-nonce>
          <token>abc123z</token>
          <updated-fields type="array">
            <item>expiration-month</item>
            <item>expiration-year</item>
          </updated-fields>
        </granted-payment-instrument-update>
      XML
    end

    def _payment_method_revoked_by_customer_sample_xml(id)
      <<-XML
        <paypal-account>
          <billing-agreement-id>a-billing-agreement-id</billing-agreement-id>
          <created-at type="datetime">2019-01-01T12:00:00Z</created-at>
          <customer-id>a-customer-id</customer-id>
          <default type="boolean">true</default>
          <email>name@email.com</email>
          <global-id>cGF5bWVudG1ldGhvZF9jaDZieXNz</global-id>
          <image-url>https://assets.braintreegateway.com/payment_method_logo/paypal.png?environment=test</image-url>
          <subscriptions type="array"/>
          <token>#{id}</token>
          <updated-at type="datetime">2019-01-02T12:00:00Z</updated-at>
          <is-channel-initiated nil="true"/>
          <payer-id>a-payer-id</payer-id>
          <payer-info nil="true"/>
          <limited-use-order-id nil="true"/>
          <revoked-at type="datetime">2019-01-02T12:00:00Z</revoked-at>
        </paypal-account>
      XML
    end

    def _local_payment_completed_sample_xml(id)
      <<-XML
        <local-payment>
          <payment-id>PAY-XYZ123</payment-id>
          <payer-id>ABCPAYER</payer-id>
          <payment-method-nonce>ee257d98-de40-47e8-96b3-a6954ea7a9a4</payment-method-nonce>
          <transaction>
            <id>#{id}</id>
            <status>authorized</status>
            <amount>49.99</amount>
            <order-id>order4567</order-id>
          </transaction>
        </local-payment>
      XML
    end
  end
end
