set runtimepath+=~/.vim_runtime

" YouCompleteMe, ALE needs vim 8+
if v:version < 801
    let g:pathogen_blacklist = ['YouCompleteMe', 'ale']
else
    let g:pathogen_blacklist = ['syntastic', 'YouCompleteMe-legacy']
endif
call add(g:pathogen_blacklist, 'vim-snipmate')
call add(g:pathogen_blacklist, 'vim-multiple_cursor')
call add(g:pathogen_blacklist, 'lightline.vim')
call add(g:pathogen_blacklist, 'lightline-ale')
call pathogen#infect('~/.local/dotfiles/vim-plugins/{}')

source ~/.vim_runtime/vimrcs/basic.vim
source ~/.vim_runtime/vimrcs/filetypes.vim
source ~/.vim_runtime/vimrcs/plugins_config.vim

" Avoid breaking airline
let g:lightline.enable = {
    \ 'statusline': 0,
    \ 'tabline': 0
    \ }
try
	source ~/.vim_runtime/my_configs.vim
catch
endtry

set t_Co=256
set background=dark
colorscheme peaksea
:imap aa <Esc>
set foldcolumn=0
set splitbelow
set splitright

try
    set undodir=~/.vim_runtime/temp_dirs/undodir
    set undofile
catch
endtry

:let operatingsystem=system('uname')
if operatingsystem=~#"^CYGWIN"
    set clipboard=unnamed
else
    set clipboard=unnamedplus
endif

let g:autoclose_on = 0

if v:version < 801
    let g:syntastic_always_populate_loc_list = 1
    let g:syntastic_auto_loc_list = 2
    let g:syntastic_check_on_open = 1
    let g:syntastic_check_on_wq = 0

    " Can always check :SyntasticInfo to see what is available/enabled for a particular file.
    let g:syntastic_python_checkers = ['pyflakes', 'pylint', 'flake8']
    let g:syntastic_python_pylint_exe = 'python3 -m pylint'
    let g:syntastic_python_pyflakes_exe = 'python -m pyflakes'
    let g:syntastic_cpp_checkers = ['gcc', 'cppcheck']
    let g:syntastic_cpp_compiler_options = '-std=c++11 -Wall'
else
    " Can always check :ALEInfo to see what is available/enabled for a particular file.
    let g:ale_linters = {
    \    'python': ['pyflakes', 'pylint', 'flake8'],
    \    'cpp': ['gcc', 'cppcheck']
    \}
    let g:ale_fixers = {
    \    '*': ['remove_trailing_lines', 'trim_whitespace'],
    \    'python': ['isort']
    \}
    let g:ale_python_pylint_executable = 'python3 -m pylint'
    let g:ale_python_pyflakes_executable = 'python3 -m pyflakes'
    let g:ale_cpp_cc_options = '-std=c++11 -Wall'
    let g:ale_python_flake8_options = '--ignore=E501,E265,E226,E302'
endif

" Show git differences
let g:gitgutter_enabled = '1'
try
	source ~/co-router-syntastic.vim
	source ~/co/router/click/etc/click.vim
catch
endtry

" Force the use of hjkl until I'm actually used to it.
autocmd VimEnter,BufNewFile,BufReadPost * silent! call HardMode()
set nowrap

" let g:HardMode_level = 'wannabe'
" :set mouse=a

if has("gui_running")
    set guifont=Monospace
endif

" WSL yank support - sadly no paste
let s:clip = '/mnt/c/Windows/System32/clip.exe'  " change this path according to your mount point
if executable(s:clip)
    augroup WSLYank
        autocmd!
        autocmd TextYankPost * if v:event.operator ==# 'y' | call system(s:clip, @0) | endif
    augroup END
endif

" Use ripgrep if available
if executable('rg')
    set grepprg=rg\ --vimgrep\ --no-heading\ --smart-case
    set grepformat=%f:%l:%c:%m,%f:%l:%m
    command! -nargs=+ Rgrep execute 'silent grep! "<args>"' | cw | redraw! | 'silent call InitializeQuickrPreview()'
    " CtrlP works nicely but loses previews. Disable for now. Possibly toggle?
    " command! -nargs=+ Rgrep execute 'silent grep! "<args>"' | CtrlPQuickfix | redraw!
    map <C-g> :Rgrep<Space>
else
    map <C-g> :Ggrep! --quiet<Space>
endif

" Column length stuff
set expandtab!
let $PAGER=''
let &colorcolumn=join(range(81,999),",")
autocmd FileType gitcommit let b:tw=72
autocmd FileType gitcommit let &colorcolumn=join(range(73,999),",") " commit messages are different
autocmd FileType python let &colorcolumn=join(range(101,999),",") " default syntastic
" Signcolumn color
highlight ColorColumn ctermbg=235
highlight SignColumn ctermbg=235
highlight! link GitGutterAdd SignColumn
highlight! link GitGutterChange SignColumn
highlight! link GitGutterDelete SignColumn
" pop-up menu
highlight Pmenu ctermbg=236
try
	set signcolumn=yes
catch
	autocmd BufEnter * sign define dummy
	autocmd BufEnter * execute 'sign place 9999 line=1 name=dummy buffer=' . bufnr('')
