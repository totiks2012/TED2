#!/usr/bin/wish
#
# syntax_basic.tcl - Базовая подсветка с автоматическим определением языка
# Created: 2025-05-07 10:08:32 by totiks2012
# Обновлен 2025-05-13 19:12 
#
# Исходная подсветка для tcl, sh
# Добавлена подсветка для C, C++, Python и Lua

namespace eval ::plugin::syntax_basic {
    variable initialized 0

    proc init {} {
        variable initialized
        if {$initialized} {
            return 1
        }
        bind .tabs <<NotebookTabChanged>> ::plugin::syntax_basic::tab_changed

        if {[info commands ::core::create_tab] ne ""} {
            rename ::core::create_tab ::core::create_tab_original
            proc ::core::create_tab {args} {
                set tab [uplevel 1 [list ::core::create_tab_original {*}$args]]
                if {$tab ne "" && [winfo exists $tab]} {
                    after idle [list ::plugin::syntax_basic::highlight_tab $tab]
                }
                return $tab
            }
        }

        if {[winfo exists .menubar]} {
            if {![winfo exists .menubar.tools]} {
                menu .menubar.tools -tearoff 0
                .menubar add cascade -label "Инструменты" -menu .menubar.tools
            }
            if {![winfo exists .menubar.tools.clear_syntax]} {
                .menubar.tools add command -label "Очистить подсветку синтаксиса" \
                    -command ::plugin::syntax_basic::clear_highlight
            }
        }

        set initialized 1
        foreach tab [.tabs tabs] {
            highlight_tab $tab
        }
        return 1
    }

    proc tab_changed {} {
        set tab [.tabs select]
        if {$tab ne "" && [winfo exists $tab.text]} {
            highlight_tab $tab
        }
    }

    proc highlight_tab {tab} {
        if {$tab eq "" || ![winfo exists $tab.text]} {
            return
        }
        set language [detect_language $tab]
        if {$language eq "tcl"} {
            highlight_tcl_full_internal $tab.text
        } elseif {$language eq "bash"} {
            highlight_bash_full_internal $tab.text
        } elseif {$language eq "c"} {
            highlight_c_full_internal $tab.text
        } elseif {$language eq "cpp"} {
            highlight_cpp_full_internal $tab.text
        } elseif {$language eq "python"} {
            highlight_python_full_internal $tab.text
        } elseif {$language eq "lua"} {
            highlight_lua_full_internal $tab.text
        }
    }

    proc detect_language {tab} {
        if {[info exists ::core::tab_files($tab)]} {
            set filepath $::core::tab_files($tab)
            set extension [string tolower [file extension $filepath]]
            switch -- $extension {
                ".tcl" - ".tk" { return "tcl" }
                ".sh" - ".bash" { return "bash" }
                ".c" { return "c" }
                ".h" { return "c" }
                ".cpp" - ".cxx" - ".cc" { return "cpp" }
                ".py" { return "python" }
                ".lua" { return "lua" }
                default { return [detect_language_by_content $tab.text] }
            }
        } else {
            return [detect_language_by_content $tab.text]
        }
    }

