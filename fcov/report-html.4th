\ fcov/report-html.4th — render a self-contained HTML coverage site.
\
\ Layout under .fcov/html/:
\
\     index.html              — overall summary + per-file table
\     style.css               — colour palette + table CSS
\     <project paths>.html    — one page per source file, mirroring
\                               the project's directory structure
\                               (e.g. .fcov/html/fcov/util.4th.html)
\
\ Each per-file page renders the entire source as a numbered table.
\ Definition lines are tagged with `class="def covered"` (green) or
\ `class="def uncovered"` (red) so coverage is immediately visible
\ when scanning. Whole-line comments (`\` after optional indent) get
\ a muted colour. The decoration is intentionally minimal — Forth
\ doesn't lend itself to the kind of token-level highlighting C/JS
\ enjoy, and the «which words ran» signal is the actual deliverable.
\
\ The output is *static* HTML + CSS only — no JavaScript, no fonts to
\ fetch, no theme switcher. Open `.fcov/html/index.html` in a browser
\ or upload the directory to GitHub Pages / nginx and you're done.

require fcov/util.4th
require fcov/collect.4th
require fcov/aggregate.4th
require ../forth-packages/fenum/0.1.1/fenum-bs.4th

\ --- Per-file bucket ------------------------------------------------------

begin-structure fcov-hbk%
    field: fcov.hbk-file-a
    field: fcov.hbk-file-u
    field: fcov.hbk-recs       \ ulist of fcov.recs records (NOT owned)
    field: fcov.hbk-total
    field: fcov.hbk-covered
end-structure

variable fcov.hbk-list    ulist-new fcov.hbk-list !

: fcov.hbk-free ( bk -- )
    dup fcov.hbk-recs @ ulist-dispose   \ frees only the wrapper list
    dup fcov.hbk-file-a @ free throw
    free throw ;

: fcov.hbk-clear
    ['] fcov.hbk-free fcov.hbk-list @ ulist-each
    fcov.hbk-list @ ulist-clear ;

\ Bucket lookup-or-create (linear scan; same shape as report-console).

variable fcov.hbk-target-a
variable fcov.hbk-target-u
variable fcov.hbk-found

: fcov.hbk-match-step ( bk -- )
    fcov.hbk-found @ IF drop EXIT THEN
    dup fcov.hbk-file-a @ over fcov.hbk-file-u @
    fcov.hbk-target-a @ fcov.hbk-target-u @
    compare 0= IF fcov.hbk-found ! ELSE drop THEN ;

: fcov.hbk-find { f-a f-u -- bk|0 }
    f-a fcov.hbk-target-a !
    f-u fcov.hbk-target-u !
    0 fcov.hbk-found !
    ['] fcov.hbk-match-step fcov.hbk-list @ ulist-each
    fcov.hbk-found @ ;

: fcov.hbk-find-or-create { f-a f-u -- bk }
    f-a f-u fcov.hbk-find ?dup IF EXIT THEN
    fcov-hbk% allocate throw { bk }
    f-a f-u fcov.str-dup
    bk fcov.hbk-file-u !
    bk fcov.hbk-file-a !
    ulist-new bk fcov.hbk-recs !
    0 bk fcov.hbk-total !
    0 bk fcov.hbk-covered !
    bk fcov.hbk-list @ ulist-add
    bk ;

\ Walk fcov.recs once, fanning each record into its file-bucket. We
\ keep ALL records (not just colon-defs) in the bucket so the HTML
\ source renderer can decorate `variable foo`, `2constant bar`, …
\ but the per-file totals only count colon defs to stay in sync with
\ aggregate.4th's summary semantics.

: fcov.hbk-ingest ( rec -- )
    >r
    r@ fcov.rec-file@ fcov.hbk-find-or-create { bk }
    r@ bk fcov.hbk-recs @ ulist-add
    r@ fcov.rec-type@ s" colon" compare 0= IF
        1 bk fcov.hbk-total +!
        r@ fcov.rec-name@ fcov.hit-count@ 0> IF
            1 bk fcov.hbk-covered +!
        THEN
    THEN
    rdrop ;

: fcov.hbk-build
    fcov.hbk-clear
    ['] fcov.hbk-ingest fcov.recs-each
    fcov.hbk-list @ ulist-reverse ;   \ files in walk order

\ --- Output paths and shell helpers ---------------------------------------

\ Strip leading "./" from a relative path. Returns shifted view.
: fcov.html-strip-dotslash { a u -- a' u' }
    u 2 < IF a u EXIT THEN
    a c@ [char] . = a 1+ c@ [char] / = and IF
        a 2 + u 2 -
    ELSE
        a u
    THEN ;

\ Map a source path → output html path: .fcov/html/<path>.html
: fcov.html-out-path { a u -- buf bu }
    a u fcov.html-strip-dotslash { sa su }
    s" .fcov/html/" sa su fcov.str-concat { p1a p1u }
    p1a p1u s" .html" fcov.str-concat { p2a p2u }
    p1a free throw
    p2a p2u ;

\ Count "/" in a stripped path → directory depth.
: fcov.html-depth { a u -- n }
    0 u 0 ?do
        a i + c@ [char] / = IF 1+ THEN
    loop ;

\ Build a "../"·N relative prefix to root. Caller frees.
: fcov.html-rel-prefix { n -- a u }
    n 0= IF s" " fcov.str-dup EXIT THEN
    n 3 * allocate throw { buf }
    n 0 ?do
        s" ../" drop  buf i 3 * +  3 move
    loop
    buf n 3 * ;

\ Lop off the basename component, leaving "<dir>" (without trailing /).
\ Returns a 0-length string when there's no parent dir.
: fcov.html-dirname { a u -- a' u' }
    u 0 ?do
        u 1 - i - 1 -                      \ scan from the right
        dup a + c@ [char] / = IF
            a swap unloop EXIT
        ELSE drop THEN
    loop
    a 0 ;

: fcov.html-mkdir-parent { a u -- }
    a u fcov.html-dirname { d-a d-u }
    d-u 0= IF EXIT THEN
    d-a d-u fcov.str-dup { copy-a copy-u }
    copy-a copy-u fcov.mkdir-p ;

\ --- HTML / CSS helpers ---------------------------------------------------

variable fcov.hb-fid

: fcov.hb-emit ( a u -- ) fcov.hb-fid @ write-file throw ;

: fcov.hb-emit-c ( c -- )
    dup [char] < = IF drop s" &lt;"   fcov.hb-emit EXIT THEN
    dup [char] > = IF drop s" &gt;"   fcov.hb-emit EXIT THEN
    dup [char] & = IF drop s" &amp;"  fcov.hb-emit EXIT THEN
    dup [char] " = IF drop s" &quot;" fcov.hb-emit EXIT THEN
    pad c! pad 1 fcov.hb-emit ;

: fcov.hb-emit-escaped { a u -- }
    a u + a ?do i c@ fcov.hb-emit-c loop ;

: fcov.hb-emit-uint ( u -- )
    fcov.u>str fcov.hb-emit ;

\ Detect whole-line comment: first non-whitespace char is `\`.
: fcov.hb-line-is-comment? { a u -- f }
    u 0 ?do
        a i + c@ dup bl <> swap 9 <> and IF
            a i + c@ [char] \ =
            unloop EXIT
        THEN
    loop
    false ;

\ --- Per-file HTML page ---------------------------------------------------

\ Stash the current bucket so per-line callbacks can find their record.
variable fcov.hb-cur-bucket
variable fcov.hb-cur-line
variable fcov.hb-cur-rec        \ matched record for this line, or 0

: fcov.hb-rec-match-step ( rec -- )
    fcov.hb-cur-rec @ IF drop EXIT THEN
    dup fcov.rec-line@ fcov.hb-cur-line @ = IF
        fcov.hb-cur-rec !
    ELSE
        drop
    THEN ;

: fcov.hb-find-rec-for-line ( -- )
    0 fcov.hb-cur-rec !
    ['] fcov.hb-rec-match-step fcov.hb-cur-bucket @ fcov.hbk-recs @ ulist-each ;

\ Emit a single source line as a <tr>. line-num is 1-based.
: fcov.hb-emit-line { la lu line-num -- }
    line-num fcov.hb-cur-line !
    fcov.hb-find-rec-for-line
    fcov.hb-cur-rec @ { rec }

    s" <tr" fcov.hb-emit
    rec IF
        s" colon" rec fcov.rec-type@ compare 0= IF
            rec fcov.rec-name@ fcov.hit-count@ 0> IF
                s\"  class=\"def covered\""   fcov.hb-emit
            ELSE
                s\"  class=\"def uncovered\"" fcov.hb-emit
            THEN
        ELSE
            s\"  class=\"def other\""         fcov.hb-emit
        THEN
    THEN
    s\"  id=\"L" fcov.hb-emit  line-num fcov.hb-emit-uint  s\" \">" fcov.hb-emit

    \ line-number cell
    s\" <td class=\"ln\"><a href=\"#L" fcov.hb-emit
    line-num fcov.hb-emit-uint
    s\" \">" fcov.hb-emit
    line-num fcov.hb-emit-uint
    s" </a></td>" fcov.hb-emit

    \ hit-count cell
    s\" <td class=\"hits\">" fcov.hb-emit
    rec IF
        s" colon" rec fcov.rec-type@ compare 0= IF
            s" ×" fcov.hb-emit
            rec fcov.rec-name@ fcov.hit-count@ fcov.hb-emit-uint
        THEN
    THEN
    s" </td>" fcov.hb-emit

    \ source cell
    s\" <td class=\"code\"><pre>" fcov.hb-emit
    la lu fcov.hb-line-is-comment? IF
        s\" <span class=\"cmt\">" fcov.hb-emit
        la lu fcov.hb-emit-escaped
        s" </span>" fcov.hb-emit
    ELSE
        la lu fcov.hb-emit-escaped
    THEN
    s\" </pre></td></tr>\n" fcov.hb-emit ;

\ Iterate src-text line by line, emitting <tr>s.
: fcov.hb-emit-src { src su -- }
    src { line-start }
    1 { line-num }
    su 0 ?do
        src i + c@ 10 = IF
            line-start  src i + line-start -  line-num fcov.hb-emit-line
            src i + 1+ to line-start
            line-num 1+ to line-num
        THEN
    loop
    \ trailing line without final \n
    src su + line-start > IF
        line-start  src su + line-start -  line-num fcov.hb-emit-line
    THEN ;

\ Render one bucket → its dedicated HTML page.
: fcov.hb-render-bucket ( bk -- )
    dup fcov.hb-cur-bucket !
    dup fcov.hbk-file-a @ over fcov.hbk-file-u @ { sa su }

    \ Output path + parent dir
    sa su fcov.html-out-path { oa ou }
    oa ou fcov.html-mkdir-parent

    oa ou w/o create-file throw { fid }
    fid fcov.hb-fid !

    \ Document head
    s\" <!doctype html>\n<html lang=\"en\"><head><meta charset=\"utf-8\">\n" fcov.hb-emit
    s\" <title>fcov: " fcov.hb-emit
    sa su fcov.html-strip-dotslash fcov.hb-emit-escaped
    s\" </title>\n<link rel=\"stylesheet\" href=\"" fcov.hb-emit

    sa su fcov.html-strip-dotslash fcov.html-depth fcov.html-rel-prefix { rpa rpu }
    rpa rpu fcov.hb-emit
    s\" style.css\"></head><body>\n" fcov.hb-emit

    \ Header
    s\" <header><a class=\"back\" href=\"" fcov.hb-emit
    rpa rpu fcov.hb-emit
    s\" index.html\">← all files</a><h1>" fcov.hb-emit
    sa su fcov.html-strip-dotslash fcov.hb-emit-escaped
    s\" </h1><p class=\"stats\">" fcov.hb-emit
    dup fcov.hbk-covered @ fcov.hb-emit-uint
    s" / " fcov.hb-emit
    dup fcov.hbk-total @ fcov.hb-emit-uint
    s"  words covered (" fcov.hb-emit
    dup fcov.hbk-covered @ over fcov.hbk-total @ fcov.percent>str fcov.hb-emit
    s\" %)</p></header>\n" fcov.hb-emit
    drop

    \ Source as a table
    s\" <main><table class=\"src\">\n" fcov.hb-emit

    sa su slurp-file { src su2 }
    src su2 fcov.hb-emit-src
    src free throw

    s\" </table></main></body></html>\n" fcov.hb-emit

    fid close-file throw
    0 fcov.hb-fid !
    rpa free throw
    oa free throw ;

\ --- Index page -----------------------------------------------------------

variable fcov.hb-idx-words-total
variable fcov.hb-idx-words-covered

: fcov.hb-idx-row ( bk -- )
    s\"   <tr><td class=\"file\"><a href=\"" fcov.hb-emit
    dup fcov.hbk-file-a @ over fcov.hbk-file-u @
    fcov.html-strip-dotslash fcov.hb-emit-escaped
    s\" .html\">" fcov.hb-emit
    dup fcov.hbk-file-a @ over fcov.hbk-file-u @
    fcov.html-strip-dotslash fcov.hb-emit-escaped
    s" </a></td>" fcov.hb-emit

    s\" <td class=\"num\">" fcov.hb-emit
    dup fcov.hbk-covered @ fcov.hb-emit-uint
    s" / " fcov.hb-emit
    dup fcov.hbk-total @ fcov.hb-emit-uint
    s" </td>" fcov.hb-emit

    s\" <td class=\"num\">" fcov.hb-emit
    dup fcov.hbk-covered @ over fcov.hbk-total @ { c t }
    c t fcov.percent>str fcov.hb-emit
    s" %</td>" fcov.hb-emit

    s\" <td class=\"bar\"><progress value=\"" fcov.hb-emit
    c fcov.hb-emit-uint
    s\" \" max=\"" fcov.hb-emit
    t fcov.hb-emit-uint
    s\" \"></progress></td></tr>\n" fcov.hb-emit

    c fcov.hb-idx-words-covered +!
    t fcov.hb-idx-words-total   +!
    drop ;

: fcov.hb-write-index
    s" .fcov/html/index.html" w/o create-file throw { fid }
    fid fcov.hb-fid !

    s\" <!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">\n" fcov.hb-emit
    s\" <title>fcov coverage report</title>\n" fcov.hb-emit
    s\" <link rel=\"stylesheet\" href=\"style.css\"></head><body>\n" fcov.hb-emit
    s\" <header><h1>fcov coverage report</h1>\n" fcov.hb-emit
    s\" <p class=\"stats\">fcov v" fcov.hb-emit
    fcov-ver-data 2@ fcov.hb-emit-escaped
    s"  · word-level coverage (only colon-defs count toward the total)" fcov.hb-emit
    s\" </p></header>\n<main><table class=\"idx\">\n" fcov.hb-emit
    s\"   <thead><tr><th>File</th><th>Words</th><th>%</th><th></th></tr></thead>\n" fcov.hb-emit
    s\"   <tbody>\n" fcov.hb-emit

    0 fcov.hb-idx-words-total !
    0 fcov.hb-idx-words-covered !
    ['] fcov.hb-idx-row fcov.hbk-list @ ulist-each

    s\"   </tbody>\n" fcov.hb-emit
    s\"   <tfoot><tr><th>TOTAL</th><th>" fcov.hb-emit
    fcov.hb-idx-words-covered @ fcov.hb-emit-uint
    s" / " fcov.hb-emit
    fcov.hb-idx-words-total @ fcov.hb-emit-uint
    s\" </th><th>" fcov.hb-emit
    fcov.hb-idx-words-covered @ fcov.hb-idx-words-total @ fcov.percent>str fcov.hb-emit
    s\" %</th><th></th></tr></tfoot>\n" fcov.hb-emit
    s\" </table></main></body></html>\n" fcov.hb-emit

    fid close-file throw
    0 fcov.hb-fid ! ;

\ --- Stylesheet (single file, ~30 rules) ---------------------------------

: fcov.hb-write-css
    s" .fcov/html/style.css" w/o create-file throw { fid }
    s\" :root{--fg:#1f2328;--bg:#ffffff;--muted:#6e7781;--cmt:#6e7781;\n" fid write-file throw
    s\"   --hit:#1a7f37;--miss:#cf222e;--hit-bg:#dafbe1;--miss-bg:#ffebe9;\n" fid write-file throw
    s\"   --other-bg:#fff8c5;--ln:#8b949e;--rule:#d0d7de;--accent:#0969da;}\n" fid write-file throw
    s\" *{box-sizing:border-box}body{font:14px/1.4 -apple-system,Segoe UI,sans-serif;\n" fid write-file throw
    s\"   color:var(--fg);background:var(--bg);margin:0;padding:0}\n" fid write-file throw
    s\" header{padding:1rem 1.5rem;border-bottom:1px solid var(--rule)}\n" fid write-file throw
    s\" header h1{margin:.2rem 0;font-size:1.3rem;font-weight:600}\n" fid write-file throw
    s\" .stats{color:var(--muted);margin:.2rem 0}\n" fid write-file throw
    s\" .back{color:var(--accent);text-decoration:none;font-size:.9rem}\n" fid write-file throw
    s\" .back:hover{text-decoration:underline}\n" fid write-file throw
    s\" main{padding:1rem 1.5rem;max-width:1200px}\n" fid write-file throw
    s\" table{border-collapse:collapse;width:100%}\n" fid write-file throw
    s\" table.src{font:13px ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}\n" fid write-file throw
    s\" table.src td{padding:0;vertical-align:top;border:0}\n" fid write-file throw
    s\" table.src tr.def.covered{background:var(--hit-bg)}\n" fid write-file throw
    s\" table.src tr.def.uncovered{background:var(--miss-bg)}\n" fid write-file throw
    s\" table.src tr.def.other{background:var(--other-bg)}\n" fid write-file throw
    s\" td.ln{color:var(--ln);text-align:right;padding:0 .8rem;user-select:none;\n" fid write-file throw
    s\"   border-right:1px solid var(--rule);width:4em}\n" fid write-file throw
    s\" td.ln a{color:var(--ln);text-decoration:none}\n" fid write-file throw
    s\" td.hits{color:var(--muted);text-align:right;padding:0 .6rem;width:4em;\n" fid write-file throw
    s\"   border-right:1px solid var(--rule)}\n" fid write-file throw
    s\" tr.def.covered td.hits{color:var(--hit);font-weight:600}\n" fid write-file throw
    s\" tr.def.uncovered td.hits{color:var(--miss);font-weight:600}\n" fid write-file throw
    s\" td.code{padding:0 .6rem}td.code pre{margin:0;white-space:pre-wrap}\n" fid write-file throw
    s\" .cmt{color:var(--cmt);font-style:italic}\n" fid write-file throw
    s\" table.idx{margin-top:1rem}table.idx th,table.idx td{text-align:left;\n" fid write-file throw
    s\"   padding:.4rem .8rem;border-bottom:1px solid var(--rule)}\n" fid write-file throw
    s\" table.idx td.num,table.idx th:nth-child(2),table.idx th:nth-child(3){text-align:right}\n" fid write-file throw
    s\" table.idx tfoot th{font-weight:700}\n" fid write-file throw
    s\" table.idx td.file a{color:var(--accent);text-decoration:none}\n" fid write-file throw
    s\" table.idx td.file a:hover{text-decoration:underline}\n" fid write-file throw
    s\" td.bar progress{width:160px;height:.7rem}\n" fid write-file throw
    fid close-file throw ;

\ --- Top-level entry point ------------------------------------------------

: fcov.report-html
    s" .fcov/html"      fcov.mkdir-p
    fcov.hbk-build
    fcov.hb-write-css
    ['] fcov.hb-render-bucket fcov.hbk-list @ ulist-each
    fcov.hb-write-index
    cr s" * fcov: HTML report written to .fcov/html/index.html" type cr ;
