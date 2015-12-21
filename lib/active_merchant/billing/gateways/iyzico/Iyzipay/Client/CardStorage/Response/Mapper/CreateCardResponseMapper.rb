#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module CardStorage
      module Response
        module Mapper
          class CreateCardResponseMapper < ResponseMapper

            def map_response(response, jsonResult)
              super
              response.external_id = jsonResult['externalId'] unless jsonResult['externalId'].nil?
              response.email = jsonResult['email'] unless jsonResult['email'].nil?
              response.card_user_key = jsonResult['cardUserKey'] unless jsonResult['cardUserKey'].nil?
              response.card_token = jsonResult['cardToken'] unless jsonResult['cardToken'].nil?
            end

          end
        end
      end
    end
  end
end
