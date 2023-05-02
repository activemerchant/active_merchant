require 'onlinepayments/sdk'

include OnlinePayments::SDK
include OnlinePayments::SDK::Domain

merchant_id = 'NamastayTest'
api_key_id = '40Exxxxxxx'
secret_api_key = 'y7ndpxxxxxxxx'
configuration_file_name = File.expand_path('.', 'config_file')

client = Factory.create_client_from_file(configuration_file_name, api_key_id, secret_api_key)
merchant_client = client.merchant(merchant_id)

# output debug info to console
httpclient = merchant_client.communicator.connection.instance_variable_get(:@http_client)
httpclient.debug_dev = $stdout

payment_hash = {
  'order' => {
    'amountOfMoney' => {
      'amount' => '4005',
      'currencyCode' => 'EUR'
    },
    'references' => {
      'merchantReference' => nil,
      'descriptor' => 'Store Purchase',
      'invoiceData' => {
        'invoiceNumber' => nil
      }
    },
    'customer' => {
      'personalInformation' => {
        'name' => {
          'firstName' => 'Longbob',
          'surname' => 'Longsen'
        }
      },
      'contactDetails' => {
        'emailAddress' => 'example@example.com',
        'phoneNumber' => '(555)555-5555'
      },
      'billingAddress' => {
        'street' => '456 My Street',
        'additionalInfo' => 'Apt 1',
        'zip' => 'K1C2N6',
        'city' => 'Ottawa',
        'state' => 'ON',
        'countryCode' => 'CA'
      }
    }
  },
  'cardPaymentMethodSpecificInput' => {
    'paymentProductId' => '1',
    'skipAuthentication' => 'true',
    'skipFraudService' => 'true',
    'authorizationMode' => 'FINAL_AUTHORIZATION',
    'card' => {
      'cvv' => '123',
      'cardNumber' => '4567350000427977',
      'expiryDate' => '0924',
      'cardholderName' => 'Longbob Longsen'
    }
  },
  'shoppingCartExtension' => {}
}

payment_request = CreatePaymentRequest.new_from_hash(payment_hash)
payment_response = merchant_client.payments().create_payment(payment_request)
