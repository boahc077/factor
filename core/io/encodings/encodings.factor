! Copyright (C) 2006, 2007 Daniel Ehrenberg.
! See http://factorcode.org/license.txt for BSD license.
USING: math kernel sequences sbufs vectors namespaces
growable strings io classes io.streams.c continuations
io.styles io.streams.nested ;
IN: io.encodings

! Decoding

TUPLE: decode-error ;

: decode-error ( -- * ) \ decode-error construct-empty throw ;

SYMBOL: begin

: decoded ( buf ch -- buf ch state )
    over push 0 begin ;

: push-replacement ( buf -- buf ch state )
    ! This is the replacement character
    HEX: fffd decoded ;

: finish-decoding ( buf ch state -- str )
    begin eq? [ decode-error ] unless drop "" like ;

: start-decoding ( seq length -- buf ch state seq )
    <sbuf> 0 begin roll ;

GENERIC: decode-step ( buf byte ch state encoding -- buf ch state )

: decode ( seq quot -- string )
    >r dup length start-decoding r>
    [ -rot ] swap compose each
    finish-decoding ; inline

: space ( resizable -- room-left )
    dup underlying swap [ length ] 2apply - ;

: full? ( resizable -- ? ) space zero? ;

: end-read-loop ( buf ch state stream quot -- string/f )
    2drop 2drop >string f like ;

: decode-read-loop ( buf ch state stream encoding -- string/f )
    >r >r pick r> r> rot full?  [ end-read-loop ] [
        over stream-read1 [
            -rot tuck >r >r >r -rot r> decode-step r> r> decode-read-loop
        ] [ end-read-loop ] if*
    ] if ;

: decode-read ( length stream encoding -- string )
    >r swap start-decoding r>
    decode-read-loop ;

TUPLE: decoded code cr ;
: <decoded> ( stream decoding-class -- decoded-stream )
    construct-empty { set-delegate set-decoded-code } decoded construct ;

: cr+ t swap set-line-reader-cr ; inline

: cr- f swap set-line-reader-cr ; inline

: line-ends/eof ( stream str -- str ) f like swap cr- ; inline

: line-ends\r ( stream str -- str ) swap cr+ ; inline

: line-ends\n ( stream str -- str )
    over line-reader-cr over empty? and
    [ drop dup cr- stream-readln ] [ swap cr- ] if ; inline

: handle-readln ( stream str ch -- str )
    {
        { f [ line-ends/eof ] }
        { CHAR: \r [ line-ends\r ] }
        { CHAR: \n [ line-ends\n ] }
    } case ;

: fix-read ( stream string -- string )
    over line-reader-cr [
        over cr-
        "\n" ?head [
            swap stream-read1 [ add ] when*
        ] [ nip ] if
    ] [ nip ] if ;

M: decoded stream-read
    tuck { delegate decoded-code } get-slots decode-read fix-read ;

M: decoded stream-read-partial tuck stream-read fix-read ;

M: decoded stream-read-until
    ! Copied from { c-reader stream-read-until }!!!
    [ swap read-until-loop ] "" make
    swap over empty? over not and [ 2drop f f ] when ;

: fix-read1 ( stream char -- char )
    over line-reader-cr [
        over cr-
        dup CHAR: \n = [
            drop stream-read1
        ] [ nip ] if
    ] [ nip ] if ;

M: decoded stream-read1 1 over stream-read ;

M: line-reader stream-readln ( stream -- str )
    "\r\n" over stream-read-until handle-readln ;

! Encoding

TUPLE: encode-error ;

: encode-error ( -- * ) \ encode-error construct-empty throw ;

TUPLE: encoded code ;
: <encoded> ( stream encoding-class -- encoded-stream )
    construct-empty { set-delegate set-encoded-code } encoded construct ;

GENERIC: encode-string ( string encoding -- byte-array )
M: tuple-class encode-string construct-empty encode-string ;

M: encoded stream-write1
    >r 1string r> stream-write ;

M: encoded stream-write
    [ encoding-code encode-string ] keep delegate stream-write ;

M: encoded dispose delegate dispose ;

M: encoded stream-nl
    CHAR: \n swap stream-write1 ;

M: encoded stream-format
    nip stream-write ;

M: encoded make-span-stream
    <style-stream> <ignore-close-stream> ;

M: encoded make-block-stream
    nip <ignore-close-stream> ;
