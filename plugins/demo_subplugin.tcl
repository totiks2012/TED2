# demo_subplugin.tcl - Демонстрационный подплагин для панели инструментов
# Created: 2025-05-06 15:58:12 by totiks2012

namespace eval ::plugin::demo_subplugin {
    # Описание плагина
    variable plugin_info
    array set plugin_info {
        name "Demo Subplugin"
        version "1.0"
        description "Демонстрационный подплагин для показа возможностей панели инструментов"
        author "totiks2012"
    }
    
    # Указание панели, в которой должен быть зарегистрирован подплагин
    # Формат: {panel_id panel_label}
    variable panel_info {main "Панель"}
    
    # Переменная для отслеживания инициализации
    variable initialized 0
    variable registered 0
    
    # Инициализация плагина
    proc init {} {
        variable initialized
        variable registered
        variable panel_info
        
        # Защита от повторной инициализации
        if {$initialized} {
            return 1
        }
        
        # Проверяем доступность панели
        if {[info exists ::PANEL_MANAGER_AVAILABLE]} {
            # Регистрируем подплагин в указанной панели
            register_in_panel
            set registered 1
        } else {
            # Устанавливаем отложенную регистрацию
            after 1000 ::plugin::demo_subplugin::delayed_registration
        }
        
        set initialized 1
        return 1
    }
    
    # Отложенная регистрация в панели
    proc delayed_registration {} {
        variable registered
        variable panel_info
        
        # Проверяем, зарегистрирован ли уже подплагин
        if {$registered} {
            return
        }
        
        # Проверяем доступность панели
        if {[info exists ::PANEL_MANAGER_AVAILABLE]} {
            register_in_panel
            set registered 1
        } else {
            # Повторяем попытку еще раз позже
            after 2000 ::plugin::demo_subplugin::delayed_registration
        }
    }
    
    # Регистрация в панели
    proc register_in_panel {} {
        variable panel_info
        
        if {[info commands ::register_panel_subplugin] ne ""} {
            # Получаем ID панели
            set panel_id [lindex $panel_info 0]
            
            # Регистрируем демонстрационный подплагин в указанной панели
            ::register_panel_subplugin $panel_id "demo" "Demo" ::plugin::demo_subplugin::show_demo_message
            puts "Демонстрационный подплагин зарегистрирован в панели '$panel_id'."
        }
    }
    
    # Функция, вызываемая при нажатии на кнопку "Demo"
    proc show_demo_message {} {
        # Устанавливаем иконку в зависимости от темы
        if {[info exists ::core::config(theme)] && $::core::config(theme) eq "dark"} {
            set icon "info"
        } else {
            set icon "info"
        }
        
        # Показываем информационное сообщение
        tk_messageBox -icon $icon -title "Демонстрационный подплагин" \
            -message "Это демонстрационный подплагин" \
            -detail "Данный подплагин предназначен только для демонстрации возможностей панели инструментов. Он не выполняет никаких полезных функций." \
            -type ok
    }
}

# Загружаем демонстрационный подплагин
::plugin::demo_subplugin::init
