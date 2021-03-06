# -*- coding: shift_jis -*-
# Copyright (C) 2003-2006 Kouichirou Eto, All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
# You can redistribute it and/or modify it under the terms of the GNU GPL 2.

$LOAD_PATH.unshift '..' unless $LOAD_PATH.include? '..'
require 'qwik/mail'
require 'qwik/password'
require 'qwik/act-httpauth'
require 'qwik/act-typekey'
require 'qwik/act-logout'
require 'qwik/act-getpass'

module Qwik
  class Action
    D_QwikWebLogin = {
      :dt => 'qwikWeb login',
      :dd => 'You can login by using three auth methods.',
      :dc => "* How to
** Login by TypeKey
You can login by using TypeKey authentication.
In login screen, you see 'Log in by TypeKey' link.
Follow the link and login at the TypeKey authentication page.
Since the qwikWeb system uses your mailaddress for the authentication,
it is necessary to select to tell your mail address.
** Login by password
Please input your mail address as user ID and input your password.
The password to login qwikWeb is automatically generated by the system.
Please follow 'Get Password' link to get the password.
** Login by Basic Authentication
You can use Basic Authentication.
When you are using a mobile phone that only have Basic Authentication method,
please follow 'Log in by Basic Authentication.' link.
"
    }

    D_QwikWebLogin_ja = {
      :dt => 'qwikWebのログイン',
      :dd => 'qwikWebでは三種類の認証方法を使えます。',
      :dc => "* 使い方
** TypeKeyによるログイン
TypeKey認証でログインすることができます。ログイン画面から「TypeKeyでロ
グインする」というリンクをたどってください。TypeKeyによる認証画面があ
らわれますので、その画面からログインします。qwikWebでは、メールアドレ
スによって認証をしているため、メールアドレスをシステムに通知する必要が
あります。

TypeKeyでのアカウント名ではなく、メールアドレスによって認証するため、
登録されているメールアドレスが、そのグループに登録されているメールアド
レスと一致している必要があります。
** パスワードでログイン
ユーザIDの欄に自分のメールアドレスを、またパスワード欄にはパスワードを
入力してください。qwikWebにおけるパスワードは、システムが自動的に生成
したパスワードが使われます。「パスワードを入手」というリンクをたどると、
パスワードを入手できます。
** BASIC認証によるログイン
BASIC認証も使えます。携帯電話のように、BASIC認証だけしかできない場合は、
「BASIC認証」のリンクをたどってください。
"
    }

    # ============================== show status
    def plg_login_status
      if @req.user
	return [:span, {:class=>'loginstatus'},
	  'user', ' | ', plg_login_user,
	  ' (', [:a, {:href=>'.logout'}, ('Logout')], ')']
      else
	return login_create_login_link
      end
    end

    def nu_login_create_login_link(msg='Login')
      sitename = @site.sitename
      pagename = @req.base
      href = '/.login'
      href += "?site=#{sitename}" if sitename
      href += "&page=#{pagename}" if pagename
      return [:a, {:href=>href}, msg]
    end

    def login_create_login_link
      return [:a, {:href=>'.login'}, 'Login']
    end

    def plg_login_user
      return [:em, @req.user]
    end

    # ============================== verify
    # called from action.rb
    def login_get_user
      check_session	# act-session: Check session id.
      return if @req.user

      check_cookie	# Get user from cookie.
      return if @req.user

      check_basicauth	# Get user from basicauth.
      return if @req.user
    end

    def check_cookie
      userpass = @req.cookies['userpass']
      if userpass
	user, pass = userpass.split(',', 2)
      else
	user = @req.cookies['user']
	pass = @req.cookies['pass']
      end

      if user
	return if user.nil? || user.empty?
	return unless MailAddress.valid?(user)
	gen = @memory.passgen
	return unless gen.match?(user, pass)

	@req.user = user
	@req.auth = 'cookie'

	# Do not move to session id for now.
	# sid = session_store(user)	# Move to session id.
	# @res.set_cookie('sid', sid)	# Set Session id by cookie
      end
    end

    # called from action.rb
    def login_invalid_user
      c_nerror(_('Login Error')){[
	  [:p, [:strong, _('Invalid ID (E-mail) or Password.')]],
	  [:p, {:class=>'warning'},
	    _('If you have no password,'), _('Access here'), [:br],
	    [:a, {:href=>'.getpass'}, [:em, _('Get Password')]]],
	  login_page_form,
	  login_page_menu,
	]}
    end

    # ============================== login
    def pre_act_login
      if @req.user
	return login_already_logged_in(@req.user)
      end

      user = @req.query['user']		# login from query
      pass = @req.query['pass']

      if ! user
	return c_notice(_('Login')) {
	  login_show_login_page(@site.site_url)	# show login page
	}
      end

      begin
	raise InvalidUserError if user.nil? || user.empty?
	raise InvalidUserError unless MailAddress.valid?(user)
	gen = @memory.passgen
	raise InvalidUserError unless gen.match?(user, pass)

      rescue InvalidUserError
	@res.clear_cookies		# IMPORTANT!
	return login_invalid_user	# password does not match
      end

      sid = session_store(user)
      @res.set_cookie('sid', sid) # Set Session id by cookie.

      return login_show_login_suceed_page
    end

    def login_already_logged_in(user)
      ar = []
      ar << [:p, _('You are now logged in with this user id.'), [:br],
	[:strong, user]]
      ar << [:p, _('If you would like to log in on another account,'), [:br],
	_('please log out first.')]
      ar << logout_form
      ar << [:hr]
      ar << login_go_frontpage
      return c_nerror(_('Already logged in.')){ar}
    end

    def login_go_frontpage
      style = ''
      return [:div, {:class=>'go_frontpage',:style=>''},
	[:a, {:href=>'FrontPage.html', :style=>style}, 'FrontPage']]
    end

    def login_show_login_page(url)
      login_msg = nil
      if page = @site['_LoginMessage']
	login_msg = [:div, {:class=>'warning'}, c_res(page.load)]
      end
      login_target_div = [:div,
	[:h2, _('Log in to '), [:em, url]],
	[:p, _('Please input ID (E-mail) and password.')]]

      div = [:div, {:class=>'login_page'}]
      div << login_target_div
      div << login_msg if login_msg

      div << login_page_form

      div << [:hr]
      div << [:div,
	[:h2, _('If you have no password')],
	[:p, _('Please input your mail address.')],
	getpass_form('', '', ''),
#	[:p, [:a, {:href=>'.sendpass'},
#	    _('You can send password for members.')]],
      ]

      div << [:hr]
      div << [:div,
	[:h2, [:a, {:href=>'.typekey'}, _('Log in by TypeKey')]],
	[:p, _('Please send mail address for authentication.')]]

      div << [:hr]
      div << [:div,
	[:h2, [:a, {:href=>'.basicauth'}, _('Log in by Basic Authentication.')]],
	[:p, _('For mobile phone users')]]

