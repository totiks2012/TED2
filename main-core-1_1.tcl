#!/usr/bin/wish
encoding system utf-8

# Main-Core.tcl - Основное ядро редактора с поддержкой плагинов
# Ядро Main-Core.tcl использует код Tide.tcl отсюда https://github.com/ALANVF/Tide
# License Non-Profit Open Software License 3.0 (NPOSL-3.0)
# Created: 2025-05-05 16:41:47 by totiks2012

package require Tk
package require ctext

# Глобальное пространство имен для ядра редактора
namespace eval ::core {
    # Базовые переменные конфигурации
    variable config
    array set config {
        version "1.0.0"
        theme "light"
        font_family "Courier"
        font_size 12
    }
    
    # Переменные для работы с вкладками
    variable tab_counter 0
    variable tab_files
    array set tab_files {}
    variable modified_tabs
    array set modified_tabs {}
    
    # Списки открытых файлов и плагинов
    variable open_files {}
    variable plugins {}
    variable plugin_buttons {}
    
    # API для плагинов
    variable plugin_api
    array set plugin_api {}
}

# Создание основного интерфейса
proc ::core::create_ui {} {
    # Настройка главного окна
    wm title . "TED2+"
    wm minsize . 800 600
    
    # Создаем тулбар
    ttk::frame .toolbar
    pack .toolbar -fill x
    
    # Фрейм для основных кнопок
    ttk::frame .toolbar.core
    pack .toolbar.core -side left -fill x
    
    # Фрейм для кнопок плагинов
    ttk::frame .toolbar.plugins
    pack .toolbar.plugins -side left -fill x -padx 5
    
    # Кнопки ядра для работы с вкладками
    ttk::button .toolbar.core.new -text "📄 Новый" -command ::core::create_tab
    ttk::button .toolbar.core.open -text "📂 Открыть" -command ::core::open_file
    ttk::button .toolbar.core.save -text "💾 Сохранить" -command ::core::save_current_file
    ttk::button .toolbar.core.save_as -text "💿 Сохранить как" -command ::core::save_as_file
    
    pack .toolbar.core.new .toolbar.core.open \
         .toolbar.core.save .toolbar.core.save_as \
         -side left -padx 2
    
    # Создаем notebook для вкладок
    ttk::notebook .tabs -padding 2
    pack .tabs -expand 1 -fill both
    
    # Привязки клавиш для основных операций с вкладками
    bind . <Control-n> { ::core::create_tab }
    bind . <Control-o> { ::core::open_file }
    bind . <Control-s> { ::core::save_current_file }
    bind . <Control-S> { ::core::save_as_file }
    bind . <Control-w> { ::core::close_current_tab }
    
    # Привязка для закрытия по правому клику
    bind .tabs <Button-3> {
        set tab [.tabs select]
        if {$tab ne ""} {
            ::core::close_current_tab
        }
    }
    
    # Настройка протокола закрытия окна
    wm protocol . WM_DELETE_WINDOW ::core::confirm_exit
}