    proc detect_language_by_content {text_widget} {
        set content [$text_widget get 1.0 "10.0"]
        if {[regexp {^\s*#!\s*(/usr/bin/|/bin/|/usr/local/bin/)(tclsh|wish)} $content] || 
            [regexp {\s(proc|namespace\s+eval|package\s+require)\s} $content]} {
            return "tcl"
        }
        if {[regexp {^\s*#!\s*(/usr/bin/|/bin/|/usr/local/bin/)(bash|sh)} $content] || 
            [regexp {\s(function\s+\w+\s*\(\)|\$\(\(|\[\[)} $content]} {
            return "bash"
        }
        if {[regexp {^\s*#include\s*[<"].+[>"]} $content]} { return "c" }
        if {[regexp {^\s*def\s+\w+\(.*\):} $content] || [regexp {^\s*import\s+\w+} $content]} { return "python" }
        if {[regexp {^\s*--} $content] || [regexp {^\s*function\s+\w+} $content]} { return "lua" }
        return ""
    }

    proc prepare_tags {text_widget} {
        catch {$text_widget tag delete keyword}
        catch {$text_widget tag delete comment}
        catch {$text_widget tag delete variable}
        catch {$text_widget tag delete string}
        if {[info exists ::core::config(theme)] && $::core::config(theme) eq "dark"} {
            $text_widget tag configure keyword -foreground "#F76D14"
            $text_widget tag configure comment -foreground "#828997"
            $text_widget tag configure variable -foreground "#E5C07B"
            $text_widget tag configure string -foreground "#98C379"
        } else {
            $text_widget tag configure keyword -foreground "#0550AE"
            $text_widget tag configure comment -foreground "#5F6368"
            $text_widget tag configure variable -foreground "#A05A00"
            $text_widget tag configure string -foreground "#188038"
        }
    }

    #######################################################################
    # Подсветка для Tcl
    #######################################################################
    proc highlight_tcl_full_internal {text_widget} {
        prepare_tags $text_widget
        clear_tags $text_widget
        highlight_tcl_strings_internal $text_widget
        highlight_tcl_comments_internal $text_widget
        highlight_tcl_keywords_internal $text_widget
        highlight_tcl_variables_internal $text_widget
    }
    proc highlight_tcl_keywords_internal {text_widget} {
        set keywords {
            proc if else elseif for foreach while switch continue break
            set return global namespace package array dict list catch
            error throw try finally upvar uplevel variable eval exec
            expr format scan string info clock after vwait update
        }
        foreach keyword $keywords {
            highlight_word $text_widget $keyword keyword
        }
    }
    proc highlight_tcl_comments_internal {text_widget} {
        set pos 1.0
        while {1} {
            set pos [$text_widget search -regexp {[^\\]#|^#} $pos end]
            if {$pos eq ""} { break }
            set line_start [$text_widget index "$pos linestart"]
            set line_end [$text_widget index "$pos lineend"]
            if {![is_inside_string $text_widget $pos]} {
                $text_widget tag add comment $pos $line_end
            }
            set pos [$text_widget index "$line_end + 1 char"]
        }
    }
    proc highlight_tcl_variables_internal {text_widget} {
        set pos 1.0
        while {1} {
            set pos [$text_widget search "$" $pos end]
            if {$pos eq ""} { break }
            if {![is_inside_comment $text_widget $pos]} {
                set line_end [$text_widget index "$pos lineend"]
                set line_text [$text_widget get $pos $line_end]
                if {[regexp {^\$([a-zA-Z0-9_:()]+)} $line_text -> varname]} {
                    set var_end [$text_widget index "$pos + [string length $varname] chars + 1 char"]
                    $text_widget tag add variable $pos $var_end
                    set pos $var_end
                } else {
                    set pos [$text_widget index "$pos + 1 char"]
                }
            } else {
                set pos [$text_widget index "$pos + 1 char"]
            }
        }
    }
    proc highlight_tcl_strings_internal {text_widget} {
        set pos 1.0
        while {1} {
            set start_pos [$text_widget search -regexp {(^|[^\\])"} $pos end]
            if {$start_pos eq ""} { break }
            if {[string index [$text_widget get $start_pos [format "%s + 1 char" $start_pos]] 0] ne "\""} {
                set start_pos [$text_widget index "$start_pos + 1 char"]
            }
            set search_pos [format "%s + 1 char" $start_pos]
            set end_pos ""
            while {1} {
                set candidate [$text_widget search "\"" $search_pos end]
                if {$candidate eq ""} {
                    set end_pos [$text_widget index "$start_pos lineend"]
                    break
                }
                if {[string index [$text_widget get [format "%s - 1 char" $candidate] $candidate] 0] ne "\\"} {
                    set end_pos [$text_widget index "$candidate + 1 char"]
                    break
                }
                set search_pos [format "%s + 1 char" $candidate]
            }
            $text_widget tag add string $start_pos $end_pos
            set pos $end_pos
        }
    }

    #######################################################################
    # Подсветка для Bash
    #######################################################################
    proc highlight_bash_full_internal {text_widget} {
        prepare_tags $text_widget
        clear_tags $text_widget
        highlight_bash_strings_internal $text_widget
        highlight_bash_comments_internal $text_widget
        highlight_bash_keywords_internal $text_widget
        highlight_bash_variables_internal $text_widget
    }
    proc highlight_bash_keywords_internal {text_widget} {
        set keywords {
            if then else elif fi for while until do done
            case esac function return exit break continue
            shift source let declare local readonly export
        }
        foreach keyword $keywords {
            highlight_word $text_widget $keyword keyword
        }
    }
    proc highlight_bash_comments_internal {text_widget} {
        set pos 1.0
        while {1} {
            set pos [$text_widget search -regexp {[^\\]#|^#} $pos end]
            if {$pos eq ""} { break }
            set line_start [$text_widget index "$pos linestart"]
            set line_end [$text_widget index "$pos lineend"]
            if {![is_inside_string $text_widget $pos]} {
                $text_widget tag add comment $pos $line_end
            }
            set pos [$text_widget index "$line_end + 1 char"]
        }
    }
    proc highlight_bash_variables_internal {text_widget} {
        set pos 1.0
        while {1} {
            set pos [$text_widget search "$" $pos end]
            if {$pos eq ""} { break }
            if {![is_inside_comment $text_widget $pos]} {
                set line_end [$text_widget index "$pos lineend"]
                set line_text [$text_widget get $pos $line_end]
                if {[regexp {^\$([a-zA-Z0-9_{}]+)} $line_text -> varname]} {
                    set var_end [$text_widget index "$pos + [string length $varname] chars + 1 char"]
                    $text_widget tag add variable $pos $var_end
                    set pos $var_end
                } else {
                    set pos [$text_widget index "$pos + 1 char"]
                }
            } else {
                set pos [$text_widget index "$pos + 1 char"]
            }
        }
    }
    proc highlight_bash_strings_internal {text_widget} {
        highlight_tcl_strings_internal $text_widget
    }

    #######################################################################
    # Подсветка для C и C++
    #######################################################################
    proc highlight_c_full_internal {text_widget} {
        prepare_tags $text_widget
        clear_tags $text_widget
        highlight_c_strings_internal $text_widget
        highlight_c_comments_internal $text_widget
        highlight_c_keywords_internal $text_widget
    }
    proc highlight_cpp_full_internal {text_widget} {
        prepare_tags $text_widget
        clear_tags $text_widget
        highlight_c_strings_internal $text_widget
        highlight_c_comments_internal $text_widget
        highlight_c_keywords_internal $text_widget
        highlight_cpp_keywords_internal $text_widget
    }
    proc highlight_c_keywords_internal {text_widget} {
        set keywords {
            int char float double void struct union enum typedef size_t
            if else for while do return switch case default break continue
            const static extern volatile inline
        }
        foreach keyword $keywords {
            highlight_word $text_widget $keyword keyword
        }
    }
    proc highlight_cpp_keywords_internal {text_widget} {
        set keywords {
            namespace using std public private protected class template throw catch try
            new delete operator this virtual friend explicit
        }
        foreach keyword $keywords {
            highlight_word $text_widget $keyword keyword
        }
    }
    proc highlight_c_comments_internal {text_widget} {
        set pos 1.0
        while {1} {
            set pos [$text_widget search "//" $pos end]
            if {$pos eq ""} { break }
            set line_end [$text_widget index "$pos lineend"]
            $text_widget tag add comment $pos $line_end
            set pos [$text_widget index "$line_end + 1 char"]
        }
        set pos 1.0
        while {1} {
            set start [$text_widget search "/*" $pos end]
            if {$start eq ""} { break }
            set end [$text_widget search "*/" $start end]
            if {$end eq ""} {
                set end [$text_widget index "end"]
            } else {
                set end [$text_widget index "$end + 2 chars"]
            }
            $text_widget tag add comment $start $end
            set pos $end
        }
    }
    proc highlight_c_strings_internal {text_widget} {
        set pos 1.0
        while {1} {
            set start_pos [$text_widget search -regexp {["']} $pos end]
            if {$start_pos eq ""} { break }
            set quote [$text_widget get $start_pos "$start_pos + 1 char"]
            set triple [$text_widget get $start_pos [format "%s + 2 chars" $start_pos]]
            if {$triple eq [string repeat $quote 3]} {
                set end_pos [$text_widget search [string repeat $quote 3] [format "%s + 3 char" $start_pos] end]
                if {$end_pos eq ""} {
                    set end_pos [$text_widget index "$start_pos lineend"]
                } else {
                    set end_pos [$text_widget index "$end_pos + 3 chars"]
                }
            } else {
                set end_pos [$text_widget search $quote [format "%s + 1 char" $start_pos] end]
                if {$end_pos eq ""} {
                    set end_pos [$text_widget index "$start_pos lineend"]
                } else {
                    set end_pos [$text_widget index "$end_pos + 1 char"]
                }
            }
            $text_widget tag add string $start_pos $end_pos
            set pos $end_pos
        }
    }

    #######################################################################
    # Подсветка для Python
    #######################################################################
    proc highlight_python_full_internal {text_widget} {
        prepare_tags $text_widget
        clear_tags $text_widget
        highlight_python_strings_internal $text_widget
        highlight_python_comments_internal $text_widget
        highlight_python_keywords_internal $text_widget
    }
    proc highlight_python_keywords_internal {text_widget} {
        set keywords {
            def class if elif else for while try except finally with as lambda
            import from return yield break continue pass global nonlocal assert
            True False None
        }
        foreach keyword $keywords {
            highlight_word $text_widget $keyword keyword
        }
    }
    proc highlight_python_comments_internal {text_widget} {
        set pos 1.0
        while {1} {
            set pos [$text_widget search "#" $pos end]
            if {$pos eq ""} { break }
            set line_end [$text_widget index "$pos lineend"]
            $text_widget tag add comment $pos $line_end
            set pos [$text_widget index "$line_end + 1 char"]
        }
    }
    proc highlight_python_strings_internal {text_widget} {
        set pos 1.0
        while {1} {
            set start_pos [$text_widget search -regexp {['"]} $pos end]
            if {$start_pos eq ""} { break }
            set quote [$text_widget get $start_pos "$start_pos + 1 char"]
            set triple [$text_widget get $start_pos [format "%s + 2 chars" $start_pos]]
            if {$triple eq [string repeat $quote 3]} {
                set end_pos [$text_widget search [string repeat $quote 3] [format "%s + 3 char" $start_pos] end]
                if {$end_pos eq ""} {
                    set end_pos [$text_widget index "$start_pos lineend"]
                } else {
                    set end_pos [$text_widget index "$end_pos + 3 chars"]
                }
            } else {
                set end_pos [$text_widget search $quote [format "%s + 1 char" $start_pos] end]
                if {$end_pos eq ""} {
                    set end_pos [$text_widget index "$start_pos lineend"]
                } else {
                    set end_pos [$text_widget index "$end_pos + 1 char"]
                }
            }
            $text_widget tag add string $start_pos $end_pos
            set pos $end_pos
        }
    }

    #######################################################################
    # Подсветка для Lua
    #######################################################################
    proc highlight_lua_full_internal {text_widget} {
        prepare_tags $text_widget
        clear_tags $text_widget
        highlight_lua_strings_internal $text_widget
        highlight_lua_comments_internal $text_widget
        highlight_lua_keywords_internal $text_widget
    }
    proc highlight_lua_keywords_internal {text_widget} {
        set keywords {
            function local if then else elseif end for while do repeat until return break
        }
        foreach keyword $keywords {
            highlight_word $text_widget $keyword keyword
        }
    }
    proc highlight_lua_comments_internal {text_widget} {
        # Однострочные комментарии (начинаются с --)
        set pos 1.0
        while {1} {
            set pos [$text_widget search -exact -- {--} $pos end]
            if {$pos eq ""} { break }
            set line_end [$text_widget index "$pos lineend"]
            $text_widget tag add comment $pos $line_end
            set pos [$text_widget index "$line_end + 1 char"]
        }
        # Многострочные комментарии (--[[ ... ]])
        set pos 1.0
        while {1} {
            set start [$text_widget search -exact -- {--[[} $pos end]
            if {$start eq ""} { break }
            set end [$text_widget search -exact -- {]]} $start end]
            if {$end eq ""} {
                set end [$text_widget index "end"]
            } else {
                set end [$text_widget index "$end + 2 chars"]
            }
            $text_widget tag add comment $start $end
            set pos $end
        }
    }
    proc highlight_lua_strings_internal {text_widget} {
        set pos 1.0
        while {1} {
            set start_pos [$text_widget search -regexp {["']} $pos end]
            if {$start_pos eq ""} { break }
            set quote [$text_widget get $start_pos "$start_pos + 1 char"]
            set end_pos [$text_widget search $quote [format "%s + 1 char" $start_pos] end]
            if {$end_pos eq ""} {
                set end_pos [$text_widget index "$start_pos lineend"]
            } else {
                set end_pos [$text_widget index "$end_pos + 1 char"]
            }
            $text_widget tag add string $start_pos $end_pos
            set pos $end_pos
        }
    }

    #######################################################################
    # Общие процедуры подсветки и проверки контекста
    #######################################################################
    proc highlight_word {text_widget word tag_name} {
        set pos 1.0
        while {1} {
            set pos [$text_widget search -nocase -exact $word $pos end]
            if {$pos eq ""} { break }
            if {![is_inside_comment $text_widget $pos] && ![is_inside_string $text_widget $pos]} {
                set char_before ""
                if {[$text_widget compare $pos > "1.0"]} {
                    set char_before_pos [$text_widget index "$pos - 1 char"]
                    set char_before [$text_widget get $char_before_pos $pos]
                }
                set word_end [$text_widget index "$pos + [string length $word] chars"]
                set char_after [$text_widget get $word_end "$word_end + 1 char"]
                if {($char_before eq "" || (![string is alnum $char_before] && $char_before ne "_")) &&
                    ($char_after eq "" || (![string is alnum $char_after] && $char_after ne "_"))} {
                    $text_widget tag add $tag_name $pos $word_end
                }
            }
            set pos [$text_widget index "$pos + [string length $word] chars"]
        }
    }

    proc clear_tags {text_widget} {
        $text_widget tag remove keyword 1.0 end
        $text_widget tag remove comment 1.0 end
        $text_widget tag remove variable 1.0 end
        $text_widget tag remove string 1.0 end
    }

    proc clear_highlight {} {
        set tab [.tabs select]
        if {$tab eq "" || ![winfo exists $tab.text]} {
            return
        }
        clear_tags $tab.text
    }

    proc is_inside_string {text_widget pos} {
        set line_num [lindex [split [$text_widget index $pos] .] 0]
        set line_start "$line_num.0"
        set text_before [$text_widget get $line_start $pos]
        set count 0
        set in_escape 0
        for {set i 0} {$i < [string length $text_before]} {incr i} {
            set char [string index $text_before $i]
            if {$char eq "\\" && !$in_escape} {
                set in_escape 1
                continue
            }
            if {$char eq "\"" && !$in_escape} {
                incr count
            }
            set in_escape 0
        }
        return [expr {$count % 2 == 1}]
    }

    proc is_inside_comment {text_widget pos} {
        set line_num [lindex [split [$text_widget index $pos] .] 0]
        set line_start "$line_num.0"
        set text_before [$text_widget get $line_start $pos]
        set comment_pos [string first "#" $text_before]
        if {$comment_pos == -1} { return 0 }
        if {$comment_pos > 0 && [string index $text_before [expr {$comment_pos - 1}]] eq "\\"} {
            return 0
        }
        set count_quotes 0
        for {set i 0} {$i < $comment_pos} {incr i} {
            set char [string index $text_before $i]
            if {$char eq "\"" && ($i == 0 || [string index $text_before [expr {$i - 1}]] ne "\\")} {
                incr count_quotes
            }
        }
        return [expr {$count_quotes % 2 == 0 && $comment_pos >= 0}]
    }

    proc text_modified {tab} {
        if {$tab eq "" || ![winfo exists $tab.text]} {
            return
        }
        set language [detect_language $tab]
        if {$language eq "tcl"} {
            highlight_tcl_full_internal $tab.text
        } elseif {$language eq "bash"} {
            highlight_bash_full_internal $tab.text
        } elseif {$language eq "c"} {
            highlight_c_full_internal $tab.text
        } elseif {$language eq "cpp"} {
            highlight_cpp_full_internal $tab.text
        } elseif {$language eq "python"} {
            highlight_python_full_internal $tab.text
        } elseif {$language eq "lua"} {
            highlight_lua_full_internal $tab.text
        }
    }
}

::plugin::syntax_basic::init
