set runtimepath+=~/.vim_runtime
source ~/.vim_runtime/vimrcs/basic.vim
source ~/.vim_runtime/vimrcs/filetypes.vim
source ~/.vim_runtime/vimrcs/plugins_config.vim
source ~/.vim_runtime/vimrcs/extended.vim

try
	source ~/.vim_runtime/my_configs.vim
catch
endtry
try
	source ~/co/router/click/etc/click.vim
catch
endtry

call pathogen#infect('~/.local/dotfiles/vim-plugins/{}')
set t_Co=256
set background=dark
colorscheme peaksea
:imap aa <Esc>
set foldcolumn=0

:let operatingsystem=system('uname')
if operatingsystem=~#"^CYGWIN"
    set clipboard=unnamed
else
    set clipboard=unnamedplus
endif
:set mouse=a

set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

let g:autoclose_on = 0

let g:syntastic_always_populate_loc_list = 0
let g:syntastic_auto_loc_list = 2
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0

" Can always check :SyntasticInfo to see what is available/enabled for a particular file.

let g:syntastic_python_checkers = ['pyflakes', 'pylint']
let g:syntastic_python_pylint_exe = 'python3 -m pylint'
let g:syntastic_python_pyflakes_exe = 'python -m pyflakes'

let g:syntastic_cpp_checkers = ['gcc', 'cppcheck']
let g:syntastic_cpp_compiler_options = '-std=c++11 -Wall'

" let g:syntastic_cpp_checkers = ['cppcheck']

" Tab navigation like Firefox.
nnoremap <C-S-tab> :tabprevious<CR>
nnoremap <C-tab>   :tabnext<CR>
inoremap <C-S-tab> <Esc>:tabprevious<CR>i
inoremap <C-tab>   <Esc>:tabnext<CR>i

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

set expandtab!
let $PAGER=''
set colorcolumn=80,100
autocmd FileType gitcommit set colorcolumn=72 "commit messages are different"
autocmd BufWritePre * :%s/\s\+$//e
set wildmode=longest,list,full
set wildmenu
set noerrorbells visualbell t_vb=
if has('autocmd')
      autocmd GUIEnter * set visualbell t_vb=
endif
