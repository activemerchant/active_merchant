module Net
  remove_const "HTTP"
  
  class Response
    def initialize(result)
      @result = result
    end
    
    def body
      @result
    end
  end
  
  class Request < Struct.new(:host, :port, :query, :post_data)
    
    cattr_accessor :fail
    @@fail = false
    
    def post(query, post)
      self.query = query
      self.post_data = post
      Response.new(self.class.fail ? "INVALID": "VERIFIED")
    end    
    
  end
  
  class Net::HTTP
      
    
    def self.start(host, port) 
      request = Request.new
      request.host = host
      request.port = port    
      
      @packages ||= []
      @packages << request

      yield request
    end
    
    def self.packages
      @packages
    end
    
  end  
end

