#!/usr/bin/wish
# syntax_basic.tcl - Подсветка синтаксиса (regex + расширенный маппинг языков)

namespace eval ::plugin::syntax_basic {
    variable initialized 0

    proc init {} {
        variable initialized
        if {$initialized} { return 1 }
        
        if {[winfo exists .tabs]} {
            bind .tabs <<NotebookTabChanged>> ::plugin::syntax_basic::tab_changed
        }

        if {[info commands ::core::create_tab] ne ""} {
            if {[info commands ::core::create_tab_original] eq ""} {
                rename ::core::create_tab ::core::create_tab_original
                proc ::core::create_tab {args} {
                    set tab [uplevel 1 [list ::core::create_tab_original {*}$args]]
                    if {$tab ne "" && [winfo exists $tab.text]} {
                        after idle [list ::plugin::syntax_basic::highlight_tab $tab]
                    }
                    return $tab
                }
            }
        }
        set initialized 1
        return 1
    }

    proc prepare_tags {text_widget} {
        $text_widget tag configure keyword -foreground "#569CD6" -font {Courier 12 bold}
        $text_widget tag configure comment -foreground "#6A9955" -font {Courier 12 italic}
        $text_widget tag configure string  -foreground "#CE9178"
        $text_widget tag configure number  -foreground "#B5CEA8"
        $text_widget tag configure var     -foreground "#9CDCFE"
        $text_widget tag configure proc    -foreground "#DCDCAA"
        
        $text_widget tag raise keyword
        $text_widget tag raise string
        $text_widget tag raise comment
    }

