! :folding=indent:collapseFolds=1:

! $Id$
!
! Copyright (C) 2004 Slava Pestov.
! 
! Redistribution and use in source and binary forms, with or without
! modification, are permitted provided that the following conditions are met:
! 
! 1. Redistributions of source code must retain the above copyright notice,
!    this list of conditions and the following disclaimer.
! 
! 2. Redistributions in binary form must reproduce the above copyright notice,
!    this list of conditions and the following disclaimer in the documentation
!    and/or other materials provided with the distribution.
! 
! THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
! INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
! FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
! DEVELOPERS AND CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
! SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
! PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
! OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
! WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
! OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
! ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

IN: compiler
USE: lists
USE: words
USE: stack
USE: namespaces
USE: inference
USE: combinators

! The linear IR is close to assembly language. It also resembles
! Forth code in some sense. It exists so that pattern matching
! optimization can be performed against it.

! Linear IR nodes. This is in addition to the symbols already
! defined in dataflow vocab.

SYMBOL: #jump-label-t ( branch if top of stack is true )
SYMBOL: #jump-label ( unconditional branch )
SYMBOL: #jump ( tail-call )

: linear, ( node -- )
    #! Add a node to the linear IR.
    [ node-op get node-param get ] bind cons , ;

: >linear ( node -- )
    #! Dataflow OPs have a linearizer word property. This
    #! quotation is executed to convert the node into linear
    #! form.
    "linearizer" [ linear, ] apply-dataflow ;

: (linearize) ( dataflow -- )
    [ >linear ] each ;

: linearize ( dataflow -- linear )
    #! Transform dataflow IR into linear IR. This strips out
    #! stack flow information, flattens conditionals into
    #! jumps and labels, and turns dataflow IR nodes into
    #! lists where the first element is an operation, and the
    #! rest is arguments.
    [ (linearize) ] make-list ;

: <label> ( -- label )
    gensym ;

: label, ( label -- )
    #label swons , ;

: linearize-ifte ( param -- )
    #! The parameter is a list of two lists, each one a dataflow
    #! IR.
    uncons car
    <label> [
        #jump-label-t swons ,
        (linearize) ( false branch )
        <label> dup #jump-label swons ,
    ] keep label, ( branch target of BRANCH-T )
    swap (linearize) ( true branch )
    label, ( branch target of false branch end ) ;

: generic-head ( param op -- end label/param )
    #! Output the jump table insn and return a list of
    #! label/branch pairs.
    >r
    <label> ( end label ) swap
    [ <label> cons ] map
    dup [ cdr ] map r> swons , ;

: generic-body ( end label/param -- )
    #! Output each branch, with a jump to the end label.
    [
        uncons label,  (linearize)  dup #jump-label swons ,
    ] each drop ;

: linearize-generic ( param op -- )
    #! The parameter is a list of lists, each one is a branch to
    #! take in case the top of stack has that type.
    generic-head dupd generic-body label, ;

#label [
    dup [ node-label get ] bind label,
    [ node-param get ] bind (linearize)
] "linearizer" set-word-property

#ifte [
    [ node-param get ] bind linearize-ifte
] "linearizer" set-word-property

#generic [
    [ node-param get node-op get ] bind linearize-generic
] "linearizer" set-word-property

#2generic [
    [ node-param get node-op get ] bind linearize-generic
] "linearizer" set-word-property
