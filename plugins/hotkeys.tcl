# hotkeys.tcl - Плагин для настройки основных горячих клавиш редактора
# Created: 2025-05-07 11:28:45 by totiks2012
# Updated: 2025-05-08 for stable block Undo/Redo functionality

namespace eval ::plugin::hotkeys {
    # Описание плагина
    variable plugin_info
    array set plugin_info {
        name "Editor Hotkeys"
        version "1.2"
        description "Настройка горячих клавиш редактора с надежным Undo/Redo для блочных операций"
        author "totiks2012"
    }
    
    # Переменная для отслеживания инициализации
    variable initialized 0
    
    # Список текстовых виджетов с установленными привязками
    variable bound_widgets
    array set bound_widgets {}
    
    # Массивы для хранения истории изменений
    variable char_stack
    array set char_stack {}
    
    # Массивы для хранения истории для повтора
    variable redo_stack
    array set redo_stack {}
    
    # Отладочная переменная (включить для диагностики)
    variable debug 0
    
    # Инициализация плагина
    proc init {} {
        variable initialized
        
        if {$initialized} {
            return 1
        }
        
        setup_text_class_bindings
        setup_common_hotkeys
        setup_file_hotkeys
        setup_search_hotkeys
        
        bind .tabs <<NotebookTabChanged>> {
            set tab [.tabs select]
            if {$tab ne "" && [winfo exists $tab.text]} {
                ::plugin::hotkeys::apply_to_text_widget $tab.text
            }
        }
        
        apply_to_all_text_widgets
        bind_tab_switching
        
        puts "Плагин горячих клавиш инициализирован (версия $::plugin::hotkeys::plugin_info(version))"
        set initialized 1
        
        after 1000 ::plugin::hotkeys::reapply_hotkeys_periodically
        return 1
    }
    
    # Периодическая проверка и применение привязок
    proc reapply_hotkeys_periodically {} {
        apply_to_all_text_widgets
        bind_tab_switching
        after 5000 ::plugin::hotkeys::reapply_hotkeys_periodically
    }
    
    # Привязки для переключения вкладок
    proc bind_tab_switching {} {
        foreach tag [list . all Text] {
            catch {bind $tag <Control-Tab> ""}
            catch {bind $tag <Control-Key-Tab> ""}
            catch {bind $tag <Control-Shift-Tab> ""}
            catch {bind $tag <Control-Shift-Key-Tab> ""}
        }
        
        event add <<NextTab>> <Control-Tab> <Control-Page_Down>
        event add <<PrevTab>> <Control-Shift-Tab> <Control-Page_Up>
        
        bind . <<NextTab>> ::plugin::hotkeys::next_tab
        bind . <<PrevTab>> ::plugin::hotkeys::prev_tab
    }
    
    # Переключение на следующую вкладку
    proc next_tab {} {
        if {[winfo exists .tabs]} {
            set tabs [.tabs tabs]
            if {[llength $tabs] > 1} {
                set current [.tabs index [.tabs select]]
                set next [expr {($current + 1) % [llength $tabs]}]
                .tabs select [lindex $tabs $next]
            }
        }
        return -code break
    }
    
    # Переключение на предыдущую вкладку
    proc prev_tab {} {
        if {[winfo exists .tabs]} {
            set tabs [.tabs tabs]
            if {[llength $tabs] > 1} {
                set current [.tabs index [.tabs select]]
                set prev [expr {($current - 1 + [llength $tabs]) % [llength $tabs]}]
                .tabs select [lindex $tabs $prev]
            }
        }
        return -code break
    }
    
    # Инициализация стеков
    proc init_char_stacks {widget} {
        variable char_stack
        variable redo_stack
        
        if {![info exists char_stack($widget)]} {
            set char_stack($widget) [list]
        }
        if {![info exists redo_stack($widget)]} {
            set redo_stack($widget) [list]
        }
    }
    
