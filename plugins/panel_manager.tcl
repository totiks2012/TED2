# panel_manager.tcl - Универсальный плагин управления несколькими панелями для кнопок подплагинов
# Created: 2025-05-06 15:58:12 by totiks2012

namespace eval ::plugin::panel_manager {
    # Переменные плагина
    variable button_order 8
    variable panel_visible
    array set panel_visible {}
    variable button_registered
    array set button_registered {}
    variable panel_widgets
    array set panel_widgets {}
    variable panel_plugins
    array set panel_plugins {}
    
    # Описание плагина
    variable plugin_info
    array set plugin_info {
        name "Panel Manager"
        version "1.1"
        description "Универсальный менеджер панелей для размещения кнопок подплагинов"
        author "totiks2012"
    }
    
    # Инициализация плагина
    proc init {} {
        # Инициализируем менеджер панелей
        initialize_panel "main" "Панель" 7
        
        # Создаем глобальную процедуру для регистрации подплагинов
        namespace eval :: {
            proc register_panel_subplugin {panel_id plugin_id label action {icon ""}} {
                return [::plugin::panel_manager::register_panel_plugin $panel_id $plugin_id $label $action $icon]
            }
            
            # Экспортируем константу, по которой подплагины могут проверить доступность панелей
            variable PANEL_MANAGER_AVAILABLE 1
        }
        
        # Запускаем проверку на наличие подплагинов для других панелей
        after 1000 ::plugin::panel_manager::check_for_new_panels
        
        return 1
    }
    
    # Инициализация новой панели
    proc initialize_panel {panel_id panel_label {btn_order 10}} {
        variable button_registered
        variable panel_plugins
        
        # Защита от повторной инициализации
        if {[info exists button_registered($panel_id)] && $button_registered($panel_id)} {
            return 1
        }
        
        # Инициализируем список плагинов для панели, если его еще нет
        if {![info exists panel_plugins($panel_id)]} {
            set panel_plugins($panel_id) [list]
        }
        
        # Регистрируем кнопку в панели инструментов
        ::core::register_plugin_button "${panel_id}_panel" $panel_label \
            [list ::plugin::panel_manager::toggle_panel $panel_id] "" $btn_order
        
        # Отмечаем, что кнопка зарегистрирована
        set button_registered($panel_id) 1
        
        puts "Панель '$panel_id' ($panel_label) инициализирована."
        return 1
    }
    
    # Проверка на наличие подплагинов для новых панелей
    proc check_for_new_panels {} {
        variable panel_plugins
        
        # Получаем список всех загруженных namespaces
        set namespaces [namespace children ::]
        
        # Проходим по всем namespaces и ищем потенциальные подплагины
        foreach ns $namespaces {
            if {[string match "::plugin::*" $ns]} {
                # Проверяем наличие данных для подплагина
                set plugin_ns [string trimleft $ns ":"]
                if {[info exists ${plugin_ns}::panel_info]} {
                    # Получаем информацию о панели
                    set panel_info [set ${plugin_ns}::panel_info]
                    
                    # Проверяем, существует ли такая панель
                    set panel_id [lindex $panel_info 0]
                    if {![info exists panel_plugins($panel_id)]} {
                        # Создаем новую панель
                        set panel_label [lindex $panel_info 1]
                        if {$panel_label eq ""} {
                            set panel_label "Панель $panel_id"
                        }
                        
                        # Инициализируем новую панель
                        initialize_panel $panel_id $panel_label
                    }
                }
            }
        }
        
        # Повторяем проверку через определенное время
        after 5000 ::plugin::panel_manager::check_for_new_panels
    }
    
    # Регистрация плагина в панели
    proc register_panel_plugin {panel_id plugin_id label action {icon ""}} {
        variable panel_plugins
        
        # Проверяем наличие указанной панели
        if {![info exists panel_plugins($panel_id)]} {
            # Создаем новую панель на лету
            set panel_label "Панель $panel_id"
            initialize_panel $panel_id $panel_label
        }
        
        # Проверяем, не зарегистрирован ли уже плагин с таким id в этой панели
        foreach plugin $panel_plugins($panel_id) {
            if {[lindex $plugin 0] eq $plugin_id} {
                puts "Предупреждение: Подплагин с ID '$plugin_id' уже зарегистрирован в панели '$panel_id'. Пропуск регистрации."
                return 0
            }
        }
        
        # Добавляем информацию о подплагине в список
        lappend panel_plugins($panel_id) [list $plugin_id $label $action $icon]
        
        # Обновляем панель, если она видима
        if {[winfo exists .plugin_panel_$panel_id]} {
            update_panel $panel_id
        }
        
        puts "Подплагин '$label' успешно зарегистрирован в панели '$panel_id'."
        return 1
    }
    
    # Переключение видимости панели
    proc toggle_panel {panel_id} {
        variable panel_visible
        
        # Инициализируем статус видимости, если его еще нет
        if {![info exists panel_visible($panel_id)]} {
            set panel_visible($panel_id) 0
        }
        
        if {$panel_visible($panel_id)} {
            hide_panel $panel_id
        } else {
            show_panel $panel_id
        }
    }
    
