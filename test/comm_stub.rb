module CommStub
  class Stub
    def initialize(gateway, method_to_stub, action)
      @gateway = gateway
      @action = action
      @complete = false
      @method_to_stub = method_to_stub
      @check = nil
    end

    def check_request(&block)
      @check = block
      self
    end

    def respond_with(*responses)
      @complete = true
      check = @check
      singleton_class = (class << @gateway; self; end)
      singleton_class.send(:undef_method, @method_to_stub)
      singleton_class.send(:define_method, @method_to_stub) do |*args|
        check.call(*args) if check
        (responses.size == 1 ? responses.last : responses.shift)
      end
      @action.call
    end

    def complete?
      @complete
    end

    class Complete
      def complete?
        true
      end
    end
  end

  def last_comm_stub
    @last_comm_stub ||= Stub::Complete.new
  end

  def stub_comms(gateway=@gateway, method_to_stub=:ssl_post, &action)
    assert last_comm_stub.complete?, "Tried to stub communications when there's a stub already in progress."
    @last_comm_stub = Stub.new(gateway, method_to_stub, action)
  end

  def teardown
    assert(last_comm_stub.complete?)
  end
end
