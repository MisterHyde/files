""""""""""""""""""""""""""
" Basic vim configuration
""""""""""""""""""""""""""
"set encoding=utf-8
"set fileencoding=ascii
set hidden

set diffopt=filler,context:2,iwhite

"MISC
set listchars=tab:•\ ,trail:•,extends:»,precedes:«
let g:screen_size_restore_pos=1
let g:screen_size_by_vim_instance=1
set modelines=0
set tabstop=4
set softtabstop=4
set shiftwidth=4
set expandtab
set autoindent
set relativenumber
set numberwidth=2
set splitbelow
set splitright
set undofile
set undodir=~/.vim/tmp/
set backupdir=~/.vim/tmp/
set directory=~/.vim/tmp/
set history=100
set undolevels=1000
set undoreload=10000
set ignorecase
set smartcase
" set wrap
set tw=160
set cursorline
hi cursorline cterm=none
hi cursorlinenr ctermfg=black

"TAGS
set tags=tags

" Close help window just with q
"autocmd FileType help noremap <buffer> q :q<cr>

"""""""""""""""""""""""""""
" configure vbundle
"""""""""""""""""""""""""""
set nocompatible
filetype off
call plug#begin()

" Nice tool for private wiki
Plug 'vimwiki/vimwiki'

" Install and use the following Plugs:
Plug 'scrooloose/nerdcommenter'
" Show a diff using Vim its sign column.
Plug 'mhinz/vim-signify'
Plug 'jezcope/vim-align'
Plug 'scrooloose/nerdtree'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'powerline/fonts'
Plug 'majutsushi/tagbar'
" Visualization and handling of vim undo history
Plug 'mbbill/undotree'
" Syntax completion; needs external programms see homepage
"Plug 'Valloric/YouCompleteMe'
"Plug 'rdnetto/YCM-Generator'
" Using snippets
" Plug 'sirver/ultisnips'
" Snippets for ultisnips
" Plug 'honza/vim-snippets.git'
" Another snippets tool
"Plug 'garbas/vim-snipmate'

" Syntax checking plugin
"Plug 'scrooloose/syntastic.git'
Plug 'w0rp/ale'
" Git in vim 
Plug 'tpope/vim-fugitive'
" Branche control
Plug 'idanarye/vim-merginal' 
" Completion script
Plug 'Shougo/neocomplete.vim'
" Controle your tabs
Plug 'vim-ctrlspace/vim-ctrlspace'
" Surrond stuff with things
Plug 'tpope/vim-surround'
" Lets you use . to repeat some things like vim-surround
Plug 'tpope/vim-repeat'
" Vim Markdown runtime files
Plug 'tpope/vim-markdown'
" Syntax for nginx
Plug 'mutewinter/nginx.vim'
" Colors
Plug 'morhetz/gruvbox'
" Use virtualenvs in the embeded python interpreter
Plug 'jmcantrell/vim-virtualenv'
" Tag files handling
Plug 'ludovicchabant/vim-gutentags'
" Vim latex suit
Plug 'lervag/vimtex'
" Fuzzy finder
Plug 'junegunn/fzf.vim'
" Ascii plantuml
Plug 'scrooloose/vim-slumlord'
Plug 'aklt/plantuml-syntax'
" Call tree
Plug 'hari-rangarajan/CCTree'
Plug 'chrisbra/csv.vim'

call plug#end()

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Basic vim configuration that has to be done after vundle configuration
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
filetype on                         " Filetype-Erkennung aktivieren
filetype indent on                  " Syntax-Einrückungen je nach Filetype
filetype plugin on                  " Filetype-Plugins erlauben
syntax enable

"STYLE
let base16colorspace=256
colorscheme gruvbox
set background=dark

"""""""""""""""""""""""""
" Airlineconfiguration
"""""""""""""""""""""""""
let g:airline_powerline_fonts=1
let g:airline#extensions#tabline#enabled = 1
if !exists('g:airline_symbols')
	let g:airline_symbols = {}
endif
let g:airline_symbols.space = "\ua0"

let g:airline_theme="murmur"
"let g:airline_theme="gruvbox"