    # Добавление действия в стек истории
    proc push_char {widget action_type text start_pos {end_pos ""}} {
        variable char_stack
        variable redo_stack
        variable debug
        
        init_char_stacks $widget
        
        set timestamp [clock milliseconds]
        set action [list $action_type $text $start_pos $end_pos $timestamp]
        
        # Простая группировка для последовательных вставок/удалений
        if {[llength $char_stack($widget)] > 0} {
            set last_action [lindex $char_stack($widget) end]
            set last_type [lindex $last_action 0]
            set last_text [lindex $last_action 1]
            set last_start [lindex $last_action 2]
            set last_end [lindex $last_action 3]
            set last_time [lindex $last_action 4]
            
            if {$last_type eq $action_type && [expr {$timestamp - $last_time}] < 500 && 
                $action_type in {insert delete} && $last_end eq $start_pos} {
                if {$action_type eq "insert"} {
                    set combined_text "$last_text$text"
                    set char_stack($widget) [lreplace $char_stack($widget) end end \
                        [list $action_type $combined_text $last_start $end_pos $timestamp]]
                    if {$debug} { puts "Grouped insert: $combined_text at $last_start" }
                    set redo_stack($widget) [list]
                    return
                } elseif {$action_type eq "delete"} {
                    set combined_text "$text$last_text"
                    set char_stack($widget) [lreplace $char_stack($widget) end end \
                        [list $action_type $combined_text $start_pos $last_end $timestamp]]
                    if {$debug} { puts "Grouped delete: $combined_text from $start_pos to $last_end" }
                    set redo_stack($widget) [list]
                    return
                }
            }
        }
        
        lappend char_stack($widget) $action
        set redo_stack($widget) [list]
        
        if {$debug} { puts "Pushed $action_type: '$text' at $start_pos (end: $end_pos)" }
        
        if {[llength $char_stack($widget)] > 10000} {
            set char_stack($widget) [lrange $char_stack($widget) end-9999 end]
        }
    }
    
    # Отмена последнего действия
    proc undo_char {widget} {
        variable char_stack
        variable redo_stack
        variable debug
        
        init_char_stacks $widget
        
        if {[llength $char_stack($widget)] == 0} {
            if {$debug} { puts "Undo: Empty stack" }
            return
        }
        
        set last_action [lindex $char_stack($widget) end]
        set action_type [lindex $last_action 0]
        set text [lindex $last_action 1]
        set start_pos [lindex $last_action 2]
        set end_pos [lindex $last_action 3]
        
        if {$debug} { puts "Undoing $action_type: '$text' at $start_pos (end: $end_pos)" }
        
        set char_stack($widget) [lrange $char_stack($widget) 0 end-1]
        
        switch -- $action_type {
            insert {
                if {$end_pos ne ""} {
                    catch {$widget delete $start_pos $end_pos}
                } else {
                    catch {$widget delete $start_pos}
                }
                lappend redo_stack($widget) $last_action
            }
            delete {
                catch {$widget insert $start_pos $text}
                lappend redo_stack($widget) $last_action
            }
            cut {
                catch {$widget insert $start_pos $text}
                lappend redo_stack($widget) $last_action
            }
            paste {
                set paste_end "$start_pos + [string length $text] chars"
                catch {$widget delete $start_pos $paste_end}
                lappend redo_stack($widget) $last_action
            }
            delete_line {
                catch {$widget insert $start_pos $text}
                lappend redo_stack($widget) $last_action
            }
            comment_toggle {
                set linenumber [expr {int([lindex [split $start_pos .] 0])}]
                catch {
                    $widget delete $start_pos "$linenumber.0 lineend"
                    $widget insert $start_pos $text
                }
                lappend redo_stack($widget) $last_action
            }
            default {
                if {$debug} { puts "Unknown action type: $action_type" }
            }
        }
        
        set tab [.tabs select]
        if {$tab ne "" && [info exists ::core::tab_files($tab)]} {
            ::core::check_modified $tab
        }
    }
    
