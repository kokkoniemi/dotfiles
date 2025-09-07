" When started as "evim", evim.vim will already have done these settings, bail
" out.
if v:progname =~? "evim"
  finish
endif

" Set leader key to space
let mapleader = " "

" Use 16-color palette
set t_Co=16

" Use ruler
set ruler

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
  set listchars=eol:¬,tab:>·,trail:~,extends:>,precedes:<,space:␣
  set wildmenu
  set wildmode=longest:list,full
  "set colorcolumn=81
  " set lsp column color same as background
  set bg=dark
  hi! link SignColumn Normal
  hi! Visual cterm=none ctermbg=blue ctermfg=black
  hi! VertSplit ctermfg=white ctermbg=NONE cterm=NONE 
  hi! StatusLine ctermfg=black ctermbg=white cterm=NONE
  hi! StatusLineNC ctermfg=darkgray ctermbg=white cterm=NONE

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

" Open fzf file opener with LEADER + F
nnoremap <Leader>f <ESC>:Files<cr>

" Open fzf buffer opener with LEADER + B
nnoremap <Leader>b <ESC>:Buffer<cr>

" Do not show file names in Ag or Rg
command! -bang -nargs=* Ag call fzf#vim#ag(<q-args>, {'options': '--delimiter : --nth 4..'}, <bang>0)
command! -bang -nargs=* Rg
  \ call fzf#vim#grep("rg --column --line-number --no-heading --color=always --smart-case ".shellescape(<q-args>), 1,
  \   fzf#vim#with_preview({'options': '--delimiter : --nth 4..'}), <bang>0)

" Open Rg with LEADER + G
nnoremap <Leader>g <ESC>:Rg<cr>

augroup FernInit
	autocmd!
	autocmd FileType fern nmap <buffer><expr> <2-LeftMouse>
	\ fern#smart#leaf(
	\  "<Plug>(fern-action-open:edit)",
	\  "<Plug>(fern-action-expand)",
	\  "<Plug>(fern-action-collapse)"
	\ )
	" Open fern with LEADER + J
	nnoremap <Leader>j :Fern . -drawer -toggle -stay -reveal=%<cr>
	let g:fern#hide_cursorline=1
	let g:fern#default_hidden=1
	let g:fern#renderer = "devicons"
	"let g:fern#renderer#default#leading = "│"
	"let g:fern#renderer#default#root_symbol = "┬─ "
	"let g:fern#renderer#default#leaf_symbol = "├─ "
	"let g:fern#renderer#default#collapsed_symbol = "├─ "
	"let g:fern#renderer#default#expanded_symbol = "├┬ "
	autocmd FileType fern setlocal fillchars=eob:\ 
	hi FernRootSymbol ctermfg=gray
	hi FernLeafSymbol ctermfg=gray
	hi FernBranchSymbol ctermfg=gray
	hi FernLeaderSymbol ctermfg=gray
augroup END


" Load VIM packages
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
   " nnoremap <buffer> <expr><c-f> lsp#scroll(+4)
   " nnoremap <buffer> <expr><c-d> lsp#scroll(-4)

    let g:lsp_format_sync_timeout = 1000
    autocmd! BufWritePre *.rs,*.go call execute('LspDocumentFormatSync')

    " refer to doc to add more commands
endfunction

augroup lsp_install
    au!
    " call s:on_lsp_buffer_enabled only for languages that has the server registered.
    autocmd User lsp_buffer_enabled call s:on_lsp_buffer_enabled()
augroup END