    # Показ панели
    proc show_panel {panel_id} {
        variable panel_visible
        variable panel_widgets
        variable panel_plugins
        
        # Проверяем, существует ли панель
        if {[winfo exists .plugin_panel_$panel_id]} {
            destroy .plugin_panel_$panel_id
        }
        
        # Создаем новую панель
        toplevel .plugin_panel_$panel_id
        wm overrideredirect .plugin_panel_$panel_id 1
        
        # Устанавливаем цвета в зависимости от темы
        if {[info exists ::core::config(theme)] && $::core::config(theme) eq "dark"} {
            set bg "#2D2D2D"
            set fg "#CCCACA"
            set button_bg "#404040"
            set button_fg "#FFFFFF"
        } else {
            set bg "#FFFFFF"
            set fg "#000000"
            set button_bg "#F0F0F0"
            set button_fg "#000000"
        }
        
        # Создаем основной фрейм с минимальными отступами
        frame .plugin_panel_${panel_id}.main -background $bg -padx 2 -pady 2
        pack .plugin_panel_${panel_id}.main -fill both -expand 1
        
        # Создаем фрейм для размещения кнопок подплагинов и кнопки закрытия
        frame .plugin_panel_${panel_id}.main.container -background $bg
        pack .plugin_panel_${panel_id}.main.container -fill x -expand 1
        
        # Добавляем кнопки подплагинов и кнопку закрытия в один ряд
        update_panel $panel_id
        
        # Позиционируем панель поверх основной панели инструментов
        # Определяем размеры и положение основной панели
        set toolbar_y [winfo rooty .toolbar]
        set toolbar_height [winfo height .toolbar]
        set toolbar_x [winfo rootx .toolbar]
        set toolbar_width [winfo width .toolbar]
        
        # Выравниваем панель по ширине на основе содержимого
        update idletasks
        set panel_width [winfo reqwidth .plugin_panel_$panel_id]
        set panel_height [winfo reqheight .plugin_panel_$panel_id]
        
        # Устанавливаем минимальную ширину панели
        if {$panel_width < $toolbar_width} {
            set panel_width $toolbar_width
        }
        
        # Позиционируем панель точно поверх основной панели инструментов
        wm geometry .plugin_panel_$panel_id "${panel_width}x${panel_height}+${toolbar_x}+${toolbar_y}"
        
        # Поднимаем панель поверх всех окон
        raise .plugin_panel_$panel_id
        
        set panel_visible($panel_id) 1
        set panel_widgets($panel_id) .plugin_panel_$panel_id
    }
    
    # Скрытие панели
    proc hide_panel {panel_id} {
        variable panel_visible
        
        # Уничтожаем панель
        if {[winfo exists .plugin_panel_$panel_id]} {
            destroy .plugin_panel_$panel_id
        }
        
        set panel_visible($panel_id) 0
    }
    
    # Обновление содержимого панели
    proc update_panel {panel_id} {
        variable panel_plugins
        
        # Проверяем, существует ли панель
        if {![winfo exists .plugin_panel_$panel_id]} {
            return
        }
        
        # Устанавливаем цвета в зависимости от темы
        if {[info exists ::core::config(theme)] && $::core::config(theme) eq "dark"} {
            set bg "#2D2D2D"
            set fg "#CCCACA"
            set button_bg "#404040"
            set button_fg "#FFFFFF"
        } else {
            set bg "#FFFFFF"
            set fg "#000000"
            set button_bg "#F0F0F0"
            set button_fg "#000000"
        }
        
        # Контейнер для кнопок и сообщений
        set container .plugin_panel_${panel_id}.main.container
        
        # Удаляем все существующие элементы
        foreach w [winfo children $container] {
            destroy $w
        }
        
        # Создаем фрейм для кнопок подплагинов (слева)
        frame $container.buttons -background $bg
        pack $container.buttons -side left -fill y -padx 2
        
        # Создаем фрейм для кнопки закрытия (справа)
        frame $container.close_frame -background $bg
        pack $container.close_frame -side right -fill y -padx 2
        
        # Добавляем кнопку закрытия (справа)
        button $container.close_frame.close -text "Закрыть" -command [list ::plugin::panel_manager::hide_panel $panel_id] \
            -relief raised -background $button_bg -foreground $button_fg -width 8 -padx 5 -pady 2
        pack $container.close_frame.close -pady 2
        
        # Проверяем наличие зарегистрированных подплагинов для этой панели
        if {![info exists panel_plugins($panel_id)] || [llength $panel_plugins($panel_id)] == 0} {
            # Если нет зарегистрированных подплагинов, показываем сообщение
            label $container.buttons.empty -text "Нет подплагинов" \
                -background $bg -foreground $fg
            pack $container.buttons.empty -pady 2
            return
        }
        
        # Добавляем кнопки для всех зарегистрированных подплагинов
        foreach plugin $panel_plugins($panel_id) {
            lassign $plugin plugin_id label action icon
            
            # Создаем кнопку подплагина фиксированного размера
            button $container.buttons.${plugin_id} -text $label -command $action \
                -relief raised -background $button_bg -foreground $button_fg -width 10 -padx 5 -pady 2
            
            # Размещаем кнопку горизонтально
            pack $container.buttons.${plugin_id} -side left -padx 2 -pady 2
        }
    }
}

# Загружаем плагин
::plugin::panel_manager::init
