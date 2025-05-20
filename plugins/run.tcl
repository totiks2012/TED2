# run.tcl - Плагин для запуска скриптов
# Created: 2025-05-05 16:49:09 by totiks2012
# Modified: 2025-05-09 to ensure isolated execution of Tcl/Tk scripts
# Modified: 2025-05-20 to add support for Python3 and Lua scripts

namespace eval ::plugin::run {
    # Устанавливаем порядок кнопки - вторая после базовых кнопок (после "Права")
    variable button_order 2
    
    # Настройки плагина
    variable config
    array set config {
        terminal "xterm"       ;# По умолчанию для Linux/Unix
        timeout 60000          ;# Таймаут выполнения в миллисекундах
        isolate_tcl 1          ;# 1 = запускать Tcl/Tk в отдельном процессе, 0 = в текущем (для отладки)
    }
    
    # Описание плагина
    variable plugin_info
    array set plugin_info {
        name "Run"
        version "1.2"
        description "Плагин для запуска скриптов с поддержкой Python и Lua"
        author "totiks2012"
    }
    
    # Инициализация плагина
    proc init {} {
        variable button_order
        variable config
        
        # Настройка терминала в зависимости от платформы
        if {$::tcl_platform(platform) eq "unix"} {
            foreach term {gnome-terminal xterm konsole xfce4-terminal terminator} {
                if {![catch {exec which $term}]} {
                    set config(terminal) $term
                    break
                }
            }
        }
        
        # Регистрируем кнопки в панели инструментов
        set run_button [::core::register_plugin_button "run" "▶️ Запуск" ::plugin::run::run_current_script "" $button_order]
        
        # Регистрируем горячие клавиши
        bind . <F5> { ::plugin::run::run_current_script }
        bind . <Control-r> { ::plugin::run::run_current_script }
        
        return 1
    }
    
