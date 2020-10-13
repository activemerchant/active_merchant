require 'mechanize/test_case'

class TestMechanizeDirectorySaver < Mechanize::TestCase

  def setup
    super

    @uri = URI 'http://example/relative/tc_relative_links.html'
    @io = StringIO.new 'hello world'
  end

  def test_self_save_to
    in_tmpdir do
      saver = Mechanize::DirectorySaver.save_to 'dir'

      saver.new @uri, nil, @io, 200

      assert File.exist? 'dir/tc_relative_links.html'
      refute File.exist? 'dir/relative'
    end
  end

  def test_self_save_to_cd
    in_tmpdir do
      saver = Mechanize::DirectorySaver.save_to 'dir'

      FileUtils.mkdir 'other'

      Dir.chdir 'other' do
        saver.new @uri, nil, @io, 200
      end

      assert File.exist? 'dir/tc_relative_links.html'
      refute File.exist? 'dir/relative'
    end
  end

  def test_with_decode_filename
    in_tmpdir do
      saver = Mechanize::DirectorySaver.save_to 'dir', :decode_filename => true
      uri = URI 'http://example.com/foo+bar.html'
      saver.new uri, nil, @io, 200

      assert File.exist? 'dir/foo bar.html'
    end
  end

  def test_initialize_no_save_dir
    in_tmpdir do
      e = assert_raises Mechanize::Error do
        Mechanize::DirectorySaver.new @uri, nil, @io, 200
      end

      assert_match %r%no save directory specified%, e.message
    end
  end

end

