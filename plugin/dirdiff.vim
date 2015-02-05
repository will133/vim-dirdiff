" -*- vim -*-
" FILE: "/home/wlee/.vim/plugin/DirDiff.vim" {{{
" LAST MODIFICATION: "Wed, 11 Apr 2012 15:49:03 -0500 (wlee)"
" HEADER MAINTAINED BY: N/A
" VERSION: 1.1.5
" (C) 2001-2015 by William Lee, <wl1012@yahoo.com>
" }}}

" Public Interface:
command! -nargs=* -complete=dir DirDiff call <SID>DirDiff (<f-args>)
command! -nargs=0 DirDiffOpen call <SID>DirDiffOpen ()
command! -nargs=0 DirDiffNext call <SID>DirDiffNext ()
command! -nargs=0 DirDiffPrev call <SID>DirDiffPrev ()
command! -nargs=0 DirDiffUpdate call <SID>DirDiffUpdate ()
command! -nargs=0 DirDiffQuit call <SID>DirDiffQuit ()

" The following comamnds can be used in the Vim diff mode:
" 
" \dg - Diff get: maps to :diffget<CR>
" \dp - Diff put: maps to :diffput<CR>
" \dj - Diff next: (think j for down) 
" \dk - Diff previous: (think k for up)

if !exists("g:DirDiffEnableMappings")
    let g:DirDiffEnableMappings = 0
endif

if g:DirDiffEnableMappings
    nnoremap <unique> <Leader>dg :diffget<CR>
    nnoremap <unique> <Leader>dp :diffput<CR>
    nnoremap <unique> <Leader>dj :DirDiffNext<CR>
    nnoremap <unique> <Leader>dk :DirDiffPrev<CR>
endif

" Global Maps:

" Default Variables.  You can override these in your global variables
" settings.
"
" For DirDiffExcludes and DirDiffIgnore, separate different patterns with a
" ',' (comma and no space!).
"
" eg. in your .vimrc file: let g:DirDiffExcludes = "CVS,*.class,*.o"
"                          let g:DirDiffIgnore = "Id:"
"                          " ignore white space in diff
"                          let g:DirDiffAddArgs = "-w" 
"
" You can set the pattern that diff excludes.  Defaults to the CVS directory
if !exists("g:DirDiffExcludes")
    let g:DirDiffExcludes = ""
endif
" This is the -I argument of the diff, ignore the lines of differences that
" matches the pattern
if !exists("g:DirDiffIgnore")
    let g:DirDiffIgnore = ""
endif
if !exists("g:DirDiffSort")
    let g:DirDiffSort = 1
endif
if !exists("g:DirDiffWindowSize")
    let g:DirDiffWindowSize = 14
endif
if !exists("g:DirDiffInteractive")
    let g:DirDiffInteractive = 0
endif
if !exists("g:DirDiffIgnoreCase")
    let g:DirDiffIgnoreCase = 0
endif
" Additional arguments
if !exists("g:DirDiffAddArgs")
    let g:DirDiffAddArgs = ""
endif
" Support for i18n (dynamically figure out the diff text)
" Defaults to off
if !exists("g:DirDiffDynamicDiffText")
    let g:DirDiffDynamicDiffText = 0
endif

" String used for the English equivalent "Files "
if !exists("g:DirDiffTextFiles")
    let g:DirDiffTextFiles = "Files "
endif

" String used for the English equivalent " and "
if !exists("g:DirDiffTextAnd")
    let g:DirDiffTextAnd = " and "
endif

" String used for the English equivalent " differ")
if !exists("g:DirDiffTextDiffer")
    let g:DirDiffTextDiffer = " differ"
endif

" String used for the English equivalent "Only in ")
if !exists("g:DirDiffTextOnlyIn")
    let g:DirDiffTextOnlyIn = "Only in "
endif

" String used for the English equivalent ": ")
if !exists("g:DirDiffTextOnlyInCenter")
    let g:DirDiffTextOnlyInCenter = ": "
endif

" Set some script specific variables:
"
let s:DirDiffFirstDiffLine = 6
let s:DirDiffALine = 1
let s:DirDiffBLine = 2

" -- Variables used in various utilities
if has("unix")
    let s:DirDiffCopyCmd = "cp"
    let s:DirDiffCopyFlags = ""
    let s:DirDiffCopyDirCmd = "cp"
    let s:DirDiffCopyDirFlags = "-rf"
    let s:DirDiffCopyInteractiveFlag = "-i"

    let s:DirDiffDeleteCmd = "rm"
    let s:DirDiffDeleteFlags = ""
    let s:DirDiffDeleteInteractiveFlag = "-i"

    let s:DirDiffDeleteDirCmd = "rm"
    let s:DirDiffDeleteDirFlags = "-rf"

    let s:sep = "/"

    let s:DirDiffMakeDirCmd  = "!mkdir "

