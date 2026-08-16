
filetype plugin indent on
syntax on

set autoindent          " Copy indent from current line when starting new line
set smartindent         " Smart autoindenting for C-like programs (helps with Python too)
set expandtab           " Use spaces instead of tabs
set tabstop=4           " A tab counts as 4 spaces visually
set softtabstop=4       " Tab key inserts 4 spaces
set shiftwidth=4        " >> and << shift by 4 spaces
set noundofile


set number
set relativenumber
set clipboard=
" normal mode
nnoremap d "_d
nnoremap D "_D
nnoremap x "_x
nnoremap c "_c
nnoremap C "_C
nnoremap s "_s
nnoremap S "_S

" visual / visual-line mode
xnoremap d "_d
xnoremap x "_x
xnoremap c "_c
xnoremap <Del> "_d
xnoremap <BS> "_d

" the Delete key in normal mode
nnoremap <Del> "_x
