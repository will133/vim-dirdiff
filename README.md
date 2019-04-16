# vim-dirdiff

DirDiff plugin for Vim

If you like Vim's diff mode, you would love to do this recursively on two
directories!

![DirDiff Session](/screenshot.png?raw=true "DirDiff Session")

## Installation

With [pathogen.vim](https://github.com/tpope/vim-pathogen):

    cd ~/.vim/bundle
    git clone git://github.com/will133/vim-dirdiff

## Usage

    :DirDiff <dir1> <dir2>

To open DirDiff from the command line, run `vim -c "DirDiff dir1 dir2"`
or add the following function to your shell init file:

    function dirdiff()
    {
        # Shell-escape each path:
        DIR1=$(printf '%q' "$1"); shift
        DIR2=$(printf '%q' "$1"); shift
        vim $@ -c "DirDiff $DIR1 $DIR2"
    }

If you use pathogen, you can use :Helptags to regenerate documentation.  You
then can see ":h dirdiff" for more information.


To specify a theme, add
```
let g:DirDiffTheme = 'github' " or any valid colorscheme
```
to your .vimrc

Adding 
```
let g:DirDiffSimpleMap=1
```
to your .vimrc will turn on 
[ and ] mappings (to replace [c and ]c)

## License

Copyright (c) 2001-2015 William Lee. (BSD-Like)  See doc/dirdiff.txt.