elseif has("win32")
    let s:DirDiffCopyCmd = "copy"
    let s:DirDiffCopyFlags = ""
    let s:DirDiffCopyDirCmd = "xcopy"
    let s:DirDiffCopyDirFlags = "/e /i /q"
    let s:DirDiffCopyInteractiveFlag = "/-y"

    let s:DirDiffDeleteCmd = "del"
    let s:DirDiffDeleteFlags = "/s /q"
    let s:DirDiffDeleteInteractiveFlag = "/p"
    " Windows is somewhat stupid since "del" can only remove the files, not
    " the directory.  The command "rd" would remove files recursively, but it
    " doesn't really work on a file (!).  where is the deltree command???
     
    let s:DirDiffDeleteDirCmd = "rd"
    " rd is by default prompting, we need to handle this in a different way
    let s:DirDiffDeleteDirFlags = "/s"
    let s:DirDiffDeleteDirQuietFlag = "/q"

    let s:sep = "\\"

    let s:DirDiffMakeDirCmd  = "!mkdir "
else
    " Platforms not supported
    let s:DirDiffCopyCmd = ""
    let s:DirDiffCopyFlags = ""
    let s:DirDiffDeleteCmd = ""
    let s:DirDiffDeleteFlags = ""
    let s:sep = ""
endif


function! <SID>DirDiff(srcA, srcB)
    " Setup
    let DirDiffAbsSrcA = fnamemodify(expand(a:srcA, ":p"), ":p")
    let DirDiffAbsSrcB = fnamemodify(expand(a:srcB, ":p"), ":p")

    " Check for an internationalized version of diff ?
    call <SID>GetDiffStrings()

    " Remove the trailing \ or /
    let DirDiffAbsSrcA = substitute(DirDiffAbsSrcA, '\\$\|/$', '', '')
    let DirDiffAbsSrcB = substitute(DirDiffAbsSrcB, '\\$\|/$', '', '')

    let DiffBuffer = tempname()
    " We first write to that file
    " Constructs the command line
    let cmd = "!diff"
    let cmdarg = " -r --brief"

    " If variable is set, we ignore the case
    if (g:DirDiffIgnoreCase)
        let cmdarg = cmdarg." -i"
    endif
    if (g:DirDiffAddArgs != "")
        let cmdarg = cmdarg." ".g:DirDiffAddArgs." "
    endif
    if (g:DirDiffExcludes != "")
        let cmdarg = cmdarg.' -x"'.substitute(g:DirDiffExcludes, ',', '" -x"', 'g').'"'
    endif
    if (g:DirDiffIgnore != "")
        let cmdarg = cmdarg.' -I"'.substitute(g:DirDiffIgnore, ',', '" -I"', 'g').'"'
    endif
    " Prompt the user for additional arguments
