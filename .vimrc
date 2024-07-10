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
  set backupdir=$HOME/.vim/backup
  if has('persistent_undo')
    set undofile	" keep an undo file (undo changes after closing)
    set undodir=$HOME/.vim/undo
  endif
endif

set directory=$HOME/.vim/swp " set directory for swap files

" Change current directory silently to opened file
" :autocmd BufEnter * silent! lcd %:p:h

set nocompatible
filetype on
filetype plugin on
filetype indent on

" VISUALS
if &t_Co > 2 || has("gui_running")
  set hlsearch
  set incsearch
  set ignorecase
  set smartcase
  set showcmd
  set showmode
  set showmatch
  set scrolloff=10
  
  if exists('$TMUX')
  	set ttymouse=xterm2
  endif
  
  set mouse=a
  set fillchars+=vert:│
  set wildmenu
  set wildmode=list:longest
  "set colorcolumn=81
  " set lsp column color same as background
  set bg=dark
  hi! link SignColumn Normal
  hi Visual cterm=none ctermbg=Blue ctermfg=NONE
  hi VertSplit ctermfg=black ctermbg=white

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
  autocmd BufReadPost *.svelte set syntax=html
augroup END

" Open file browser with CTRL + B
" inoremap <c-b> <ESC>:Lex<cr>:vertical resize 30<cr>
" nnoremap <c-b> <ESC>:Lex<cr>:vertical resize 30<cr>
" Disable filebrowser banner
let g:netrw_banner=0
let g:netrw_liststyle=3

" Open fzf with CTRL + B
nnoremap <c-b> <ESC>:Files<cr>

" Load VIM 8 packages
packloadall

if executable('pylsp')
    " pip install python-lsp-server
    au User lsp_setup call lsp#register_server({
        \ 'name': 'pylsp',
        \ 'cmd': {server_info->['pylsp']},
        \ 'allowlist': ['python'],
        \ })
endif

function! s:on_lsp_buffer_enabled() abort
    setlocal omnifunc=lsp#complete
    setlocal signcolumn=yes
    if exists('+tagfunc') | setlocal tagfunc=lsp#tagfunc | endif
    nmap <buffer> gd <plug>(lsp-definition)
    nmap <buffer> gs <plug>(lsp-document-symbol-search)
    nmap <buffer> gS <plug>(lsp-workspace-symbol-search)
    nmap <buffer> gr <plug>(lsp-references)
    nmap <buffer> gi <plug>(lsp-implementation)
    nmap <buffer> gt <plug>(lsp-type-definition)
    nmap <buffer> <leader>rn <plug>(lsp-rename)
    nmap <buffer> [g <plug>(lsp-previous-diagnostic)
    nmap <buffer> ]g <plug>(lsp-next-diagnostic)
    nmap <buffer> K <plug>(lsp-hover)
    nnoremap <buffer> <expr><c-f> lsp#scroll(+4)
    nnoremap <buffer> <expr><c-d> lsp#scroll(-4)

    let g:lsp_format_sync_timeout = 1000
    autocmd! BufWritePre *.rs,*.go call execute('LspDocumentFormatSync')

    " refer to doc to add more commands
endfunction

augroup lsp_install
    au!
    " call s:on_lsp_buffer_enabled only for languages that has the server registered.
    autocmd User lsp_buffer_enabled call s:on_lsp_buffer_enabled()
augroup END