# Создание новой вкладки
proc ::core::create_tab {{filename ""}} {
    variable config
    variable tab_counter
    variable tab_files
    variable modified_tabs
    
    # Создаем уникальное имя вкладки
    incr tab_counter
    while {[winfo exists .tabs.tab$tab_counter]} {
        incr tab_counter
    }
    set tab_name "tab$tab_counter"
    
    # Создаем фрейм для вкладки
    set tab .tabs.$tab_name
    ttk::frame $tab
    
    # Определяем цвета на основе темы
    if {$config(theme) eq "dark"} {
        set bg_color "#2D2D2D"
        set fg_color "#CCCACA"
        set sel_bg "#0F6FBF"
        set sel_fg "#FFFFFF"
        set ins_bg "#FFFFFF"
    } else {
        set bg_color "#FFFFFF"
        set fg_color "#000000"
        set sel_bg "#0060C0"
        set sel_fg "#FFFFFF"
        set ins_bg "#000000"
    }
    
    # Создаем текстовый виджет и полосы прокрутки
    ctext $tab.text \
        -wrap none \
        -undo 1 \
        -font [list $config(font_family) $config(font_size)] \
        -foreground $fg_color \
        -background $bg_color \
        -insertbackground $ins_bg \
        -selectbackground $sel_bg \
        -selectforeground $sel_fg \
        -height 24 \
        -yscrollcommand [list $tab.yscroll set] \
        -xscrollcommand [list $tab.xscroll set]
        
    ttk::scrollbar $tab.yscroll \
        -orient vertical \
        -command [list $tab.text yview]
    ttk::scrollbar $tab.xscroll \
        -orient horizontal \
        -command [list $tab.text xview]
        
    # Размещаем элементы с помощью grid
    grid $tab.text -row 0 -column 0 -sticky nsew
    grid $tab.yscroll -row 0 -column 1 -sticky ns
    grid $tab.xscroll -row 1 -column 0 -sticky ew
    
    # Настраиваем веса столбцов и строк
    grid columnconfigure $tab 0 -weight 1
    grid rowconfigure $tab 0 -weight 1
    
    # Добавляем вкладку в notebook
    if {$filename eq ""} {
        set tab_title "Новый $tab_counter"
        .tabs add $tab -text $tab_title
    } else {
        # Если указан файл, пытаемся его открыть
        if {[file exists $filename]} {
            if {[catch {
                set f [open $filename r]
                fconfigure $f -encoding utf-8
                set content [read $f]
                close $f
                
                # Устанавливаем содержимое
                $tab.text delete 1.0 end
                $tab.text insert 1.0 $content
                
                # Обновляем заголовок вкладки
                set tab_title [file tail $filename]
                .tabs add $tab -text $tab_title
                
                # Сохраняем информацию о файле
                set tab_files($tab) [file normalize $filename]
                if {[lsearch -exact $::core::open_files $filename] == -1} {
                    lappend ::core::open_files $filename
                }
                
            } err]} {
                tk_messageBox -icon error -title "Ошибка" \
                    -message "Ошибка открытия файла:\n$err"
                destroy $tab
                return ""
            }
        } else {
            tk_messageBox -icon error -title "Ошибка" \
                -message "Файл не существует:\n$filename"
            destroy $tab
            return ""
        }
    }
    
    # Включаем подсветку синтаксиса
    after idle "$tab.text highlight 1.0 end"
    
    # Настраиваем отслеживание изменений
    $tab.text edit modified 0
    bind $tab.text <<Modified>> [list ::core::check_modified $tab]
    
    # Инициализируем состояние
    set modified_tabs($tab) 0
    
    # Выбираем созданную вкладку
    .tabs select $tab
    focus $tab.text
    
    return $tab
}

# Проверка модификации текста
proc ::core::check_modified {tab} {
    variable modified_tabs
    
    if {[winfo exists $tab] && [string match ".tabs.*" $tab]} {
        set txt $tab.text
        if {[winfo exists $txt] && [$txt edit modified]} {
            # Обновляем заголовок вкладки
            set title [.tabs tab $tab -text]
            set base_title [string trimright $title " •"]
            
            if {![string match "*•" $title]} {
                .tabs tab $tab -text "$base_title •"
            }
            set modified_tabs($tab) 1
            
            # Сбрасываем флаг modified
            $txt edit modified 0
        }
    }
}

# Очистка состояния модификации
proc ::core::clear_tab_modified {tab} {
    variable modified_tabs

    set modified_tabs($tab) 0
    
    set title [.tabs tab $tab -text]
    set base_title [string trimright $title " •"]
    .tabs tab $tab -text $base_title
}

# Открытие файла
proc ::core::open_file {} {
    variable tab_files
    variable open_files
    
    set types {
        {"Tcl Scripts"     {.tcl}}
        {"Text Files"      {.txt}}
        {"Shell Scripts"   {.sh}}
        {"All Files"       *}
    }
    
    set filename [tk_getOpenFile -filetypes $types]
    if {$filename eq ""} {
        return
    }
    
    set norm_path [file normalize $filename]
    
    # Проверяем, не открыт ли уже файл
    foreach tab [.tabs tabs] {
        if {[info exists tab_files($tab)] && 
            [file normalize $tab_files($tab)] eq $norm_path} {
            .tabs select $tab
            return
        }
    }
    
    # Создаем новую вкладку
    ::core::create_tab $filename
}

# Сохранение текущего файла
proc ::core::save_current_file {} {
    variable tab_files
    variable modified_tabs
    variable open_files
    
    set current_tab [.tabs select]
    if {$current_tab eq ""} {
        tk_messageBox -icon warning -title "Сохранение" \
            -message "Нет открытой вкладки."
        return
    }
    
    # Если файл еще не существует, запускаем "Сохранить как"
    if {![info exists tab_files($current_tab)]} {
        ::core::save_as_file
        return
    }
    
    # Сохраняем файл
    if {[catch {
        set f [open $tab_files($current_tab) w]
        fconfigure $f -encoding utf-8
        puts -nonewline $f [$current_tab.text get 1.0 end-1c]
        close $f
        
        # Сбрасываем состояние
        ::core::clear_tab_modified $current_tab
        
    } err]} {
        tk_messageBox -icon error -title "Ошибка" \
            -message "Ошибка сохранения файла: $err"
    }
}

