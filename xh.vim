" Language:   xh
" Maintainer: Spencer Tipping

if !exists("main_syntax")
  if version < 600
    syntax clear
  elseif exists("b:current_syntax")
    finish
  endif
  let main_syntax = 'xh'
endif

syn case match
set iskeyword=37,38,42-63,65-90,94-122,124,127-255

syn region xhShebang start=/\%^#!/ end=/$/
syn region xhList             matchgroup=xhInterpolationParens start=/\(@!\|@\|!\)\?(/   end=/)/ contains=@xhTop
syn region xhInterpolatedList matchgroup=xhInterpolationParens start=/\(@!\|@\|!\|\$\)(/ end=/)/ contains=@xhTop
syn region xhVector           matchgroup=xhParens              start=/\[/                end=/]/ contains=@xhTop
syn region xhMap              matchgroup=xhParens              start=/{/                 end=/}/ contains=@xhTop
syn region xhSoftString       matchgroup=xhQuoteMarks          start=/\(^\|\s\)"/        end=/"/ contains=xhSoftEscape,@xhStringInterpolable
syn region xhHardString       matchgroup=xhQuoteMarks          start=/\(^\|\s\)'/        end=/'/ contains=xhHardEscape

syn cluster xhTop add=xhList,xhVector,xhMap,xhSoftString,xhHardString,xhInterpolatedWord,xhCore,xhMeta,xhProbablyMeta,xhEscapedWord,xhLineComment
syn cluster xhInterpolable add=xhList,xhInterpolatedWord
syn cluster xhStringInterpolable add=xhInterpolatedList,xhInterpolatedWord

syn match xhSoftEscape /\\./     contained
syn match xhHardEscape /\\[\\']/ contained

syn keyword xhCore == apply array assoc bindings defs do empty contains
syn keyword xhCore get globals hash if into iota keys len list literal
syn keyword xhCore module modules parse realtype reduce scope slice str
syn keyword xhCore unquote vals var

syn match xhCore ![if]u\?[-+*/%<>=|&^~!]\+!

syn keyword xhMeta concrete def delay fn\* hashcode quote type undef

syn match xhProbablyMeta     /def\k\+/
syn match xhInterpolatedWord /\(@!\|[!@$]\)\k\+/

syn match xhLineComment /#.*/
syn match xhEscapedWord /\^\+\k\+/

hi def link xhShebang             Special
hi def link xhCore                Keyword
hi def link xhMeta                Type
hi def link xhProbablyMeta        Type
hi def link xhParens              Special
hi def link xhQuoteMarks          Special
hi def link xhSoftString          String
hi def link xhHardString          String
hi def link xhInterpolatedWord    Identifier
hi def link xhInterpolationParens Special
hi def link xhLineComment         Comment
hi def link xhEscapedWord         Special

hi def link xhSoftEscape          Special
hi def link xhHardEscape          Special
