# Given the state of remote tests, the VCR gem will initially be disabled and
# will only be available in test classes that enable the VCRModule.
# To do this, simply add VCRModule with the prepend keyword.

module VCRRemote
  def setup
    class_name = self.name.match(/\((\w*)\)/)[1]

    unless config_already_defined?
      VCR.configure do |conf|
        conf.before_record do |interaction|
          if @gateway.supports_scrubbing
            interaction.request.body = @gateway.scrub(interaction.request.body)
            interaction.response.body = @gateway.scrub(interaction.response.body)
          end
        end
      end
    end

    VCR.turn_on!
    VCR.insert_cassette([class_name, method_name].compact.join('/').underscore)
    super
  end

  def teardown
    VCR.eject_cassette
    VCR.turn_off!
    super
  end

  private

  def config_already_defined?
    VCR.configuration.hooks[:before_record].any? do |hook|
      hook.hook.source_location.first =~ /vcr_module/
    end
  end
end