# Сохранение как
proc ::core::save_as_file {} {
    variable tab_files
    variable modified_tabs
    variable open_files
    
    set current_tab [.tabs select]
    if {$current_tab eq ""} {
        tk_messageBox -icon warning -title "Сохранение" \
            -message "Нет открытой вкладки."
        return
    }
    
    set types {
        {"Tcl Scripts"     {.tcl}}
        {"Text Files"      {.txt}}
        {"Shell Scripts"   {.sh}}
        {"All Files"       *}
    }
    
    set filename [tk_getSaveFile -filetypes $types]
    if {$filename eq ""} {
        return
    }
    
    if {[catch {
        # Сохраняем файл
        set f [open $filename w]
        fconfigure $f -encoding utf-8
        puts -nonewline $f [$current_tab.text get 1.0 end-1c]
        close $f
        
        # Обновляем информацию
        set tab_files($current_tab) [file normalize $filename]
        if {[lsearch -exact $open_files $filename] == -1} {
            lappend open_files $filename
        }
        
        # Сбрасываем состояние
        ::core::clear_tab_modified $current_tab
        
        # Обновляем заголовок
        .tabs tab $current_tab -text [file tail $filename]
        
    } err]} {
        tk_messageBox -icon error -title "Ошибка" \
            -message "Ошибка сохранения файла: $err"
    }
}

# Закрытие текущей вкладки
proc ::core::close_current_tab {} {
    variable tab_files
    variable modified_tabs
    variable open_files
    
    set current_tab [.tabs select]
    if {$current_tab eq ""} return
    
    # Проверяем наличие несохраненных изменений
    if {[info exists modified_tabs($current_tab)] && 
        $modified_tabs($current_tab)} {
        set answer [tk_messageBox -icon question -type yesnocancel \
            -title "Закрытие вкладки" \
            -message "В файле есть несохраненные изменения. Сохранить?"]
        
        switch -- $answer {
            yes {
                ::core::save_current_file
                # Проверяем, изменился ли статус модификации после сохранения
                if {[info exists modified_tabs($current_tab)] && $modified_tabs($current_tab)} {
                    # Если файл всё ещё помечен как модифицированный, значит сохранение не произошло
                    return
                }
            }
            cancel { return }
        }
    }
    
    # Удаляем информацию о файле
    if {[info exists tab_files($current_tab)]} {
        set idx [lsearch -exact $open_files $tab_files($current_tab)]
        if {$idx != -1} {
            set open_files [lreplace $open_files $idx $idx]
        }
        unset tab_files($current_tab)
    }
    
    # Удаляем информацию о модификации
    if {[info exists modified_tabs($current_tab)]} {
        unset modified_tabs($current_tab)
    }
    
    # Удаляем вкладку
    destroy $current_tab
    
    # Если не осталось вкладок, создаем новую
    if {[llength [.tabs tabs]] == 0} {
        ::core::create_tab
    }
}

# Подтверждение выхода из программы
proc ::core::confirm_exit {} {
    variable modified_tabs
    
    # Проверяем наличие несохраненных изменений
    set has_unsaved false
    foreach tab [.tabs tabs] {
        if {[info exists modified_tabs($tab)] && $modified_tabs($tab)} {
            set has_unsaved true
            break
        }
    }
    
    if {$has_unsaved} {
        set answer [tk_messageBox -icon question -type yesnocancel \
            -title "Несохраненные изменения" \
            -message "Есть несохраненные изменения. Сохранить перед выходом?"]
        
        switch -- $answer {
            yes {
                set save_failed false
                foreach tab [.tabs tabs] {
                    if {[info exists modified_tabs($tab)] && $modified_tabs($tab)} {
                        .tabs select $tab
                        ::core::save_current_file
                        # Проверяем, сохранился ли файл
                        if {[info exists modified_tabs($tab)] && $modified_tabs($tab)} {
                            set save_failed true
                            break
                        }
                    }
                }
                if {!$save_failed} {
                    exit
                }
            }
            no { exit }
            cancel { return }
        }
    } else {
        exit
    }
}

