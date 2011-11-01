module CommStub
  class Stub
    def initialize(gateway, action)
      @gateway = gateway
      @action = action
      @complete = false
    end

    def check_request(&block)
      @check = block
      self
    end

    def respond_with(*responses)
      @complete = true
      check = @check
      (class << @gateway; self; end).send(:define_method, :ssl_post) do |*args|
        check.call(*args) if check
        (responses.size == 1 ? responses.last : responses.shift)
      end
      @action.call
    end

    def complete?
      @complete
    end
  end

  def stub_comms(gateway=@gateway, &action)
    if @last_comm_stub
      assert @last_comm_stub.complete?, "Tried to stub communications when there's a stub already in progress."
    end
    @last_comm_stub = Stub.new(gateway, action)
  end

  def teardown
    assert(@last_comm_stub.complete?) if @last_comm_stub
  end
end