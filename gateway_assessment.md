I need you to identify and extract information related to an specific gateway, I have grouped the extracted data into 3 sections 
(Transactions, Extra Features and Payment Methods) 

# Gateway documentation Context:

This is the Maya gateway API documentation page (https://developers.maya.ph/reference/pay) used as the  knowledge base to identify and extract each relevant piece of inforamtion.

Note: The gateway docs have several implementations, the one that is under "Payments Processing Platform" and also take into consideration the "Maya vault" section for storing payment methods.

# Transactions
based on this page I need you to confirm if the following operation types are supported, here are the operations and their definitions:

- Authorize:
A transaction type where the payment gateway through the CreditCard issuer verifies if the card is valida and customer has sufficient funds for a purchase but does not capture the funds immediately.

- Capture:
The process of tranforming an authorized transaction into a completed payment, capturing the funds from the customer's account.

- Partial capture:
Capturing only a portion of the authorized amount in a transaction.

- Purchase:
A transaction where the payment gateway both authorizes the payment and captures the funds simultaneously.

- Void: 
Canceling an Authorization transaction before it is settled, typically done before the funds are captured.

- Verify:
A transaction type used to check the validity of a payment method without actually processing a payment.

- Refund: 
The process of returning funds to the customer for a previous transaction, typically done after funds are captured and transaction has been settled.

- Partial Refund: 
Refunding only a portion of the original transaction amount.

- General Credit: 
A transaction type where funds are credited to the customer's account, often used for payouts or refunds.

- Store: 
Stand alone transaction to tokenize and securely storing a customer's payment method on the Gateways vault for future transactions, it should be antstand alone end-point or transaction type and not part of purchas or authorize transaction.

- Unstore: 
Removing a stored payment method from the gateway's system, it's also known as redact or delete.

## Output Specification and Format

for each transaction type I need you to respond with an csv file structured like this:


| Transaction | Supported | Explanation                                                                           | Link                          |
|-------------|-----------|---------------------------------------------------------------------------------------|-------------------------------|
| Authorize   | Yes       | The "Payments" endpoint is the main one used for authorizations.                      | [Authorize](https://docs.adyen.com/api...) |
| Capture     | Yes       | This is achieved by setting the captureDelay parameter "auto" in the payments request | [Capture](https://docs.adyen.com/api...)   |

## Considerations:

These considerations will help you with the criteria to explain if the transaction is supported or not:

* Be aware of deprecated warnings or any other warning when analyzing if a transaction is supported.
* The link column at the end of the table should have a link that supports the claims done in the explanation column.

# Extra Features:
We need to also identify if some features are supported by the gateway, this is the list of features and their description:

- Level II &  Level III:
Extra information on transaction the purchase/authorize transaction, Level II is targeted to tax-related information (tax Id, tax amount, customer code, etc) and level III is targeted to the purchase items (quantity, prices, unit, category, etc)

- 3DS Global:
Also know as 'third-party 3DS', refers to the gateway capacity to receive the result as part of an authorize/purchase/verify/store transaction the result of a 3DS authentication that was conducted by a 3DS server that doesn't belong to the gateway. the resulting data include:

    * `eci`: Electronic Commerce Indicator, a value that indicates the security level of the transaction.
    * `cavv`: Cardholder Authentication Verification Value, a cryptographic value that validates the cardholder's identity.
    * `ds_transaction_id`: Directory Server Transaction ID, a unique identifier for the 3DS transaction assigned by the directory server.
    * `acs_transaction_id`: Access Control Server Transaction ID, a unique identifier for the transaction assigned by the access control server.
    * `cavv_algorithm`: The algorithm used to generate the CAVV.
    * `directory_response_status`: The response status from the directory server indicating the outcome of the 3DS authentication.
    * `authentication_response_status`: The response status from the access control server indicating the result of the authentication.
    * `xid`: Transaction Identifier, a unique identifier for the transaction.
    * `enrolled`: Indicates whether the cardholder is enrolled in the 3DS program.
    * `three_ds_server_trans_id`: 3DS Server Transaction ID, a unique identifier for the transaction assigned by the 3DS server.

- 3DS Gateway Specific:
Here the 3DS authentication is being provided by the gateway itself, most of the cases a different flow that usually is asyncronous needs to
be applied, so you will see some flags on the transaction that tells the gateway that merchant desires to follow a 3DS flow.

- Stored Credentials:
Stored credentials is a payments framework that is used by the main credit card schemes to deal with recurring payments using stored credit cards (Card of File), to that each transaction should send params like:

   * `initiator`: Indicates who initiated the transaction (`merchant` or `cardholder`).
   * `reason_type`: The reason for storing the credential (`recurring`, `installment`, `unscheduled`).
   * `initial_transaction`: A boolean indicating if this is the initial transaction in a series.
   * `network_transaction_id`: An identifier for the network transaction.

for each extra feature type I need you to respond with an csv file with structure table structure like this:

| Feature            | Supported | Explanation                          | Link                          |
|--------------------|-----------|--------------------------------------|-------------------------------|
| 3Ds Global         | Yes       | You can find where to add 3DS info.. | https://docs.adyen.com/api... |
| Stored Credentials | Yes       | This feature is supported because    | https://docs.adyen.com/api..  |


# Payment methods

We need to identify what are the supported payment methods, so i need you to tell me if each one of the following payment methods is supported:

- Credit Cards
- Bank accounts (ACH / SEPA)
- Apple Pay
- Google pay
- Network Tokens

## Considerations

This considerations help with the criteria to explain if the payment method is supported or not:

* Google Pay => To identify if Google Ray is supported we need to check if gateway supports them as third party Network Tokens, not native google pay tokens.
* Apple Pay => To identify if Apple Ray is supported we need to check if gateway supports them as third party Network Tokens, not native Apple pay tokens.
* Network Tokens => It refers by tokens created by other entities with a different TRID (Token Requestor Id)

for each extra feature type I need you to respond with an csv file with structure table structure like this:

| Payment Method | Supported | Explanation                              | Link                          |
| -------------- | --------- | ---------------------------------------- | ----------------------------- |
| Credit Cards   | Yes       | Credit cards are supported on brands ... | https://docs.adyen.com/api... |
|                |           |                                          |                               |
