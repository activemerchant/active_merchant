#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Service
      class CardStorageServiceClient < BaseServiceClient
        def self.from_configuration(configuration)
          self.new(configuration)
        end

        def create_card(request)
          raw_result = HttpClientTemplate.post("#{@configuration.base_url}/cardstorage/card", get_http_header(request), request.to_json_string)
          response = CardStorage::Response::CreateCardResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

        def delete_card(request)
          raw_result = HttpClientTemplate.delete("#{@configuration.base_url}/cardstorage/card", get_http_header(request), request.to_json_string)
          response = CardStorage::Response::DeleteCardResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end

        def get_cards(request)
          raw_result = HttpClientTemplate.post("#{@configuration.base_url}/cardstorage/cards", get_http_header(request), request.to_json_string)
          response = CardStorage::Response::RetrieveCardListResponse.new
          json_decode_and_prepare_response(response, raw_result)
          response
        end
      end
    end
  end
end
