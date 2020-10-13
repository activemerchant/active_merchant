require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::Gateway do
  before :each do
    @gateway = Braintree::Gateway.new(
      :environment => :development,
      :merchant_id => "integration_merchant_id",
      :public_key => "integration_public_key",
      :private_key => "integration_private_key",
    )

  end

  describe "query" do
    it "makes valid GraphQL queries when given a definition" do
      definition = <<-GRAPHQL
      mutation ExampleServerSideSingleUseToken($input: TokenizeCreditCardInput!) {
        tokenizeCreditCard(input: $input) {
          paymentMethod {
            id
            usage
            details {
              ... on CreditCardDetails {
                bin
                brandCode
                last4
                expirationYear
                expirationMonth
              }
            }
          }
        }
      }
      GRAPHQL

      variables = {
        "input" => {
          "creditCard" => {
            "number" => "4005519200000004",
            "expirationYear" => "2024",
            "expirationMonth" => "05",
            "cardholderName" => "Joe Bloggs",
          }
        }
      }

      response = @gateway.graphql_client.query(definition, variables)
      payment_method = response[:data][:tokenizeCreditCard][:paymentMethod]
      details = payment_method[:details]

      expect(payment_method[:id]).to be
      expect(details[:bin]).to eq("400551")
      expect(details[:last4]).to eq("0004")
      expect(details[:brandCode]).to eq("VISA")
      expect(details[:expirationMonth]).to eq("05")
      expect(details[:expirationYear]).to eq("2024")
    end

    it "makes valid GraphQL queries when given a definition" do
      definition = <<-GRAPHQL
      query {
        ping
      }
      GRAPHQL

      response = @gateway.graphql_client.query(definition)

      expect(response[:data]).to eq({:ping=>"pong"})
    end
  end
end
