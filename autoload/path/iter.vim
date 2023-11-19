" Initializes an iterator over a path based on given options.
"
" Parameters:
" - path: The path to iterate over.
" - ...: The optional arguments dict or flags.
"
" Returns:
" The iterator object.
"
function! path#iter#(path, ...) abort
  " Resolve the iterator options based on the input arguments.
  let opts = deepcopy(get(a:, 1, {}))
  let opts = s:resolve_opts(opts)
  let components = path#split(a:path)

  let l:iterator = {}
  let l:iterator.components = components
  let l:iterator.n_components = len(components)

  if opts.order ==# 'top-down'
    return s:top_down_init(l:iterator)
  elseif opts.order ==# 'bottom-up'
    return s:bottom_up_init(l:iterator, a:path)
  else
    throw 'Illegal Arguments: Invalid order provided.'
  endif
endfunction


" Initializes the iterator for top-down order.
function! s:top_down_init(iterator) abort
  let a:iterator.index = 0
  let a:iterator.path = ''
  let a:iterator.next = function('s:top_down_next')
  let a:iterator.has_next = function('s:has_next')
  return a:iterator
endfunction


" Initializes the iterator for bottom-up order.
function! s:bottom_up_init(iterator, path) abort
  let a:iterator.index = a:iterator.n_components - 1
  let a:iterator.path = a:path
  let a:iterator.next = function('s:bottom_up_next')
  let a:iterator.has_next = function('s:has_next')
  return a:iterator
endfunction


function! s:resolve_opts(arg) abort
  let arg_type = type(a:arg)
  let opts = extend({}, get(g:, 'path_iter_opts', {}))
  let opts = extend(opts, s:default_opts(), 'keep')

  if arg_type == v:t_string
    " Convert the flags to opts
    let flags_map = {
    \ '\v^t(op-down)?$': 'top-down',
    \ '\v^b(ottom-up)?$': 'bottom-up',
    \ }

    for [pat, val] in items(flags_map)
      if a:arg =~? pat
        let opts['order'] = val
      endif
    endfor
  elseif arg_type == v:t_dict
    let opts = extend(opts, a:arg, 'force')
  else
    throw 'Illegal Arguments: Expected a string or dictionary.'
  endif

  return opts
endfunction


" Returns the default iterator options.
function! s:default_opts() abort
  return {
    \ 'order': 'top-down',
  \ }
endfunction


" Returns the next concatenated path in the top-down order.
function! s:top_down_next() abort dict
  if self.index < len(self.components)
    let self.path .= self.components[self.index]
    let self.index += 1
    return self.path
  endif
  return ''
endfunction


" Returns the next concatenated path in the bottom-up order.
function! s:bottom_up_next() abort dict
  if self.index >= 0
    let result = self.path
    let len_strip = len(self.components[self.index]) + 1
    let self.path = self.path[:-len_strip]
    let self.index -= 1
    return result
  endif
  return ''
endfunction


" Checks if the iteration is done.
function! s:has_next() abort dict
  return (0 <= self.index) && (self.index < self.n_components)
endfunction
