set nocompatible "vi互換モードを切る

set fenc=utf-8 "文字コードの設定
set encoding=utf-8
scriptencoding utf-8

set belloff=all "ビープ音OFF
set virtualedit=onemore "行末１文字先までカーソル移動可能

set cursorline "現在の行を強調表示
set showcmd "入力途中のコマンドを下部に表示
set number "行番号を表示
set hlsearch "検索語句をハイライト表示
nnoremap <Esc><Esc> :nohlsearch<CR><Esc>

inoremap qq <ESC>
vnoremap qq <ESC>

nnoremap j gj
nnoremap k gk
nnoremap $ $l
nnoremap <END> <END>l

"set expandtab "タブをスペースに変換して表示
set tabstop=4 "タブの文字幅（スペース幅）
set softtabstop=4 "tabキー押下時に挿入する文字幅
set shiftwidth=4 "自動挿入される文字幅

set ignorecase "検索時に英大小文字の区別を無視
set smartcase  " -> ignorecaseの動作を一部変更：検索時に全て英小文字で入力した場合のみ区別を無視

augroup highlightIdegraphicSpace "全角スペースの可視化
  autocmd!
  autocmd Colorscheme * highlight IdeographicSpace term=underline ctermbg=DarkGreen guibg=DarkGreen
  autocmd VimEnter,WinEnter * match IdeographicSpace /　/
augroup END

syntax enable "シンタックスハイライトの有効化
colorscheme default "カラースキームの設定（全角スペースの可視化の実行に必要）