"    let addarg = input("Additional diff args (current =". cmdarg. "): ")
    let addarg = ""
    let cmd = cmd.cmdarg." ".addarg." \"".DirDiffAbsSrcA."\" \"".DirDiffAbsSrcB."\""
    let cmd = cmd." > \"".DiffBuffer."\""

    echo "Diffing directories, it may take a while..."
    let error = <SID>DirDiffExec(cmd, 0)
    if (error == 0)
        redraw | echom "diff found no differences - directories match."
        return
    endif
    silent exe "edit ".DiffBuffer
    echo "Defining [A] and [B] ... "
    " We then do a substitution on the directory path
    " We need to do substitution of the the LONGER string first, otherwise
    " it'll mix up the A and B directory
    if (strlen(DirDiffAbsSrcA) > strlen(DirDiffAbsSrcB))
	    silent! exe "%s/".<SID>EscapeDirForRegex(DirDiffAbsSrcA)."/[A]/"
	    silent! exe "%s/".<SID>EscapeDirForRegex(DirDiffAbsSrcB)."/[B]/"
    else
	    silent! exe "%s/".<SID>EscapeDirForRegex(DirDiffAbsSrcB)."/[B]/"
	    silent! exe "%s/".<SID>EscapeDirForRegex(DirDiffAbsSrcA)."/[A]/"
    endif
    " In windows, diff behaves somewhat weirdly, for the appened path it'll
    " use "/" instead of "\".  Convert this to \
    if (has("win32"))
        silent! %s/\//\\/g
    endif

    echo "Sorting entries ..."
    " We then sort the lines if the option is set
    if (g:DirDiffSort == 1)
        1,$call <SID>Sort("s:Strcmp")
    endif

    " Put in spacer in front of each line
    silent! %s/^/    /

    " We then put the file [A] and [B] on top of the diff lines
    call append(0, "[A]=". DirDiffAbsSrcA)
    call append(1, "[B]=". DirDiffAbsSrcB)
    if g:DirDiffEnableMappings
        call append(2, "Usage:   <Enter>/'o'=open,'s'=sync,'<Leader>dg'=diffget,'<Leader>dp'=diffput,'<Leader>dj'=next,'<Leader>dk'=prev, 'q'=quit")
    else
        call append(2, "Usage:   <Enter>/'o'=open,'s'=sync,'q'=quit")
    endif
    call append(3, "Options: 'u'=update,'x'=set excludes,'i'=set ignore,'a'=set args" )
    call append(4, "Diff Args:" . cmdarg)
    call append(5, "")
    " go to the beginning of the file
    0
    setlocal nomodified
    setlocal nomodifiable
    setlocal buftype=nowrite
    "setlocal buftype=nofile
    "setlocal bufhidden=delete
    setlocal bufhidden=hide
    setlocal nowrap

    " Set up local key bindings
    " 'n' actually messes with the search next pattern, I think using \dj and
    " \dk is enough.  Otherwise, use j,k, and enter.
"    nnoremap <buffer> n :call <SID>DirDiffNext()<CR>
"    nnoremap <buffer> p :call <SID>DirDiffPrev()<CR>
    nnoremap <buffer> s :. call <SID>DirDiffSync()<CR>
    vnoremap <buffer> s :call <SID>DirDiffSync()<CR>
    nnoremap <buffer> u :call <SID>DirDiffUpdate()<CR>
    nnoremap <buffer> x :call <SID>ChangeExcludes()<CR>
    nnoremap <buffer> a :call <SID>ChangeArguments()<CR>
    nnoremap <buffer> i :call <SID>ChangeIgnore()<CR>
    nnoremap <buffer> q :call <SID>DirDiffQuit()<CR>

    nnoremap <buffer> o    :call <SID>DirDiffOpen()<CR>
    nnoremap <buffer> <CR>  :call <SID>DirDiffOpen()<CR>  
    nnoremap <buffer> <2-Leftmouse> :call <SID>DirDiffOpen()<CR>
    call <SID>SetupSyntax()

    " Open the first diff
    call <SID>DirDiffNext()
endfunction

" Set up syntax highlighing for the diff window
"function! <SID>SetupSyntax()
function! <SID>SetupSyntax()
  if has("syntax") && exists("g:syntax_on") 
      "&& !has("syntax_items")
    syn match DirDiffSrcA               "\[A\]"
    syn match DirDiffSrcB               "\[B\]"
    syn match DirDiffUsage              "^Usage.*"
    syn match DirDiffOptions            "^Options.*"
    " exec 'syn match DirDiffFiles              "' . s:DirDiffDifferLine .'"'
    " exec 'syn match DirDiffOnly               "' . s:DirDiffDiffOnlyLine . '"'
    syn match DirDiffSelected           "^==>.*" contains=DirDiffSrcA,DirDiffSrcB

    hi def link DirDiffSrcA               Directory
    hi def link DirDiffSrcB               Type
    hi def link DirDiffUsage              Special
    hi def link DirDiffOptions            Special
    hi def link DirDiffFiles              String
    hi def link DirDiffOnly               PreProc
    hi def link DirDiffSelected           DiffChange
  endif
endfunction

" You should call this within the diff window
function! <SID>DirDiffUpdate()
    let dirA = <SID>GetBaseDir("A")
    let dirB = <SID>GetBaseDir("B")
    call <SID>DirDiff(dirA, dirB)
endfun

" Quit the DirDiff mode
function! <SID>DirDiffQuit()
    let in = confirm ("Are you sure you want to quit DirDiff?", "&Yes\n&No", 2)
    if (in == 1)
        call <SID>CloseDiffWindows()
        bd!
    endif
endfun

" Returns an escaped version of the path for regex uses
function! <SID>EscapeDirForRegex(path)
    " This list is probably not complete, modify later
    return escape(a:path, "/\\[]$^~")
endfunction

