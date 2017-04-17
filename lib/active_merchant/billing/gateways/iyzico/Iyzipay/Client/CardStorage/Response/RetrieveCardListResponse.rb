#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module CardStorage
      module Response
        class RetrieveCardListResponse < Iyzipay::Client::Response
          attr_accessor :card_user_key
          attr_accessor :card_details

          def from_json(json_result)
            Mapper::RetrieveCardListResponseMapper.new.map_response(self, json_result)
          end
        end
      end
    end
  end
end