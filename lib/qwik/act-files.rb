# Copyright (C) 2003-2006 Kouichirou Eto, All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
# You can redistribute it and/or modify it under the terms of the GNU GPL 2.

$LOAD_PATH.unshift '..' unless $LOAD_PATH.include? '..'

module Qwik
  class Action
    D_ExtFiles = {
      :dt => 'Attach file function',
      :dd => 'You can attach files to pages.',
      :dc => "* How to
Go to edit page, you see attach file form on the bottom.
You can attach many files at once by following 'attach many' link.

If you attached files, system automatically added link to the files.
 {{file(\"somefile.txt\")}}
** Show attached files plugin
{{show_files}}
 {{show_files}}
You can show the list of attached files.
"
    }

    D_ExtFiles_ja = {
      :dt => 'ファイル添付機能 ',
      :dd => 'ページにファイルを添付できます。',
      :dc => '* 使い方
編集画面の一番下に、ファイル添付のためのフォームがあります。
「\'\'\'たくさん添付する\'\'\'」というリンクをたどると、
たくさんのファイルを一度に添付するための画面にとびます。

添付をすると、に自動的にページの一番下に添付ファイルへのリンクがつきます。
 {{file("somefile.txt")}}
** 添付ファイル一覧プラグイン
 {{show_files}}
ファイル一覧を表示できます。
'
    }

    # ============================== files list
    def plg_show_files
      div = [:div, {:class=>'files'},
	[:h5, [:a, {:href=>"#{@req.base}.files"}, _('Files')]]]
      list = files_list
      div << [:ul, *list] if list
      return div
    end

    def files_list
      return files_list_internal(@req.base, @site.files(@req.base))
    end

    def files_list_internal(base, files)
      list = files.list
      return nil if list.empty?
      return list.map {|file|
	encoded = Filename.encode(file)
	[:li, [:a, {:href=>"#{base}.files/#{encoded}"}, file.to_page_charset],
	  [:span, {:class=>'delete'},
	    ' (', [:a, {:href=>"#{base}.file_del/#{encoded}"},
	      _('del')], ')'],
	  [:span, {:class=>'download'},
	    ' (', [:a, {:href=>"#{base}.download/#{encoded}"},
	      _('download')], ')'],
	]
      }
    end

    # ============================== download
    FILES_FORCE_DOWNLOAD = %w(doc xls ppt)

    def ext_download
      if 0 < @req.path_args.length	# has target file
	if @req.path_args[0] == '.theme'
	  @req.path_args.shift
	  return pre_act_theme
	end

	filename = files_parse_filename(@req.path_args)
	files = @site.files(@req.base)
	if files.nil? || ! files.exist?(filename)
	  return c_notfound(_('No such file'))
	end

	if FILES_FORCE_DOWNLOAD.include?(filename.path.ext)
	  return c_download(files.path(filename).to_s)	# Download it.
	end

	return c_download(files.path(filename).to_s)	# Download it.
      end

      return c_nerror(_('Error')) 
    end
    alias act_download ext_download

    # ============================== files
    def ext_files
      if 0 < @req.path_args.length	# has target file
	if @req.path_args[0] == '.theme'
	  @req.path_args.shift
	  return pre_act_theme
	end

	filename = files_parse_filename(@req.path_args)
	files = @site.files(@req.base)
	if files.nil? || ! files.exist?(filename)
	  return c_notfound(_('No such file'))
	end

	if FILES_FORCE_DOWNLOAD.include?(filename.path.ext)
	  return c_download(files.path(filename).to_s)	# Download it.
	end

	if ! Filename.allowable_characters_for_path?(filename)
	  return c_download(files.path(filename).to_s)	# Download it.
	end

	return c_simple_send(files.path(filename).to_s)	# Send it.
      end

      # Upload the content.
      content = @req.query['content']
      return files_put(content) if content

      # Show files form and the list.
      return show_files_form_and_the_list
    end
    alias act_files ext_files

    def show_files_form_and_the_list
      c_require_member
      ar = plg_files_form(20)
      w = c_notice(_('Attach file')) {[
	  [:p, _('Attach a file')],
	  ar
	]}
      return w
    end

    def files_parse_filename(args)
      filename = args.join('/').set_url_charset		# Must be UTF-8
      filename = Filename.decode(filename)
      return filename
    end

    def ext_file_del
      c_require_member
      return c_nerror(_('Error')) if @req.path_args.length == 0
      filename = files_parse_filename(@req.path_args)

      if @req.path_args[0] == '.theme'
	@req.path_args.shift
	return pre_act_theme
      end

      # confirm before delete
      return files_delete_confirm(filename) unless @req.is_post?
      return files_delete(filename)	# delete it
    end

    def files_delete_confirm(filename)
      encoded = Filename.encode(filename)
      action = "../#{@req.base}.file_del/#{encoded}"	# Bad...
      return c_notice(_('Confirm to delete a file')) {
	[:form, {:method=>'POST', :action=>action},
	  [:p, _("Push 'Delete' to delete a file")],
	  [:p, [:input, {:type=>'submit', :value=>_('Delete')}]]]
      }
    end

    def files_delete(filename)
      c_require_post
      url = "../#{@req.base}.html"
      begin
	@site.files(@req.base).delete(filename)
      rescue FileNotExist
	return c_nerror(_('Already deleted.'), url)
      rescue FailedToDelete
	return c_nerror(_('Failed to delete.'), url)
      end

      c_make_log('file delete')		# FILE DELETE

      return c_notice(_('The file is deleted.'), url) {
	[:p, [:a, {:href=>url}, _('Go back')]]
      }
    end

    # ==============================
    def plg_files_form(upload_number=1)
      files_form(@req.base, upload_number)
    end

    # called from act-edit
    def files_form(pagename, upload_number=1)
      size = '40'
      ar = []
      upload_number.times {
	ar << [:div, {:class=>'inputfile'},
	  [:input, {:type=>'file', :name=>'content'}]]
      }
      ar << [:div, {:class=>'input_submit'},
	[:input, {:class=>'submit', :type=>'submit', :value=>_('Attach')}]]
      form = [:form, {:action=>"#{pagename}.files",
	  :method=>'POST', :enctype=>'multipart/form-data'},
	*ar]
      return form
    end

    private

    def files_put(content)
      c_require_member
      c_require_post

      list = []
      content.each_data {|data|
	fullfilename = data.filename
	next if fullfilename.empty?

	# Get basename.
	#filename = fullfilename.path.basename.to_s
	filename = Action.get_basename(fullfilename)

	max_size = @site.siteconfig['max_file_size'].to_i
	if max_size < data.length
	  list << [:p, [:strong, filename], [:em, _('Max size exceeded.')],
	    [:br],
	    _('Max size'), max_size, [:br],
	    _('File size'), data.length, [:br]]
	  next
	end

	# If the file is saved as another name, you can use return value.
	filename = @site.files(@req.base).fput(filename, data)

	c_make_log('file attach')	# FILE ATTACH

	page = @site[@req.base]
	page.add("\n{{file(#{filename})}}\n")	# files_update_page

	list << [:p, [:strong, filename], ' : ', _('The file is saved.')]
      }

      url = "#{@req.base}.html"

      ar = list + [
	[:hr],
	[:p, _('Go next'), ' : ', [:a, {:href=>url}, url]],
      ]
      return c_notice(_('Attach file done'), url) { ar }
    end

    def self.get_basename(filename)
      basename = filename.sub(/\A.*[\/\\]([^\/\\]+)\z/) { $1 }
      return basename
    end
  end
end

if $0 == __FILE__
  require 'qwik/test-common'
  $test = true
end

if defined?($test) && $test
  class TestActFiles < Test::Unit::TestCase
    include TestSession

    def test_files
      t_add_user

      ok_wi([:div, {:class=>'files'},
	      [:h5, [:a, {:href=>'1.files'}, 'Files']]],
	    '{{show_files}}')

      page = @site['1']
      page.store('t')

      # See the form.
      res = session('/test/1.files')
      form = res.body.get_path("//div[@class='section']/form")
      ok_eq({:method=>'POST', :action=>'1.files',
	      :enctype=>'multipart/form-data'}, form[1])
      ok_eq([:div, {:class=>'inputfile'},
	      [:input, {:type=>'file', :name=>'content'}]], form[2])
      ok_eq([:div, {:class=>'input_submit'},
	      [:input, {:value=>'Attach', :type=>'submit', :class=>'submit'}]],
	    form.last)

      # Put a file.
      res = session('POST /test/1.files') {|req|
	req.query.update('content'=>t_make_content('t.txt', 't'))
      }
      ok_title('Attach file done')

      # Check log.
      eq(",0.000000,user@e.com,file attach,1\n", @site['_SiteLog'].load)

      # The reference is added.
      ok_eq('t

{{file(t.txt)}}
', page.load)

      # Get the file.
      res = session('/test/1.files/t.txt')
      ok_eq('t', res.body)
      ok_eq('text/plain', res['Content-Type'])

      # Put a file with same file name again.
      # The file is saved as another filename.
      res = session('POST /test/1.files') {|req|
	req.query.update('content'=>t_make_content('t.txt', 't2'))
      }
      ok_title('Attach file done')
      ok_xp([:p, [:strong, '1-t.txt'], ' : ',
	      'The file is saved.'],
	    "//div[@class='section']/p")

      # Delete the second file.
      res = session('POST /test/1.file_del/1-t.txt')
      ok_title('The file is deleted.')

      # See the page again.
      ok_wi([:div, {:class=>'files'},
	      [:h5, [:a, {:href=>'1.files'}, 'Files']],
	      [:ul,
		[:li, [:a, {:href=>'1.files/t.txt'}, 't.txt'],
		  [:span, {:class=>'delete'},
		    " (", [:a, {:href=>"1.file_del/t.txt"}, 'del'], ")"],
		  [:span, {:class=>'download'},
		    " (", [:a, {:href=>'1.download/t.txt'}, 'download'],
		    ")"]]]],
	    '{{show_files}}')

      # Put another file.
      res = session('POST /test/1.files') {|req|
	req.query.update('content'=>t_make_content('s.png', TEST_PNG_DATA))
      }
      ok_title('Attach file done')

      # The reference is added too.
      ok_eq('{{show_files}}

{{file(s.png)}}
', page.load)

      # See the page again.
      res = session('/test/1.html')
      ok_xp([:div, {:class=>'files'},
	      [:h5, [:a, {:href=>'1.files'}, 'Files']],
	      [:ul,
		[:li, [:a, {:href=>'1.files/s.png'}, 's.png'],
		  [:span, {:class=>'delete'},
		    " (", [:a, {:href=>"1.file_del/s.png"}, 'del'], ")"],
		  [:span, {:class=>'download'},
		    " (", [:a, {:href=>'1.download/s.png'},
		      'download'], ")"]],
		[:li, [:a, {:href=>'1.files/t.txt'}, 't.txt'],
		  [:span, {:class=>'delete'},
		    " (", [:a, {:href=>"1.file_del/t.txt"}, 'del'], ")"],
		  [:span, {:class=>'download'},
		    " (", [:a, {:href=>'1.download/t.txt'},
		      'download'], ")"]]]],
	    "//div[@class='files']")

      # Show a form to delete the file.
      res = session('/test/1.file_del/t.txt')
      ok_title('Confirm to delete a file')

      # Delete it.
      res = session('POST /test/1.file_del/t.txt')
      ok_title('The file is deleted.')

      # Try to delete it again.  But the file is already deleted.
      res = session('POST /test/1.file_del/t.txt')
      ok_title('Already deleted.')

      # Try to get file agin.  But the file is already deleted.
      res = session('/test/1.files/t.txt')
      ok_title('No such file')
    end

    def test_multi_files
      t_add_user
      page = @site.create_new

      # See the form.
      res = session('/test/1.files')
      form = @res.body.get_path("//div[@class='section']/form")
      ok_eq({:method=>'POST', :action=>'1.files',
	      :enctype=>'multipart/form-data'}, form[1])
      ok_eq([:div, {:class=>'inputfile'},
	      [:input, {:type=>'file', :name=>'content'}]], form[2])
      ok_eq([:div, {:class=>'inputfile'},
	      [:input, { :type=>'file', :name=>'content'}]], form[4])
      ok_eq([:div, {:class=>'input_submit'},
	      [:input, {:value=>'Attach', :type=>'submit', :class=>'submit'}]],
	    form.last)

      # Put multiple files.
      content1 = t_make_content('t1.txt', 't1')
      content2 = t_make_content('t2.txt', 't2')
      content1.append_data(content2)
      res = session('POST /test/1.files') {|req|
	req.query.update('content'=>content1)
      }

      ok_title('Attach file done')
      ok_in([
	      [:p, [:strong, 't1.txt'], ' : ', 'The file is saved.'],
	      [:p, [:strong, 't2.txt'], ' : ', 'The file is saved.'],
	      [:hr],
	      [:p, 'Go next', ' : ',
		[:a, {:href=>'1.html'}, '1.html']]],
	    "//div[@class='section']")

      # The reference is added.
      ok_eq('
{{file(t1.txt)}}

{{file(t2.txt)}}
', page.load)
    end

    def test_act_files
      t_add_user

      page = @site['FrontPage']
      page.store('t')

      # See the form.
      res = session('/test/.files')
      form = res.body.get_path("//div[@class='section']/form")
      ok_eq({:method=>'POST', :action=>'FrontPage.files',
	      :enctype=>'multipart/form-data'}, form[1])

      # Put a file.
      res = session('POST /test/.files') {|req|
	req.query.update('content'=>t_make_content('t.txt', 't'))
      }
      ok_title('Attach file done')

      # Check log.
      eq(",0.000000,user@e.com,file attach,FrontPage\n", @site['_SiteLog'].load)

      # The reference is added.
      ok_eq('t

{{file(t.txt)}}
', page.load)

      # Get the file.
      res = session('/test/.files/t.txt')
      ok_eq('t', res.body)
    end

    def test_jfilename
      t_add_user

      page = @site.create_new
      page.store('t')

      # Put a file with Japanese filename.
      res = session('POST /test/1.files') {|req|
	req.query.update('content'=>t_make_content('あ.txt', 't'))
      }
      ok_title('Attach file done')

      # Check log.
      ok_eq(",0.000000,user@e.com,file attach,1\n", @site['_SiteLog'].load)

      # The reference is added.
      ok_eq('t

{{file(あ.txt)}}
', page.load)

      # Get the file.
      res = session('/test/1.files/=E3=81=82.txt')
      ok_eq('t', res.body)

      # You can use SJIS charset.
      res = session('/test/1.files/あ.txt')
      ok_eq('t', res.body)

      # You can use UTF-8 charset.
      res = session('/test/1.files/あ.txt'.set_sourcecode_charset.to_url_charset)
      ok_eq('t', res.body)

      # Delete it.
      res = session('POST /test/1.file_del/=E3=81=82.txt')
      ok_title('The file is deleted.')
    end

    def test_download
      t_add_user

      page = @site.create_new
      page.store('t')

      # Put a file.
      res = session('POST /test/1.files') {|req|
	req.query.update('content'=>t_make_content('t.txt', 't'))
      }
      ok_title('Attach file done')

      # Error check.
      res = session('/test/1.download')
      ok_title('Error')

      # Download the file.
      res = session('/test/1.download/t.txt')
      ok_eq('text/plain', res['Content-Type'])
      ok_eq("attachment; filename=\"t.txt\"", res['Content-Disposition'])
      ok_eq('t', res.body)

      # Put a file with Japanese filename.
      res = session('POST /test/1.files') {|req|
	req.query.update('content'=>t_make_content('あ.txt', 't'))
      }
      ok_title('Attach file done')

      # Download the file.
      res = session('/test/1.download/=E3=81=82.txt')
      ok_eq('text/plain', res['Content-Type'])
      ok_eq("attachment; filename=\"あ.txt\"",
	    res['Content-Disposition'])
      ok_eq('t', res.body)
    end

    def test_force_download
      t_add_user

      page = @site.create_new
      page.store('t')

      # Put a file.
      res = session('POST /test/1.files') {|req|
	req.query.update('content'=>t_make_content('t.doc', 't'))
      }
      ok_title('Attach file done')

      # Download the file.
      res = session('/test/1.download/t.doc')
      ok_eq('application/msword', res['Content-Type'])
      ok_eq("attachment; filename=\"t.doc\"", res['Content-Disposition'])
      ok_eq('t', res.body)

      # Download by files extension.
      res = session('/test/1.files/t.doc')
      ok_eq('application/msword', res['Content-Type'])
      ok_eq("attachment; filename=\"t.doc\"", res['Content-Disposition'])
      ok_eq('t', res.body)
    end

    def test_class_method
      c = Qwik::Action
      eq("a.txt", c.get_basename("/tmp/a.txt"))
      eq("a.txt", c.get_basename("c:\\tmp\\a.txt"))
    end

    def test_upload_from_windows
      t_add_user

      page = @site.create_new
      page.store('t')

      # Put a file.
      res = session('POST /test/1.files') {|req|
	req.query.update('content'=>t_make_content("c:\\tmp\\t.txt", 't'))
      }
      ok_title('Attach file done')

      # Download by files extension.
      res = session('/test/1.files/t.txt')
      ok_eq('text/plain', res['Content-Type'])
      ok_eq('t', res.body)
    end

    def test_big_file
      t_add_user

      # Set max_file_size to 1MB.
      config = @site['_SiteConfig']
      max_size = 1 * 1024 * 1024	# 1MB
      config.store(":max_file_size:#{max_size}")

      page = @site.create_new
      page.store('t')

      # Try to store a file with 2MB size.
      big_content = '0' * (2 * 1024 * 1024)	# 2MB
      res = session('POST /test/1.files') {|req|
	req.query.update('content'=>t_make_content('t.txt', big_content))
      }
      ok_title('Attach file done')
      ok_in(["Max size exceeded."],
	    "//div[@class='section']/p/em")

      # Get the file.
      res = session('/test/1.files/t.txt')
      ok_title('No such file')
    end

    def test_force_download_by_character
      t_add_user

      page = @site.create_new
      page.store('t')

      # Put a file.
      res = session('POST /test/1.files') {|req|
	req.query.update('content'=>t_make_content('t!.txt', 't'))
      }
      ok_title('Attach file done')

      # Download the file.
      res = session('/test/1.download/t!.txt')
      ok_eq("attachment; filename=\"t!.txt\"", res['Content-Disposition'])
      ok_eq('t', res.body)

      # Download by files extension.
      res = session('/test/1.files/t!.txt')
      ok_eq("attachment; filename=\"t!.txt\"", res['Content-Disposition'])
      ok_eq('t', res.body)
    end
  end
end
