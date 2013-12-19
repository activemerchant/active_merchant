require 'json'

class SlidePayResponse < String
  attr_accessor :success, :custom, :operation, :endpoint, :timezone,
                :method, :obj, :id, :milliseconds, :data, :data_md5

  def initialize(response_json=nil)
    if response_json
      # Fill the contents of this object with the response JSON
      replace response_json
      parse_object_from_json
    end
  end

  def was_successful?
    @success == true
  end

  private

  def parse(body)
    JSON.parse(body)
  end

  def parse_object_from_json
    object = parse(self)

    @success = object['success']
    @custom = object['custom']
    @operation = object['operation']
    @endpoint = object['endpoint']
    @timezone = object['timezone']
    @method = object['method']
    @obj = object['obj']
    @id = object['id']
    @milliseconds = object['milliseconds']
    @data = object['data']
    @data_md5 = object['data_md5']
  end
end