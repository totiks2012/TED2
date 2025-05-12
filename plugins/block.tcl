# block.tcl - Плагин для блочной замены текста
# Created: 2025-05-05 17:35:22 by totiks2012

namespace eval ::plugin::block {
    # Устанавливаем порядок кнопки - четвертая после базовых кнопок
    variable button_order 4
    
    # Переменные плагина
    variable replace_all 0    ;# Переменная для опции "Заменить все"
    
    # Описание плагина
    variable plugin_info
    array set plugin_info {
        name "Block"
        version "1.0"
        description "Плагин для блочной замены текста"
        author "totiks2012"
    }
    
    # Инициализация плагина
    proc init {} {
        variable button_order
        
        # Регистрируем кнопку в панели инструментов
        set block_button [::core::register_plugin_button "block" "🧱 Block" ::plugin::block::show_complex_replace_dialog "" $button_order]
        
        # Регистрируем горячие клавиши
        bind . <Control-Shift-F> { ::plugin::block::show_complex_replace_dialog }
        bind . <Control-Shift-f> { ::plugin::block::show_complex_replace_dialog }
        
        return 1
    }
    
    # Процедура показа диалога блочной замены
    proc show_complex_replace_dialog {} {
        variable replace_all

        # Создаем модальное окно
        set w .complex_replace_dialog
        catch {destroy $w}
        toplevel $w
        wm title $w "Блочная замена"
        wm transient $w .
        wm resizable $w 1 1

        # Создаем и размещаем элементы управления
        ttk::frame $w.f -padding "10 10 10 10"
        pack $w.f -expand 1 -fill both

        # Поле для начальной метки
        ttk::labelframe $w.f.start -text "Начальная метка:"
        pack $w.f.start -fill x -pady 2
        entry $w.f.start.entry -width 40
        pack $w.f.start.entry -fill x -padx 5 -pady 2
        
        # Глобальные привязки для Ctrl+A и стандартных операций копирования/вставки для полей entry
        bind $w.f.start.entry <Control-a> {%W selection range 0 end; break}
        bind $w.f.start.entry <Control-A> {%W selection range 0 end; break}
        
        # Стандартные комбинации копирования/вставки для полей entry
        bind $w.f.start.entry <Control-c> {event generate %W <<Copy>>; break}
        bind $w.f.start.entry <Control-v> {event generate %W <<Paste>>; break}
        bind $w.f.start.entry <Control-x> {event generate %W <<Cut>>; break}

        # Поле для конечной метки
        ttk::labelframe $w.f.end -text "Конечная метка:"
        pack $w.f.end -fill x -pady 2
        entry $w.f.end.entry -width 40
        pack $w.f.end.entry -fill x -padx 5 -pady 2
        
        # Привязки для второго поля entry
        bind $w.f.end.entry <Control-a> {%W selection range 0 end; break}
        bind $w.f.end.entry <Control-A> {%W selection range 0 end; break}
        bind $w.f.end.entry <Control-c> {event generate %W <<Copy>>; break}
        bind $w.f.end.entry <Control-v> {event generate %W <<Paste>>; break}
        bind $w.f.end.entry <Control-x> {event generate %W <<Cut>>; break}

        # Текстовое поле для нового кода
        ttk::labelframe $w.f.newcode -text "Новый код:"
        pack $w.f.newcode -fill both -expand 1 -pady 2
        
        # Добавляем скроллбары для текстового поля
        text $w.f.newcode.text -width 60 -height 15 -wrap none \
            -xscrollcommand "$w.f.newcode.xscroll set" \
            -yscrollcommand "$w.f.newcode.yscroll set"
        ttk::scrollbar $w.f.newcode.yscroll -orient vertical -command "$w.f.newcode.text yview"
        ttk::scrollbar $w.f.newcode.xscroll -orient horizontal -command "$w.f.newcode.text xview"
        
        # Размещаем текстовое поле и скроллбары
        grid $w.f.newcode.text -row 0 -column 0 -sticky nsew
        grid $w.f.newcode.yscroll -row 0 -column 1 -sticky ns
        grid $w.f.newcode.xscroll -row 1 -column 0 -sticky ew
        grid columnconfigure $w.f.newcode 0 -weight 1
        grid rowconfigure $w.f.newcode 0 -weight 1
        
        # Привязки для текстового поля
        bind $w.f.newcode.text <Control-a> {%W tag add sel 1.0 end; break}
        bind $w.f.newcode.text <Control-A> {%W tag add sel 1.0 end; break}
        bind $w.f.newcode.text <Control-c> {event generate %W <<Copy>>; break}
        bind $w.f.newcode.text <Control-v> {event generate %W <<Paste>>; break}
        bind $w.f.newcode.text <Control-x> {event generate %W <<Cut>>; break}

        # Кнопки
        ttk::frame $w.f.buttons
        pack $w.f.buttons -fill x -pady 5
        ttk::button $w.f.buttons.find -text "Найти" \
            -command "::plugin::block::find_complex_replace \[$w.f.start.entry get\] \[$w.f.end.entry get\]"
        ttk::button $w.f.buttons.replace -text "Заменить" \
            -command "::plugin::block::do_complex_replace \[$w.f.start.entry get\] \[$w.f.end.entry get\] \[$w.f.newcode.text get 1.0 end-1c\]"
        ttk::button $w.f.buttons.cancel -text "Закрыть" \
            -command "destroy $w"
        ttk::checkbutton $w.f.buttons.all -text "Заменить все" \
            -variable ::plugin::block::replace_all

        # Размещаем кнопки
        grid $w.f.buttons.find $w.f.buttons.replace $w.f.buttons.cancel -padx 5 -pady 5 -sticky ew
        grid $w.f.buttons.all -row 0 -column 3 -padx 5 -pady 5 -sticky e
        
        # Настраиваем одинаковый размер кнопок
        grid columnconfigure $w.f.buttons 0 -weight 1
        grid columnconfigure $w.f.buttons 1 -weight 1
        grid columnconfigure $w.f.buttons 2 -weight 1
        grid columnconfigure $w.f.buttons 3 -weight 0

        # Привязки клавиш для диалога
        bind $w <Return> "::plugin::block::find_complex_replace \[$w.f.start.entry get\] \[$w.f.end.entry get\]"
        bind $w <Control-Return> "::plugin::block::do_complex_replace \[$w.f.start.entry get\] \[$w.f.end.entry get\] \[$w.f.newcode.text get 1.0 end-1c\]"
        bind $w <Escape> "destroy $w"

        # Очищаем флаг модификации и отключаем событие <<Modified>>
        $w.f.newcode.text edit modified 0
        
        # Устанавливаем минимальный размер окна
        wm minsize $w 500 400
        
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
        apply_theme_to_dialog $w
    }
    
