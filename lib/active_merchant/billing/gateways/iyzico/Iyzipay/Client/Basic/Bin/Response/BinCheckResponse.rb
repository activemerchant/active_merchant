#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Bin
        module Response
          class BinCheckResponse < Iyzipay::Client::Response
            attr_accessor :bin_number
            attr_accessor :card_type
            attr_accessor :card_association
            attr_accessor :card_family
            attr_accessor :bank_name
            attr_accessor :bank_code

            def from_json(json_result)
              Mapper::BinCheckResponseMapper.new.map_response(self, json_result)
            end
          end
        end
      end
    end
  end
end