    # Запуск текущего скрипта
    proc run_current_script {} {
        variable config
        
        # Получаем текущую вкладку
        set current_tab [.tabs select]
        if {$current_tab eq ""} {
            tk_messageBox -icon warning -title "Запуск" \
                -message "Нет открытой вкладки."
            return
        }
        
        # Получаем путь к файлу через API ядра
        set filepath ""
        
        # Проверяем, есть ли у текущей вкладки связанный файл
        if {[info exists ::core::tab_files($current_tab)]} {
            set filepath $::core::tab_files($current_tab)
            
            # Если файл модифицирован, предлагаем сохранить
            if {[info exists ::core::modified_tabs($current_tab)] && 
                $::core::modified_tabs($current_tab)} {
                set answer [tk_messageBox -icon question -type yesnocancel \
                    -title "Запуск скрипта" \
                    -message "Файл имеет несохраненные изменения. Сохранить перед запуском?"]
                
                switch -- $answer {
                    yes {
                        ::core::save_current_file
                        if {[info exists ::core::modified_tabs($current_tab)] && 
                            $::core::modified_tabs($current_tab)} {
                            return
                        }
                    }
                    cancel { return }
                }
            }
        } else {
            # Создаём временный файл для несохранённого скрипта
            set tmp_dir [file normalize [file join [pwd] "temp"]]
            file mkdir $tmp_dir
            
            set tmp_file [file join $tmp_dir "temp_script_[clock seconds][get_script_extension $current_tab]"]
            if {[catch {
                set f [open $tmp_file w]
                fconfigure $f -encoding utf-8
                puts -nonewline $f [$current_tab.text get 1.0 end]
                close $f
                set filepath $tmp_file
                
                # Устанавливаем права на выполнение (Unix)
                if {$::tcl_platform(platform) eq "unix"} {
                    exec chmod +x $tmp_file
                }
            } err]} {
                tk_messageBox -icon error -title "Ошибка" \
                    -message "Ошибка создания временного файла: $err"
                return
            }
        }
        
        # Проверяем существование файла
        if {![file exists $filepath]} {
            tk_messageBox -icon error -title "Ошибка" \
                -message "Файл не найден: $filepath"
            return
        }
        
        # Определяем рабочую директорию
        set work_dir [file dirname $filepath]
        
        # Определяем команду запуска
        set run_cmd [get_run_command $filepath]
        
        if {$run_cmd eq ""} {
            tk_messageBox -icon warning -title "Запуск" \
                -message "Неизвестный тип файла. Невозможно определить команду запуска."
            return
        }
        
        # Для Tcl/Tk скриптов с isolate_tcl=0 можем запускать в текущем интерпретаторе (для отладки)
        set extension [string tolower [file extension $filepath]]
        if {$extension eq ".tcl" && !$config(isolate_tcl)} {
            if {[catch {
                puts "Запуск $filepath в текущем интерпретаторе (для отладки)"
                uplevel #0 source $filepath
            } err]} {
                tk_messageBox -icon error -title "Ошибка" \
                    -message "Ошибка выполнения в текущем интерпретаторе:\n$err"
            }
            return
        }
        
        # Формируем команду для отдельного процесса
        if {$::tcl_platform(platform) eq "unix"} {
            set cmd [list $config(terminal)]
            
            switch -glob $config(terminal) {
                "gnome-terminal" {
                    lappend cmd "--" "bash" "-c" "cd \"$work_dir\"; $run_cmd; echo; echo 'Нажмите Enter для закрытия окна...'; read"
                }
                "konsole" {
                    lappend cmd "-e" "bash" "-c" "cd \"$work_dir\"; $run_cmd; echo; echo 'Нажмите Enter для закрытия окна...'; read"
                }
                "xfce4-terminal" {
                    lappend cmd "-e" "bash -c \"cd \\\"$work_dir\\\"; $run_cmd; echo; echo 'Нажмите Enter для закрытия окна...'; read\""
                }
                default {
                    lappend cmd "-e" "bash" "-c" "cd \"$work_dir\"; $run_cmd; echo; echo 'Нажмите Enter для закрытия окна...'; read"
                }
            }
        } else {
            # Windows
            set cmd [list "cmd.exe" "/c" "start" "cmd.exe" "/k" "cd /d \"$work_dir\" && $run_cmd && pause"]
        }
        
        # Запускаем скрипт
        if {[catch {
            puts "Рабочая директория: $work_dir"
            puts "Запуск команды: $cmd"
            set pid [exec {*}$cmd &]
            puts "Процесс запущен, PID: $pid"
        } err]} {
            tk_messageBox -icon error -title "Ошибка" \
                -message "Ошибка выполнения:\n$err"
        }
        
        # Удаляем временный файл
        if {[string match "*/temp_script_*" $filepath]} {
            after $config(timeout) [list file delete -force $filepath]
        }
    }
    
    # Определение расширения файла
    proc get_script_extension {tab} {
        set first_line [$tab.text get 1.0 "1.0 lineend"]
        
        if {[string match "#!/bin/bash*" $first_line] || 
            [string match "#!/usr/bin/bash*" $first_line] || 
            [string match "#!/bin/sh*" $first_line]} {
            return ".sh"
        } elseif {[string match "#!/usr/bin/env python*" $first_line] || 
                 [string match "#!/usr/bin/python*" $first_line]} {
            return ".py"
        } elseif {[string match "#!/usr/bin/env perl*" $first_line] || 
                 [string match "#!/usr/bin/perl*" $first_line]} {
            return ".pl"
        } elseif {[string match "#!/usr/bin/env ruby*" $first_line] || 
                 [string match "#!/usr/bin/ruby*" $first_line]} {
            return ".rb"
        } elseif {[string match "#!/usr/bin/env lua*" $first_line] || 
                 [string match "#!/usr/bin/lua*" $first_line]} {
            return ".lua"
        } elseif {[string match "#!/usr/bin/wish*" $first_line] || 
                 [string match "#!/usr/bin/env wish*" $first_line] ||
                 [string match "package require Tk*" $first_line]} {
            return ".tcl"
        } elseif {[string match "#!/usr/bin/tclsh*" $first_line] || 
                 [string match "#!/usr/bin/env tclsh*" $first_line]} {
            return ".tcl"
        } else {
            # Проверяем содержимое на соответствие типичным языковым конструкциям
            set content [$tab.text get 1.0 "end"]
            
            if {[string match "*import *" $content] && 
                ([string match "*def *(*):*" $content] || [string match "*print(*" $content])} {
                return ".py"
            } elseif {[string match "*function*(*)" $content] && 
                     ([string match "*require*" $content] || [string match "*end*" $content])} {
                return ".lua"
            } else {
                return ".tcl"
            }
        }
    }
    
