#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
      module CardStorage
        module Response
          class CreateCardResponse < Iyzipay::Client::Response
            attr_accessor :external_id
            attr_accessor :email
            attr_accessor :card_user_key
            attr_accessor :card_token

            def from_json(json_result)
              Mapper::CreateCardResponseMapper.new.map_response(self, json_result)
            end
          end
        end
      end
    end
  end
