$LOAD_PATH << '..' unless $LOAD_PATH.include? '..'
require 'qwik/util-pathname'
require 'qwik/page-files'

module Qwik
  class Site
    def files(k = 'FrontPage')
      page = self[k]
      return nil if page.nil?
      page.files = PageFiles.new(@dir, k) if page.files.nil?
      return page.files
    end

    # obsolete
    def attach
      @attach = SiteAttach.new(@dir) unless defined? @attach
      return @attach
    end
  end

  # obsolete
  class SiteAttach
    include Enumerable
    include AttachModule

    def initialize(site_dir)
      @attach_path = site_dir.path+'.attach'
    end
  end
end

if $0 == __FILE__
  require 'qwik/testunit'
  require 'qwik/test-module-path'
  $test = true
end

if defined?($test) && $test
  class TestSiteAttach < Test::Unit::TestCase
    def test_site_attach
      dir = 'test/'.path
      dir.setup
      attach = Qwik::SiteAttach.new(dir)

      d = dir+'.attach'
      d.teardown if d.exist?

      ok_eq(false, attach.exist?('t.txt'))

      # test put
      attach.fput('t.txt', 't')
      ok_eq(true, attach.exist?('t.txt'))

      # test get
      path = attach.path('t.txt')
      ok_eq('test/.attach/t.txt', path.to_s)
      ok_eq('t', path.read)

      # test delete
      attach.delete('t.txt')
      ok_eq(false, attach.exist?('t.txt'))

      # test_security
#      path = attach.path('t/t.txt') # ok
#      assert_raise(Qwik::CanNotAccessParentDirectory) {
#	path = attach.path('../t.txt') # bad
#      }

      dir.teardown
    end
  end
end