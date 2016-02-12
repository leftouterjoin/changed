" Changed
"
" Description:
"   Displays signs on changed lines.
" Last Change: 2009-1-17
" Maintainer: Shuhei Kubota <kubota.shuhei+vim@gmail.com>
" Requirements:
"   * +signs (appears in :version)
"   * diff command
"   * setting &termencoding
" Installation:
"   Just source this file. (Put this file into the plugin directory.)
" Usage:
"   [Settings]
"
"   1. Setting &termencoding
"       Set &termencoding option according to your terminal encoding. 
"       Its default value is same as &encoding.
"       example:
"           set termencoding=cp932
"
"   2. Changing signs
"       To change signs, re-define signs after sourcing this script.
"       example (changing text):
"           sign define SIGN_CHANGED_DELETED_VIM text=D texthl=ChangedDefaultHl
"           sign define SIGN_CHANGED_ADDED_VIM   text=A texthl=ChangedDefaultHl
"           sign define SIGN_CHANGED_VIM         text=M texthl=ChangedDefaultHl
"       example (changin highlight @gvimrc):
"           highlight ChangedDefaultHl cterm=bold ctermbg=red ctermfg=white gui=bold guibg=red guifg=white
"
"   [Usual]
"
"   Edit a buffer and wait seconds or execute :Changed.
"   Then signs appear on changed lines.
"

command!  Changed       :call <SID>Changed_execute()
command!  ChangedClear  :call <SID>Changed_clear()

au! BufWritePost * Changed
"au! CursorHold   * Changed
"au! CursorHoldI  * call <SID>Changed_execute()
" heavy
au! InsertLeave * call <SID>Changed_execute()
" too heavy
"au! CursorMoved * call <SID>Changed_execute()
au! TextChanged * call <SID>Changed_execute()

if !exists('g:Changed_definedSigns')
    let g:Changed_definedSigns = 1
"    highlight ChangedDefaultHl cterm=bold ctermbg=yellow ctermfg=black gui=bold guibg=yellow guifg=black
    highlight ChangedDefaultHl cterm=bold ctermbg=green ctermfg=black gui=bold guibg=green guifg=black
    sign define SIGN_CHANGED_DELETED_VIM text=- texthl=ChangedDefaultHl
    sign define SIGN_CHANGED_ADDED_VIM 	 text=+ texthl=ChangedDefaultHl
    sign define SIGN_CHANGED_VIM 		 text=* texthl=ChangedDefaultHl
    sign define SIGN_CHANGED_NONE
endif

function! s:Changed_clear()
    sign unplace *
    if 0 < line('$')
        execute 'sign place 1 line=1 name=SIGN_CHANGED_NONE buffer=' . bufnr('%')
    endif
    if exists('b:signId') | unlet b:signId | endif
endfunction

function! s:GetPlacedSignsDic(buffer)
    let placedstr = ''
    redir => placedstr
        silent execute "sign place buffer=".a:buffer
    redir END
    let dic ={}
    let signPlaceLines = split(placedstr, '\n')
    for line in signPlaceLines
        let lineNum = matchstr(line, '\v\D{1,}\zs\d{1,}\ze\D.*')
        if ! empty(lineNum)
            let id = matchstr(line, '\v\D{1,}\d{1,}\D{1,}\zs\d{1,}\ze\D.*')
            let name = matchstr(line, '\v\D{1,}\d{1,}\D{1,}\d{1,} [^\=]{1,}\=\zs.{1,}\ze')
            if ! has_key(dic, lineNum)
                let dic[lineNum] = {}
            endif
            let dic[lineNum][id] = name
        endif
    endfor
    return dic
endfunction

function! s:Changed_execute()
    if exists('b:Changed__tick') && b:Changed__tick == b:changedtick | return | endif

    if ! &modified
        call s:Changed_clear()
        return
    endif

    " get paths
    let originalPath = substitute(expand('%:p'), '\', '/', 'g')
    let changedPath = substitute(tempname(), '\', '/', 'g')
    "echom 'originalPath' . originalPath
    "echom 'changedPath' . changedPath

    " both files are not saved -> don't diff
    if ! filereadable(originalPath) | return | endif

    " change encodings of paths (enc -> tenc)
    if exists('&tenc')
        let tenc = &tenc
    else
        let tenc = ''
    endif
    if strlen(tenc) == 0 | let tenc = &enc | endif

    " get diff text
    silent execute 'write! ' . escape(changedPath, ' ')
    "echom 'diff -u "' . originalPath . '" "' . changedPath . '"'
    let diffText = system(iconv('diff -u "' . originalPath . '" "' . changedPath . '"', &enc, tenc))
    let diffLines = split(diffText, '\n')

    " clear all temp files
    call system(iconv('rm "' . changedPath . '"', &enc, tenc))
    call system(iconv('del "' . substitute(changedPath, '/', '\', 'g') . '"', &enc, tenc))

    " list lines and their signs
    let pos = 1 " changed line number
    let changedLineNums = {} " collection of pos
    let minusLevel = 0
    for line in diffLines
        "echom 'line: ' . line
        if line[0] == '@'
            " reset pos
            let regexp = '@@\s*-\d\+\(,\d\+\)\?\s\++\(\d\+\),\d\+\s\+@@'
            let pos = eval(substitute(line, regexp, '\2', ''))
            let minusLevel = 0
        elseif line[0] == '-' && line !~ '^---'
            let changedLineNums[pos] = 'SIGN_CHANGED_DELETED_VIM'
            let minusLevel += 1
        elseif line[0] == '+' && line !~ '^+++'
            if minusLevel > 0
                let changedLineNums[pos] = 'SIGN_CHANGED_VIM'
            else
                let changedLineNums[pos] = 'SIGN_CHANGED_ADDED_VIM'
            endif
            let pos += 1
            let minusLevel -= 1
        else
            let pos += 1
            let minusLevel = 0
        endif
    endfor
    "echom 'changedLineNums: ' . join(changedLineNums, ', ')

    let curSignedLines = s:GetPlacedSignsDic(bufnr('%'))

    " place signs
    let lastLineNum = line('$')
    for i in range(1, lastLineNum)
        if has_key(changedLineNums, i)
            let newName = changedLineNums[i]
            let isSigned = 0
            if has_key(curSignedLines, i)
                let oldSignsDic = curSignedLines[i]
                let oldIdList = keys(oldSignsDic)
                for j in oldIdList
                    if oldSignsDic[j] == newName
                         unlet isSigned | let isSigned = 1
                    else
                         execute 'sign unplace ' . j . ' buffer=' . bufnr('%')
                    endif
                endfor
            endif
            if ! isSigned
                let b:signId = exists('b:signId') ? b:signId+1 : 1
                execute 'sign place ' . b:signId . ' line=' . i . ' name=' . newName . ' buffer=' . bufnr('%')
            endif
        else
            if has_key(curSignedLines, i)
                let oldSignsDic = curSignedLines[i]
                let oldIdList = keys(oldSignsDic)
                for j in oldIdList
                    execute 'sign unplace ' . j . ' buffer=' . bufnr('%')
                endfor
            endif
        endif
    endfor

    let b:Changed__tick = b:changedtick
    "echom 'bufnr: ' . bufnr('%')
    "echom 'changedtick: ' . b:changedtick
endfunction