endtry
let g:airline_theme='peaksea'
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#hunks#enabled=0
let g:ctrlp_user_command = {
	\ 'types': {
                \ 1: ['yocto', 'cd %s && git ls-files -co --exclude-standard|grep -v "^build\|^linux\|^yocto/build\|^testbed\|^wlan\|^wired\|^vivotek"'],
		\ 2: ['.git', 'cd %s && git ls-files'],
		\ 3: ['.hg', 'hg --cwd %s locate -I .'],
		\ },
	\ 'fallback': 'find %s -type f'
	\ }
set tabstop=8 softtabstop=0 expandtab shiftwidth=4 smarttab

autocmd BufWritePre * :%s/\s\+$//e
set wildmode=longest,list,full
set wildmenu
set noerrorbells visualbell t_vb=
if has('autocmd')
      autocmd GUIEnter * set visualbell t_vb=
endif

" autocmd WinEnter * vertical resize 82
" autocmd FileType qf nnoremap <buffer> <CR> *@:silent call HandleEnterQuickfix(line("."))

" map <C-r> :CtrlPMRU<CR>
noremap <C-f> :CtrlPMixed<CR>
map <C-b> :CtrlPBuffer<CR>
map <C-t> :CtrlPTag<CR>
" execute pre-commit hook: I generally set this up to run unit tests
" generally add something like this to .git/hooks/pre-commit:
"
" OUTPUT="$(./run-tests 2>&1)"
" if [ $? -ne 0 ]; then
"     if [ -z "$VIM" ]; then
"         echo "$OUTPUT"
"     else
"         echo "$OUTPUT" | sed '/^|/!d;s/^|//g;/: error: /!d;s/\.\.\///'
"     fi
"     exit 1
" fi
map <C-x> :cgetexpr system("LANG=en_US.UTF-8 ./.git/hooks/pre-commit")<CR>:cw<CR>

let g:quickr_preview_keymaps = 0
let g:quickr_preview_on_cursor = 1
let g:quickr_preview_exit_on_enter = 1
let g:gitgutter_map_keys = 0

function! PaneNavTmuxTry(d)
	let wid = win_getid()
	if a:d == 'D'
		wincmd j
	elseif a:d == 'U'
		wincmd k
	elseif a:d == 'L'
		wincmd h
	elseif a:d == 'R'
		wincmd l
	endif
	if win_getid() == wid
		call system('tmux select-pane -' . a:d)
	endif
endfunction
nnoremap <silent> <C-k> :call PaneNavTmuxTry('U')<CR>
nnoremap <silent> <C-j> :call PaneNavTmuxTry('D')<CR>
nnoremap <silent> <C-h> :call PaneNavTmuxTry('L')<CR>
nnoremap <silent> <C-l> :call PaneNavTmuxTry('R')<CR>
inoremap <silent> <C-k> <Esc>:call PaneNavTmuxTry('U')<CR>
inoremap <silent> <C-j> <Esc>:call PaneNavTmuxTry('D')<CR>
inoremap <silent> <C-h> <Esc>:call PaneNavTmuxTry('L')<CR>
inoremap <silent> <C-l> <Esc>:call PaneNavTmuxTry('R')<CR>
" Stuff to remember!
" :ALEInfo        diagnostic info about why syntax checks might not be working
" Ctrl+F               to rapid search using the 'ctrlp' fuzzy file/tag searcher
" ,f                                              same, but through recent files
" ,b                                            same, but through recent buffers
" gp                                                      open file under cursor
" ,pp                                                           toggle pastemode
" ,o (simultaneously)                           look through all current buffers
" gc, gcc                               comment/uncomment the target of a motion
" gv                                                  reselect last visual block
" >, <                                                    indent, unindent block
" ci(                                             change text inside parenthesis
" o                                                          open new line below
" :Git      call git from within vim. Wraps most git functions to do nice things
" :Ggrep                                                           fast git grep
" :Gbrowse          from visual mode opens the lines on the source browser (web)
" ,te                                open current file's directory in new buffer
" ,cd                                  set $CWD to current buffer, for !commands
" ,pp                                                          toggle paste mode
" <visual> */#                     search forward/backward for current selection
" <visual> ,r                               search/replace current selected text
" ,nn                                                    open 'nerd tree' plugin
" :Bookmark                                   bookmark current file in nerd tree
" ,z                                              'zen mode', hide distractions?
" ,v                    copy a link to the line of a git repository to clipboard
" F5              execute current file. needs ~/.vim_runtime/vimrcs/extended.vim
" ,cc                                      open a new window with current errors
" ,bd                                                       close current buffer
" ,ba                                                          close all buffers
" ^w v/s                                      split pane horizontally/vertically
" ^w hjkl                                                         navigate panes
" ^O                                             go back to last cursor position
" gd                               go to definition of local symbol under cursor
" { }                                                previous or next blank line
" [ ]                                           jump forward/back blocks of code
" cnext, cprev                                   jump between results from Ggrep
" J                                                    join next line to current
" C-v and C-x  when using CtrlP                           open selected in split
"                       maybe add QFEnter and some binds to make it do the same?
" ,b                                   ctrlpbuffer... bit nicer than bufexplorer