" Close the opened diff comparison windows if they exist
function! <SID>CloseDiffWindows()
    if (<SID>AreDiffWinsOpened())
        wincmd k
        " Ask the user to save if buffer is modified
        call <SID>AskIfModified()
        bd!
        " User may just have one window opened, we may not need to close
        " the second diff window
        if (&diff)
            call <SID>AskIfModified()
            bd!
        endif
    endif
endfunction

function! <SID>EscapeFileName(path)
	if (v:version >= 702)
		return fnameescape(a:path)
	else
		" This is not a complete list of escaped character, so it's
		" not as sophisicated as the fnameescape, but this should
		" cover most of the cases and should work for Vim version <
		" 7.2
		return escape(a:path, " \t\n*?[{`$\\%#'\"|!<")
	endif
endfunction

function! <SID>EchoErr(varName, varValue)
	echoe '' . a:varName . ' : ' . a:varValue
endfunction

function! <SID>DirDiffOpen()
    " First dehighlight the last marked
    call <SID>DeHighlightLine()

	let buffNumber = bufnr('%')
    let line = getline(".")

    " We first parse back the [A] and [B] directories from the top of the line
    let dirA = <SID>GetBaseDir("A")
    let dirB = <SID>GetBaseDir("B")


    " Save the number of this window, to which we wish to return
    " This is required in case there are other windows open
	" let thisWindow = winnr()
	"let thisWindow = winnr(buffNumber)

	exec 'buffer ' . buffNumber

    call <SID>CloseDiffWindows()
    " Mark the current location of the line
    "mark n
    let b:currentDiff = line(".")

    " Ensure we're in the right window
    " silent! exec thisWindow.'wincmd w'

    " Parse the line and see whether it's a "Only in" or "Files Differ"
    call <SID>HighlightLine()
    let fileA = <SID>GetFileNameFromLine("A", line)
    let fileB = <SID>GetFileNameFromLine("B", line)
    if <SID>IsOnly(line)
        " We open the file
        let fileSrc = <SID>ParseOnlySrc(line)
        if (fileSrc == "A")
            let fileToOpen = fileA
        elseif (fileSrc == "B")
            let fileToOpen = fileB
        endif
        split
        wincmd k
        silent exec "edit ". <SID>EscapeFileName(fileToOpen)
        " Fool the window saying that this is diff
        diffthis
        wincmd j
        " Resize the window
        exe("resize " . g:DirDiffWindowSize)
        exe (b:currentDiff)
    elseif <SID>IsDiffer(line)
        "Open the diff windows
        split
        wincmd k
        silent exec "edit ".<SID>EscapeFileName(fileB)

        " To ensure that A is on the left and B on the right, splitright must be off
        " let saved_splitright = &splitright
        " set nosplitright
        " silent exec "vert diffsplit ".<SID>EscapeFileName(fileA)
        " let &splitright = saved_splitright
        silent exec "leftabove vert diffsplit ".<SID>EscapeFileName(fileA)

        " Go back to the diff window
        wincmd j
        " Resize the window
        exe("resize " . g:DirDiffWindowSize)
        exe (b:currentDiff)
        " Center the line
        exe ("normal z.")
    else
        echo "There is no diff at the current line!"
    endif
endfunction

" Ask the user to save if the buffer is modified
"
function! <SID>AskIfModified()
    if (&modified)
        let input = confirm("File " . expand("%:p") . " has been modified.", "&Save\nCa&ncel", 1)
        if (input == 1)
            w!
        endif
    endif
endfunction


function! <SID>HighlightLine()
    let savedLine = line(".")
    exe (b:currentDiff)
    setlocal modifiable
    let line = getline(".")
    if (match(line, "^    ") == 0)
        s/^    /==> /
    endif
    setlocal nomodifiable
    setlocal nomodified
    exe (savedLine)
    " This is necessary since the modified file would make the syntax
    " disappear.
    call <SID>SetupSyntax()
    redraw
endfunction

function! <SID>DeHighlightLine()
    let savedLine = line(".")
    exe (b:currentDiff)
    let line = getline(".")
    setlocal modifiable
    if (match(line, "^==> ") == 0)
        s/^==> /    /
    endif
    setlocal nomodifiable
    setlocal nomodified
    exe (savedLine)
    redraw
endfunction

