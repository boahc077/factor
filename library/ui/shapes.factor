! Copyright (C) 2005 Slava Pestov.
! See http://factor.sf.net/license.txt for BSD license.
IN: gadgets
USING: generic kernel lists math namespaces ;

! Shape protocol. Shapes are immutable; moving or resizing a
! shape makes a new shape.

! These dynamically-bound variables affect the generic word
! inside?.
SYMBOL: x
SYMBOL: y

GENERIC: inside? ( point shape -- ? )

! A shape is an object with a defined bounding
! box, and a notion of interior.
GENERIC: shape-x
GENERIC: shape-y
GENERIC: shape-w
GENERIC: shape-h

GENERIC: move-shape ( x y shape -- )
GENERIC: resize-shape ( w h shape -- )

: shape>screen ( shape -- x1 y1 x2 y2 )
    [ shape-x x get + ] keep
    [ shape-y y get + ] keep
    [ shape-w pick + ] keep
    shape-h pick + ;

: with-translation ( shape quot -- )
    #! All drawing done inside the quotation is translated
    #! relative to the shape's origin.
    [
        >r dup
        shape-x x [ + ] change
        shape-y y [ + ] change
        r> call
    ] with-scope ; inline

: max-width ( list -- n )
    #! The width of the widest shape.
    [ [ shape-w ] map [ > ] top ] [ 0 ] ifte* ;

: max-height ( list -- n )
    #! The height of the tallest shape.
    [ [ shape-h ] map [ > ] top ] [ 0 ] ifte* ;

: run-widths ( list -- w list )
    #! Compute a list of running sums of widths of shapes.
    [ 0 swap [ over , shape-w + ] each ] make-list ;

: run-heights ( list -- h list )
    #! Compute a list of running sums of heights of shapes.
    [ 0 swap [ over , shape-h + ] each ] make-list ;

! A point, represented as a complex number, is the simplest
! shape. It is not mutable and cannot be used as the delegate of
! a gadget.
: shape-pos ( shape -- pos )
    dup shape-x swap shape-y rect> ;

M: number inside? ( point point -- )
    >r shape-pos r> = ;

M: number shape-x real ;
M: number shape-y imaginary ;
M: number shape-w drop 0 ;
M: number shape-h drop 0 ;

: translate ( point shape -- point )
    #! Translate a point relative to the shape.
    swap shape-pos swap shape-pos - ;

! A rectangle maps trivially to the shape protocol.
TUPLE: rectangle x y w h ;
M: rectangle shape-x rectangle-x ;
M: rectangle shape-y rectangle-y ;
M: rectangle shape-w rectangle-w ;
M: rectangle shape-h rectangle-h ;

: fix-neg ( a b c -- a+c b -c )
    dup 0 < [ neg tuck >r >r + r> r> ] when ;

C: rectangle ( x y w h -- rect )
    #! We handle negative w/h for convinience.
    >r fix-neg >r fix-neg r> r>
    [ set-rectangle-h ] keep
    [ set-rectangle-w ] keep
    [ set-rectangle-y ] keep
    [ set-rectangle-x ] keep ;

M: rectangle move-shape ( x y rect -- )
    tuck set-rectangle-y set-rectangle-x ;

M: rectangle resize-shape ( w h rect -- )
    tuck set-rectangle-h set-rectangle-w ;

: rectangle-x-extents ( rect -- x1 x2 )
    dup shape-x x get + swap shape-w 1 - dupd + ;

: rectangle-y-extents ( rect -- x1 x2 )
    dup shape-y y get + swap shape-h 1 - dupd + ;

: inside-rect? ( point rect -- ? )
    over shape-x over rectangle-x-extents between? >r
    swap shape-y swap rectangle-y-extents between? r> and ;

M: rectangle inside? ( point rect -- ? )
    inside-rect? ;

! A line.
TUPLE: line x y w h ;
C: line ( x y w h -- line )
    [ set-line-h ] keep
    [ set-line-w ] keep
    [ set-line-y ] keep
    [ set-line-x ] keep ;

M: line shape-x dup line-x dup rot line-w + min ;
M: line shape-y dup line-y dup rot line-h + min ;
M: line shape-w line-w abs ;
M: line shape-h line-h abs ;

: line-pos ( line -- #{ x y }# ) dup line-x swap line-y rect> ;
: line-dir ( line -- #{ w h }# ) dup line-w swap line-h rect> ;

: move-line-x ( x line -- )
    [ line-w dupd - max ] keep set-line-x ;

: move-line-y ( y line -- )
    [ line-h dupd - max ] keep set-line-y ;

M: line move-shape ( x y line -- )
    tuck move-line-y move-line-x ;

: resize-line-w ( w line -- )
    dup line-w 0 >= [
        set-line-w
    ] [
        2dup
        [ [ line-w + ] keep line-x + ] keep set-line-x
        >r neg r> set-line-w
    ] ifte ;

: resize-line-h ( w line -- )
    dup line-h 0 >= [
        set-line-h
    ] [
        2dup
        [ [ line-h + ] keep line-y + ] keep set-line-y
        >r neg r> set-line-h
    ] ifte ;

M: line resize-shape ( w h line -- )
    tuck resize-line-h resize-line-w ;

: line-inside? ( p d -- ? )
    tuck proj - absq 2 < ;

M: line inside? ( point line -- ? )
    2dup inside-rect? [
        [ line-pos - ] keep line-dir line-inside?
    ] [
        2drop f
    ] ifte ;

! An ellipse.
TUPLE: ellipse x y w h ;
M: ellipse shape-x ellipse-x ;
M: ellipse shape-y ellipse-y ;
M: ellipse shape-w ellipse-w ;
M: ellipse shape-h ellipse-h ;

C: ellipse ( x y w h -- line )
    #! We handle negative w/h for convenience.
    >r fix-neg >r fix-neg r> r>
    [ set-ellipse-h ] keep
    [ set-ellipse-w ] keep
    [ set-ellipse-y ] keep
    [ set-ellipse-x ] keep ;

M: ellipse move-shape ( x y line -- )
    tuck set-ellipse-y set-ellipse-x ;

M: ellipse resize-shape ( w h line -- )
    tuck set-ellipse-h set-ellipse-w ;

: ellipse>screen ( shape -- x y rx ry )
    [ dup shape-x swap shape-w 2 /i + x get + ] keep
    [ dup shape-y swap shape-h 2 /i + y get + ] keep
    [ shape-w 2 /i ] keep
    shape-h 2 /i ;

M: ellipse inside? ( point ellipse -- ? )
    ellipse>screen swap sq swap sq
    2dup * >r >r >r
    pick shape-y - sq
    >r swap shape-x - sq r>
    r> * r> rot * + r> <= ;
