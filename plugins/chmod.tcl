# chmod.tcl - Плагин для установки прав на выполнение скриптов
# Created: 2025-05-05 16:45:41 by totiks2012

namespace eval ::plugin::chmod {
    # Устанавливаем порядок кнопки - первая после базовых кнопок
    variable button_order 1
    
    # Описание плагина
    variable plugin_info
    array set plugin_info {
        name "Chmod"
        version "1.0"
        description "Плагин для установки прав на выполнение скриптов"
        author "totiks2012"
    }
    
    # Инициализация плагина
    proc init {} {
        variable button_order
        
        # Проверяем, работаем ли в Unix-подобной системе
        if {$::tcl_platform(platform) eq "unix"} {
            # Регистрируем кнопку в панели инструментов
            set button_id [::core::register_plugin_button "chmod" "🔐 Права" ::plugin::chmod::set_executable_permissions "" $button_order]
            
            # Регистрируем горячие клавиши
            bind . <Alt-x> { ::plugin::chmod::set_executable_permissions }
            
            return 1
        } else {
            # В Windows не регистрируем кнопку, т.к. она там не нужна
            puts "Плагин 'chmod' пропущен: не требуется в Windows"
            return 0
        }
    }
    
    # Установка прав на выполнение для текущего скрипта
    proc set_executable_permissions {} {
        # Проверяем, что работаем в Unix-подобной системе
        if {$::tcl_platform(platform) ne "unix"} {
            tk_messageBox -icon info -title "Информация" \
                -message "Установка прав не требуется в Windows."
            return
        }
        
        # Получаем текущую вкладку
        set current_tab [.tabs select]
        if {$current_tab eq ""} {
            tk_messageBox -icon warning -title "Предупреждение" \
                -message "Нет открытой вкладки."
            return
        }
        
        # Проверяем, есть ли связанный файл у текущей вкладки
        if {![info exists ::core::tab_files($current_tab)]} {
            tk_messageBox -icon warning -title "Предупреждение" \
                -message "Сначала сохраните файл."
            return
        }
        
        # Получаем путь к файлу
        set filepath $::core::tab_files($current_tab)
        
        # Проверяем, существует ли файл
        if {![file exists $filepath]} {
            tk_messageBox -icon error -title "Ошибка" \
                -message "Файл не существует:\n$filepath"
            return
        }
        
        # Определяем тип файла по расширению
        set extension [string tolower [file extension $filepath]]
        
        # Список скриптовых расширений
        set script_extensions {".tcl" ".sh" ".py" ".pl" ".rb" ".bash"}
        
        # Проверка, является ли файл скриптом
        set is_script 0
        if {$extension in $script_extensions} {
            set is_script 1
        } else {
            # Дополнительная проверка: смотрим первую строку файла на shebang (#!)
            if {[catch {
                set f [open $filepath r]
                set first_line [gets $f]
                close $f
                if {[string match "#!*" $first_line]} {
                    set is_script 1
                }
            } err]} {
                puts "Ошибка проверки файла: $err"
            }
        }
        
        # Устанавливаем права в зависимости от типа файла
        if {[catch {
            if {$is_script} {
                # Для скриптов - выполняемые права (rwxr-xr-x)
                exec chmod 755 $filepath
                tk_messageBox -icon info -title "Права установлены" \
                    -message "Установлены права на выполнение (755) для файла:\n$filepath"
            } else {
                # Для обычных файлов - только чтение и запись (rw-r--r--)
                exec chmod 644 $filepath
                tk_messageBox -icon info -title "Права установлены" \
                    -message "Установлены стандартные права (644) для файла:\n$filepath"
            }
        } err]} {
            tk_messageBox -icon error -title "Ошибка" \
                -message "Ошибка установки прав:\n$err"
        }
    }
}