" Returns the directory for buffer "A" or "B".  You need to be in the diff
" buffer though.
function! <SID>GetBaseDir(diffName)
    let currLine = line(".")
    if (a:diffName == "A")
        let baseLine = s:DirDiffALine
    else
        let baseLine = s:DirDiffBLine
    endif
    let regex = '\['.a:diffName.'\]=\(.*\)'
    let line = getline(baseLine)
    let rtn = substitute(line, regex , '\1', '')
    return rtn
endfunction

function! <SID>DirDiffNext()
    " If the current window is a diff, go down one
    if (&diff == 1)
        wincmd j
    endif
    " if the current line is <= 6, (within the header range), we go to the
    " first diff line open it
    if (line(".") < s:DirDiffFirstDiffLine)
        exe (s:DirDiffFirstDiffLine)
        let b:currentDiff = line(".")
    endif
    silent! exe (b:currentDiff + 1)
    call <SID>DirDiffOpen()
endfunction

function! <SID>DirDiffPrev()
    " If the current window is a diff, go down one
    if (&diff == 1)
        wincmd j
    endif
    silent! exe (b:currentDiff - 1)
    call <SID>DirDiffOpen()
endfunction

" For each line, we can perform a recursive copy or delete to sync up the
" difference. Returns non-zero if the operation is NOT successful, returns 0
" if everything is fine.
"
function! <SID>DirDiffSyncHelper(AB, line)
    let fileA = <SID>GetFileNameFromLine("A", a:line)
    let fileB = <SID>GetFileNameFromLine("B", a:line)
"    echo "Helper line is ". a:line. " fileA " . fileA . " fileB " . fileB
    if <SID>IsOnly(a:line)
        " If a:AB is "A" and the ParseOnlySrc returns "A", that means we need to
        " copy
        let fileSrc = <SID>ParseOnlySrc(a:line)
        let operation = ""
        if (a:AB == "A" && fileSrc == "A")
            let operation = "Copy"
            " Use A, and A has source, thus copy the file from A to B
            let fileFrom = fileA
            let fileTo = fileB
        elseif (a:AB == "A" && fileSrc == "B")
            let operation = "Delete"
            " Use A, but B has source, thus delete the file from B
            let fileFrom = fileB
            let fileTo = fileA
        elseif (a:AB == "B" && fileSrc == "A")
            let operation = "Delete"
            " Use B, but the source file is A, thus removing A
            let fileFrom = fileA
            let fileTo = fileB
        elseif (a:AB == "B" && fileSrc == "B")
            " Use B, and B has the source file, thus copy B to A
            let operation = "Copy"
            let fileFrom = fileB
            let fileTo = fileA
        endif
    elseif <SID>IsDiffer(a:line)
        " Copy no matter what
        let operation = "Copy"
        if (a:AB == "A")
            let fileFrom = fileA
            let fileTo = fileB
        elseif (a:AB == "B")
            let fileFrom = fileB
            let fileTo = fileA
        endif
    else 
        echo "There is no diff here!"
        " Error
        return 1
    endif
    if (operation == "Copy")
        let rtnCode = <SID>Copy(fileFrom, fileTo)
    elseif (operation == "Delete")
        let rtnCode = <SID>Delete(fileFrom)
    endif
    return rtnCode
endfunction

" Synchronize the range
function! <SID>DirDiffSync() range
    let answer = 1
    let silence = 0
    let syncMaster = "A"
    let currLine = a:firstline
    let lastLine = a:lastline
    let syncCount = 0

    while ((currLine <= lastLine))
        " Update the highlight
        call <SID>DeHighlightLine()
        let b:currentDiff = currLine
        call <SID>HighlightLine()
        let line = getline(currLine)
        if (!silence)
            let answer = confirm(substitute(line, "^....", '', ''). "\nSynchronization option:" , "&A -> B\n&B -> A\nA&lways A\nAl&ways B\n&Skip\nCa&ncel", 6)
            if (answer == 1 || answer == 3)
                let syncMaster = "A"
            endif
            if (answer == 2 || answer == 4)
                let syncMaster = "B"
            endif
            if (answer == 3 || answer == 4)
                let silence = 1
            endif
            if (answer == 5)
                let currLine = currLine + 1
                continue
            endif
            if (answer == 6)
                break
            endif
        endif

"        call <SID>DeHighlightLine()
        let rtnCode = <SID>DirDiffSyncHelper(syncMaster, line)
        if (rtnCode == 0)
            " Successful
            let syncCount = syncCount + 1
            " Assume that the line is synchronized, we delete the entry
            setlocal modifiable
            exe (currLine.",".currLine." delete")
            setlocal nomodifiable
            setlocal nomodified
            let lastLine = lastLine - 1
        else
            " Failed!
            let currLine = currLine + 1
        endif
    endwhile
    echo syncCount . " diff item(s) synchronized."
