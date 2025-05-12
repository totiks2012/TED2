# search.tcl - Плагин для поиска и замены текста
# Created: 2025-05-05 17:24:18 by totiks2012

namespace eval ::plugin::search {
    # Устанавливаем порядок кнопки - третья после базовых кнопок
    variable button_order 3
    
    # Переменные плагина
    variable replace_all 0    ;# Переменная для опции "Заменить все"
    
    # Описание плагина
    variable plugin_info
    array set plugin_info {
        name "Search"
        version "1.0"
        description "Плагин для поиска и замены текста"
        author "totiks2012"
    }
    
    # Инициализация плагина
    proc init {} {
        variable button_order
        
        # Регистрируем кнопку в панели инструментов
        set search_button [::core::register_plugin_button "search" "🔍 Поиск" ::plugin::search::show_search_dialog "" $button_order]
        
        # Регистрируем горячие клавиши
        bind . <Control-f> { ::plugin::search::show_search_dialog }
        bind . <Control-h> { ::plugin::search::show_search_dialog }
        bind . <F3> { ::plugin::search::find_text }
        
        return 1
    }
    
    # Процедура показа диалога поиска
    proc show_search_dialog {} {
        variable replace_all
        
        # Создаем модальное окно поиска
        set w .search_dialog
        catch {destroy $w}
        toplevel $w
        wm title $w "Поиск и замена"
        wm transient $w .
        wm resizable $w 0 0
        
        # Создаем и размещаем элементы управления
        ttk::frame $w.f
        pack $w.f -expand 1 -fill both -padx 5 -pady 5
        
        # Поле поиска
        ttk::labelframe $w.f.find -text "Найти:"
        pack $w.f.find -fill x -pady 2
        
        entry $w.f.find.entry -width 40
        pack $w.f.find.entry -fill x -padx 5 -pady 2
        bind $w.f.find.entry <Control-a> {%W selection range 0 end}
        bind $w.f.find.entry <Control-A> {%W selection range 0 end}
        
        # Поле замены
        ttk::labelframe $w.f.replace -text "Заменить на:"
        pack $w.f.replace -fill x -pady 2
        
        entry $w.f.replace.entry -width 40
        pack $w.f.replace.entry -fill x -padx 5 -pady 2
        bind $w.f.replace.entry <Control-a> {%W selection range 0 end}
        bind $w.f.replace.entry <Control-A> {%W selection range 0 end}
        
        # Кнопки поиска и замены
        ttk::frame $w.f.buttons
        pack $w.f.buttons -fill x -pady 5
        
        ttk::button $w.f.buttons.prev -text "↑" \
            -command "::plugin::search::do_search \[$w.f.find.entry get\] backward"
        ttk::button $w.f.buttons.next -text "↓" \
            -command "::plugin::search::do_search \[$w.f.find.entry get\] forward"
        ttk::button $w.f.buttons.replace -text "Заменить" \
            -command "::plugin::search::do_replace \[$w.f.find.entry get\] \[$w.f.replace.entry get\]"
        ttk::checkbutton $w.f.buttons.all -text "Заменить все" \
            -variable ::plugin::search::replace_all
        
        pack $w.f.buttons.prev $w.f.buttons.next $w.f.buttons.replace \
            -side left -padx 2
        pack $w.f.buttons.all -side right -padx 2
        
        # Привязки клавиш
        bind $w <Return> "::plugin::search::do_search \[$w.f.find.entry get\] forward"
        bind $w <Shift-Return> "::plugin::search::do_search \[$w.f.find.entry get\] backward"
        bind $w <Control-Return> "::plugin::search::do_replace \[$w.f.find.entry get\] \[$w.f.replace.entry get\]"
        bind $w <Escape> {destroy .search_dialog}
        
        # Центрируем окно
        wm withdraw $w
        update idletasks
        set x [expr {([winfo screenwidth .] - [winfo reqwidth $w]) / 2}]
        set y [expr {([winfo screenheight .] - [winfo reqheight $w]) / 2}]
        wm geometry $w +$x+$y
        wm deiconify $w
        
        # Фокус на поле поиска
        focus $w.f.find.entry
        
        # Применяем цвета в зависимости от темы
        apply_theme_to_search_dialog $w
    }
    
    # Процедура применения темы для окон поиска и сложной замены
    proc apply_theme_to_search_dialog {w} {
        # Определяем цвета в зависимости от темы
        if {$::core::config(theme) eq "dark"} {
            set entry_bg "#2D2D2D"
            set entry_fg "#CCCACA"
            set insert_bg "#FFFFFF" ;# Светлый курсор
            set text_bg "#2D2D2D"
            set text_fg "#CCCACA"
        } else {
            set entry_bg "#FFFFFF"
            set entry_fg "#000000"
            set insert_bg "#000000" ;# Темный курсор
            set text_bg "#FFFFFF"
            set text_fg "#000000"
        }

        # Настройка элементов диалога поиска
        $w.f.find.entry configure \
            -background $entry_bg \
            -foreground $entry_fg \
            -insertbackground $insert_bg
        $w.f.replace.entry configure \
            -background $entry_bg \
            -foreground $entry_fg \
            -insertbackground $insert_bg
    }
    
