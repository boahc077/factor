! Copyright © 2008 Reginald Keith Ford II
! See http://factorcode.org/license.txt for BSD license.
! Secant Method of approximating roots
USING: kernel math math.function-tools math.points math.vectors ;
IN: math.secant-method

<PRIVATE

: secant-solution ( x1 x2 function -- solution )
    [ eval ] curry bi@ linear-solution ;

: secant-step ( x1 x2 func -- x2 x3 func )
    [ secant-solution ] 2keep swapd ;

: secant-precision ( -- n ) 15 ; inline

PRIVATE>

: secant-method ( left right function -- x )
    secant-precision [ secant-step ] times drop + 2 / ;

! : close-enough? ( a b -- t/f ) - abs tiny-amount < ;

! : secant-method2 ( left right function -- x )
    ! 2over close-enough?
    ! [ drop average ] [ secant-step secant-method ] if  ;
