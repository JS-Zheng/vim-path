""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Execution Guard {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
if exists('g:loaded_path')
  finish
endif

let g:loaded_path = 1


" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Init {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let s:cpo_save = &cpo
set cpo&vim

let s:is_win = has('win32')
let s:is_nvim = has('nvim')
let s:has_cmd_tcd = exists(':tcd')

if (has('patch-8.2.0868'))
  let s:has_patch_8_2_0868 = 1
  " Add an argument to only trim the beginning or end.
  " https://github.com/vim/vim/commit/2245ae18e3480057f98fc0e5d9f18091f32a5de0
  let s:has_fn_dir_trim = 1
  let s:has_fn_trim = 1
elseif (has('patch-8.0.1630'))
  let s:has_patch_8_0_1630 = 1
  " Add the trim() function.
  " https://github.com/vim/vim/commit/295ac5ab5e840af6051bed5ec9d9acc3c73445de
  let s:has_fn_dir_trim = 0
  let s:has_fn_trim = 1
else
  let s:has_fn_dir_trim = 0
  let s:has_fn_trim = 0
endif



" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Definitions {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let g:path#version = '0.1.1'
let g:path#lib_name = 'vim-path'


" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Constructor {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! path#(...) abort
  if (!a:0)
    return '.'
  endif

  let arg_type = type(a:1)
  let l:expand = (a:0 > 1) ? a:2 : 1
  let l:normalize = (a:0 > 2) ? a:3 : 1
  let l:resolve = (a:0 > 3) ? a:4 : 0

  if (arg_type == v:t_string)
    let path = a:1
  elseif (arg_type == v:t_dict)
    let dir = get(a:1, 'dir', '')
    let base = get(a:1, 'base', '')
    if (path#get_basename(dir) ==# base)
      let path = dir
    else
      let path = s:join_path([dir, base], 0)
    endif
  elseif (arg_type == v:t_list)
    let path = s:join_path(a:1, 0)
  elseif (arg_type == v:t_none)
    let path = '.'
  else
    throw "Illegal Arguments"
  endif

  let path = (l:expand) ? path#expand(path) : path
  let path = (l:normalize) ? path#normalize(path) : path
  let path = (l:resolve) ? path#resolve(path) : path
  return path
endfunction


function! path#home() abort
  return fnamemodify('~', ':p')
endfunction


function! path#curr_buf(...) abort
  let absolute = (a:0 > 0) ? a:1 : 1
  return (absolute) ? expand('%:p') : expand('%')
endfunction


function! path#curr_buf_dir(...) abort
  let absolute = (a:0 > 0) ? a:1 : 1
  return (absolute) ? expand('%:p:h') : expand('%:h')
endfunction


" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Join & Split {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! path#join(...) abort
  if (!a:0)
    return '.'
  endif

  if (a:0 == 1)
    let arg_type = type(a:1)
    if (arg_type == v:t_string)
      return path#normalize(a:1)
    elseif (arg_type == v:t_list)
      return s:join_path(a:1, 1)
    else
      throw "Path: Illegal Arguments"
    endif
  endif

  return s:join_path(a:000, 1)
endfunction


if (s:is_win)

  function! path#split(path) abort
    " UNC Path
    " https://docs.microsoft.com/en-us/dotnet/standard/io/file-path-formats
    if (path#is_unc(a:path))
      let is_shellslash = s:is_shellslash()
      return s:split_unc_path(a:path, is_shellslash, 0)
    endif

    " Windows path
    let is_shellslash = s:is_shellslash()
    if (is_shellslash)
      return split(a:path, '/\zs')
    endif

    return split(a:path, '\\\zs')
  endfunction


  function! path#split_unc(path) abort
    let is_shellslash = s:is_shellslash()
    return s:split_unc_path(a:path, is_shellslash, 1)
  endfunction

else

  function! path#split(path) abort
    return split(a:path, '/\zs')
  endfunction

endif


function! s:join_path(components, normalize) abort
  let len = len(a:components)
  if (!len)
    return '.'
  elseif (len == 1)
    if (a:normalize)
      return path#normalize(a:components[0])
    else
      return a:components[0]
    endif
  endif

  let i = 0
  let joined_path = ''
  let sep = path#get_sep()
  for l:comp in a:components
    if (empty(comp))
      continue
    endif

    if (i == 0)
      let joined_path = path#strip_trailing_sep(comp)
    elseif (i != (len - 1))
      let joined_path ..= (sep .. path#strip_sep(comp))
    else
      let joined_path ..= (sep .. path#strip_leading_sep(comp))
    endif

    let i += 1
  endfor

  if (empty(joined_path))
    return '.'
  endif

  if (a:normalize)
    return path#normalize(joined_path)
  endif

  return joined_path
endfunction


function! s:split_unc_path(path, is_shellslash, checking) abort
  if (a:checking && !path#is_unc(a:path))
    throw "Path: Not a valid UNC path."
  endif

  if (!a:is_shellslash)
    return split(a:path, '\v(^|^\\)@<!\\\zs')
  endif

  return split(a:path, '\v(^|^/)@<!/\zs')
endfunction


" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Parser {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! path#parse(path) abort
  let root = path#get_root(a:path)
  let dir = fnamemodify(a:path, ':h')

  let path = path#strip_trailing_sep(a:path)
  let base = fnamemodify(path, ':t')
  let name = fnamemodify(base, ':r')
  let ext = fnamemodify(path, ':e')

  return {'root': root, 'dir': dir, 'base': base, 'name': name, 'ext': ext}
endfunction


function! path#get_basename(path) abort
  let path = path#strip_trailing_sep(a:path)
  return fnamemodify(path, ':t')
endfunction


function! path#get_dir(path, ...) abort
  let ignore_trailing_sep = (a:0 > 0) ? a:1 : 0
  let path = (ignore_trailing_sep)
        \ ? path#strip_trailing_sep(a:path)
        \ : a:path
  return fnamemodify(path, ':h')
endfunction


function! path#get_name(path) abort
  let path = path#strip_trailing_sep(a:path)
  return fnamemodify(path, ':t:r')
endfunction


function! path#get_ext(path) abort
  let path = path#strip_trailing_sep(a:path)
  return fnamemodify(path, ':e')
endfunction


if (s:is_win)

  function! path#get_root(path) abort
    let is_shellslash = s:is_shellslash()
    if (path#is_unc(a:path))
      return s:get_unc_root(a:path, is_shellslash, 0)
    endif

    return (l:is_shellslash)
        \? matchstr(a:path, '\v^/|^\a:/')
        \: matchstr(a:path, '\v^\\|^\a:\\')
  endfunction


  function! path#get_unc_root(path) abort
    let is_shellslash = s:is_shellslash()
    return s:get_unc_root(a:path, is_shellslash, 1)
  endfunction


  function! s:get_unc_root(path, is_shellslash, checking) abort
    if (a:checking && !path#is_unc(a:path))
      throw "Path: Not a valid UNC path."
    endif

    if (!a:is_shellslash)
      return matchstr(a:path, '^\v(\\\\[^\\]+)')
    endif

    return matchstr(a:path, '^\v(//[^/]+)')
  endfunction

else

  function! path#get_root(path) abort
    return (a:path =~# '^/') ? '/' : ''
  endfunction

endif


" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Iterator {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! path#iter(path, ...) abort
  let top_down = (a:0) ? a:1 : 1
  let components = path#split(a:path)
  let i = 0
  for l:comp in components
    if (i == 0)
      let i += 1
      continue
    endif

    let components[i] = l:components[i - 1] .. l:comp

    let i += 1
  endfor

  return (top_down) ? components : reverse(components)
endfunction


function! path#find_markers(path, markers, ...) abort
  let top_down = (a:0) ? a:1 : 1
  let excludes = (a:0 > 1) ? a:2 : []
  let comps = path#split(a:path)
  let n_comps = len(comps)
  if (!n_comps)
    return ['', '']
  endif

  if (top_down)
    return s:find_markers_top_down(comps, a:markers, excludes)
  endif

  return s:find_markers_bottom_up(a:path, comps, n_comps, a:markers, excludes)
endfunction


function! s:is_exclusive_path(excludes, path)
  return index(a:excludes, path) >= 0
endfunction


function! s:find_markers_top_down(comps, markers, excludes) abort
  let path = ''
  for comp in a:comps
    let path ..= comp
    for marker in a:markers
      if (!empty(globpath(path, marker)))
        let strip_path = path#strip_trailing_sep_s(path)
        if (!s:is_exclusive_path(a:excludes, strip_path))
          return [strip_path, marker]
        endif
      endif
    endfor
  endfor

  return ['', '']
endfunction


function! s:find_markers_bottom_up(path, comps, n_comps, markers, excludes) abort
  let i = a:n_comps - 1
  let path = a:path
  while (i >= 0)
    let comp = a:comps[i]
    for marker in a:markers
      if (!empty(globpath(path, marker)))
        let strip_path = path#strip_trailing_sep_s(path)
        if (!s:is_exclusive_path(a:excludes, strip_path))
          return [strip_path, marker]
        endif
      endif
    endfor

    let path = path[:-(strlen(comp) + 1)]
    let i -= 1
  endwhile

  return ['', '']
endfunction


" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Separator {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
if (s:is_win)

  function! path#get_sep() abort
    return (s:is_shellslash()) ? '/' : '\'
  endfunction


  function! path#as_dir(path) abort
    let path = path#strip_trailing_sep(a:path)
    return path .. path#get_sep()
  endfunction


  function! path#strip_trailing_sep_s(path) abort
    if (empty(a:path) || a:path =~# '^\a:[\/]$' || a:path =~# '^[\/]$')
      return a:path
    endif

    return path#strip_trailing_sep(a:path)
  endfunction


  if (s:has_fn_dir_trim)

    function! path#strip_sep(path) abort
      return trim(a:path, '\/', 0)
    endfunction


    function! path#strip_leading_sep(path) abort
      return trim(a:path, '\/', 1)
    endfunction


    function! path#strip_trailing_sep(path) abort
      return trim(a:path, '\/', 2)
    endfunction

  else

    if (s:has_fn_trim)

      function! path#strip_sep(path) abort
        return trim(a:path, '\/')
      endfunction

    else

      function! path#strip_sep(path) abort
        return substitute(a:path, '\v^[\/]+|[\/]+$', '','g')
      endfunction

    endif


    function! path#strip_leading_sep(path) abort
      return substitute(a:path, '\v^[\/]+', '', '')
    endfunction


    function! path#strip_trailing_sep(path) abort
      return substitute(a:path, '\v[\/]+$', '', '')
    endfunction

  endif

else

  function! path#get_sep() abort
    return '/'
  endfunction


  function! path#as_dir(path) abort
    let path = path#strip_trailing_sep(a:path)
    return path .. '/'
  endfunction


  function! path#strip_trailing_sep_s(path) abort
    if (empty(a:path) || a:path =~# '^/$')
      return a:path
    endif

    return path#strip_trailing_sep(a:path)
  endfunction


  if (s:has_fn_dir_trim)

    function! path#strip_sep(path) abort
      return trim(a:path, '/', 0)
    endfunction


    function! path#strip_leading_sep(path) abort
      return trim(a:path, '/', 1)
    endfunction


    function! path#strip_trailing_sep(path) abort
      return trim(a:path, '/', 2)
    endfunction

  else

    if (s:has_fn_trim)

      function! path#strip_sep(path) abort
        return trim(a:path, '/')
      endfunction

    else

      function! path#strip_sep(path) abort
        return substitute(a:path, '\v^/+|/+$', '','g')
      endfunction

    endif


    function! path#strip_leading_sep(path) abort
      return substitute(a:path, '\v^/+', '', '')
    endfunction


    function! path#strip_trailing_sep(path) abort
      return substitute(a:path, '\v/+$', '', '')
    endfunction

  endif

endif


" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Type Detection {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! path#is_dir(path, ...) abort
  let l:expand = (a:0 > 0) ? a:1 : 1
  let path = (l:expand) ? path#expand(a:path) : a:path
  return isdirectory(path)
endfunction


function! path#is_file(path, ...) abort
  let l:expand = (a:0 > 0) ? a:1 : 1
  let l:resolve = (a:0 > 1) ? a:2 : 0
  let type = path#get_type(a:path, l:expand, l:resolve)
  return type ==# 'file'
endfunction


function! path#is_readable_file(path, ...) abort
  let l:expand = (a:0 > 0) ? a:1 : 1
  let l:resolve = (a:0 > 1) ? a:2 : 0
  let path = (l:expand) ? path#expand(a:path) : a:path
  let path = (l:resolve) ? path#resolve(path) : path
  return filereadable(path)
endfunction


function! path#is_writable_file(path, ...) abort
  let l:expand = (a:0 > 0) ? a:1 : 1
  let l:resolve = (a:0 > 1) ? a:2 : 0
  let path = (l:expand) ? path#expand(a:path) : a:path
  let path = (l:resolve) ? path#resolve(path) : path
  return filewritable(path)
endfunction


function! path#is_link(path, ...) abort
  let l:expand = (a:0 > 0) ? a:1 : 1
  let l:resolve = (a:0 > 1) ? a:2 : 0
  let type = path#get_type(a:path, l:expand, l:resolve)
  return type ==# 'link'
endfunction


function! path#get_type(path, ...) abort
  let l:expand = (a:0 > 0) ? a:1 : 1
  let l:resolve = (a:0 > 1) ? a:2 : 0
  let path = (l:expand) ? path#expand(a:path) : a:path
  let path = (l:resolve) ? path#resolve(path) : path
  return getftype(path)
endfunction


function! s:is_shellslash() abort
  if (exists('+shellslash'))
    return &shellslash
  endif

  return 0
endfunction


if (s:is_win)

  function! path#is_abs(path, ...) abort
    let l:expand = (a:0 > 0) ? a:1 : 1
    let path = (l:expand) ? path#expand(a:path) : a:path
    if (s:is_shellslash())
      " \\\\ for UNC path
      return a:path =~# '\v^%(/|\\\\|\a:/)'
    else
      return a:path =~# '\v^%(\\|\a:\\)'
    endif
  endfunction


  function! path#is_unc(path) abort
    if (s:is_shellslash())
      return a:path =~# '\v^//|\\\\'
    endif

    return a:path =~# '^\\\\'
  endfunction

else

  function! path#is_abs(path, ...) abort
    let l:expand = (a:0 > 0) ? a:1 : 1
    let path = (l:expand) ? path#expand(a:path) : a:path
    return a:path =~# '^/'
  endfunction

end


" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Change Directory {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! path#cd(...) abort
  let path = (a:0 > 0) ? a:1 : '-'
  if (a:0 > 1)
    let cmd = a:2
  else
    let cmd = s:get_dflt_cd_cmd()
  endif
  execute cmd fnameescape(path)
endfunction


function! path#pushd(dirpath, ...) abort
  let cmd = (a:0 > 0) ? a:1 : s:get_dflt_cd_cmd()
  let stack = (a:0 > 1) ? a:2 : s:get_dflt_dir_stack()

  let cwd = getcwd()
  let escaped_path = fnameescape(a:dirpath)

  execute cmd escaped_path
  call add(stack, cwd)
endfunction


function! path#popd(...) abort
  let stack = (a:0 > 1) ? a:2 : s:get_dflt_dir_stack()
  if (empty(stack))
    return -1
  endif
  let cmd = (a:0 > 0) ? a:1 : s:get_dflt_cd_cmd()

  " pop the directory stack
  let origin = remove(stack, -1)

  execute cmd fnameescape(origin)
endfunction


function! s:get_dflt_dir_stack() abort
  if (!exists('g:path_dir_stack'))
    let g:path_dir_stack = []
  endif
  return g:path_dir_stack
endfunction


if (s:has_cmd_tcd)

  function! s:get_dflt_cd_cmd() abort
    if (haslocaldir())
      return 'lcd'
    else
      return haslocaldir(-1) ? 'tcd' : 'cd'
    endif
  endfunction

else

  function! s:get_dflt_cd_cmd() abort
    return (haslocaldir()) ? 'lcd' : 'cd'
  endfunction

endif


" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Conversion {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! path#to_abs(path) abort
  " |filename-modifiers| - :p
  " For a file name that does not exist and does not have an absolute path the
  " result is **unpredictable**.
  if (path#is_abs(a:path))
    return a:path
  endif

  let cwd = getcwd()
  let sep = path#get_sep()
  return path#normalize(cwd .. sep .. a:path)
endfunction


if (s:is_win)

  function! path#to_glob(path) abort
    " See |wildcard|
    let glob_path = escape(a:path, '\?*[')
    return substitute(glob_path, '\V[', '[[]', 'g')
  endfunction

else

  function! path#to_glob(path) abort
    " See |wildcard|
    return escape(a:path, '\?*[')
  endfunction

endif


" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Basis {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! path#shellescape_b(paths, ...) abort
  let special = (a:0 > 0) ? a:1 : 0
  return map(a:paths, function('s:escape_search_path', [special]))
endfunction


function! path#shellescape(path, ...) abort
  let special = (a:0 > 0) ? a:1 : 0
  if (a:path =~# '^\~')
    let p = a:path[1:]
    if (empty(p))
      return '~'
    endif
    return '~' .. shellescape(p, special)
  endif

  if (a:path =~# '^\$')
    return shellescape(expand(a:path), special)
  endif

  return shellescape(a:path, special)
endfunction


function! path#expand(...) abort
  if (len(a:000) == 1)
    let args = a:000 + [get(g:, 'path_expand_nosuf', 1)]
    return call('expand', args)
  endif

  return call ('expand', a:000)
endfunction


function! path#shorten(path, ...) abort
  let len = (a:0 > 0) ? a:1 : 1
  if (len < 0)
    let len = 1
  endif
  let components = path#split(a:path)
  let n_comps = len(components)

  let results = s:build_uniq_comps(components, n_comps, len)
  return path#join(results)
endfunction


function! path#resolve(path) abort
  if (getftype(a:path) ==# 'link')
    return resolve(a:path)
  endif
  return path#normalize(a:path)
endfunction


if (s:is_win)

  function! path#normalize(path) abort
    if (empty(a:path))
      return '.'
    endif

    let path = simplify(a:path)

    if (s:is_shellslash())
      return substitute(path, '\', '/', 'g')
    endif

    return substitute(path, '/', '\', 'g')
  endfunction

else

  function! path#normalize(path) abort
    if (empty(a:path))
      return '.'
    endif

    return simplify(a:path)
  endfunction

endif


function! s:build_uniq_comps(components, n_comps, len) abort
  let results = s:init_uniq_comps(a:components, a:n_comps, a:len)

  let i = 0
  while i < a:n_comps - 1
    let target = a:components[i]

    let j = 0
    while j < a:n_comps
      if (i == j)
        let j += 1
        continue
      endif

      let comp = a:components[j]
      let uniq = s:get_uniq_part(target, comp)
      if (strchars(uniq) > strchars(results[i]))
        let results[i] = uniq
      endif

      let j += 1
    endwhile

    let i += 1
  endwhile

  return results
endfunction


function! s:init_uniq_comps(components, n_comps, len) abort
  if (a:n_comps < 2)
    return a:components[:]
  endif

  let results = []
  if (path#is_abs(a:components[0]))
    let i = 1
    call add(results, a:components[0])
  else
    let i = 0
  endif
  while i < a:n_comps - 1
    let comp = a:components[i]
    let qualifier = printf('{1,%d}', a:len)
    let min_comp = matchstr(comp, '\v^.{-}[^.\/:*?"<>|]' .. qualifier)
    if (empty(min_comp))
      let min_comp = comp
    endif
    call add(results, min_comp)
    let i += 1
  endwhile

  call add(results, a:components[a:n_comps - 1])
  return results
endfunction


function! s:get_uniq_part(target, other) abort
  let len_target = strchars(a:target)
  let len_other = strchars(a:other)
  let i = 0
  while i < len_target
    if (i >= len_other)
      return a:target[0: i]
    endif

    let tc = strcharpart(a:target, i, 1)
    let oc = strcharpart(a:other, i, 1)
    if (tc !=# oc)
      return a:target[0: i]
    endif

    let i += 1
  endwhile

  return a:target
endfunction


function! s:escape_search_path(special, index, path)
  return path#shellescape(a:path, a:special)
endfunction


" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Restore Options {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let &cpo = s:cpo_save
unlet s:cpo_save


" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