    # Процедура выполнения поиска
    proc do_search {text direction} {
        if {$text ne ""} {
            search_text $text $direction
        }
    }
    
    # Процедура выполнения замены
    proc do_replace {find_text replace_text} {
        if {$find_text ne ""} {
            replace_text $find_text $replace_text
        }
    }
    
    # Процедура поиска текста
    proc search_text {text direction} {
        # Получаем текущую вкладку
        set current_tab [.tabs select]
        if {$current_tab eq ""} return
        
        # Получаем текстовый виджет
        set txt $current_tab.text
        
        # Определяем направление поиска
        if {$direction eq "forward"} {
            # Для поиска вперед
            if {[catch {set pos [$txt index sel.last]} err]} {
                set pos [$txt index insert]
            }
            set found [$txt search -- $text "$pos + 1c" end]
            if {$found eq ""} {
                # Если не найдено - начинаем сначала
                set found [$txt search -- $text 1.0 $pos]
            }
        } else {
            # Для поиска назад
            if {[catch {set pos [$txt index sel.first]} err]} {
                set pos [$txt index insert]
            }
            set found [$txt search -backwards -- $text "$pos - 1c" 1.0]
            if {$found eq ""} {
                # Если не найдено - начинаем с конца
                set found [$txt search -backwards -- $text end $pos]
            }
        }
        
        if {$found ne ""} {
            # Вычисляем конец найденного текста
            set last [$txt index "$found + [string length $text] chars"]
            
            # Выделяем найденный текст и перемещаем к нему
            $txt tag remove sel 1.0 end
            $txt tag add sel $found $last
            $txt mark set insert $found
            $txt see $found
            
            return 1
        } else {
            tk_messageBox -icon info -title "Поиск" \
                -message "Текст \"$text\" не найден."
            return 0
        }
    }
    
    # Процедура замены текста
    proc replace_text {find_text replace_text} {
        variable replace_all
        
        # Получаем текущую вкладку
        set current_tab [.tabs select]
        if {$current_tab eq ""} return
        
        # Получаем текстовый виджет
        set txt $current_tab.text
        
        # Если нет выделения или выделенный текст не совпадает с искомым,
        # ищем следующее вхождение
        if {[catch {set selected [$txt get sel.first sel.last]}] || 
            $selected ne $find_text} {
            if {![search_text $find_text forward]} {
                return
            }
        }
        
        # Получаем границы выделения
        set start [$txt index sel.first]
        set end [$txt index sel.last]
        
        # Заменяем текст
        $txt delete $start $end
        $txt insert $start $replace_text
        
        # Если включена опция "Заменить все"
        if {$replace_all} {
            while {[search_text $find_text forward]} {
                set start [$txt index sel.first]
                set end [$txt index sel.last]
                $txt delete $start $end
                $txt insert $start $replace_text
            }
        } else {
            # Ищем следующее вхождение
            search_text $find_text forward
        }
    }
    
