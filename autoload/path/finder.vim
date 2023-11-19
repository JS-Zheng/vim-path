" Creates a finder object to locate specific markers within a given path.
"
" This function constructs a finder object used to search for specified markers (like
" '.git', '.svn', etc.) within a path. It can perform both top-down and bottom-up searches
" based on the given options. This is commonly used in plugins to determine project roots
" or locate specific configuration files within a directory structure.
"
" Parameters:
" - ...: A dictionary containing finder options, such as the order of search
"        ('top-down' or 'bottom-up'), markers to search for, and paths to exclude.
"
" Returns:
" - A dictionary representing the finder object. This object contains a 'find'
"   method that can be used to perform the search.
"
" Examples:
"   " This will search for '.git' or '.svn' directories starting from the top of
"   " '/path/to/project'.
"   let finder = path#finder#({'order': 'top-down', 'markers': ['.git', '.svn']})
"   let [found_path, marker] = finder.find('/path/to/project')
"
"   " This will search for a '.git' directory starting from '/path/to/project/subdir' and
"   " moving upwards.
"   let finder = path#finder#({'order': 'bottom-up', 'markers': ['.git']})
"   let [found_path, _] = finder.find('/path/to/project/subdir')
"
function! path#finder#(...) abort
  " Resolve the finder options.
  let opts = deepcopy(get(a:, 1, {}))
  let finder = s:resolve_opts(opts)

  " Determine the search direction and assign the appropriate function.
  if finder.order =~? '\v^t(op-down)?$'
    let finder.find = function('s:top_down_find')
  elseif finder.order =~? '\v^b(ottom-up)?$'
    let finder.find = function('s:bottom_up_find')
  else
    throw 'Illegal Arguments: Invalid order provided.'
  endif

  return finder
endfunction


" Searches for markers from the top of the path downwards.
function! s:top_down_find(...) abort dict
  let path = get(a:, 1, getcwd())
  let comps = path#split(path)
  let n_comps = len(comps)
  if (!n_comps)
    return ['', '']
  endif

  let p = ''
  for comp in comps
    let p ..= comp
    for marker in self.markers
      if (!empty(globpath(p, marker)))
        let strip_path = path#strip_trailing_sep_s(p)
        if (index(self.excludes, strip_path) < 0)
          return [strip_path, marker]
        endif
      endif
    endfor
  endfor

  return ['', '']
endfunction


" Searches for markers from the bottom of the path upwards.
function! s:bottom_up_find(...) abort dict
  let path = get(a:, 1, getcwd())
  let comps = path#split(path)
  let n_comps = len(comps)
  if (!n_comps)
    return ['', '']
  endif

  for i in range(n_comps - 1, 0, -1)
    let comp = comps[i]
    for marker in self.markers
      if (!empty(globpath(path, marker)))
        let strip_path = path#strip_trailing_sep_s(path)
        if (index(self.excludes, strip_path) < 0)
          return [strip_path, marker]
        endif
      endif
    endfor

    let path = path[:-(strlen(comp) + 1)]
  endfor

  return ['', '']
endfunction


" Resolves options for the finder.
function! s:resolve_opts(arg) abort
  if type(a:arg) != v:t_dict
    throw 'Illegal Arguments: Expected a dictionary.'
  endif

  let g_opts = deepcopy(get(g:, 'path_finder_marker_opts', {}))
  let opts = extend(a:arg, g_opts, 'keep')
  let opts = extend(opts, s:default_opts(), 'keep')

  " Ensure trailing separators are stripped from excludes
  if has_key(opts, 'excludes')
    let opts['excludes'] = map(opts['excludes'], 'path#strip_trailing_sep_s(v:val)')
  endif

  return opts
endfunction


" Returns the default finder options.
function! s:default_opts() abort
  return {
    \ 'order': 'top-down',
    \ 'excludes': ['/', $HOME],
    \ 'markers': ['.git', '.hg', '.svn', '.idefnamemodifya', '.vscode', '.root',
      \ 'package.json', 'node_modules'],
  \ }
endfunction
