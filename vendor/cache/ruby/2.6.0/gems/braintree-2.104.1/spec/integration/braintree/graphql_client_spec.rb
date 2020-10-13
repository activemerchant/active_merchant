require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe Braintree::GraphQLClient do
  before :each do
      @config = Braintree::Configuration.instantiate
  end

  describe "initialize" do
    it "assigns overriding graphql headers" do
      expect(@config.graphql_client.instance_variable_get("@graphql_headers")).to be_kind_of(Hash)
    end
  end

  describe "query" do
    it "makes valid GraphQL queries when given a definition" do
      definition = <<-GRAPHQL
      query {
        ping
      }
      GRAPHQL

      response = Braintree::GraphQLClient.new(@config).query(definition)

      expect(response[:data]).to eq({:ping=>"pong"})
    end

    it "makes valid GraphQL requests when given a definitiona and variable" do
      definition = <<-GRAPHQL
mutation CreateClientToken($input: CreateClientTokenInput!) {
  createClientToken(input: $input) {
    clientMutationId
    clientToken
  }
}
      GRAPHQL

      variables = {
        input: {
          clientMutationId: "abc123",
          clientToken: {
            merchantAccountId: "ABC123"
          }
        }
      }

      response = Braintree::GraphQLClient.new(@config).query(definition, variables)

      expect(response[:data][:createClientToken][:clientToken]).to be_a(String)
    end

    it "returns results parsable into validation errors" do
      definition = <<-GRAPHQL
query TransactionLevelFeeReport($date: Date!, $merchantAccountId: ID) {
  report {
    transactionLevelFees(date: $date, merchantAccountId: $merchantAccountId) {
      url
    }
  }
}
      GRAPHQL

      variables = {
        date: "2018-01-01",
        merchantAccountId: "some_merchant"
      }

      response = Braintree::GraphQLClient.new(@config).query(definition, variables)
      errors = Braintree::ValidationErrorCollection.new(response)

      expect(errors.size).to eq(1)
      expect(errors.first.message).to eq("Invalid merchant account id: some_merchant")
    end
  end
end