endfunction

" Return file "A" or "B" depending on the line given.  If it's a Only line,
" either A or B does not exist, but the according value would be returned.
function! <SID>GetFileNameFromLine(AB, line)
    " Determine where the source of the copy is.
    let dirA = <SID>GetBaseDir("A")
    let dirB = <SID>GetBaseDir("B")

    let fileToProcess = ""

    if <SID>IsOnly(a:line)
        let fileToProcess = <SID>ParseOnlyFile(a:line)
    elseif <SID>IsDiffer(a:line)
        let regex = '^.*' . s:DirDiffDifferLine . '\[A\]\(.*\)' . s:DirDiffDifferAndLine . '\[B\]\(.*\)' . s:DirDiffDifferEndLine . '.*$'
        let fileToProcess = substitute(a:line, regex, '\1', '')
    else
    endif

    "echo "line : " . a:line. "AB = " . a:AB . " File to Process " . fileToProcess
    if (a:AB == "A")
        return dirA . fileToProcess
    elseif (a:AB == "B")
        return dirB . fileToProcess
    else
        return ""
    endif
endfunction

"Returns the source (A or B) of the "Only" line
function! <SID>ParseOnlySrc(line)
    return substitute(a:line, '^.*' . s:DirDiffDiffOnlyLine . '\[\(.\)\].*' . s:DirDiffDiffOnlyLineCenter . '.*', '\1', '')
endfunction

function! <SID>ParseOnlyFile(line)
    let regex = '^.*' . s:DirDiffDiffOnlyLine . '\[.\]\(.*\)' . s:DirDiffDiffOnlyLineCenter . '\(.*\)'
    let root = substitute(a:line, regex , '\1', '')
    let file = root . s:sep . substitute(a:line, regex , '\2', '')
    return file
endfunction

function! <SID>Copy(fileFromOrig, fileToOrig)
    let fileFrom = substitute(a:fileFromOrig, '/', s:sep, 'g')
    let fileTo = substitute(a:fileToOrig, '/', s:sep, 'g')
    echo "Copy from " . fileFrom . " to " . fileTo
    if (s:DirDiffCopyCmd == "")
        echo "Copy not supported on this platform"
        return 1
    endif

    " Constructs the copy command
    let copycmd = "!".s:DirDiffCopyCmd." ".s:DirDiffCopyFlags
    " Append the interactive flag
    if (g:DirDiffInteractive)
        let copycmd = copycmd . " " . s:DirDiffCopyInteractiveFlag
    endif
    let copycmd = copycmd . " \"".fileFrom."\" \"".fileTo."\""

    " Constructs the copy directory command
    let copydircmd = "!".s:DirDiffCopyDirCmd." ".s:DirDiffCopyDirFlags
    " Append the interactive flag
    if (g:DirDiffInteractive)
        let copydircmd = copydircmd . " " . s:DirDiffCopyInteractiveFlag
    endif
    let copydircmd = copydircmd . " \"".fileFrom."\" \"".fileTo."\""

    let error = 0
    if (isdirectory(fileFrom))
        let error = <SID>DirDiffExec(copydircmd, g:DirDiffInteractive)
    else
        let error = <SID>DirDiffExec(copycmd, g:DirDiffInteractive)
    endif
    if (error != 0)
        echo "Can't copy from " . fileFrom . " to " . fileTo
        return 1
    endif
    return 0
endfunction

" Would execute the command, either silent or not silent, by the
" interactive flag ([0|1]).  Returns the v:shell_error after
" executing the command.
function! <SID>DirDiffExec(cmd, interactive)
    let error = 0
    if (a:interactive)
        exe (a:cmd)
        let error = v:shell_error
    else
        silent exe (a:cmd)
        let error = v:shell_error
    endif
"    let d = input("DirDiffExec: " . a:cmd . " " . a:interactive . " returns " . v:shell_error)
    return error
endfunction