"AUTOCOMPLETION
"autocmd FileType c set omnifunc=ccomplete#Complete
"set cpt-=i
"let g:SuperTabDefaultCompletionType="context"
"Snippets
"let g:commentChar={'vim': '"', 'c': '//', 'cpp': '//', 'h': '//'}
"let g:snipMate={}
""let g:snipMate.scope_aliases={}
"let g:snipMate.snippet_version=1

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" YouCompleteMe
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"let g:ycm_clangd_binary_path = "/usr/bin/clangd"

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Configure ale
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let g:ale_lint_on_text_changed = 'never'
let g:ale_lint_on_insert_leave = 0
" You can disable this option too
" " if you don't want linters to run on opening a file
let g:ale_lint_on_enter = 0
let g:ale_set_loclist = 1
let g:ale_set_quickfix = 0
let b:ale_linters = ['clang', 'clangtidy', 'gcc']
let b:ale_fixers = ['clangtidy', 'remove_trailing_lines', 'trim_whitespace']
let g:ale_c_parse_compile_commands = 1
let g:ale_c_build_dir = './project'
let g:ale_c_gcc_options = '-mmcu=atmega328p'

" Use ALE and also some plugin 'foobar' as completion sources for all code.
"call deoplete#custom#option('sources', {
"\ '_': ['ale', 'foobar'],
"\})

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Configure vimspector
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"let g:vimspector_enable_mappings = 'HUMAN'

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Configure gutentags
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Just parse c++ files otherwise ctags generates a malformed tag file for the iu_app project...
let g:gutentags_ctags_extra_args = ['-R','--c++-kinds=+p --fields=+iaS --extra=+q']
let g:gutentags_moduels = ['ctags', 'gtags_cscope']
let g:gutentags_cache_dir = expand('~/.cache/tags')
let g:gutentags_plus_switch = 1

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" tmux stuff
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
if has('mouse')
	set mouse=a
	if &term =~ "xterm" || &term =~ "screen"
		" for some reason, doing this directly with 'set ttymouse=xterm2'
		" doesn't work -- 'set ttymouse?' returns xterm2 but the mouse
		" makes tmux enter copy mode instead of selecting or scrolling
		" inside Vim -- but luckily, setting it up from within autocmds
		" works
		autocmd VimEnter * set ttymouse=xterm2
		autocmd FocusGained * set ttymouse=xterm2
		autocmd BufEnter * set ttymouse=xterm2
	endif
endif

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Copy paste system clipboard
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
map <leader>y "*y
map <leader>p "*p
map <leader>P "*P

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Quit help easily
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! QuitWithQ()
	if &buftype == 'help'
		nnoremap <buffer> <silent> q :q<cr>
	endif
endfunction
autocmd FileType help exe QuitWithQ()

"NERDTREE
let NERDTreeMinimalUI=0
let NERDTreeDirArrows=1

"SEARCH REPLACEMENT EASYMOTION
map  / <Plug>(easymotion-sn)
omap / <Plug>(easymotion-tn)
" These `n` & `N` mappings are options. You do not have to map `n` & `N` to EasyMotion.
" Without these mappings, `n` & `N` works fine. (These mappings just provide
" different highlight method and have some other features )
map  n <Plug>(easymotion-next)
map  N <Plug>(easymotion-prev)
set hlsearch
let hlstate=1

"RESIZE SPLITS
set winheight=5
set winwidth=10
set winminheight=5
set winminwidth=10
nnoremap <silent> <S-K> :res+5<CR>
nnoremap <silent> <S-J> :res-5<CR>
nnoremap <silent> <S-H> :vertical res-10<CR>
nnoremap <silent> <S-L> :vertical res+10<CR>

"NAVIGATE BETWEEN SPLITS
nnoremap <C-J> :wincmd j<CR>
nnoremap <C-K> :wincmd k<CR>
nnoremap <C-L> :wincmd l<CR>
nnoremap <C-H> :wincmd h<CR>

" Jump tags back with backspace
nmap <backspace> <C-t>

inoremap jj <ESC>
inoremap jk <ESC>

" Make backspace delete again
set backspace=indent,eol,start

" Changing the syntax of vimwiki to markdown
"let g:vimwiki_list = [{'path': '~/felix/vimwiki/', 'syntax': 'markdown', 'ext': '.md'}]

" Use latex instead of plain tex
let g:tex_flavor = 'latex'

nnoremap <C-P> :Files<CR>

let mapleader = ","

let g:signify_disable_by_default = 1

nnoremap <Leader>oc :e %<.c<CR>
nnoremap <Leader>oh :e %<.h<CR>

map <silent><F1> :UndotreeToggle<CR>
noremap <silent><F2> :SignifyToggle<CR>
nnoremap <F3> :set hlsearch!<CR>
set pastetoggle=<F5>
noremap <silent><F6> :MerginalToggle<CR>
map <silent><F7> :NERDTreeToggle<CR>
nmap <silent><F8> :TagbarToggle<CR>
nnoremap <F9> :set mouse=r<CR>
nnoremap <F10> :set mouse=a<CR>
nnoremap ? :Ag <C-R><C-W>