# Регистрация API для плагинов
proc ::core::register_plugin_api {} {
    variable plugin_api
    
    # API для работы с вкладками
    set plugin_api(create_tab) ::core::create_tab
    set plugin_api(close_tab) ::core::close_current_tab
    set plugin_api(get_current_tab) {.tabs select}
    set plugin_api(get_current_text) {
        set tab [.tabs select]
        if {$tab ne ""} {return $tab.text} else {return ""}
    }
    
    # API для работы с текстом
    set plugin_api(get_text) {
        set tab [.tabs select]
        if {$tab ne ""} {
            return [$tab.text get 1.0 end-1c]
        } else {
            return ""
        }
    }
    set plugin_api(set_text) {
        set tab [.tabs select]
        if {$tab ne ""} {
            $tab.text delete 1.0 end
            $tab.text insert 1.0 $text
        }
    }
    
    # API для файловых операций
    set plugin_api(get_file_path) {
        set tab [.tabs select]
        if {$tab ne "" && [info exists ::core::tab_files($tab)]} {
            return $::core::tab_files($tab)
        } else {
            return ""
        }
    }
    
    # API для настройки редактора
    set plugin_api(get_config) {
        set key [lindex $args 0]
        if {[info exists ::core::config($key)]} {
            return $::core::config($key)
        } else {
            return ""
        }
    }
    set plugin_api(set_config) {
        set key [lindex $args 0]
        set value [lindex $args 1]
        set ::core::config($key) $value
    }
    
    # API для работы с плагинами
    set plugin_api(register_button) ::core::register_plugin_button
}

# Регистрация кнопки плагина
proc ::core::register_plugin_button {plugin_name button_text command {icon ""} {button_order 100}} {
    variable plugin_buttons
    
    # Создаем уникальный идентификатор для кнопки
    set button_id [string map {" " "_"} $plugin_name]_[llength $plugin_buttons]
    
    # Создаем кнопку
    ttk::button .toolbar.plugins.$button_id -text $button_text -command $command
    
    # Сохраняем информацию о кнопке вместе с порядком
    lappend plugin_buttons [list $button_id $plugin_name $button_text $command $button_order]
    
    # Сортируем кнопки по порядку и перерисовываем
    ::core::update_plugin_buttons_order
    
    return $button_id
}

# Обновление порядка кнопок плагинов
proc ::core::update_plugin_buttons_order {} {
    variable plugin_buttons
    
    # Сортируем кнопки по значению button_order (5-й элемент)
    set sorted_buttons [lsort -integer -index 4 $plugin_buttons]
    
    # Удаляем все кнопки из панели
    foreach widget [pack slaves .toolbar.plugins] {
        pack forget $widget
    }
    
    # Упаковываем кнопки в отсортированном порядке
    foreach btn $sorted_buttons {
        set button_id [lindex $btn 0]
        if {[winfo exists .toolbar.plugins.$button_id]} {
            pack .toolbar.plugins.$button_id -side left -padx 2
        }
    }
}

# Загрузка плагинов
proc ::core::load_plugins {} {
    variable plugins
    
    # Определяем путь к каталогу плагинов
    set plugin_dir [file join [file dirname [info script]] "plugins"]
    
    # Проверяем существование каталога
    if {![file exists $plugin_dir] || ![file isdirectory $plugin_dir]} {
        puts "Каталог плагинов не найден: $plugin_dir"
        file mkdir $plugin_dir
        puts "Создан каталог плагинов: $plugin_dir"
        return
    }
    
    # Собираем все плагины для последующей сортировки
    set plugin_files [glob -nocomplain -directory $plugin_dir *.tcl]
    
    # Сортируем плагины по имени файла, чтобы сохранить порядок загрузки
    set sorted_plugin_files [lsort $plugin_files]
    
    # Загружаем каждый .tcl файл в каталоге
    foreach plugin_file $sorted_plugin_files {
        # Загружаем плагин в безопасном режиме
        if {[catch {
            set plugin_name [file rootname [file tail $plugin_file]]
            puts "Загрузка плагина: $plugin_name"
            
            # Создаем пространство имен для плагина
            namespace eval ::plugin::$plugin_name {
                # Устанавливаем по умолчанию button_order равным 100
                variable button_order 100
            }
            
            # Загружаем код плагина
            source $plugin_file
            
            # Проверяем инициализацию плагина
            if {[info commands ::plugin::${plugin_name}::init] ne ""} {
                # Вызываем инициализацию плагина
                if {[catch {::plugin::${plugin_name}::init} err]} {
                    puts "Ошибка инициализации плагина $plugin_name: $err"
                } else {
                    lappend plugins $plugin_name
                }
            } else {
                puts "Плагин $plugin_name не имеет функции init"
            }
        } err]} {
            puts "Ошибка загрузки плагина $plugin_file: $err"
        }
    }
    
    puts "Загружено плагинов: [llength $plugins]"
}

# Инициализация редактора
proc ::core::init {} {
    # Создаем интерфейс
    ::core::create_ui
    
    # Регистрируем API для плагинов
    ::core::register_plugin_api
    
    # Загружаем плагины
    ::core::load_plugins
    
    # Создаем начальную вкладку
    ::core::create_tab
    
    puts "Modular Editor инициализирован успешно."
    puts "Версия: $::core::config(version)"
}

# Запуск инициализации
::core::init
