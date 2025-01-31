! Copyright (C) 2009 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors alien.c-types alien.data alien.syntax arrays
assocs cache classes colors combinators core-foundation
core-foundation.attributed-strings core-foundation.strings
core-graphics core-graphics.types core-text.fonts destructors
fonts io.encodings.string io.encodings.utf16 kernel make
math math.functions math.vectors namespaces opengl sequences
strings ;
IN: core-text

TYPEDEF: void* CTLineRef

C-GLOBAL: CFStringRef kCTFontAttributeName
C-GLOBAL: CFStringRef kCTKernAttributeName
C-GLOBAL: CFStringRef kCTLigatureAttributeName
C-GLOBAL: CFStringRef kCTForegroundColorAttributeName
C-GLOBAL: CFStringRef kCTParagraphStyleAttributeName
C-GLOBAL: CFStringRef kCTUnderlineStyleAttributeName
C-GLOBAL: CFStringRef kCTVerticalFormsAttributeName
C-GLOBAL: CFStringRef kCTGlyphInfoAttributeName

FUNCTION: CTLineRef CTLineCreateWithAttributedString ( CFAttributedStringRef string )

FUNCTION: void CTLineDraw ( CTLineRef line, CGContextRef context )

FUNCTION: CGFloat CTLineGetOffsetForStringIndex ( CTLineRef line, CFIndex charIndex, CGFloat* secondaryOffset )

FUNCTION: CFIndex CTLineGetStringIndexForPosition ( CTLineRef line, CGPoint position )

FUNCTION: double CTLineGetTypographicBounds ( CTLineRef line, CGFloat* ascent, CGFloat* descent, CGFloat* leading )

FUNCTION: CGRect CTLineGetImageBounds ( CTLineRef line, CGContextRef context )

MEMO: make-attributes ( open-font color -- hashtable )
    [
        kCTForegroundColorAttributeName ,,
        kCTFontAttributeName ,,
    ] H{ } make ;

: <CTLine> ( string open-font color -- line )
    [
        [
            dup selection? [ string>> ] when
            string check-instance
        ] 2dip
        make-attributes <CFAttributedString> &CFRelease
        CTLineCreateWithAttributedString
    ] with-destructors ;

TUPLE: line < disposable font string line metrics image loc dim
render-loc render-dim render-ext ;

: typographic-bounds ( line -- width ascent descent leading )
    { CGFloat CGFloat CGFloat }
    [ CTLineGetTypographicBounds ] with-out-parameters ; inline

: store-typographic-bounds ( metrics width ascent descent leading -- metrics )
    {
        [ >>width ]
        [ >>ascent ]
        [ >>descent ]
        [ >>leading ]
    } spread ; inline

: compute-font-metrics ( metrics font -- metrics )
    [ CTFontGetCapHeight >>cap-height ]
    [ CTFontGetXHeight >>x-height ]
    bi ; inline

: compute-line-metrics ( open-font line -- line-metrics )
    [ metrics new ] 2dip
    [ compute-font-metrics ]
    [ typographic-bounds store-typographic-bounds ] bi*
    compute-height ;

: metrics>dim ( bounds -- dim )
    [ width>> ] [ [ ascent>> ] [ descent>> ] bi + ] bi
    ceiling >integer 2array ;

: fill-background ( context font dim -- )
    [ background>> >rgba-components CGContextSetRGBFillColor ]
    [ [ 0 0 ] dip first2 <CGRect> CGContextFillRect ]
    bi-curry* bi ;

: selection-rect ( dim line selection -- rect )
    [let [ start>> ] [ end>> ] [ string>> ] tri :> ( start end string )
     start end [ 0 swap string subseq utf16n encode length 2 /i ] bi@
    ]
    [ f CTLineGetOffsetForStringIndex ] bi-curry@ bi
    [ drop nip 0 ] [ swap - swap second ] 3bi <CGRect> ;

: CGRect-translate-x ( CGRect x -- CGRect' )
    [ dup CGRect-x ] dip - over set-CGRect-x ;

:: fill-selection-background ( context loc dim line string -- )
    string selection? [
        context string color>> >rgba-components CGContextSetRGBFillColor
        context dim line string selection-rect
        loc first CGRect-translate-x
        CGContextFillRect
    ] when ;

: line-rect ( line -- rect )
    dummy-context CTLineGetImageBounds ;

: set-text-position ( context loc -- )
    first2 [ neg ] bi@ CGContextSetTextPosition ;

:: line-loc ( metrics loc dim -- loc )
    loc first
    metrics ascent>> dim second loc second + - 1 - 2array ;

: load-2x? ( -- ? )
    gl-scale-factor get-global [ 1.0 > ] [ f ] if* ;

:: <line> ( font string -- line )
    [
        line new-disposable
        font load-2x? [ cache-font@2x ] [ cache-font ] if :> open-font
        string open-font font foreground>> <CTLine> |CFRelease :> line
        open-font line compute-line-metrics
        [ >>metrics ] [ metrics>dim >>dim ] bi
        font >>font
        string >>string
        line >>line
    ] with-destructors ;

:: render ( line -- line image )
    line line>> :> ctline
    line string>> :> string
    line font>> :> font

    line render-loc>> [

        ctline line-rect :> rect
        rect origin>> CGPoint>loc :> (loc)
        rect size>> CGSize>dim :> (dim)

        (loc) vfloor :> loc
        (dim) vceiling :> dim
        dim [ >integer 1 + ] map :> ext

        loc line render-loc<<
        dim line render-dim<<
        ext line render-ext<<

        line metrics>> loc dim line-loc line loc<<

    ] unless

    line render-loc>> :> loc
    line render-dim>> :> dim
    line render-ext>> :> ext

    line ext [
        {
            [ font ext fill-background ]
            [ loc first 0 2array dim first ext second 2array ctline string fill-selection-background ]
            [ loc set-text-position ]
            [ [ ctline ] dip CTLineDraw ]
        } cleave
    ] make-bitmap-image load-2x? >>2x? ;

: line>image ( line -- image )
    dup image>> [ render >>image ] unless image>> ;

M: line dispose* line>> CFRelease ;

SYMBOL: cached-lines

: cached-line ( font string -- line )
    cached-lines get-global [ <line> ] 2cache ;

STARTUP-HOOK: [ <cache-assoc> cached-lines set-global ]
