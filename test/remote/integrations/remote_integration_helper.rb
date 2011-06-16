require 'mechanize'
require 'action_view/base'
require 'launchy'
require 'mongrel'

module RemoteIntegrationHelper
  class FakeView < ActionView::Base
    include ActiveMerchant::Billing::Integrations::ActionViewHelper
  end
  
  def submit(string)
    view = FakeView.new
    body = view.render(:inline => string)
    page = Mechanize::Page.new(nil, {'content-type' => 'text/html; charset=utf-8'}, body, nil, agent)
    page.forms.first.submit
  end
  
  def agent
    @agent ||= Mechanize.new{|a| a.log = Logger.new(STDERR) if verbose? }
  end

  def listen_for_notification(external_port=42063)
    exception = nil
    requests = []
    test = self
    server = notification_server do |request, response|
      begin
        test.log("[HANDLER] request received")
        requests << request
        response.start(200, true){|h,b| b << "OK"}
      rescue Exception => e
        exception = e
      end
    end
    listener = server.run
    
    mapper = Thread.new do
      require 'UPnP.rb'
      upnp = UPnP::UPnP.new(true, 10)
      begin
        log "[MAPPER] adding port mapping"
        upnp.addPortMapping(external_port, 42063, UPnP::Protocol::TCP, "AM Test Port")
        log "[MAPPER] yielding"
        yield("http://#{upnp.externalIP}#{":#{external_port}" unless external_port == 80}/")
        count = 0
        20.times do
          log "[MAPPER] waiting"
          sleep 1
          break if requests.size > 0 && requests.size == count
          count = requests.size
        end
        log "[MAPPER] returned"
      rescue Exception => e
        log "[MAPPER] exception #{e}"
        exception = e
      ensure
        log "[MAPPER] deleting port mapping"
        upnp.deletePortMapping(external_port, UPnP::Protocol::TCP)
        log "[MAPPER] stopping server"
        server.stop(true)
        log "[MAPPER] server stopped"
      end
    end
    
    [listener, mapper].each{|t| t.abort_on_exception = true}
    [listener, mapper].each{|t| t.join}
    
    raise exception if exception
    
    assert requests.size > 0

    request = requests.last
    log "[REQUEST] QUERY: #{request.params["QUERY_STRING"]}"
    log "[REQUEST] BODY: #{request.body.string}"
    request
  end
  
  def notification_server(&handler_body)
    http_server = Mongrel::HttpServer.new('0.0.0.0', 42063)
    handler = Mongrel::HttpHandler.new
    handler.class_eval do
      define_method(:process, &handler_body)
    end
    http_server.register('/', handler)
  end

  def log(message)
    puts message if verbose?
  end
  
  def verbose?
    (ENV["ACTIVE_MERCHANT_DEBUG"] == "true")
  end
  
  def open_in_browser(body)
    File.open('tmp.html', 'w'){|f| f.write body}
    Launchy::Browser.run("file:///#{Dir.pwd}/tmp.html")
  end
end