    # Определение команды запуска
    proc get_run_command {filepath} {
        set extension [string tolower [file extension $filepath]]
        
        switch -glob $extension {
            ".tcl" {
                set contains_tk 0
                if {![catch {
                    set f [open $filepath r]
                    set content [read $f]
                    close $f
                    if {[string match "*package require Tk*" $content] || 
                        [string match "*#!/usr/bin/wish*" $content] || 
                        [string match "*#!/usr/bin/env wish*" $content]} {
                        set contains_tk 1
                    }
                }]} {
                    if {$contains_tk} {
                        return "wish \"$filepath\""
                    } else {
                        return "tclsh \"$filepath\""
                    }
                } else {
                    return "tclsh \"$filepath\""
                }
            }
            ".sh" {
                return "bash \"$filepath\""
            }
            ".py" {
                # Проверяем доступные интерпретаторы Python
                if {![catch {exec which python3}]} {
                    return "python3 \"$filepath\""
                } elseif {![catch {exec which python}]} {
                    return "python \"$filepath\""
                } else {
                    # Предполагаем, что python3 должен быть доступен
                    return "python3 \"$filepath\""
                }
            }
            ".lua" {
                # Проверяем доступные интерпретаторы Lua
                if {![catch {exec which lua5.3}]} {
                    return "lua5.3 \"$filepath\""
                } elseif {![catch {exec which lua5.4}]} {
                    return "lua5.4 \"$filepath\""
                } elseif {![catch {exec which lua}]} {
                    return "lua \"$filepath\""
                } else {
                    # Предполагаем, что lua должен быть доступен
                    return "lua \"$filepath\""
                }
            }
            ".pl" {
                return "perl \"$filepath\""
            }
            ".rb" {
                return "ruby \"$filepath\""
            }
            default {
                if {$::tcl_platform(platform) eq "unix" && [file executable $filepath]} {
                    return "\"$filepath\""
                } else {
                    # Попытка определить тип файла по содержимому
                    if {![catch {
                        set f [open $filepath r]
                        set content [read $f]
                        close $f
                        
                        if {[string match "*import *" $content] && 
                            ([string match "*def *(*):*" $content] || [string match "*print(*" $content])} {
                            # Проверяем доступные интерпретаторы Python
                            if {![catch {exec which python3}]} {
                                return "python3 \"$filepath\""
                            } else {
                                return "python3 \"$filepath\""  # Всегда используем python3
                            }
                        } elseif {[string match "*function*(*)" $content] && 
                                ([string match "*require*" $content] || [string match "*end*" $content])} {
                            # Проверяем доступные интерпретаторы Lua
                            if {![catch {exec which lua5.3}]} {
                                return "lua5.3 \"$filepath\""
                            } elseif {![catch {exec which lua}]} {
                                return "lua \"$filepath\""
                            } else {
                                return "lua \"$filepath\""  # Предполагаем, что lua должен быть доступен
                            }
                        }
                    }]} {
                        # Не удалось определить по содержимому
                        return ""
                    }
                    
                    return ""
                }
            }
        }
    }
}