    proc highlight_tab {tab} {
        if {$tab eq "" || ![winfo exists $tab.text]} return
        set w $tab.text
        set lang [detect_language $tab]
        
        prepare_tags $w
        
        foreach tag {keyword comment string number var proc} {
            $w tag remove $tag 1.0 end
        }

        # Общие правила (Строки и Числа)
        highlight_by_regexp $w {"[^"\\]*(\\.[^"\\]*)*"} string
        highlight_by_regexp $w {\y\d+(\.\d+)?\y} number

        switch -- $lang {
            "tcl"    { highlight_tcl $w }
            "python" { highlight_python $w }
            "c"      { highlight_c $w }
            "cpp"    { highlight_c $w }
            "js"     { highlight_js $w }
            "html"   { highlight_html $w }
            "sql"    { highlight_sql $w }
            "bash"   { highlight_bash $w }
        }
    }

    proc highlight_by_regexp {w regexp tag} {
        set pos 1.0
        while {[set pos [$w search -count c -regexp $regexp $pos end]] ne ""} {
            $w tag add $tag $pos "$pos + $c chars"
            set pos "$pos + $c chars"
        }
    }

    proc highlight_tcl {w} {
        set keys {\y(proc|if|else|elseif|for|foreach|while|return|set|global|namespace|switch|bind|pack|grid|destroy|exit|after|puts|read|open|close|eval|uplevel|upvar|variable|array|dict|lappend|lreplace|lindex|llength|split|join|string|expr|incr|append|format|scan|subst|regexp|regsub|catch|throw|error|info|interp|trace|file|exec|source|package|list|concat)\y}
        highlight_by_regexp $w $keys keyword
        highlight_by_regexp $w {^\s*#.*} comment
        highlight_by_regexp $w {;\s*#.*} comment
        highlight_by_regexp $w {\$[a-zA-Z0-9_:()]+} var
        highlight_by_regexp $w {\yproc\s+([a-zA-Z0-9_:]+)} proc
    }

    proc highlight_python {w} {
        set keys {\y(def|class|if|elif|else|for|while|import|from|return|try|except|finally|lambda|with|as|None|True|False|pass|break|continue|in|is|not|and|or|raise|yield|async|await|print|range|len|self|__init__)\y}
        highlight_by_regexp $w $keys keyword
        highlight_by_regexp $w {#.*} comment
        highlight_by_regexp $w {'[^']*'} string
        highlight_by_regexp $w {""".*?"""} string
        highlight_by_regexp $w {@[a-zA-Z0-9_.]+} var
        highlight_by_regexp $w {\ydef\s+([a-zA-Z0-9_]+)} proc
    }

    proc highlight_c {w} {
        set keys {\y(int|char|float|double|void|if|else|for|while|return|struct|switch|case|break|continue|typedef|static|extern|volatile|unsigned|signed|include|define|sizeof|enum|union|const|long|short|auto|register|do|default|goto)\y}
        highlight_by_regexp $w $keys keyword
        highlight_by_regexp $w {//.*} comment
        highlight_by_regexp $w {/\*.*?\*/} comment
        highlight_by_regexp $w {^#.*} proc
    }

    proc highlight_js {w} {
        set keys {\y(function|var|let|const|if|else|for|while|return|class|import|export|from|try|catch|finally|throw|async|await|new|this|typeof|instanceof|switch|case|break|continue|do|of|in|true|false|null|undefined|NaN|console|require|module|Promise|Map|Set)\y}
        highlight_by_regexp $w $keys keyword
        highlight_by_regexp $w {//.*} comment
        highlight_by_regexp $w {/\*.*?\*/} comment
    }

    proc highlight_html {w} {
        highlight_by_regexp $w {</?[a-zA-Z][^>]*>} keyword
        highlight_by_regexp $w {<!--.*?-->} comment
    }

    proc highlight_sql {w} {
        set keys {\y(SELECT|FROM|WHERE|INSERT|INTO|VALUES|UPDATE|SET|DELETE|CREATE|TABLE|ALTER|DROP|INDEX|JOIN|LEFT|RIGHT|INNER|OUTER|ON|AND|OR|NOT|IN|LIKE|BETWEEN|IS|NULL|AS|ORDER|BY|GROUP|HAVING|LIMIT|OFFSET|UNION|ALL|DISTINCT|COUNT|SUM|AVG|MIN|MAX|EXISTS|CASE|WHEN|THEN|ELSE|END|BEGIN|COMMIT|ROLLBACK|PRIMARY|KEY|FOREIGN|REFERENCES|CASCADE|INT|VARCHAR|TEXT|BOOLEAN|DATE|FLOAT)\y}
        highlight_by_regexp $w $keys keyword
        highlight_by_regexp $w {--.*} comment
        highlight_by_regexp $w {/\*.*?\*/} comment
    }

    proc highlight_bash {w} {
        set keys {\y(if|then|else|elif|fi|for|while|do|done|case|esac|function|return|exit|export|source|local|echo|read|set|unset|shift|trap|exec|test|let|declare|typeset|select|until|in)\y}
        highlight_by_regexp $w $keys keyword
        highlight_by_regexp $w {#.*} comment
        highlight_by_regexp $w {\$[a-zA-Z0-9_{}]+} var
    }

    proc detect_language {tab} {
        if {[info exists ::core::tab_files($tab)]} {
            set ext [string tolower [file extension $::core::tab_files($tab)]]
            switch -- $ext {
                ".tcl" - ".tk"     { return "tcl" }
                ".py" - ".pyw"     { return "python" }
                ".c" - ".h"        { return "c" }
                ".cpp" - ".hpp" - ".cc" - ".cxx" { return "cpp" }
                ".js" - ".ts"      { return "js" }
                ".html" - ".htm"   { return "html" }
                ".sql"             { return "sql" }
                ".sh" - ".bash"    { return "bash" }
                ".java"            { return "c" }
                ".rb"              { return "python" }
                ".css"             { return "html" }
                ".php"             { return "html" }
                ".xml"             { return "html" }
                default            { return "tcl" }
            }
        }
        return "tcl"
    }

    proc tab_changed {} {
        set current_tab [.tabs select]
        if {$current_tab ne ""} { highlight_tab $current_tab }
    }
}

::plugin::syntax_basic::init