" Delete the file or directory.  Returns 0 if nothing goes wrong, error code
" otherwise.
function! <SID>Delete(fileFromOrig)
    let fileFrom = substitute(a:fileFromOrig, '/', s:sep, 'g')
    echo "Deleting from " . fileFrom
    if (s:DirDiffDeleteCmd == "")
        echo "Delete not supported on this platform"
        return 1
    endif

    let delcmd = ""

    if (isdirectory(fileFrom))
        let delcmd = "!".s:DirDiffDeleteDirCmd." ".s:DirDiffDeleteDirFlags
        if (g:DirDiffInteractive)
            " If running on Unix, and we're running in interactive mode, we
            " append the -i tag
            if (has("unix"))
                let delcmd = delcmd . " " . s:DirDiffDeleteInteractiveFlag
            endif
        else
            " If running on windows, and we're not running in interactive
            " mode, we append the quite flag to the "rd" command
            if (has("win32"))
                let delcmd = delcmd . " " . s:DirDiffDeleteDirQuietFlag
            endif
        endif
    else
        let delcmd = "!".s:DirDiffDeleteCmd." ".s:DirDiffDeleteFlags
        if (g:DirDiffInteractive)
            let delcmd = delcmd . " " . s:DirDiffDeleteInteractiveFlag
        endif
    endif

    let delcmd = delcmd ." \"".fileFrom."\""
    let error = <SID>DirDiffExec(delcmd, g:DirDiffInteractive)
    if (error != 0)
        echo "Can't delete " . fileFrom
    endif
    return error
endfunction

function! <SID>AreDiffWinsOpened()
    let currBuff = expand("%:p")
    let currLine = line(".")
    wincmd k
    let abovedBuff = expand("%:p")
    if (&diff)
        let abovedIsDiff = 1
    else
        let abovedIsDiff = 0
    endif
    " Go Back if the aboved buffer is not the same
    if (currBuff != abovedBuff)
        wincmd j
        " Go back to the same line
        exe (currLine)
        if (abovedIsDiff == 1)
            return 1
        else
            " Aboved is just a bogus buffer, not a diff buffer
            return 0
        endif
    else
        exe (currLine)
        return 0
    endif
endfunction

" The given line begins with the "Only in"
function! <SID>IsOnly(line)	
    return (match(a:line, "^ *" . s:DirDiffDiffOnlyLine . "\\|^==> " . s:DirDiffDiffOnlyLine ) == 0)
endfunction

" The given line begins with the "Files"
function! <SID>IsDiffer(line)
    return (match(a:line, "^ *" . s:DirDiffDifferLine . "\\|^==> " . s:DirDiffDifferLine  ) == 0)
endfunction

" Let you modify the Exclude patthern
function! <SID>ChangeExcludes()
    let g:DirDiffExcludes = input ("Exclude pattern (separate multiple patterns with ','): ", g:DirDiffExcludes)
    echo "\nPress update ('u') to refresh the diff."
endfunction

" Let you modify additional arguments for diff
function! <SID>ChangeArguments()
    let g:DirDiffAddArgs = input ("Additional diff args: ", g:DirDiffAddArgs)
    echo "\nPress update ('u') to refresh the diff."
endfunction

" Let you modify the Ignore patthern
function! <SID>ChangeIgnore()
    let g:DirDiffIgnore = input ("Ignore pattern (separate multiple patterns with ','): ", g:DirDiffIgnore)
    echo "\nPress update ('u') to refresh the diff."
endfunction

" Sorting functions from the Vim docs.  Use this instead of the sort binary.
"
" Function for use with Sort(), to compare two strings.
func! <SID>Strcmp(str1, str2)
  if (a:str1 < a:str2)
	return -1
  elseif (a:str1 > a:str2)
	return 1
  else
	return 0
  endif
endfunction

" Sort lines.  SortR() is called recursively.
func! <SID>SortR(start, end, cmp)
  if (a:start >= a:end)
	return
  endif
  let partition = a:start - 1
  let middle = partition
  let partStr = getline((a:start + a:end) / 2)
  let i = a:start
  while (i <= a:end)
	let str = getline(i)
	exec "let result = " . a:cmp . "(str, partStr)"
	if (result <= 0)
	    " Need to put it before the partition.  Swap lines i and partition.
	    let partition = partition + 1
	    if (result == 0)
		let middle = partition
	    endif
	    if (i != partition)
		let str2 = getline(partition)
		call setline(i, str2)
		call setline(partition, str)
	    endif
	endif
	let i = i + 1
  endwhile

  " Now we have a pointer to the "middle" element, as far as partitioning
  " goes, which could be anywhere before the partition.  Make sure it is at
  " the end of the partition.
  if (middle != partition)
	let str = getline(middle)
	let str2 = getline(partition)
	call setline(middle, str2)
	call setline(partition, str)
  endif
  call <SID>SortR(a:start, partition - 1, a:cmp)
  call <SID>SortR(partition + 1, a:end, a:cmp)