#      div << [:hr]
#      div << login_page_menu

      style = [:style, '
.container {
  margin-top: 20px;
}
']

      return [style, div]
    end

    def login_show_login_suceed_page
      url = 'FrontPage.html'
      title = _('Login') + ' ' + _('Success')
      return c_notice(title, url) {
	[login_go_frontpage]
      }
    end

    private

    def login_page_form
      return [:div, {:class=>'login'},
	[:form, {:method=>'POST', :action=>'.login'},
	  [:dl,
	    [:dt, _('ID'), '(E-mail)', ': '],
	    [:dd, [:input, {:name=>'user', :istyle=>'3', :class=>'focus'}]],
	    [:dt, _('Password'), ': '],
	    [:dd, [:input, {:type=>'password', :name=>'pass'}]]],
	  [:p,
	    [:input, {:type=>'submit', :value=>_('Login')}]]]]
    end

    def login_page_menu
      return [:ul,
#	[:li, _("If you don't have password"), ' : ',
#	  [:a, {:href=>'.getpass'}, [:em, _('Get Password')]]],
	[:li, _('For mobile phone users'), ' : ',
	  [:a, {:href=>'.basicauth'}, _('Log in by Basic Authentication.')]],
#	[:li,
#	  [:a, {:href=>'.typekey'}, _('Log in by TypeKey')]]
]
    end
  end
end

if $0 == __FILE__
  require 'qwik/test-common'
  $test = true
end

if defined?($test) && $test
  class TestActLogin < Test::Unit::TestCase
    include TestSession

    def assert_cookie(hash, cookies)
      cookies.each {|cookie|
	eq cookie.value, hash[cookie.name]
      }
    end

    def test_private_site
      t_add_user

      # See FrontPage.
      res = session('/test/') {|req|
	req.cookies.clear
      }
      ok_title 'Login'
      ok_xp([:meta, {:content=>'1; url=/test/.login',
		'http-equiv'=>'Refresh'}],
	    '//meta[2]')

      # See login page.
      res = session('/test/.login') {|req|
	req.cookies.clear
      }
      ok_title 'Login'
      ok_xp([:input, {:istyle=>'3', :name=>'user', :class=>'focus'}],
	    '//input')
#      ok_xp([:a, {:href=>'.getpass'}, [:em, 'Get Password']], '//a')
      assert_cookie({'user'=>'', 'pass'=>''}, @res.cookies)

      # Get password by e-mail.  See act-getpass.

      # Invalid mail address
      res = session('/test/.login?user=test@example') {|req|
	req.cookies.clear
      }
      assert_text('Invalid ID (E-mail) or Password.', 'p')

      # Invalid password
      res = session('/test/.login?user=user@e.com&pass=wrongpassword') {|req|
	req.cookies.clear
      }
      assert_text('Invalid ID (E-mail) or Password.', 'p')

      # Login by GET method. Set cookies and redirect to FrontPage.
      res = session('/test/.login?user=user@e.com&pass=95988593') {|req|
	req.cookies.clear
      }
      ok_title 'Login Success'
      #assert_cookie({'user'=>'user@e.com', 'pass'=>'95988593'}, @res.cookies)
      eq 'sid', @res.cookies[0].name
      eq 32, @res.cookies[0].value.length
      #pw('//head')
      ok_xp([:meta, {:content=>'0; url=FrontPage.html',
		'http-equiv'=>'Refresh'}],
	    '//meta[2]') # force redirect for security reason.

      # Set the cookie
      res = session('/test/') {|req|
	req.cookies.update({'user'=>'user@e.com', 'pass'=>'95988593'})
      }
      ok_title 'FrontPage'
      assert_cookie({'user'=>'user@e.com', 'pass'=>'95988593'},
		    @res.cookies)
      #eq 'sid', @res.cookies[0].name
      #eq 32, @res.cookies[0].value.length

      # Use POST method to set user and pass by queries.
      res = session('POST /test/.login?user=user@e.com&pass=95988593') {|req|
	req.cookies.clear
      }
      ok_title 'Login Success'
      eq 200, @res.status
      #assert_cookie({'user'=>'user@e.com', 'pass'=>'95988593'}, @res.cookies)
      eq 'sid', @res.cookies[0].name
      eq 32, @res.cookies[0].value.length
      ok_xp([:meta, {:content=>'0; url=FrontPage.html',
		'http-equiv'=>'Refresh'}],
	    '//meta[2]') # force redirect for security reason.

      # test_login_status
      res = session('/test/')
      ok_in(['user', ' | ', [:em, 'user@e.com'],
	      ' (', [:a, {:href=>'.logout'}, 'Logout'], ')'],
	    "//span[@class='loginstatus']")

      # See TextFormat
      res = session('/test/TextFormat.html')

      # See the Logout page.
      res = session('/test/.logout')
      ok_title 'Log out Confirm'
      ok_xp([:form, {:action=>'.logout', :method=>'POST'},
	      [:input, {:value=>'yes', :type=>'hidden',
		  :name=>'confirm'}], [:input, {:value=>'Log out',
		  :type=>'submit', :class=>'focus'}]], '//form')
      ok_xp([:input, {:value=>'yes', :type=>'hidden', :name=>'confirm'}],
	    '//input')
      ok_xp([:input, {:value=>'Log out',
		:type=>'submit', :class=>'focus'}], '//input[2]')

      # Confirm Logout.
      res = session('/test/.logout?confirm=yes')
      ok_title 'Log out done.'
      assert_text('Log out done.', 'h1')
      ok_xp([:p, [:a, {:href=>'FrontPage.html'}, 'Go back']],
	    "//div[@class='section']/p")
      assert_cookie({'user'=>'', 'pass'=>'', 'sid'=>''}, @res.cookies)
      #eq 'sid', @res.cookies[0].name
      #eq 32, @res.cookies[0].value.length
    end

    def test_open_site
      t_add_user
      t_site_open # OPEN site

      # See FrontPage. Check login_status before login.
      res = session('/test/') {|req|
	req.cookies.clear
      }
      ok_title 'FrontPage'
      ok_in(['Login'], "//div[@class='adminmenu']//a")
      ok_in([[:a, {:href=>'.login'}, 'Login'],
	      ["\n"], ["\n"]],
	    "//div[@class='adminmenu']")

      # You can see login page before login.
      res = session('/test/.login') {|req|
	req.cookies.clear
      }
      ok_title 'Login'
    end
  end
end
