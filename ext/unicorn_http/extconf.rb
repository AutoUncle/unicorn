# -*- encoding: binary -*-
# frozen_string_literal: false
require 'mkmf'

def generate_ragel_source
  src = File.expand_path('unicorn_http.c', __dir__)
  return if File.exist?(src)

  ragel_cfg = with_config('ragel') { find_executable('ragel') }
  ragel = if ragel_cfg.respond_to?(:strip)
    ragel_cfg = ragel_cfg.strip
    ragel_cfg unless ragel_cfg.empty? ||
                   (ragel_cfg.is_a?(String) && ragel_cfg !~ %r{\A/})
  end
  ragel ||= find_executable('ragel')
  unless ragel
    abort <<~MSG
      ragel(1) is required to generate ext/unicorn_http/unicorn_http.c.

      Install ragel (e.g. via your package manager) or run `gmake ragel`
      from the repository root before installing unicorn from git.
    MSG
  end

  Dir.chdir(__dir__) do
    cmd = [ragel, 'unicorn_http.rl', '-C', '-G2', '-o', 'unicorn_http.c']
    message("running #{cmd.join(' ')}\n")
    system(*cmd) || abort("ragel failed to generate unicorn_http.c")
  end
end

generate_ragel_source

have_func("rb_hash_clear", "ruby.h") or abort 'Ruby 2.0+ required'

message('checking if String#-@ (str_uminus) dedupes... ')
begin
  a = -(%w(t e s t).join)
  b = -(%w(t e s t).join)
  if a.equal?(b)
    $CPPFLAGS += ' -DSTR_UMINUS_DEDUPE=1 '
    message("yes\n")
  else
    $CPPFLAGS += ' -DSTR_UMINUS_DEDUPE=0 '
    message("no, needs Ruby 2.5+\n")
  end
rescue NoMethodError
  $CPPFLAGS += ' -DSTR_UMINUS_DEDUPE=0 '
  message("no, String#-@ not available\n")
end

message('checking if Hash#[]= (rb_hash_aset) dedupes... ')
h = {}
x = {}
r = rand.to_s
h[%W(#{r}).join('')] = :foo
x[%W(#{r}).join('')] = :foo
if x.keys[0].equal?(h.keys[0])
  $CPPFLAGS += ' -DHASH_ASET_DEDUPE=1 '
  message("yes\n")
else
  $CPPFLAGS += ' -DHASH_ASET_DEDUPE=0 '
  message("no, needs Ruby 2.6+\n")
end

if have_func('epoll_create1', %w(sys/epoll.h))
  have_func('rb_io_descriptor') # Ruby 3.1+
end
create_makefile("unicorn_http")
