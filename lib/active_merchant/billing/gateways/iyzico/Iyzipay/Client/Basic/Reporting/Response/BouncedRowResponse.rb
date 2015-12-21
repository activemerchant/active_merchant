#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Reporting
        module Response
          class BouncedRowResponse < Iyzipay::Client::Response
            attr_accessor :bounced_rows

            def from_json(json_result)
              Mapper::BouncedRowResponseMapper.new.map_response(self, json_result)
            end
          end
        end
      end
    end
  end
end
