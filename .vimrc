" When started as "evim", evim.vim will already have done these settings, bail
" out.
if v:progname =~? "evim"
  finish
endif

" Get the defaults that most users want.
source $VIMRUNTIME/defaults.vim

if has("vms")
  set nobackup		" do not keep a backup file, use versions instead
else
  set backup		" keep a backup file (restore to previous version)
  if has('persistent_undo')
    set undofile	" keep an undo file (undo changes after closing)
  endif
endif

" Change current directory silently to opened file
":autocmd BufEnter * silent! lcd %:p:h
"set nocompatible
"filetype on
"filetype plugin on
"filetype indent on

" VISUALS
if &t_Co > 2 || has("gui_running")
  set hlsearch
  set incsearch
  set ignorecase
  set smartcase
  set showcmd
  set showmode
  set showmatch
  set wildmenu
  set wildmode=list:longest
  "set colorcolumn=81
  
  syntax on
  "set number
  "set cursorline
  "set statusline=
  "set statusline+=%n:\ %F\ %1*%m%*\ %R
  "set statusline+=%=
  "set statusline+=%{GitBranch()}
  "set statusline+=%5l/%L
  "set laststatus=2
  
  "autocmd VimEnter,VimLeave * silent !tmux set status off
endif


" Put these in an autocmd group, so that we can delete them easily.
augroup vimrcEx
  au!

  " For all text files set 'textwidth' to 80 characters.
  autocmd FileType text setlocal textwidth=80
augroup END

" Open file browser with CTRL + B
inoremap <c-b> <ESC>:30 Lex %:h<cr>
nnoremap <c-b> <ESC>:30 Lex %:h<cr>
" Disable filebrowser banner
let g:netrw_banner=0
let g:netrw_liststyle=3

" Load VIM 8 packages
packloadall