    # Плагин для блочного поиска и замены
    proc show_complex_replace_dialog {} {
        variable replace_all

        # Создаем модальное окно
        set w .complex_replace_dialog
        catch {destroy $w}
        toplevel $w
        wm title $w "Сложная замена"
        wm transient $w .
        wm resizable $w 0 0

        # Создаем и размещаем элементы управления
        ttk::frame $w.f -padding "5 5 5 5"
        pack $w.f -expand 1 -fill both

        # Поле для начальной метки
        ttk::labelframe $w.f.start -text "Начальная метка:"
        pack $w.f.start -fill x -pady 2
        entry $w.f.start.entry -width 40
        pack $w.f.start.entry -fill x -padx 5 -pady 2
        bind $w.f.start.entry <Control-a> {%W selection range 0 end}
        bind $w.f.start.entry <Control-A> {%W selection range 0 end}

        # Поле для конечной метки
        ttk::labelframe $w.f.end -text "Конечная метка:"
        pack $w.f.end -fill x -pady 2
        entry $w.f.end.entry -width 40
        pack $w.f.end.entry -fill x -padx 5 -pady 2
        bind $w.f.end.entry <Control-a> {%W selection range 0 end}
        bind $w.f.end.entry <Control-A> {%W selection range 0 end}

        # Текстовое поле для нового кода
        ttk::labelframe $w.f.newcode -text "Новый код:"
        pack $w.f.newcode -fill both -expand 1 -pady 2
        text $w.f.newcode.text -width 40 -height 10 -wrap word
        pack $w.f.newcode.text -fill both -padx 5 -pady 2
        bind $w.f.newcode.text <Control-a> {%W tag add sel 1.0 end}
        bind $w.f.newcode.text <Control-A> {%W tag add sel 1.0 end}

        # Кнопки
        ttk::frame $w.f.buttons
        pack $w.f.buttons -fill x -pady 5
        ttk::button $w.f.buttons.find -text "Найти" \
            -command "::plugin::search::find_complex_replace \[$w.f.start.entry get\] \[$w.f.end.entry get\]"
        ttk::button $w.f.buttons.replace -text "Заменить" \
            -command "::plugin::search::do_complex_replace \[$w.f.start.entry get\] \[$w.f.end.entry get\] \[$w.f.newcode.text get 1.0 end-1c\]"
        ttk::button $w.f.buttons.cancel -text "Отмена" \
            -command "destroy $w"
        ttk::checkbutton $w.f.buttons.all -text "Заменить все" \
            -variable ::plugin::search::replace_all

        pack $w.f.buttons.find $w.f.buttons.replace $w.f.buttons.cancel \
            -side left -padx 2
        pack $w.f.buttons.all -side right -padx 2

        # Привязки клавиш
        bind $w <Return> "::plugin::search::find_complex_replace \[$w.f.start.entry get\] \[$w.f.end.entry get\]"
        bind $w <Control-Return> "::plugin::search::do_complex_replace \[$w.f.start.entry get\] \[$w.f.end.entry get\] \[$w.f.newcode.text get 1.0 end-1c\]"
        bind $w <Escape> "destroy $w"

        # Очищаем флаг модификации и отключаем событие <<Modified>>
        $w.f.newcode.text edit modified 0
        
        # Центрируем окно
        wm withdraw $w
        update idletasks
        set x [expr {([winfo screenwidth .] - [winfo reqwidth $w]) / 2}]
        set y [expr {([winfo screenheight .] - [winfo reqheight $w]) / 2}]
        wm geometry $w +$x+$y
        wm deiconify $w

        # Фокус на поле начальной метки
        focus $w.f.start.entry

        # Применяем тему
        if {$::core::config(theme) eq "dark"} {
            set text_bg "#2D2D2D"
            set text_fg "#CCCACA"
            set insert_bg "#FFFFFF"
            $w.f.newcode.text configure \
                -background $text_bg \
                -foreground $text_fg \
                -insertbackground $insert_bg
            $w.f.start.entry configure \
                -background $text_bg \
                -foreground $text_fg \
                -insertbackground $insert_bg
            $w.f.end.entry configure \
                -background $text_bg \
                -foreground $text_fg \
                -insertbackground $insert_bg
        }
    }

    # Процедура поиска блока строк между метками
    proc find_complex_replace {start_marker end_marker} {
        set current_tab [.tabs select]
        if {$current_tab eq ""} return

        set txt $current_tab.text
        # Находим начальную метку
        set start_pos [$txt search -- $start_marker 1.0 end]
        if {$start_pos eq ""} {
            tk_messageBox -icon info -title "Поиск" \
                -message "Начальная метка \"$start_marker\" не найдена."
            return 0
        }

        # Получаем номер строки начальной метки и переходим к следующей строке
        set start_line [lindex [split $start_pos .] 0]
        set start_pos "$start_line.0 lineend + 1c"
        if {[$txt compare $start_pos >= end]} {
            tk_messageBox -icon info -title "Поиск" \
                -message "Нет строк после начальной метки."
            return 0
        }

        # Находим конечную метку, начиная с позиции после начальной метки
        set end_pos [$txt search -- $end_marker $start_pos end]
        if {$end_pos eq ""} {
            tk_messageBox -icon info -title "Поиск" \
                -message "Конечная метка \"$end_marker\" не найдена."
            return 0
        }

        # Получаем номер строки конечной метки и переходим к началу предыдущей строки
        set end_line [lindex [split $end_pos .] 0]
        if {$end_line <= $start_line + 1} {
            tk_messageBox -icon info -title "Поиск" \
                -message "Нет строк между метками."
            return 0
        }
        set end_pos "[expr {$end_line - 1}].0 lineend"

        # Выделяем блок от начала следующей строки после начальной метки
        # до конца предыдущей строки перед конечной меткой
        $txt tag remove sel 1.0 end
        $txt tag add sel $start_pos $end_pos
        $txt mark set insert $start_pos
        $txt see $start_pos
        return 1
    }

    # Процедура выполнения сложной замены (блок строк)
    proc do_complex_replace {start_marker end_marker new_code} {
        variable replace_all
        set current_tab [.tabs select]
        if {$current_tab eq ""} return

        set txt $current_tab.text
        if {![find_complex_replace $start_marker $end_marker]} {
            return
        }

        # Заменяем выделенный блок строк
        set start_pos [$txt index sel.first]
        set end_pos [$txt index sel.last]
        $txt delete $start_pos $end_pos
        $txt insert $start_pos $new_code

        # Если включена опция "Заменить все"
        if {$replace_all} {
            while {[find_complex_replace $start_marker $end_marker]} {
                set start_pos [$txt index sel.first]
                set end_pos [$txt index sel.last]
                $txt delete $start_pos $end_pos
                $txt insert $start_pos $new_code
            }
        } else {
            # Ищем следующий блок
            find_complex_replace $start_marker $end_marker
        }
    }
}
