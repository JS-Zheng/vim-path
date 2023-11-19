""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Init {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let s:is_win = has('win32') || has('win64')
let s:is_nvim = has('nvim')
let s:has_cmd_tcd = exists(':tcd')
let s:has_opt_shellslash = exists('+shellslash')

if has('patch-8.2.0868')
  let s:has_patch_8_2_0868 = 1
  " Add an argument to only trim the beginning or end.
  " https://github.com/vim/vim/commit/2245ae18e3480057f98fc0e5d9f18091f32a5de0
  let s:has_fn_dir_trim = 1
  let s:has_fn_trim = 1
elseif has('patch-8.0.1630')
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
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Definitions {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let g:path#version = '0.1.0'
let g:path#lib_name = 'vim-path'


" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Constructor {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" The main constructor for creating a path object. It accepts various types of
" inputs and optional arguments to process the path accordingly.
"
" This function can handle different types of inputs for the path, such as
" a string, dictionary, or list, and applies additional path processing options
" like expansion, normalization, or resolving symbolic links based on the
" optional arguments provided.
"
" Parameters:
" - ...: The first argument can be of different types:
"        - string: A path string.
"        - dict: A dictionary with 'dir' and/or 'base' keys, equivalent to
"                `fnamemodify(a:path, ':h')` and `fnamemodify(path, ':t')`
"                respectively.
"        - list: A list of path segments that will be joined.
"        - v:t_none: Uses the current directory ('.').
"        Any other type will throw an "Illegal Arguments" exception.
"
"        The second argument can be:
"        - dict: Options to decide if to expand, normalize, or resolve the path,
"                e.g., {'expand': 1, 'normalize': 1, 'resolve': 0}.
"        - string: Short-hand notation for the same options, e.g., 'en' for
"                  expand and normalize.
"        Any other type will throw an "Illegal Arguments" exception.
"
" Returns:
" A string representing the processed path based on the given arguments and
" options.
"
" Examples:
"   path#('/home/user')
"     -> Returns the string '/home/user'.
"
"   path#({'dir': '/home', 'base': 'user'})
"     -> Joins 'dir' and 'base' into '/home/user'.
"
"   path#(['home', 'user'])
"     -> Joins the list elements into 'home/user'.
"
"   path#('$HOME/foo/bar/.././baz', {'expand': 1, 'normalize': 1})
"     -> '/home/user/foo/baz'
"
"   path#('/foo/../user', 'en')
"     -> '/user'
"
function! path#(...) abort
  " Default to the current directory if no arguments are provided.
  if !a:0
    return '.'
  endif

  " Determine the path based on the type of the first argument.
  let arg_type = type(a:1)

  if arg_type == v:t_string
    " A simple string path.
    let path = a:1
  elseif arg_type == v:t_dict
    " A dictionary specifying directory and base parts of the path.
    let dir = get(a:1, 'dir', '')
    let base = get(a:1, 'base', '')

    let paths = []
    if !empty(dir)
      call add(paths, dir)
    endif
    if !empty(base)
      call add(paths, base)
    endif

    if empty(paths)
      return '.'
    endif

    let path = s:join_paths(paths)
  elseif arg_type == v:t_list
    if empty(a:1)
      return '.'
    endif
    " A list of path components to be joined together.
    let path = s:join_paths(a:1)
  elseif arg_type == v:t_none
    " Use '.' to represent the current directory.
    let path = '.'
  else
    throw "Illegal Arguments: Invalid path type"
  endif

  " Resolve options for path manipulation.
  let opts = deepcopy(get(a:, 2, {}))
  let opts = s:resolve_constructor_opts(opts)

  " Apply expand, normalize, and resolve operations based on the options.
  let path = opts['expand'] ? path#expand(path) : path
  let path = opts['normalize'] ? path#normalize(path) : path
  let path = opts['resolve'] ? path#resolve(path) : path

  return path
endfunction


" Return the home directory path.
function! path#home() abort
  return expand('~')
endfunction


" Return the current buffer's path.
function! path#curr_buf(...) abort
  let absolute = (a:0 > 0) ? a:1 : 1
  return (absolute) ? expand('%:p') : expand('%')
endfunction


" Return the current buffer's directory.
function! path#curr_buf_dir(...) abort
  let absolute = (a:0 > 0) ? a:1 : 1
  return (absolute) ? expand('%:p:h') : expand('%:h')
endfunction


" Resolves the options for the constructor.
function! s:resolve_constructor_opts(arg) abort
  " Extend the passed options with global settings and default options.
  let opts = extend({}, get(g:, 'path_constructor_opts', {}))
  let opts = extend(opts, s:default_constructor_opts(), 'keep')

  let arg_type = type(a:arg)

  " Process string-based flags into options.
  if arg_type == v:t_string
    " Define a mapping from flags to their respective settings.
    let flags_map = {
      \ 'e': ['expand', 1],
      \ 'E': ['expand', 0],
      \ 'n': ['normalize', 1],
      \ 'N': ['normalize', 0],
      \ 'r': ['resolve', 1],
      \ 'R': ['resolve', 0]
    \ }

    " Apply the flags to set options.
    for [flag, setting] in items(flags_map)
      if a:arg =~# flag
        let opts[setting[0]] = setting[1]
      endif
    endfor
  elseif arg_type == v:t_dict
    " Directly extend the options with the provided dictionary.
    let opts = extend(opts, a:arg, 'force')
  else
    throw 'Illegal Arguments: Expected a string or dictionary.'
  endif

  return opts
endfunction


" Returns the default options for the constructor.
function! s:default_constructor_opts() abort
  return {
    \'expand': 1,
    \'normalize': 1,
    \'resolve': 0,
  \ }
endfunction


" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Join & Split {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Joins one or more path segments into a single path.
"
" This function intelligently concatenates a list of path segments into a single
" path. It ensures that there is exactly one directory separator between each
" non-empty segment, except for the last one. The result will end in a separator
" only if the last part is empty or already ends in a separator. If any segment
" in the list is an absolute path, all previous segments are ignored, and the
" joining continues from the absolute path segment.
"
" Parameters:
" - ...: One or more path segments as a list. Each segment is a string representing
"        a part of the path.
"
" Returns:
" A string representing the joined path. The function intelligently handles
" directory separators between segments.
"
" Examples:
"   path#join(['foo', 'bar'])
"     -> 'foo/bar'
"
"   path#join(['foo', 'bar', ''])
"     -> 'foo/bar/'
"
"   path#join(['foo', '/bar', 'baz'])
"     -> '/bar/baz' (ignores 'foo' because '/bar' is absolute)
"
"   path#join(['foo/', 'bar'])
"     -> 'foo/bar'
"
"   path#join(['/foo', 'bar', '/baz'])
"     -> '/baz' (ignores '/foo' and 'bar')
"
function! path#join(...) abort
  if !a:0
    return ''
  endif

  " If there's only one argument, check its type
  if a:0 == 1
    let arg_type = type(a:1)

    " If the argument is a string, convert it to a list and join
    if arg_type == v:t_string
      return s:join_paths([a:1])
    " If the argument is already a list, directly pass it to the helper function
    elseif arg_type == v:t_list
      return s:join_paths(a:1)
    else
      " Throw an error if the argument is neither a string nor a list
      throw "Illegal Arguments"
    endif
  endif

  " If there are multiple arguments, treat them as variadic and join them
  return s:join_paths(a:000)
endfunction


if s:is_win

  function! path#split(path) abort
    " UNC Path
    " https://docs.microsoft.com/en-us/dotnet/standard/io/file-path-formats
    if path#is_unc(a:path)
      return s:split_unc_path(a:path)
    endif

    " Windows path
    return split(a:path, '\v(/|\\)\zs')
  endfunction


  function! s:join_paths(components) abort
    if !len(a:components)
      return ''
    endif

    " Start with an empty string
    let result = ''
    let sep = path#get_sep()

    " Iterate through each component
    for comp in a:components
      " If the component is an absolute path, reset the result string
      if path#is_abs(comp) || comp =~# '\v^[\/]'
        let result = comp
      else
        " Add a separator if the result doesn't already end with one and isn't empty
        if (result != '') && (!path#is_end_w_sep(result))
          let result ..= sep
        endif

        " Concatenate the current component to the result
        let result ..= comp
      endif
    endfor

    " Ensure the resulting path adheres to the trailing separator rule
    let last_comp = a:components[-1]
    if (!path#is_end_w_sep(result)) && (last_comp == '')
      let result ..= sep
    endif

    " Return the constructed path
    return result
  endfunction


  function! s:split_unc_path(path) abort
    " @<!: This is a negative look-behind assertion. It ensures that the pattern
    "      before @<! is not immediately before the current match position.
    "      see also: */\@<!*
    let result = split(a:path, '\v((^|^/)@<!/\zs)|((^|^\\)@<!\\\zs)')
    return [result[0] .. result[1]] + result[2:]
  endfunction

else

  " Splits the given path into its individual components, preserving root and
  " separators.
  "
  " Instead of removing path separators like many path libraries, this function
  " retains them. This design choice ensures that:
  " 1. Users can easily reassemble the original path using Vim's native join().
  " 2. Efficient top-down or bottom-up iteration over the path components is
  "    possible.
  "
  " Examples:
  " - `/home/user/file.txt` => ['/', 'home/', 'user/', 'file.txt']
  " - `/foo/bar/`           => ['/', 'foo/', 'bar/']
  " - `/foo/bar`            => ['/', 'foo/', 'bar']
  "
  function! path#split(path) abort
    " \zs: A special Vim regular expression atom. `\zs` sets the start of the
    "      match (zs stands for "zero start"). In other words, it marks the
    "      position in the string where the match will be considered to start.
    "      Everything before the \zs is not included in the match that split
    "      uses to divide the string.
    return split(a:path, '/\zs')
  endfunction


  function! s:join_paths(components) abort
    if !len(a:components)
      return ''
    endif

    " Start with an empty string
    let result = ''

    " Iterate through each component
    for comp in a:components
      " If the component is an absolute path, reset the result string
      if path#is_abs(comp)
        let result = comp
      else
        " Add a separator if the result doesn't already end with one and isn't empty
        if (result != '') && (!path#is_end_w_sep(result))
          let result ..= '/'
        endif

        " Concatenate the current component to the result
        let result ..= comp
      endif
    endfor

    " Ensure the resulting path adheres to the trailing separator rule
    let last_comp = a:components[-1]
    if (!path#is_end_w_sep(result)) && (last_comp == '')
      let result ..= '/'
    endif

    " Return the constructed path
    return result
  endfunction

endif


" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Parser {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
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


if s:is_win

  function! path#get_root(path) abort
    let is_shellslash = s:is_shellslash()
    if path#is_unc(a:path)
      return s:get_unc_root(a:path, is_shellslash)
    endif

    return (is_shellslash)
        \? matchstr(a:path, '\v^/|^\a:/')
        \: matchstr(a:path, '\v^\\|^\a:\\')
  endfunction


  function! path#get_unc_root(path) abort
    let is_shellslash = s:is_shellslash()
    return s:get_unc_root(a:path, is_shellslash)
  endfunction


  function! s:get_unc_root(path, is_shellslash) abort
    if !a:is_shellslash
      let result = matchstr(a:path, '^\v(\\\\[^\/]+\\[^\/]+)')
      if !empty(result)
        return result
      endif

      let result = matchstr(a:path, '^\v(//[^\/]+/[^\/]+)')
      if !empty(result)
        return result
      endif

      throw "Path: Not a valid UNC path."
    endif

    let result = matchstr(a:path, '^\v(//[^\/]+/[^\/]+)')
      if !empty(result)
        return result
      endif

      throw "Path: Not a valid UNC path."
  endfunction


  function! s:convert_win_sl(path, ...)
    let is_ssl = get(a:, 1, s:is_shellslash())
    if is_ssl
      return substitute(a:path, '\', '/', 'g')
    else
      return substitute(a:path, '/', '\', 'g')
    endif
  endfunction


else

  function! path#get_root(path) abort
    return (a:path =~# '^/') ? '/' : ''
  endfunction

endif


" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Separator {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
if s:is_win

  " Get appropriate path separator for Windows.
  function! path#get_sep() abort
    return (s:is_shellslash()) ? '/' : '\'
  endfunction


  " Ensure path ends with a separator.
  function! path#as_dir(path) abort
    let path = path#strip_trailing_sep(a:path)
    return path .. path#get_sep()
  endfunction


  " Remove trailing separator, but handle Windows drive letters.
  function! path#strip_trailing_sep_s(path) abort
    if (empty(a:path)) || (a:path =~# '^\a:[\/]$') || (a:path =~# '^[\/]$')
      return a:path
    endif

    return path#strip_trailing_sep(a:path)
  endfunction


  function! path#is_end_w_sep(path) abort
    return a:path =~# '[\/]$'
  endfunction


  if s:has_fn_dir_trim

    " Removes both leading and trailing path separators.
    function! path#strip_sep(path) abort
      return trim(a:path, '\/', 0)
    endfunction


    " Removes only leading path separators.
    function! path#strip_leading_sep(path) abort
      return trim(a:path, '\/', 1)
    endfunction


    " Removes only trailing path separators.
    function! path#strip_trailing_sep(path) abort
      return trim(a:path, '\/', 2)
    endfunction

  else

    if s:has_fn_trim

      " Removes both leading and trailing path separators.
      function! path#strip_sep(path) abort
        return trim(a:path, '\/')
      endfunction

    else

      " Removes both leading and trailing path separators.
      function! path#strip_sep(path) abort
        return substitute(a:path, '\v^[\/]+|[\/]+$', '','g')
      endfunction

    endif


    " Removes only leading path separators.
    function! path#strip_leading_sep(path) abort
      return substitute(a:path, '\v^[\/]+', '', '')
    endfunction


    " Removes only trailing path separators.
    function! path#strip_trailing_sep(path) abort
      return substitute(a:path, '\v[\/]+$', '', '')
    endfunction

  endif

else " For non-Windows platforms

  function! path#get_sep() abort
    return '/'
  endfunction


  function! path#as_dir(path) abort
    let path = path#strip_trailing_sep(a:path)
    return path .. '/'
  endfunction


  function! path#strip_trailing_sep_s(path) abort
    if (empty(a:path)) || (a:path =~# '^/$')
      return a:path
    endif

    return path#strip_trailing_sep(a:path)
  endfunction


  function! path#is_end_w_sep(path) abort
    return a:path =~# '/$'
  endfunction


  if s:has_fn_dir_trim

    " Removes both leading and trailing path separators.
    function! path#strip_sep(path) abort
      return trim(a:path, '/', 0)
    endfunction


    " Removes only leading path separators.
    function! path#strip_leading_sep(path) abort
      return trim(a:path, '/', 1)
    endfunction


    " Removes only trailing path separators.
    function! path#strip_trailing_sep(path) abort
      return trim(a:path, '/', 2)
    endfunction

  else

    if s:has_fn_trim

    " Removes both leading and trailing path separators.
      function! path#strip_sep(path) abort
        return trim(a:path, '/')
      endfunction

    else

    " Removes both leading and trailing path separators.
      function! path#strip_sep(path) abort
        return substitute(a:path, '\v^/+|/+$', '','g')
      endfunction

    endif


    " Removes only leading path separators.
    function! path#strip_leading_sep(path) abort
      return substitute(a:path, '\v^/+', '', '')
    endfunction


    " Removes only trailing path separators.
    function! path#strip_trailing_sep(path) abort
      return substitute(a:path, '\v/+$', '', '')
    endfunction

  endif

endif " if s:is_win


" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Type Detection {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! path#is_dir(path) abort
  return isdirectory(a:path)
endfunction


function! path#is_file(path) abort
  return getftype(a:path) ==# 'file'
endfunction


function! path#is_readable_file(path) abort
  return filereadable(a:path)
endfunction


function! path#is_writable_file(path) abort
  return filewritable(a:path)
endfunction


function! path#is_link(path) abort
  return getftype(a:path) ==# 'link'
endfunction


function! path#get_type(path) abort
  return getftype(a:path)
endfunction


function! s:is_shellslash() abort
  if s:has_opt_shellslash
    return &shellslash
  endif

  return 0
endfunction


if s:is_win

  function! path#is_abs(path) abort
    return a:path =~# '\v^%(//|\\\\|\a:/|\a:\\)'
  endfunction


  function! path#is_unc(path) abort
    return a:path =~# '\v^//[^\/]+/[^\/]+'
          \ || a:path =~# '\v\\\\[^\/]+\\[^\/]+'
  endfunction

else

  " Determines if the given path is an absolute path.
  "
  " This function checks if the provided path is an absolute path. An absolute
  " path refers to a complete path from the root directory (in UNIX-like
  " systems) or includes the drive letter in Windows systems.
  "
  " Parameters:
  " - path: The path string to be checked.
  "
  " Returns:
  " - 1 (true) if the path is absolute.
  " - 0 (false) if the path is relative or does not meet the criteria of an
  "             absolute path.
  "
  " Examples:
  "   path#is_abs('/home/user') -> 1
  "
  "   path#is_abs('relative/path') -> 0
  "
  "   path#is_abs('~/path') -> 0
  "
  function! path#is_abs(path) abort
    return a:path =~# '^/'
  endfunction

end


" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Change Directory {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! path#cd(...) abort
  let path = (a:0 > 0) ? a:1 : '-'
  if a:0 > 1
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
  if empty(stack)
    return -1
  endif
  let cmd = (a:0 > 0) ? a:1 : s:get_dflt_cd_cmd()

  " pop the directory stack
  let origin = remove(stack, -1)

  execute cmd fnameescape(origin)
endfunction


function! s:get_dflt_dir_stack() abort
  if !exists('g:path_dir_stack')
    let g:path_dir_stack = []
  endif
  return g:path_dir_stack
endfunction


if s:has_cmd_tcd

  function! s:get_dflt_cd_cmd() abort
    if haslocaldir()
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
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Conversion {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Converts a given path to an absolute path.
"
" This function takes a path and converts it into an absolute path based on the
" current working directory. If the given path is already an absolute path, it
" is returned as is. For relative paths, the function combines them with the
" current working directory and normalizes the result. It is important to note
" that the behavior for non-existent files without an absolute path is
" unpredictable.
"
" Parameters:
" - path: The path string to be converted to an absolute path. This can be
"         either an absolute or a relative path.
"
" Returns:
" An absolute path as a string. If the input path is already absolute, it is
" returned without modification. Otherwise, it is combined with the current
" working directory.
"
" Examples:
"   path#to_abs('file.txt')          -> '/current/working/dir/file.txt'
"   path#to_abs('/already/absolute') -> '/already/absolute'
"   path#to_abs('../parent/file')    -> '/current/working/parent/file'
"
function! path#to_abs(path) abort
  " |filename-modifiers| - :p
  " For a file name that does not exist and does not have an absolute path the
  " result is **unpredictable**.
  if path#is_abs(a:path)
    return a:path
  endif

  let cwd = getcwd()
  let sep = path#get_sep()
  return path#normalize(cwd .. sep .. a:path)
endfunction


if s:is_win

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
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Shorten {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Shortens a given path by reducing each component of the path to a specified
" length or a minimal distinguishable length while ensuring the result is still
" unique.
"
" This function takes a path and shortens each of its components (directories or
" file names) to the specified length, ensuring that the shortened components
" are still unique enough to distinguish the path. It's useful for displaying
" paths in a more compact form while maintaining their uniqueness and
" readability.
"
" Parameters:
" - path: The path string to be shortened.
" - ...: An optional argument specifying the desired length for each component
"        of the path. If not provided, defaults to 1.
"
" Returns:
" A shortened version of the path as a string.
"
" Examples:
"   path#shorten('/home/user/projects/vim-plugin')
"     -> '/h/u/p/vim-plugin' (assuming default length of 1)
"
"   path#shorten('/home/user/projects/vim-plugin', 2)
"     -> '/ho/us/pr/vim-plugin' (each component shortened to 2 characters)
"
"   path#shorten('/home/user/projects/vim-plugin', 10)
"     -> '/home/user/projects/vim-plugin' (length greater than component length)
"
"   path#shorten('user/projects/vim-plugin')
"     -> 'u/p/vim-plugin' (relative path example)
"
"   path#shorten('/使用者/專案/插件', 1)
"     -> '/使/專/插件' (handling Unicode characters)
"
function! path#shorten(path, ...) abort
  let len = (a:0 > 0) ? a:1 : 1
  if len < 0
    let len = 1
  endif
  let components = path#split(a:path)
  let n_comps = len(components)

  let results = s:build_uniq_comps(components, n_comps, len)
  return path#join(results)
endfunction


" Generate a list of unique shortened components from the given path components.
" It attempts to make each component distinct but shortened based on the
" specified length.
function! s:build_uniq_comps(components, n_comps, len) abort
  let results = s:init_uniq_comps(a:components, a:n_comps, a:len)

  let i = 0
  while i < a:n_comps - 1
    let target = a:components[i]

    let j = 0
    while j < a:n_comps
      if i == j
        let j += 1
        continue
      endif

      let comp = a:components[j]
      let uniq = s:get_uniq_part(target, comp)
      if strchars(uniq) > strchars(results[i])
        let results[i] = uniq
      endif

      let j += 1
    endwhile

    let i += 1
  endwhile

  return results
endfunction


" Initialize the list of unique shortened components. For absolute paths, the
" first component remains unchanged, while subsequent components are shortened.
function! s:init_uniq_comps(components, n_comps, len) abort
  if a:n_comps < 2
    return a:components[:]
  endif

  let results = []
  if path#is_abs(a:components[0])
    let i = 1
    call add(results, a:components[0])
  else
    let i = 0
  endif

  while i < a:n_comps - 1
    let comp = a:components[i]
    let qualifier = printf('{1,%d}', a:len)
    let min_comp = matchstr(comp, '\v^.{-}[^.\/:*?"<>|]' .. qualifier)
    if empty(min_comp)
      let min_comp = comp
    endif
    call add(results, min_comp)
    let i += 1
  endwhile

  call add(results, a:components[a:n_comps - 1])
  return results
endfunction


" Get the shortest unique substring of 'target' by comparing it with 'other'.
" This is used to determine how to shorten each component in a way that remains
" distinguishable.
function! s:get_uniq_part(target, other) abort
  let len_target = strchars(a:target)
  let len_other = strchars(a:other)
  let i = 0
  while i < len_target
    if i >= len_other
      return a:target[0: i]
    endif

    let tc = strcharpart(a:target, i, 1)
    let oc = strcharpart(a:other, i, 1)
    if tc !=# oc
      return a:target[0: i]
    endif

    let i += 1
  endwhile

  return a:target
endfunction


" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Basis {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Expands a given path by substituting special characters and environment
" variables.
"
" This function expands special characters like `~` to the user's home directory
" and replaces environment variable placeholders (supports `$VAR`, `${VAR}`, and
" `%VAR%` formats) with their corresponding values. It does not expand wildcards
" or special Vim sequences like `%` or `#`.
"
" Parameters:
" - path: The path string to be expanded.
"
" Returns:
" The expanded path as a string.
"
" Examples:
"   path#expand('~/file')                 -> '/home/username/file'
"   path#expand('$HOME/file')             -> '/home/username/file'
"   path#expand('${CONFIG_DIR}/settings') -> '/etc/settings'
"   path#expand('%APPDATA%\config')       -> 'C:\Users\Username\AppData\Roaming\config'
"
if s:is_win

  function! path#expand(path) abort
    let expanded_path = s:unix_expand(a:path)

    " Handle the %VAR_NAME% format
    let pct_env_var_pat = '\v\%(\w+)\%'
    let expanded_path = substitute(expanded_path, pct_env_var_pat,
      \ '\=s:env_expand("$" .. submatch(1), "%" .. submatch(1) .. "%")', 'g')

    return expanded_path
  endfunction

else

  function! path#expand(path) abort
    return s:unix_expand(a:path)
  endfunction

endif


" Expands a given path by replacing `~` with the user's home directory and
" substituting environment variables in the form `$VAR_NAME` or `${VAR_NAME}`.
"
"" NOTE:
"  This function uses Vim's expand() to resolve environment variables. As per
"  the Vim manual, if the environment variable is not known inside the current
"  Vim session, a shell will be invoked to expand the variable. This can be
"  slow, especially if many such resolutions are needed in rapid succession.
"  However, it ensures that all variables that the shell knows about are
"  expanded.
"
" NOTE:
" Should not implement by directly call `expand()`, which also expands wildcards
" (like *), file modifiers (like :p for full path), and even handles things like
" % for the current file. This means that you might get unexpected behavior if
" the path string contains any of these special characters or sequences.
"
function! s:unix_expand(path)
  " Expand ~ to the home directory
  let expanded_path = substitute(a:path, '\v^[~]',
    \ '\=s:env_expand("~", "~")', '')

  " Expand environment variables
  let env_var_pat = '\v\$\w+'
  let expanded_path = substitute(expanded_path, env_var_pat,
    \ '\=s:env_expand(submatch(0), submatch(0))', 'g')

  " Handle the ${VAR_NAME} format
  let braced_env_var_pat = '\v\$\{(\w+)\}'
  let expanded_path = substitute(expanded_path, braced_env_var_pat,
    \ '\=s:env_expand("$" .. submatch(1), "${" .. submatch(1) .. "}")', 'g')

  return expanded_path
endfunction


function! s:env_expand(env_var, fallback)
  if a:env_var =~# '\v\$\w+$'
    let evaluated = eval(a:env_var)
    if !empty(evaluated)
      return evaluated
    endif
  endif

  let expanded = expand(a:env_var)
  if expanded == a:env_var
    return a:fallback
  else
    return expanded
  endif
endfunction


" Resolves symbolic link.
function! path#resolve(path) abort
  return resolve(a:path)
endfunction


" Normalizes a given path based on the provided options.
"
" This function simplifies the path by resolving `.` and `..` segments, handling
" redundant separators, and applying additional normalization options specified
" by the user.
"
" Parameters:
" - path: The path to be normalized.
" - ...: An optional dictionary or a string of flags that dictate the normalization
"        behavior. Supported options include:
"        - 'rel_leading_dot': If set, a leading '.' is added to relative paths.
"        - 'dot_if_empty': If set, an empty path is converted to a single '.'.
"        - 'dir_trailing_sep': If set, a trailing separator is added to directory paths.
"
" Returns:
" The normalized path as a string.
"
" Examples:
"   path#normalize('/foo/./bar//baz/') -> '/foo/bar/baz'
"   path#normalize('foo/./bar//baz/', {'rel_leading_dot': 1}) -> './foo/bar/baz'
"   path#normalize('foo/bar/..', {'dir_trailing_sep': 1}) -> 'foo/'
"   path#normalize('', {'dot_if_empty': 1}) -> '.'
"
if s:is_win

  function! path#normalize(path, ...) abort
    let opts = deepcopy(get(a:, 1, {}))
    let path = s:convert_win_sl(a:path)
    if s:is_shellslash()
      return s:normalize_path_w_slash_sep(path, opts)
    else
      return s:normalize_path_w_backslash_sep(path, opts)
    endif
  endfunction

else

  function! path#normalize(path, ...) abort
    let opts = deepcopy(get(a:, 1, {}))
    return s:normalize_path_w_slash_sep(a:path, opts)
  endfunction

endif


function! s:normalize_path_w_slash_sep(path, opts) abort
    " Resolve the normalization options based on the input arguments.
    let opts = s:normalize_resolve_opts(a:opts)

    " Simplify the path
    let path = s:simplify_slash(a:path)

    " Handle empty path cases.
    if (empty(a:path)) || (path =~# '^\.\/\?$')
      let path = (opts.rel_leading_dot || opts.dot_if_empty) ? '.' : ''
      let path ..= opts.dir_trailing_sep ? '/' : ''
      return path
    endif

    " Ensure leading './' is present for relative paths if the option is set.
    if opts.rel_leading_dot == 1
      if !path#is_abs(path) && path !~# '^\.\/'
        let path = './' .. path
      endif
    else
      " Remove leading './' if the option is unset.
      let path = substitute(path, '^\.\/', '', '')
    endif

    " Ensure trailing separator is correctly set based on the option.
    if opts.dir_trailing_sep == 1
      if (isdirectory(path)) && (path !~# '\/$')
        let path ..= '/'
      endif
    else
      let path = path#strip_trailing_sep_s(path)
    endif

    return path
endfunction


function! s:normalize_path_w_backslash_sep(path, opts) abort
    " Resolve the normalization options based on the input arguments.
    let opts = s:normalize_resolve_opts(a:opts)

    " Simplify the path
    let path = s:simplify_backslash(a:path)

    " Handle empty path cases.
    if (empty(a:path)) || (path =~# '^\.\\\?$')
      let path = (opts.rel_leading_dot || opts.dot_if_empty) ? '.' : ''
      let path ..= opts.dir_trailing_sep ? '\' : ''
      return path
    endif

    " Ensure leading './' is present for relative paths if the option is set.
    if opts.rel_leading_dot == 1
      if (!path#is_abs(path)) && (path !~# '^\.\\')
        let path = '.\' .. path
      endif
    else
      " Remove leading './' if the option is unset.
      let path = substitute(path, '^\.\\', '', '')
    endif

    " Ensure trailing separator is correctly set based on the option.
    if opts.dir_trailing_sep == 1
      if (isdirectory(path)) && (path !~# '\\$')
        let path ..= '\'
      endif
    else
      let path = path#strip_trailing_sep_s(path)
    endif

    return path
endfunction


function! s:simplify_slash(text)
    let text = simplify(a:text)
    return substitute(text, '^\v^/{3,}', '/', 'g')
endfunction


function! s:simplify_backslash(text)
    let text = simplify(a:text)
    return substitute(text, '^\v^\\{3,}', '\\', 'g')
endfunction


" Resolves normalization options based on input, either as flags or as
" a dictionary.
function! s:normalize_resolve_opts(arg)
    let arg_type = type(a:arg)
    let opts = extend({}, get(g:, 'path_normalize', {}))
    let opts = extend(opts, s:default_normalize_opts(), 'keep')

    if arg_type == v:t_string
      " Convert the flags to opts
      let flags_map = {
      \ 'd': ['rel_leading_dot', 1],
      \ 'D': ['rel_leading_dot', 0],
      \ 'e': ['dot_if_empty', 1],
      \ 'E': ['dot_if_empty', 0],
      \ 't': ['dir_trailing_sep', 1],
      \ 'T': ['dir_trailing_sep', 0]
      \ }

      for [flag, setting] in items(flags_map)
        if a:arg =~# flag
          let opts[setting[0]] = setting[1]
        endif
      endfor
    elseif arg_type == v:t_dict
      let opts = extend(opts, a:arg, 'force')
    else
      throw 'Illegal Arguments: Expected a string or dictionary.'
    endif

    return opts
endfunction


" Returns the default normalization options.
function! s:default_normalize_opts() abort
  return {
    \ 'rel_leading_dot': 0,
    \ 'dot_if_empty': 1,
    \ 'dir_trailing_sep': 0,
  \ }
endfunction


" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" vim: sw=2 ts=2 tw=80 et foldmethod=marker
