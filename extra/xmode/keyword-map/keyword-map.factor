USING: accessors kernel strings assocs sequences hashtables
sorting unicode.case unicode.categories sets ;
IN: xmode.keyword-map

! Based on org.gjt.sp.jedit.syntax.KeywordMap
TUPLE: keyword-map no-word-sep ignore-case? ;

: <keyword-map> ( ignore-case? -- map )
    H{ } clone { set-keyword-map-ignore-case? set-delegate }
    keyword-map construct ;

: invalid-no-word-sep ( keyword-map -- ) f >>no-word-sep drop ;

: handle-case ( key keyword-map -- key assoc )
    [ keyword-map-ignore-case? [ >upper ] when ] keep
    delegate ;

M: keyword-map at* handle-case at* ;

M: keyword-map set-at
    [ handle-case set-at ] keep invalid-no-word-sep ;

M: keyword-map clear-assoc
    [ delegate clear-assoc ] keep invalid-no-word-sep ;

M: keyword-map >alist delegate >alist ;

: (keyword-map-no-word-sep) ( assoc -- str )
    keys concat [ alpha? not ] filter prune natural-sort ;

: keyword-map-no-word-sep* ( keyword-map -- str )
    dup keyword-map-no-word-sep [ ] [
        dup (keyword-map-no-word-sep)
        dup rot set-keyword-map-no-word-sep
    ] ?if ;

INSTANCE: keyword-map assoc
