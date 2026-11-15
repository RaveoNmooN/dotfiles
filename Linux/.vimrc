" ==============================================================================
"  ~/.vimrc - Vim defaults for Linux (from the dotfiles repo)
" ==============================================================================

" ------------------------------------------------------------------------------
"  General
" ------------------------------------------------------------------------------

" Disable compatibility with vi, which can cause unexpected issues.
set nocompatible

" The "tiny" Vim that minimal systems ship lacks some features, so each
" optional one is checked first. This file then loads without errors anywhere.

" Detect file types and load their plugins and indentation rules.
if has('autocmd')
  filetype plugin indent on
endif

" Turn syntax highlighting on.
if has('syntax')
  syntax on
endif

" Let Backspace delete over indentation, line breaks and the insert start.
set backspace=indent,eol,start

" ------------------------------------------------------------------------------
"  Display
" ------------------------------------------------------------------------------

" Colours for a dark terminal background.
set background=dark

" Add numbers to each line on the left-hand side.
" set number

" Highlight the line under the cursor.
" set cursorline

" Highlight the column under the cursor.
" set cursorcolumn

" ------------------------------------------------------------------------------
"  Search
" ------------------------------------------------------------------------------

" Show matches while typing and highlight them afterwards (:noh clears them).
if has('extra_search')
  set incsearch
  set hlsearch
endif

" ------------------------------------------------------------------------------
"  Indentation
" ------------------------------------------------------------------------------

" Insert spaces when Tab is pressed.
set expandtab

if has('autocmd')
  augroup dotfiles_indent
    autocmd!
    " Two-space indentation for YAML files.
    autocmd FileType yaml setlocal autoindent tabstop=2 shiftwidth=2 expandtab
  augroup END
endif

" ------------------------------------------------------------------------------
"  Abbreviations
" ------------------------------------------------------------------------------

" Type _sh followed by Space or Tab to get the Bash shebang.
abbr _sh #!/bin/bash
