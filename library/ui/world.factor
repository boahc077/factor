! Copyright (C) 2005, 2006 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
IN: gadgets
USING: freetype gadgets-labels gadgets-layouts gadgets-theme
generic kernel namespaces queues sequences ;

! The world gadget is the top level gadget that all (visible)
! gadgets are contained in. The current world is stored in the
! world variable. The invalid slot is a list of gadgets that
! need to be layout.
TUPLE: world glass status handle ;

C: world ( gadget status dim -- world )
    <stack> over set-delegate
    t over set-gadget-root?
    [ set-gadget-dim ] keep
    [ set-world-status ] keep
    [ add-gadget ] keep ;

: hide-glass ( world -- )
    dup world-glass unparent f swap set-world-glass ;

: <glass> ( gadget -- glass )
    <gadget> 2dup add-gadget swap prefer ;

: show-glass ( gadget world -- )
    dup hide-glass
    >r <glass> r> 2dup add-gadget
    set-world-glass ;

: relevant-help ( seq -- help )
    [ gadget-help ] map [ ] find nip ;

: show-message ( string/f -- )
    #! Show a message in the status bar.
    world-status set-label-text* ;

: update-help ( -- string )
    #! Update mouse-over help message.
    hand get hand-gadget parents [ relevant-help ] keep
    dup empty? [ 2drop ] [ peek show-message ] if ;

: under-hand ( -- seq )
    #! A sequence whose first element is the world and last is
    #! the current gadget, with all parents in between.
    hand get hand-gadget parents reverse-slice ;

: hand-grab ( world -- gadget )
    hand get rect-loc swap pick-up ;

: update-hand-gadget ( world -- )
    hand-grab hand get set-hand-gadget ;

: move-hand ( loc world -- )
    swap under-hand >r hand get set-rect-loc
    update-hand-gadget
    under-hand r> hand-gestures update-help ;

: update-hand ( world -- )
    #! Called when a gadget is removed or added.
    hand get rect-loc swap move-hand ;

: draw-world ( world -- )
    [ dup rect-dim init-gl draw-gadget ] with-scope ;

GENERIC: find-world ( gadget -- world )

M: f find-world ;

M: gadget find-world gadget-parent find-world ;

M: world find-world ;

: repaint ( gadget -- )
    find-world [ world-handle repaint-handle ] when* ;

: layout-done ( gadget -- )
    find-world [
        dup update-hand world-handle repaint-handle
    ] when* ;