endfunc

" To Sort a range of lines, pass the range to Sort() along with the name of a
" function that will compare two lines.
func! <SID>Sort(cmp) range
  call <SID>SortR(a:firstline, a:lastline, a:cmp)
endfunc

" Added to deal with internationalized version of diff, which returns a
" different string than "Files ... differ" or "Only in ... "

function! <SID>GetDiffStrings()
    " Check if we have the dynamic text string turned on.  If not, just return
    " what's set in the global variables

    if (g:DirDiffDynamicDiffText == 0)
        let s:DirDiffDiffOnlyLineCenter = g:DirDiffTextOnlyInCenter
        let s:DirDiffDiffOnlyLine = g:DirDiffTextOnlyIn
        let s:DirDiffDifferLine = g:DirDiffTextFiles
        let s:DirDiffDifferAndLine = g:DirDiffTextAnd
        let s:DirDiffDifferEndLine = g:DirDiffTextDiffer
        return
    endif

	let tmp1 = tempname()
	let tmp2 = tempname()
	let tmpdiff = tempname()

    " We need to pad the backslashes in order to make it match
    let tmp1rx = <SID>EscapeDirForRegex(tmp1)
    let tmp2rx = <SID>EscapeDirForRegex(tmp2)
    let tmpdiffrx = <SID>EscapeDirForRegex(tmpdiff)

	silent exe s:DirDiffMakeDirCmd . "\"" . tmp1 . "\""
	silent exe s:DirDiffMakeDirCmd . "\"" . tmp2 . "\""
	silent exe "!echo test > \"" . tmp1 . s:sep . "test" . "\""
	silent exe "!diff -r --brief \"" . tmp1 . "\" \"" . tmp2 . "\" > \"" . tmpdiff . "\""

	" Now get the result of that diff cmd
	silent exe "split ". tmpdiff
    "echo "First line: " . getline(1)
    "echo "tmp1: " . tmp1
    "echo "tmp1rx: " . tmp1rx
    let regex = '\(^.*\)' . tmp1rx . '\(.*\)' . "test"
	let s:DirDiffDiffOnlyLine = substitute( getline(1), regex, '\1', '') 
	let s:DirDiffDiffOnlyLineCenter = substitute( getline(1), regex, '\2', '') 
    "echo "DirDiff Only: " . s:DirDiffDiffOnlyLine
	
	q

	" Now let's get the Differ string
    "echo "Getting the diff in GetDiffStrings"
	
	silent exe "!echo testdifferent > \"" . tmp2 . s:sep . "test" . "\""
	silent exe "!diff -r --brief \"" . tmp1 . "\" \"" . tmp2 . "\" > \"" . tmpdiff . "\""
	
	silent exe "split ". tmpdiff
	let s:DirDiffDifferLine = substitute( getline(1), tmp1rx . ".*$", "", '') 
    " Note that the diff on cygwin may output '/' instead of '\' for the
    " separator, so we need to accomodate for both cases
    let andrx = "^.*" . tmp1rx . "[\\\/]test\\(.*\\)" . tmp2rx . "[\\\/]test.*$"
    let endrx = "^.*" . tmp1rx . "[\\\/]test.*" . tmp2rx . "[\\\/]test\\(.*$\\)"
    "echo "andrx : " . andrx
    "echo "endrx : " . endrx
	let s:DirDiffDifferAndLine = substitute( getline(1), andrx , "\\1", '') 
    let s:DirDiffDifferEndLine = substitute( getline(1), endrx, "\\1", '') 

	"echo "s:DirDiffDifferLine = " . s:DirDiffDifferLine
	"echo "s:DirDiffDifferAndLine = " . s:DirDiffDifferAndLine
	"echo "s:DirDiffDifferEndLine = " . s:DirDiffDifferEndLine

	q

	" Delete tmp files
    "echo "Deleting tmp files."

	call <SID>Delete(tmp1)
	call <SID>Delete(tmp2)
	call <SID>Delete(tmpdiff)

	"avoid get diff text again
	let g:DirDiffTextOnlyInCenter = s:DirDiffDiffOnlyLineCenter
	let g:DirDiffTextOnlyIn = s:DirDiffDiffOnlyLine
	let g:DirDiffTextFiles = s:DirDiffDifferLine
	let g:DirDiffTextAnd = s:DirDiffDifferAndLine
	let g:DirDiffTextDiffer = s:DirDiffDifferEndLine
	let g:DirDiffDynamicDiffText = 0

endfunction
