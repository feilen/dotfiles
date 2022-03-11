set runtimepath+=~/.vim_runtime
source ~/.vim_runtime/vimrcs/basic.vim
source ~/.vim_runtime/vimrcs/filetypes.vim
source ~/.vim_runtime/vimrcs/plugins_config.vim
source ~/.vim_runtime/vimrcs/extended.vim
try
source ~/.vim_runtime/my_configs.vim
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

let g:syntastic_always_populate_loc_list = 0
let g:syntastic_auto_loc_list = 2
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0

let g:syntastic_python_checkers = ['pyflakes', 'pylint']
let g:syntastic_python_pylint_exe = 'python -m pylint'
let g:syntastic_python_pyflakes_exe = 'python -m pyflakes'

" Tab navigation like Firefox.
nnoremap <C-S-tab> :tabprevious<CR>
nnoremap <C-tab>   :tabnext<CR>
inoremap <C-S-tab> <Esc>:tabprevious<CR>i
inoremap <C-tab>   <Esc>:tabnext<CR>i

if has("gui_running")
    set guifont=Monospace
endif


set expandtab!
let $PAGER=''