    # Применение темы к диалогу
    proc apply_theme_to_dialog {w} {
        # Определяем цвета в зависимости от текущей темы
        if {[info exists ::core::config(theme)] && $::core::config(theme) eq "dark"} {
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

        # Применяем цвета к элементам диалога
        $w.f.newcode.text configure \
            -background $text_bg \
            -foreground $text_fg \
            -insertbackground $insert_bg
        $w.f.start.entry configure \
            -background $entry_bg \
            -foreground $entry_fg \
            -insertbackground $insert_bg
        $w.f.end.entry configure \
            -background $entry_bg \
            -foreground $entry_fg \
            -insertbackground $insert_bg
    }

    # Процедура поиска блока строк между метками
    proc find_complex_replace {start_marker end_marker} {
        # Получаем текущую вкладку
        set current_tab [.tabs select]
        if {$current_tab eq ""} {
            tk_messageBox -icon warning -title "Поиск" \
                -message "Нет открытой вкладки."
            return 0
        }

        set txt $current_tab.text
        
        # Проверяем, не пустые ли маркеры
        if {$start_marker eq "" || $end_marker eq ""} {
            tk_messageBox -icon warning -title "Поиск" \
                -message "Начальная и конечная метки не могут быть пустыми."
            return 0
        }
        
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
        
        # Копируем выделенный текст в поле нового кода
        set selected_text [$txt get $start_pos $end_pos]
        if {[winfo exists .complex_replace_dialog]} {
            .complex_replace_dialog.f.newcode.text delete 1.0 end
            .complex_replace_dialog.f.newcode.text insert 1.0 $selected_text
            # Выделяем весь вставленный текст для удобства
            .complex_replace_dialog.f.newcode.text tag add sel 1.0 end
            .complex_replace_dialog.f.newcode.text see 1.0
            # Передаем фокус на текстовое поле для удобства редактирования
            focus .complex_replace_dialog.f.newcode.text
        }
        
        return 1
    }

    # Процедура выполнения сложной замены (блок строк)
    proc do_complex_replace {start_marker end_marker new_code} {
        variable replace_all
        
        # Получаем текущую вкладку
        set current_tab [.tabs select]
        if {$current_tab eq ""} {
            tk_messageBox -icon warning -title "Замена" \
                -message "Нет открытой вкладки."
            return
        }

        set txt $current_tab.text
        if {![find_complex_replace $start_marker $end_marker]} {
            return
        }

        # Заменяем выделенный блок строк
        set start_pos [$txt index sel.first]
        set end_pos [$txt index sel.last]
        $txt delete $start_pos $end_pos
        $txt insert $start_pos $new_code

        # Отмечаем файл как модифицированный
        if {[info exists ::core::modified_tabs($current_tab)]} {
            set ::core::modified_tabs($current_tab) 1
            if {[info commands ::core::check_modified] ne ""} {
                ::core::check_modified $current_tab
            }
        }

        # Если включена опция "Заменить все"
        if {$replace_all} {
            set count 1
            while {[find_complex_replace $start_marker $end_marker]} {
                set start_pos [$txt index sel.first]
                set end_pos [$txt index sel.last]
                $txt delete $start_pos $end_pos
                $txt insert $start_pos $new_code
                incr count
            }
            tk_messageBox -icon info -title "Замена" \
                -message "Заменено блоков: $count"
        } else {
            # Ищем следующий блок
            after 100 [list ::plugin::block::find_complex_replace $start_marker $end_marker]
        }
    }
}
