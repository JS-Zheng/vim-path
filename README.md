# vim-path
🛣 Minimalist Vim Path Library


## Introduction
**vim-path** is a streamlined and efficient Vim library, expertly crafted for path manipulation. It embraces a minimalist approach, focusing on essential features to facilitate seamless and effective path handling in a cross-platform environment. Unencumbered by unnecessary complexities, **vim-path** is the perfect tool for those seeking a straightforward solution to path management in Vim.


## Installation
To install **vim-path**, you can either manually download [path.vim](https://raw.githubusercontent.com/JS-Zheng/vim-path/main/path.vim) and place it in your "autoload" directory, or use a Vim plugin manager for an easier setup. For instance, if you're using [vim-plug](https://github.com/junegunn/vim-plug), simply add the following line to your `.vimrc` or `init.vim`:
```vim
Plug 'js-zheng/vim-path'
```

Then, execute the following Vim commands:
```vim
:source %
:PlugInstall
```
This will ensure that **vim-path** is correctly installed and ready for use.


## Features

- **Expansion:** Expand environment variables and user shortcuts in paths.
- **Finder:** Locate specific markers within a path structure.
- **Iteration:** Iterate over path components in either forward or backward direction.
- **Joining:** Intelligently join multiple path segments into a single path.
- **Normalization:** Normalize paths by resolving '..' and '.' segments.
- **Parsing:** Extract components like directory, filename, extension from paths.
- **Shortening:** Shorten paths to specified lengths while maintaining uniqueness.
- **Type Detection:** Detect if a path is absolute, a file, a directory, etc.


## Usage

**vim-path** offers a variety of functions to handle different aspects of path manipulation. Below is a guide to some of the key functionalities:

### Path Constructor
Create a path object with various input types and options for expansion, normalization, and resolution.

#### Using a String
Pass a string representing the path directly.

```vim
path#('/path/to/directory')
-> '/path/to/directory'
```

#### Using a Dictionary
Pass a dictionary with `dir` and `base` keys for more control.

```vim
path#({'dir': '/path/to', 'base': 'file.txt'})
-> '/path/to/file.txt'
```

#### Using a List
Pass a list of path segments to be joined.

```vim
path#(['path', 'to', 'file.txt'])
-> 'path/to/file.txt'
```

#### Specifying Path Manipulation Options
Pass a dictionary or string with flags to control expansion, normalization, and resolution.

```vim
" Using dictionary for specific options
path#('$HOME/path/to/../dir', {'expand': 1, 'normalize': 1, 'resolve': 0})
-> '/home/user/path/dir'

" Using string shorthand for options (e.g., 'en' for expand and normalize)
path#('$HOME/path/to/../dir', 'en')
-> '/home/user/path/dir'
```

These examples showcase the flexibility of the **vim-path** constructor, allowing you to easily build and manipulate paths based on different inputs and requirements. The constructor is a central feature, providing a streamlined approach to handling various path formats and operations.

### Normalization
Normalize paths by resolving `.` and `..`, removing redundant separators, etc.

```vim
path#normalize('/path/to/./dir/../file')
-> '/path/to/file'
```

### Joining
Intelligently join multiple path segments into a single path.

```vim
path#join(['segment1', 'segment2', 'segment3'])
-> 'segment1/segment2/segment3'
```

### Splitting
Split a path into its individual components.

```vim
path#split('/path/to/file')
-> ['/', 'path/', 'to/', 'file']
```

The `path#split()` function splits a given path into its individual components, uniquely retaining the path separators. This approach has several advantages:

- It allows for the easy reassembly of the original path using Vim's native `join()` function.
- It facilitates efficient top-down or bottom-up iteration over path components.

**vim-path** can be particularly useful in tasks like locating project markers (e.g., `.git`, `.svn`, `.vscode`), which are common in plugin development to determine project roots.

Consider this Vim function leveraging **vim-path** to find project markers:

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

By preserving path separators during the `split` operation, **vim-path** enhances the effectiveness of path-based computations and iterations in Vim scripting. This design decision aligns with the practical needs of Vim script development, offering both simplicity and performance.


### Expansion
Expand environment variables and shortcuts like `~` in paths.

```vim
let $VAR = file
path#expand('~/path/to/$VAR')
-> '/home/user/path/to/file'
```

### Absolute Path Conversion
Convert relative paths to absolute paths based on the current working directory.

```vim
path#to_abs('relative/path')
-> '/cwd/relative/path'
```

### Shortening
Shorten each component of the path to a specified length for a more concise representation.

```vim
path#shorten('/long/path/name', 1)
-> '/l/p/name'
```

### Type Detection
Check if a given path is a directory, file, symbolic link, etc.

```vim
if path#is_dir('/path/to/dir')
  echo 'It is a directory'
endif
```

### Parsing
Parse a path into its constituent elements like directory, filename, extension, etc.

```vim
let parsed = path#parse('/path/to/file.txt')
-> {'root': '/', 'dir': '/path/to', 'name': 'file', 'base': 'file.txt', 'ext': 'txt'}
```

### Finding
Locate specific markers or patterns within a path, traversing directories as needed.

```vim
let finder = path#finder#({'order': 'top-down', 'markers': ['.git']})
let [found_path, found_marker] = finder.find('/path/to/start/searching')
```

## License
MIT

