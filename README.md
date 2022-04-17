# vim-path
🛣 Minimalist Vim Path Library


## Introduction
**vim-path** is a lightweight, cross-platform and fast path library. It doesn't have any fancy or magnificent features, just the essence for handling paths.


## Installation
[Download path.vim](https://raw.githubusercontent.com/JS-Zheng/vim-path/main/path.vim) and put it in the "autoload" directory, or use your favorite Vim plugin manager. For example, put this in your `.vimrc` or `init.vim` if you want to install it with [vim-plug](https://github.com/junegunn/vim-plug):
```vim
Plug 'js-zheng/vim-path'
```
and then running:
```vim
:source %
:PlugInstall
```


## APIs

### Constructor
Except for the empty constructor, the following ones support these optional arguments:
- `expand: bool` - whether to expand home symbol (i.e., `~`), environment variables and special characters supported by Vim's `expand()` (default: `1`).
- `normalize: bool` - whether to strip redundant components (e.g., `..`, `.`) (default: `1`).
- `resolve: bool` - whether to follow path if it is a symlink (default: `0`).
```vim
" Get the current directory symbol (i.e., '.')
path#(): string
path#(v:none): string

" For examples:
" - path#('%')
"   return 'README.md' (current file name)
"
" - (Unix)
"   path#('~/School Reports/SSIS-287.mp4')
"   return '/Users/js-zheng/School Reports/SSIS-287.mp4'
"          (in my MBPR)
"
" - (Windows)
"   path#('~\Workspace\Vim\..\lf-queue', 1, 1)
"   return 'C:\Users\js-zheng\Workspace\lf-queue'
"          (in my MBPR)
path#(path: string, ...): string

" For examples:
" - (Unix)
"   path#(#{dir: '/home/alice/.local/bin', base: 'clangd'})
"   return '/home/alice/.local/bin/clangd'
"
" - (Windows)
"   path#(#{dir: '\\host\share\alice\..\bob', base: 'rg.exe'})
"   return '\\host\share\bob\rg.exe'
"          (vim-path supports UNC path on Windows)
path#(path: {dir: string, base: string}, ...): string

" For examples:
" - (Unix)
"   path#(['/', 'home', '/bob', '//.vim', '/files.txt'])
"   return '/home/bob/.vim/files.txt'
"
" - (Windows)
"   path#(['C:\', '\Queen', '\Bohemian\.\', 'Rhapsody\'])
"   return 'C:\Queen\Bohemian\Rhapsody\'
path#(paths: list<string>, ...): string
```

vim-path also provides the following shortcut functions:
```vim
" Get the path to the user home directory.
path#home(): string


" Get the path to the current vim buffer.
" @absolute: bool - [optional] returns an absolute path if true, otherwise
"                   returns a relative path (default: 1).
path#curr_buf([absolute: bool]): string


" Get the path to the current vim buffer directory.
" @absolute: bool - [optional] returns an absolute path if true, otherwise
"                   returns a relative path (default: 1).
path#curr_buf_dir([absolute: bool]): string
```

---

### Join & Split
```vim
" Joins any number of components into a single path with the platform-specific
" separator, then normalizes it.
" Same as the `path#(paths: list<string>, 0, 1, 0)`
"
" For examples:
" - (Unix)
"   path#join('.local/', '/share/', 'man/', '/man1', 'fzf.1')
"   return '.local/share/man/man1/fzf.1'
"
" - (Windows)
"   path#join('Program Files\', 'LLVM\', '\..', 'Git\')
"   return 'Program Files\Git\'
path#join(paths: list<string>): string
path#join(...string): string


" Splits a path into path components with the platform-specific separator.
"
" For examples:
" - (Unix)
"   path#split('/home/user/bob/vim/vimrcs/general.vim')
"   return ['/', 'home/', 'user/', 'bob/', 'vim/', 'vimrcs/', 'general.vim']
"          (#1)
"
" - (Windows)
"   path#split('C:\Lamb\of\God')
"   return ['C:\', 'Lamb\', 'of\', 'God']
"
" - (Windows)
"   path#split('\\Avenged\Sevenfold\Buried\Alive')
"   return ['\\Avenged\', 'Sevenfold\', 'Buried\', 'Alive']
"               (#2)
path#split(): list<string>

```
In most cases, `split` a normalized path and then `join` it should get a path the same as the original.


**NOTE**: The behavior of `path#split()` is different from many path libraries (not limited to VIM), which often trim path separators (e.g., `/a/b/c -> ['a', 'b', 'c']`).

vim-path tries to keep the path root and separators, therefore, `/` (i.e., root) is the first element in above example (#1) and `\\Avenged\` (Windows UNC hostname) is also the first element at (#2).

The benefit of this behavior is that users can join it to get the original path by the **fast native** `join()` function. Furthermore, users can iterator components top-down/bottom-up very easily, for example, implement a project root finder, a common plug-in feature:
```vim
func! FindMarkers(base, markers = ['.git', '.svn', '.vscode'])
  let path = ''
  let comps = path#split(a:base)
  for comp in a:comps
    let path .= comp
    for marker in a:markers
      if (!empty(globpath(path, marker)))
        return path
      endif
    endfor
  endfor

  return ''
endfunc
```

---

### Iterator

vim-path provides a `path#find_markers()` which works like the previous exmaple but supports bottom-up iteration:
```vim
" Finds `markers` in each component of `path`.
" Returns a list, which contains the directory path and the marker which has
" been found, otherwise returns ['', ''].
" @top_down: bool - [optional] top-down or bottom-up search (default: 1)
" @excludes: list<string> - [optional] exclude paths (default: [])
"
" For examples:
" - (Unix)
"   path#find_markers(path#curr_buf_dir(), ['.git', '.svn', '.vscode'], 0)
"   return ['/Users/js-zheng/Workspace/vim-path', '.git']
"          (in my MBPR)
"
path#find_markers(path: string, markers: list<string>, [top_down: bool]): [path: string, marker: string]
```

vim-path also provides a `path#iter()`, which is a simple wrapper function to make each element of the `path#split()` result to be accessible. It's slightly slow but very convenient.
```vim
" Returns an accessible split components.
" @top_down: bool - [optional] (default: 1)
"
" For examples:
" - (Unix)
"   path#iter('/I/am/Lo/Ta-yu/', 1)
"   return ['/', '/I/', '/I/am/', '/I/am/Lo/', '/I/am/Lo/Ta-yu/']
"
" - (Unix)
"   path#iter('/I/am/Lo/Ta-yu/', 0)
"   return ['/I/am/Lo/Ta-yu/', '/I/am/Lo/', '/I/am/', '/I/', '/']
"
" - (Windows)
"   path#iter('c:\look\at\me')
"   return ['c:\', 'c:\look\', 'c:\look\at\', 'c:\look\at\me']
"
" - (Windows)
"   path#iter('c:\look\at\me')
"   return ['c:\look\at\me', 'c:\look\at\', 'c:\look\', 'c:\']
path#iter(path: string, [top_down: bool]): list<string>
```

**NOTE**: For performance reasons, vim-path doesn't provide iterator objects and methods like in OOP (e.g., `has_next()`, `next()`), just a string path list. (Things may change in |vim9script|)

---

### Parser
```vim

" Returns an object whose properties represent significant elements of the path.
" This API was inspired by Node.js `path.parse()` function.
"
" For examples:
" - (Unix)
"   path#parse('/home/user/nuno/riff.gp6')
"   return {'root': '/', 'dir': '/home/user/nuno', 'name': 'riff', 'base':
"           'riff.gp6', 'ext': 'gp6'}
"
" - (Unix)
"   path#parse('/home/user/skid/row')
"   return {'root': '/', 'dir': '/home/user/skid', 'name': 'row', 'base':
"           'row', 'ext': ''}
"
" - (Windows)
"   path#parse('C:\Amazing\Show\Sin\Man.mp4')
"   return {'root': 'C:\', 'dir': 'C:\Amazing\Show\Sin', 'name': 'Man', 'base':
"           'Man.mp4', 'ext': 'mp4'}
"
" - (Windows)
"   path#parse('C:\Attack\Titan\Eren\Yeager')
"   return {'root': 'C:\', 'dir': 'C:\Attack\Titan\Eren', 'name': 'Yeager',
"           'base': 'Yeager', 'ext': ''}
"
" - (Windows)
"   path#parse('\\JoJo\Bizarre\Adventure')
"   return {'root': '\\JoJo', 'dir': '\\JoJo\Bizarre', 'name': 'Adventure',
"           'base': 'Adventure', 'ext': ''}
path#parse(path: string): {
    root: string,
    dir: string,
    base: string,
    name: string,
    ext: string
}


" Low-level APIs
path#get_root(path: string): string
path#get_dir(path: string, [ignore_trailing_sep: bool]): string
path#get_basename(path: string): string
path#get_name(path: string): string
path#get_ext(path: string): string
```

---

### Separator

```vim
" Get the path separator.
" (Unix): Returns '/'.
" (Windows): Returns '/' if set &shellslash, otherwise returns '\'.
path#get_sep(): string


" Strips the leading/trailing path separators in the `path`.
"
" For examples:
" - (Unix)
"   path#strip_sep('//////\Extreme/Decadence/Dance\/////')
"   return '\Extreme/Decadence/Dance\'
"   (Many Unix allows backslashes in filename)
"
" - (Windows)
"   path#strip_sep('//////\Extreme/Decadence/Dance\/////')
"   return 'Extreme/Decadence/Dance'
"   (Windows doesn't allow backslashes in filename)
path#strip_sep(path: string): string
path#strip_leading_sep(path: string): string
path#strip_trailing_sep(path: string): string


" Same as the `path#strip_trailing_sep()` but if the path is root, it will not
" be executed.
path#strip_trailing_sep_s(path: string): string


" Append a path separator to path if possible.
path#as_dir(path: string): string
```

---

### Type Dectection

```vim
" Determines if the `path` is a directory.
" @expand: bool - whether to expand home symbol (i.e., `~`) and environment
"                 variables (default: 1).
" NOTE: Due to the Vim strategy, the `~` and $HOME will not be interpreted as
"       HOME directory if no expand it.
path#is_dir(path: string, [expand: bool]): bool


" Determines if the `path` is an absolute path.
" @expand: bool - whether to expand home symbol (i.e., `~`) and environment
"                 variables (default: 1).
path#is_abs(path: string, [expand: bool]): bool


" Determines if the `path` is a file.
" @expand: bool - whether to expand home symbol (i.e., `~`) and environment
"                 variables (default: 1).
" @resolve: bool - whether to follow path if it is a symlink (default: 0).
path#is_file(path: string, [expand: bool, resolve: bool]): bool
path#is_readable_file(path: string, [expand: bool, resolve: bool]): bool
path#is_writable_file(path: string, [expand: bool, resolve: bool]): bool


" Determines if the `path` is a symlink.
" @expand: bool - whether to expand home symbol (i.e., `~`) and environment
"                 variables (default: 1).
" @resolve: bool - whether to follow path if it is a symlink (default: 0).
path#is_link(path: string, [expand: bool, resolve: bool]): bool


" Returns the file type, see also `getftype()`.
" @expand: bool - whether to expand home symbol (i.e., `~`) and environment
"                 variables (default: 1).
" @resolve: bool - whether to follow path if it is a symlink (default: 0).
path#get_type(path: string, [expand: bool, resolve: bool]): bool
```

---

### Change Directory
```vim
" Uses the `cmd` to change the working directory to the `path`.
" @path: string - a path to change directory (default: `-`).
" @cmd: string - e.g., cd, lcd, tcd
path#cd([path: string, cmd: string])


" Pushes the current working directory to the `stack` and then change the
" working directory to the `path`.
" @cmd: string - e.g., cd, lcd, tcd
" @stack: list<string> - a directory stack to save pushd history.
"         (default: `g:path_dir_stack`)
path#pushd(path, [cmd: string, stack: list<string>])


" Pops the `stack` and then change the working directory to the result.
" @cmd: string - e.g., cd, lcd, tcd
" @stack: list<string> - a directory stack to save pushd history.
"         (default: `g:path_dir_stack`)
path#popd([cmd: string, stack: list<string>])
```

---

### Conversion

```vim
" Converts the `path` to an absolute path.
path#to_abs(path: string): string


" Converts the `path` to a glob pattern.
path#to_glob(path: string): string


" Likes the Vim's pathshorten() but makes each component be
" **identifiable**.
" @min_len: uint - min component length (default: 1)
"
" For examples:
" - (Unix)
"   path#shorten('/apple/banana/applications/bat')
"   return '/apple/b/appli/bat'
"   (Vim's pathshorten: '/a/b/a/bat')
"
" - (Windows)
"   path#shorten('c:\cat\categories\ginger')
"   return 'c:\cat\cate\ginger'
"   (Vim's pathshorten: 'c:\c\c\ginger')
path#shorten(path: string, min_len: uint): string
```

---

### Basis

```vim
" Same as the Vim's expand(), but change the default argument `nosuf` to
" g:path_expand_nosuf (default: 1).
path#expand(expr: string, [nosuf: bool, list: bool]): string


" Follows the `path` if it is a symlink, otherwise normalize it.
path#resolve(path: string): string


" Same as the Vim's simplify() but returns a dot symbol if the `path` is empty,
" and convert path separator based on &shellslash if running on Windows.
path#normalize(path: string): string
```

---

## License
MIT

