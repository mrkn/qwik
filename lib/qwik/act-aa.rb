$LOAD_PATH << '..' unless $LOAD_PATH.include? '..'

module Qwik
  class Action
    def plg_aa(type=nil, message=nil, &b)
      s = aa_get(type, message, &b)
      return [:pre, {:class=>'aa'}, s]
    end

    def aa_get(type=nil, message=nil)
      if type.nil?
	raise unless block_given?
	return yield
      end

      aa, msg = aa_database
      a = aa[type]
      raise 'no such aa' if a.nil?
      m = msg[type]
      m = message if message
      a = a.gsub(/\$1/) { m }
      return a
    end

    def aa_database
      aa = {}
      msg = {}
      aa['smile'] = '(^_^) $1'
      msg['smile'] = 'Hi!'

      aa['i['] =
'@@ ΘQΘ@@^PPPPP
@@i@LΝMj@$1
@@i@@@@j @_QQQQQ
@@b b@|
@@i_QjQj
'
      msg['i['] = 'I}Gi['
      aa['N}@'] =
'@@@ZQZ
@@ i@E(ͺ)Ej @$1
@@/J@€J
@@΅\-J
'
      msg['N}@'] = 'ΈΟ§!'
      return [aa, msg]
    end
  end
end

if $0 == __FILE__
  require 'qwik/test-common'
  $test = true
end

if defined?($test) && $test
  class TestActAA < Test::Unit::TestCase
    include TestSession

    def test_all
      ok_wi([:pre, {:class=>'aa'}, "a\n"], "{{aa\na\n}}")
      ok_wi([:pre, {:class=>'aa'}, "(^_^) Hi!"], '{{aa(smile)}}')
      ok_wi([:pre, {:class=>'aa'}, "(^_^) Bye!"], '{{aa(smile, Bye!)}}')
      ok_wi(/monar/, '{{aa(i[, monar)}}')
      ok_wi(/kumar/, '{{aa(N}@, kumar)}}')
    end
  end
end
