module CommStub
  class Stub
    def initialize(gateway, method_to_stub, action)
      @gateway = gateway
      @action = action
      @complete = false
      @method_to_stub = method_to_stub
    end

    def check_request(&block)
      @check = block
      self
    end

    def respond_with(*responses)
      @complete = true
      check = @check
      (class << @gateway; self; end).send(:define_method, @method_to_stub) do |*args|
        check.call(*args) if check
        (responses.size == 1 ? responses.last : responses.shift)
      end
      @action.call
    end

    def complete?
      @complete
    end
  end

  def stub_comms(method_to_stub=:ssl_post, &action)
    if @last_comm_stub
      assert @last_comm_stub.complete?, "Tried to stub communications when there's a stub already in progress."
    end
    @last_comm_stub = Stub.new(@gateway, method_to_stub, action)
  end

  def teardown
    assert(@last_comm_stub.complete?) if @last_comm_stub
  end
end