#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module CardStorage
      module Response
        class DeleteCardResponse < Iyzipay::Client::Response

          def from_json(json_result)
            Mapper::DeleteCardResponseMapper.new.map_response(self, json_result)
          end

        end
      end
    end
  end
end