    # Повтор последнего отмененного действия
    proc redo_char {widget} {
        variable char_stack
        variable redo_stack
        variable debug
        
        init_char_stacks $widget
        
        if {[llength $redo_stack($widget)] == 0} {
            if {$debug} { puts "Redo: Empty stack" }
            return
        }
        
        set last_action [lindex $redo_stack($widget) end]
        set action_type [lindex $last_action 0]
        set text [lindex $last_action 1]
        set start_pos [lindex $last_action 2]
        set end_pos [lindex $last_action 3]
        
        if {$debug} { puts "Redoing $action_type: '$text' at $start_pos (end: $end_pos)" }
        
        set redo_stack($widget) [lrange $redo_stack($widget) 0 end-1]
        
        switch -- $action_type {
            insert {
                catch {$widget insert $start_pos $text}
                lappend char_stack($widget) $last_action
            }
            delete {
                set delete_end "$start_pos + [string length $text] chars"
                catch {$widget delete $start_pos $delete_end}
                lappend char_stack($widget) $last_action
            }
            cut {
                set cut_end "$start_pos + [string length $text] chars"
                catch {$widget delete $start_pos $cut_end}
                lappend char_stack($widget) $last_action
            }
            paste {
                catch {$widget insert $start_pos $text}
                lappend char_stack($widget) $last_action
            }
            delete_line {
                set line_end "$start_pos + [string length $text] chars"
                catch {$widget delete $start_pos $line_end}
                lappend char_stack($widget) $last_action
            }
            comment_toggle {
                set linenumber [expr {int([lindex [split $start_pos .] 0])}]
                catch {
                    set orig_line [$widget get "$linenumber.0" "$linenumber.0 lineend"]
                    if {[string match {[[:space:]]*#*} $orig_line]} {
                        set new_line [regsub {^([[:space:]]*)#([[:space:]]?)} $orig_line {\1}]
                    } else {
                        set new_line "# $orig_line"
                    }
                    $widget delete "$linenumber.0" "$linenumber.0 lineend"
                    $widget insert "$linenumber.0" $new_line
                }
                lappend char_stack($widget) $last_action
            }
            default {
                if {$debug} { puts "Unknown redo action type: $action_type" }
            }
        }
        
        set tab [.tabs select]
        if {$tab ne "" && [info exists ::core::tab_files($tab)]} {
            ::core::check_modified $tab
        }
    }
    
    # Настройка привязок для класса Text
    proc setup_text_class_bindings {} {
        foreach binding [bind Text] {
            if {[string match <Control-*> $binding] || 
                [string match <Control-Key-*> $binding] ||
                [string match <Control-Shift-*> $binding]} {
                bind Text $binding {}
            }
        }
        
        bind Text <Control-a> {
            %W tag add sel 1.0 end
            return -code break
        }
        bind Text <Control-Key-a> {
            %W tag add sel 1.0 end
            return -code break
        }
    }
    
    # Настройка общих горячих клавиш
    proc setup_common_hotkeys {} {
        bind . <Control-q> {
            if {[info commands ::core::confirm_exit] ne ""} {
                ::core::confirm_exit
            } else {
                exit
            }
        }
        
        bind . <Control-comma> {
            if {[info commands ::plugin::settings::show_settings] ne ""} {
                ::plugin::settings::show_settings
            }
        }
        
        bind . <Control-t> {
            if {[info commands ::core::create_tab] ne ""} {
                ::core::create_tab
            }
        }
        
        bind . <Control-w> {
            if {[info commands ::core::close_current_tab] ne ""} {
                ::core::close_current_tab
            }
        }
        
        for {set i 1} {$i <= 9} {incr i} {
            bind . <Control-Key-$i> [list ::plugin::hotkeys::switch_to_tab [expr {$i - 1}]]
        }
    }
    
    # Сохранение без артефактов
    proc save_without_artifacts {} {
        set focus_widget [focus]
        
        if {[info commands ::core::save_current_file] ne ""} {
            ::core::save_current_file
        }
        
        if {[winfo exists $focus_widget] && [string match "*text*" [winfo class $focus_widget]]} {
            set cursor_pos [$focus_widget index insert]
            if {[$focus_widget compare insert > "1.0"]} {
                set prev_char [$focus_widget get "insert-1c" insert]
                if {$prev_char eq "\u0013"} {
                    $focus_widget delete "insert-1c" insert
                }
            }
            set next_char [$focus_widget get insert "insert+1c"]
            if {$next_char eq "\u0013"} {
                $focus_widget delete insert "insert+1c"
            }
        }
        
        return -code break
    }
    
    # Настройка горячих клавиш для файловых операций
    proc setup_file_hotkeys {} {
        bind . <Control-o> {
            if {[info commands ::core::open_file] ne ""} {
                ::core::open_file
            }
        }
        
        bind . <Control-s> ::plugin::hotkeys::save_without_artifacts
        bind . <Control-Shift-S> {
            if {[info commands ::core::save_as_file] ne ""} {
                ::core::save_as_file
            }
        }
    }
    
    # Настройка горячих клавиш для поиска и замены
    proc setup_search_hotkeys {} {
        bind . <Control-f> {
            if {[info commands ::plugin::search::show_find] ne ""} {
                ::plugin::search::show_find
            } else {
                tk_messageBox -icon info -title "Поиск" \
                    -message "Плагин поиска не загружен."
            }
        }
        
        bind . <Control-h> {
            if {[info commands ::plugin::search::show_replace] ne ""} {
                ::plugin::search::show_replace
            } else {
                tk_messageBox -icon info -title "Замена" \
                    -message "Плагин поиска не загружен."
            }
        }
        
        bind . <F3> {
            if {[info commands ::plugin::search::find_next] ne ""} {
                ::plugin::search::find_next
            }
        }
        
        bind . <Shift-F3> {
            if {[info commands ::plugin::search::find_prev] ne ""} {
                ::plugin::search::find_prev
            }
        }
        
        bind . <Control-g> {
            if {[info commands ::plugin::search::goto_line] ne ""} {
                ::plugin::search::goto_line
            } else {
                ::plugin::hotkeys::goto_line_dialog
            }
        }
    }
    
    # Применение привязок к текстовому виджету
    proc apply_to_text_widget {widget} {
        variable bound_widgets
        variable debug
        
        if {![winfo exists $widget] || [winfo class $widget] ne "Text"} {
            return
        }
        
        set bound_widgets($widget) 1
        init_char_stacks $widget
        catch {$widget configure -undo 0}
        bindtags $widget "$widget Text [winfo toplevel $widget] all"
        
        bind $widget <Control-s> ::plugin::hotkeys::save_without_artifacts
        bind $widget <Control-Key-s> ::plugin::hotkeys::save_without_artifacts
        
        bind $widget <KeyPress> {
            if {"%A" ne "" && [string length "%A"] == 1} {
                set pos [%W index insert]
                ::plugin::hotkeys::push_char %W "insert" "%A" $pos
            }
        }
        
        bind $widget <BackSpace> {
            if {[%W tag ranges sel] ne ""} {
                set start_pos [%W index sel.first]
                set end_pos [%W index sel.last]
                set text [%W get $start_pos $end_pos]
                %W delete $start_pos $end_pos
                ::plugin::hotkeys::push_char %W "delete" $text $start_pos $end_pos
            } elseif {[%W compare insert > "1.0"]} {
                set char [%W get "insert-1c" insert]
                set pos [%W index "insert-1c"]
                %W delete "insert-1c" insert
                ::plugin::hotkeys::push_char %W "delete" $char $pos
            }
            set tab [.tabs select]
            if {$tab ne "" && [info exists ::core::tab_files($tab)]} {
                ::core::check_modified $tab
            }
            return -code break
        }
        
        bind $widget <Delete> {
            if {[%W tag ranges sel] ne ""} {
                set start_pos [%W index sel.first]
                set end_pos [%W index sel.last]
                set text [%W get $start_pos $end_pos]
                %W delete $start_pos $end_pos
                ::plugin::hotkeys::push_char %W "delete" $text $start_pos $end_pos
            } elseif {[%W compare insert < "end-1c"]} {
                set char [%W get insert "insert+1c"]
                set pos [%W index insert]
                %W delete insert "insert+1c"
                ::plugin::hotkeys::push_char %W "delete" $char $pos
            }
            set tab [.tabs select]
            if {$tab ne "" && [info exists ::core::tab_files($tab)]} {
                ::core::check_modified $tab
            }
            return -code break
        }
        
        bind $widget <Control-z> {
            ::plugin::hotkeys::undo_char %W
            return -code break
        }
        bind $widget <Control-y> {
            ::plugin::hotkeys::redo_char %W
            return -code break
        }
        bind $widget <Control-Shift-z> {
            ::plugin::hotkeys::redo_char %W
            return -code break
        }
        
        bind $widget <Control-a> {
            %W tag add sel 1.0 end
            return -code break
        }
        
        bind $widget <Control-x> {
            if {[%W tag ranges sel] ne ""} {
                set start_pos [%W index sel.first]
                set text [%W get sel.first sel.last]
                tk_textCut %W
                ::plugin::hotkeys::push_char %W "cut" $text $start_pos
                set tab [.tabs select]
                if {[info exists ::core::tab_files($tab)]} {
                    ::core::check_modified $tab
                }
            }
            return -code break
        }
        
        bind $widget <Control-c> {
            if {[%W tag ranges sel] ne ""} {
                tk_textCopy %W
            }
            return -code break
        }
        
        bind $widget <Control-v> {
            set start_pos [%W index insert]
            tk_textPaste %W
            set clipboard ""
            catch {set clipboard [selection get -selection CLIPBOARD -type STRING]}
            if {$clipboard ne ""} {
                ::plugin::hotkeys::push_char %W "paste" $clipboard $start_pos
            }
            set tab [.tabs select]
            if {[info exists ::core::tab_files($tab)]} {
                ::core::check_modified $tab
            }
            return -code break
        }
        
        bind $widget <Control-d> {
            set start_pos [%W index "insert linestart"]
            set text [%W get "insert linestart" "insert lineend + 1 chars"]
            %W delete "insert linestart" "insert lineend + 1 chars"
            ::plugin::hotkeys::push_char %W "delete_line" $text $start_pos
            set tab [.tabs select]
            if {[info exists ::core::tab_files($tab)]} {
                ::core::check_modified $tab
            }
            return -code break
        }
        
        bind $widget <Control-l> {
            set start_pos [%W index "insert lineend"]
            set text [%W get "insert linestart" "insert lineend"]
            %W insert "insert lineend" "\n$text"
            ::plugin::hotkeys::push_char %W "insert" "\n$text" $start_pos
            set tab [.tabs select]
            if {[info exists ::core::tab_files($tab)]} {
                ::core::check_modified $tab
            }
            return -code break
        }
        
        bind $widget <Control-slash> {
            set linenumber [expr {int([%W index insert])}]
            set start_pos "$linenumber.0"
            set orig_line [%W get $start_pos "$linenumber.0 lineend"]
            if {[string match {[[:space:]]*#*} $orig_line]} {
                set new_line [regsub {^([[:space:]]*)#([[:space:]]?)} $orig_line {\1}]
            } else {
                set new_line "# $orig_line"
            }
            %W delete $start_pos "$linenumber.0 lineend"
            %W insert $start_pos $new_line
            ::plugin::hotkeys::push_char %W "comment_toggle" $orig_line $start_pos
            set tab [.tabs select]
            if {[info exists ::core::tab_files($tab)]} {
                ::core::check_modified $tab
            }
            return -code break
        }
        
        bind $widget <Alt-z> {
            if {[%W cget -wrap] eq "none"} {
                %W configure -wrap word
            } else {
                %W configure -wrap none
            }
            return -code break
        }
        
        bind $widget <Control-Left> {
            %W mark set insert {insert wordstart}
            %W see insert
            return -code break
        }
        
        bind $widget <Control-Right> {
            %W mark set insert {insert wordend}
            %W see insert
            return -code break
        }
        
        bind $widget <Home> {
            set line_start [%W index {insert linestart}]
            set current_pos [%W index insert]
            set line_text [%W get $line_start "insert lineend"]
            
            if {[regexp -indices {[^[:space:]]} $line_text match_indices]} {
                set first_non_whitespace "$line_start + [lindex $match_indices 0] chars"
                if {[%W compare $current_pos != $first_non_whitespace]} {
                    %W mark set insert $first_non_whitespace
                } else {
                    %W mark set insert $line_start
                }
            } else {
                %W mark set insert $line_start
            }
            %W see insert
            return -code break
        }
    }
    
    # Применение привязок ко всем текстовым виджетам
    proc apply_to_all_text_widgets {} {
        if {[winfo exists .tabs]} {
            foreach tab [.tabs tabs] {
                if {[winfo exists $tab.text]} {
                    apply_to_text_widget $tab.text
                }
            }
        }
        
        foreach widget [winfo children .] {
            if {[winfo exists $widget] && [winfo class $widget] eq "Text"} {
                apply_to_text_widget $widget
            }
            check_nested_text_widgets $widget
        }
    }
    
    # Рекурсивная проверка вложенных текстовых виджетов
    proc check_nested_text_widgets {parent} {
        foreach widget [winfo children $parent] {
            if {[winfo exists $widget]} {
                if {[winfo class $widget] eq "Text"} {
                    apply_to_text_widget $widget
                }
                check_nested_text_widgets $widget
            }
        }
    }
    
    # Диалог перехода к строке
    proc goto_line_dialog {} {
        set tab [.tabs select]
        if {$tab eq "" || ![winfo exists $tab.text]} {
            return
        }
        
        set total_lines [lindex [split [$tab.text index end] .] 0]
        
        toplevel .goto_line
        wm title .goto_line "Перейти к строке"
        wm transient .goto_line .
        wm resizable .goto_line 0 0
        
        if {[info exists ::core::config(theme)] && $::core::config(theme) eq "dark"} {
            set bg "#2D2D2D"
            set fg "#CCCACA"
            set input_bg "#404040"
            set input_fg "#FFFFFF"
        } else {
            set bg "#FFFFFF"
            set fg "#000000"
            set input_bg "#FFFFFF"
            set input_fg "#000000"
        }
        
        frame .goto_line.f -background $bg -padx 10 -pady 10
        pack .goto_line.f -fill both -expand 1
        
        label .goto_line.f.lbl -text "Введите номер строки (1-$total_lines):" \
            -background $bg -foreground $fg
        pack .goto_line.f.lbl -pady 5
        
        entry .goto_line.f.entry -justify center -background $input_bg -foreground $input_fg
        pack .goto_line.f.entry -fill x -pady 5
        
        frame .goto_line.f.buttons -background $bg
        pack .goto_line.f.buttons -fill x -pady 5
        
        button .goto_line.f.buttons.ok -text "Перейти" -command {
            if {[string is integer -strict [.goto_line.f.entry get]]} {
                set line_num [.goto_line.f.entry get]
                if {$line_num >= 1 && $line_num <= $total_lines} {
                    set tab [.tabs select]
                    $tab.text mark set insert "$line_num.0"
                    $tab.text see insert
                    destroy .goto_line
                } else {
                    tk_messageBox -icon error -title "Ошибка" \
                        -message "Номер строки должен быть в диапазоне 1-$total_lines"
                }
            } else {
                tk_messageBox -icon error -title "Ошибка" \
                    -message "Введите корректный номер строки"
            }
        }
        
        button .goto_line.f.buttons.cancel -text "Отмена" -command {destroy .goto_line}
        
        grid .goto_line.f.buttons.ok .goto_line.f.buttons.cancel -padx 5 -pady 5
        
        focus .goto_line.f.entry
        bind .goto_line.f.entry <Return> {
            .goto_line.f.buttons.ok invoke
        }
        bind .goto_line <Escape> {
            destroy .goto_line
        }
        
        center_window .goto_line
    }
    
    # Переключение на вкладку по номеру
    proc switch_to_tab {index} {
        if {[winfo exists .tabs]} {
            set tabs [.tabs tabs]
            if {$index < [llength $tabs]} {
                .tabs select [lindex $tabs $index]
            }
        }
    }
    
    # Центрирование окна
    proc center_window {w} {
        wm withdraw $w
        update idletasks
        set screenwidth [winfo screenwidth .]
        set screenheight [winfo screenheight .]
        set reqwidth [winfo reqwidth $w]
        set reqheight [winfo reqheight $w]
        set x [expr {($screenwidth - $reqwidth) / 2}]
        set y [expr {($screenheight - $reqheight) / 2}]
        wm geometry $w +$x+$y
        wm deiconify $w
    }
}

# Загрузка плагина
::plugin::hotkeys::init

# Применение привязок ко всем текстовым виджетам
after 200 ::plugin::hotkeys::apply_to_all_text_widgets

# Установка глобальных привязок для переключения вкладок
after 300 ::plugin::hotkeys::bind_tab_switching

# Инициализация стеков для всех текстовых виджетов
after 400 {
    if {[winfo exists .tabs]} {
        foreach tab [.tabs tabs] {
            if {[winfo exists $tab.text]} {
                ::plugin::hotkeys::init_char_stacks $tab.text
            }
        }
    }
}

# Глобальные привязки для Ctrl+Z и Ctrl+Y
after 500 {
    bind all <Control-z> {
        set w [focus]
        if {[winfo exists $w] && [string match "*text*" [winfo class $w]]} {
            ::plugin::hotkeys::undo_char $w
        }
        return -code break
    }
    
    bind all <Control-y> {
        set w [focus]
        if {[winfo exists $w] && [string match "*text*" [winfo class $w]]} {
            ::plugin::hotkeys::redo_char $w
        }
        return -code break
    }
    
    bind all <Control-Shift-z> {
        set w [focus]
        if {[winfo exists $w] && [string match "*text*" [winfo class $w]]} {
            ::plugin::hotkeys::redo_char $w
        }
        return -code break
    }
}
