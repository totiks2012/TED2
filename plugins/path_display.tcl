# path_display.tcl - Плагин для отображения полного пути текущего файла
# Updated: 2025-05-07 15:52:25 by totiks2012

namespace eval ::plugin::path_display {
    # Устанавливаем порядок кнопки (можно изменить по необходимости)
    variable button_order 6
    
    # Флаг для отслеживания статуса инициализации
    variable initialized 0
    
    # Флаг отображения панели пути
    variable is_path_panel_visible 0
    
    # Виджет панели пути (текстовое поле для выделения/копирования)
    variable path_entry ""
    
    # Путь к последнему открытому файлу
    variable last_file_path ""
    
    # Описание плагина
    variable plugin_info
    array set plugin_info {
        name "PathDisplay"
        version "1.7"
        description "Плагин для отображения и копирования полного пути открытого файла"
        author "totiks2012"
    }
    
    # Инициализация плагина
    proc init {} {
        variable button_order
        variable initialized
        
        # Проверяем, не был ли плагин уже инициализирован
        if {$initialized} {
            puts "Плагин PathDisplay уже инициализирован."
            return 1
        }
        
        # Регистрируем кнопку в панели инструментов
        set path_button [::core::register_plugin_button "path" "📍 Путь" ::plugin::path_display::toggle_path_panel "" $button_order]
        
        # Создаем панель для отображения пути
        create_path_panel
        
        # Регистрируем обработчики событий для обнаружения изменений файла и табов
        bind .tabs <<NotebookTabChanged>> {
            after 100 ::plugin::path_display::update_path_display
        }
        
        # Также привязываемся к событию изменения геометрии окна (resize)
        bind . <Configure> {
            if {$::plugin::path_display::is_path_panel_visible} {
                after 200 ::plugin::path_display::adjust_panel_position
            }
        }
        
        # Привязка к событию активации окна
        bind . <FocusIn> {
            if {$::plugin::path_display::is_path_panel_visible} {
                after 100 ::plugin::path_display::update_path_display
            }
        }
        
        # Перехватываем события сохранения файла
        if {[info commands ::core::save_current_file] ne ""} {
            rename ::core::save_current_file ::core::_original_save_current_file
            proc ::core::save_current_file {} {
                set result [::core::_original_save_current_file]
                after idle {
                    if {$::plugin::path_display::is_path_panel_visible} {
                        ::plugin::path_display::update_path_display
                    }
                }
                return $result
            }
        }
        
        # Перехватываем события открытия файла
        if {[info commands ::core::open_file] ne ""} {
            # Сначала проверим, сколько аргументов принимает оригинальная функция
            set original_args_count [llength [info args ::core::open_file]]
            
            # Сохраняем оригинальную функцию
            rename ::core::open_file ::core::_original_open_file
            
            # Определяем новую функцию с правильным количеством аргументов
            if {$original_args_count == 0} {
                # Если оригинальная функция не принимает аргументов
                proc ::core::open_file {} {
                    set result [::core::_original_open_file]
                    
                    # После открытия файла пытаемся получить путь
                    # из заголовка текущей вкладки
                    if {[catch {
                        set current_tab [.tabs select]
                        if {$current_tab ne ""} {
                            set tab_text [.tabs tab $current_tab -text]
                            if {$tab_text ne ""} {
                                # Используем имя файла для поиска полного пути
                                set current_dir [pwd]
                                if {[file exists [file join $current_dir $tab_text]]} {
                                    set file_path [file normalize [file join $current_dir $tab_text]]
                                    set ::plugin::path_display::last_file_path $file_path
                                } else {
                                    # Просто сохраняем имя файла как частичный путь
                                    set ::plugin::path_display::last_file_path $tab_text
                                }
                            }
                        }
                    } err]} {
                        # Если произошла ошибка, просто игнорируем ее
                    }
                    
                    # Обновляем отображение пути с небольшой задержкой
                    after idle {
                        if {$::plugin::path_display::is_path_panel_visible} {
                            ::plugin::path_display::update_path_display
                        }
                    }
                    
                    return $result
                }
            } else {
                # Если оригинальная функция принимает аргументы
                proc ::core::open_file {{file_path ""}} {
                    # Вызываем оригинальную функцию с тем же аргументом
                    if {$file_path eq ""} {
                        set result [::core::_original_open_file]
                    } else {
                        set result [::core::_original_open_file $file_path]
                        # Сохраняем путь, если он указан
                        set ::plugin::path_display::last_file_path $file_path
                    }
                    
                    # Обновляем отображение пути с небольшой задержкой
                    after idle {
                        if {$::plugin::path_display::is_path_panel_visible} {
                            ::plugin::path_display::update_path_display
                        }
                    }
                    
                    return $result
                }
            }
        }
        
        # Устанавливаем флаг инициализации
        set initialized 1
        puts "Плагин PathDisplay версии 1.7 успешно инициализирован."
        
        return 1
    }
    
    # Создание панели для отображения пути
    proc create_path_panel {} {
        variable path_entry
        
        # Создаем фрейм для панели пути в нижней части редактора
        if {![winfo exists .path_panel]} {
            frame .path_panel -height 25 -background "#F0F0F0" -relief flat -bd 1
            
            # Создаем текстовое поле для отображения пути
            set path_entry [entry .path_panel.path -relief flat -bd 0 \
                          -background "#F0F0F0" -foreground "#333333" -highlightthickness 0]
            
            # Делаем поле только для чтения, но с возможностью выделения
            $path_entry configure -state readonly -readonlybackground "#F0F0F0" \
                                -disabledforeground "#333333" -exportselection 1
            
            # Упаковываем текстовое поле, чтобы оно занимало всю ширину
            pack $path_entry -fill x -expand 1 -padx 5 -pady 2
            
            # Устанавливаем шрифт для пути
            $path_entry configure -font "TkDefaultFont"
            
            # Добавляем подсказку при наведении
            tooltip $path_entry "Полный путь к файлу (можно выделить и скопировать)"
            
            # Добавляем привязку для Ctrl+C (копирование выделенного текста)
            bind $path_entry <Control-c> {
                if {[%W selection present]} {
                    clipboard clear
                    clipboard append [%W get] 
                    ::plugin::path_display::show_notification "Путь скопирован в буфер обмена"
                }
            }
            
            # Добавляем привязку для двойного клика (выделение всего текста)
            bind $path_entry <Double-1> {
                %W selection range 0 end
            }
            
            # Скрываем панель изначально
            hide_path_panel
        }
    }
    
    # Регулировка положения панели при изменении размера окна
    proc adjust_panel_position {} {
        variable is_path_panel_visible
        
        # Если панель не отображается, ничего не делаем
        if {!$is_path_panel_visible} {
            return
        }
        
        # Если панель размещена через place, обновляем её размеры
        if {[string match "place" [winfo manager .path_panel]]} {
            # Определяем новые размеры
            set screen_width [winfo width .]
            set path_height 25
            set screen_height [winfo height .]
            
            # Обновляем размеры и положение
            place .path_panel -x 0 -y [expr {$screen_height - $path_height}] \
                             -width $screen_width -height $path_height
        }
    }
    
    # Показать панель пути
    proc show_path_panel {} {
        variable is_path_panel_visible
        
        # Если панель еще не отображается, показываем ее
        if {!$is_path_panel_visible} {
            # Размещаем панель внизу основного окна, пытаясь несколько вариантов
            if {[catch {
                # Пробуем вариант 1: Размещаем перед .tabs 
                pack .path_panel -side bottom -fill x -before .tabs
            }]} {
                if {[catch {
                    # Пробуем вариант 2: Размещаем в конце упаковки
                    pack .path_panel -side bottom -fill x
                }]} {
                    # Пробуем вариант 3: Размещаем через place (абсолютное позиционирование)
                    set screen_width [winfo width .]
                    set path_height 25
                    set screen_height [winfo height .]
                    
                    place .path_panel -x 0 -y [expr {$screen_height - $path_height}] \
                                     -width $screen_width -height $path_height
                }
            }
            
            # Обновляем флаг видимости
            set is_path_panel_visible 1
            
            # Сразу обновляем путь
            after 50 ::plugin::path_display::update_path_display
        }
    }
    
    # Скрыть панель пути
    proc hide_path_panel {} {
        variable is_path_panel_visible
        
        # Если панель отображается, скрываем ее
        if {$is_path_panel_visible} {
            # Определяем менеджер размещения и скрываем панель соответствующим образом
            set mgr [winfo manager .path_panel]
            if {$mgr eq "pack"} {
                pack forget .path_panel
            } elseif {$mgr eq "place"} {
                place forget .path_panel
            } elseif {$mgr eq "grid"} {
                grid forget .path_panel
            }
            
            # Обновляем флаг видимости
            set is_path_panel_visible 0
        }
    }
    
    # Переключение видимости панели пути
    proc toggle_path_panel {} {
        variable is_path_panel_visible
        
        if {$is_path_panel_visible} {
            hide_path_panel
        } else {
            show_path_panel
        }
    }
    
    # Обновление отображения пути
    proc update_path_display {} {
        variable path_entry
        variable is_path_panel_visible
        variable last_file_path
        
        # Если панель не видна, нет смысла обновлять путь
        if {!$is_path_panel_visible || ![winfo exists $path_entry]} {
            return
        }
        
        # Получаем текущую вкладку
        if {[catch {set current_tab [.tabs select]} err]} {
            set_entry_text $path_entry "Ошибка: не удалось получить текущую вкладку"
            return
        }
        
        # Проверяем, существует ли вкладка
        if {$current_tab eq ""} {
            set_entry_text $path_entry "Нет открытого файла"
            return
        }
        
        # Получаем имя файла из заголовка вкладки
        if {[catch {set tab_text [.tabs tab $current_tab -text]} err]} {
            set tab_text ""
        }
        
        # ПРЯМОЙ ДОСТУП К ГЛОБАЛЬНЫМ ПЕРЕМЕННЫМ РЕДАКТОРА
        # Проверяем наличие различных переменных, которые могут содержать путь
        
        # Метод 1: Проверяем глобальные массивы с путями файлов
        set found_path ""
        
        # Проверяем переменную tab_files, которая очень часто используется в Tcl редакторах
        if {[info exists ::tab_files]} {
            if {[array exists ::tab_files] && [info exists ::tab_files($current_tab)]} {
                set found_path $::tab_files($current_tab)
            } elseif {[array exists ::tab_files]} {
                # Если доступны какие-либо элементы массива, проверяем их
                foreach tab_id [array names ::tab_files] {
                    if {[string first $tab_text $::tab_files($tab_id)] != -1} {
                        set found_path $::tab_files($tab_id)
                        break
                    }
                }
            }
        }
        
        # Проверяем другие популярные переменные
        if {$found_path eq ""} {
            # Список часто используемых имен переменных для хранения путей к файлам
            set var_names {::core::tab_files ::editor::tab_files ::fileTab}
            
            foreach var_name $var_names {
                if {[info exists $var_name] && [array exists $var_name]} {
                    if {[info exists ${var_name}($current_tab)]} {
                        set found_path [set ${var_name}($current_tab)]
                        break
                    } else {
                        # Если текущая вкладка не найдена в массиве, ищем по имени файла
                        foreach tab_id [array names $var_name] {
                            set file_path [set ${var_name}($tab_id)]
                            if {[string first $tab_text $file_path] != -1} {
                                set found_path $file_path
                                break
                            }
                        }
                    }
                    if {$found_path ne ""} break
                }
            }
        }
        
        # Метод 2: Проверяем существующий файл с именем из вкладки
        if {$found_path eq "" && $tab_text ne "" && $tab_text ne "Новый"} {
            # Проверяем относительный путь от текущей директории
            set current_dir [pwd]
            set possible_path [file join $current_dir $tab_text]
            
            if {[file exists $possible_path]} {
                set found_path [file normalize $possible_path]
            }
        }
        
        # Метод 3: Проверяем, есть ли сохраненный путь для текущей вкладки
        if {$found_path eq "" && $last_file_path ne ""} {
            # Если имя файла совпадает с именем вкладки, используем сохраненный путь
            if {[file tail $last_file_path] eq $tab_text} {
                set found_path $last_file_path
            }
        }
        
        # Метод 4: Проверяем другие глобальные переменные
        if {$found_path eq ""} {
            # Проверяем переменные с "подозрительными" именами
            set scalar_vars {::current_file ::core::current_file ::editor::current_file 
                           ::file_path ::core::file_path ::editor::file_path}
            
            foreach var_name $scalar_vars {
                if {[info exists $var_name]} {
                    set val [set $var_name]
                    if {[string is true [string match "*$tab_text*" $val]]} {
                        set found_path $val
                        break
                    }
                }
            }
        }
        
        # Если путь пустой, но есть имя файла, пытаемся его использовать
        if {$found_path eq "" && $tab_text ne "" && $tab_text ne "Новый"} {
            set found_path $tab_text
        }
        
        # Если путь пустой, показываем сообщение
        if {$found_path eq ""} {
            set_entry_text $path_entry "Путь к файлу не найден. Введите его вручную →"
            
            # Делаем поле редактируемым, чтобы пользователь мог ввести путь
            $path_entry configure -state normal
            
            # Добавляем обработчик ввода
            bind $path_entry <Return> ::plugin::path_display::handle_manual_path
        } else {
            # Преобразуем путь в абсолютный, если это необходимо
            if {![string match {[A-Za-z]:/*} $found_path] && ![string match {/*} $found_path]} {
                set current_dir [pwd]
                set found_path [file normalize [file join $current_dir $found_path]]
            }
            
            # Сохраняем найденный путь
            set last_file_path $found_path
            
            # Настраиваем отображение пути
            set_entry_text $path_entry $found_path
        }
    }
    
    # Обработка ручного ввода пути
    proc handle_manual_path {} {
        variable path_entry
        variable last_file_path
        
        # Получаем введенный путь
        set entered_path [$path_entry get]
        
        # Проверяем, существует ли файл
        if {[file exists $entered_path]} {
            # Нормализуем путь
            set normalized_path [file normalize $entered_path]
            
            # Сохраняем путь
            set last_file_path $normalized_path
            
            # Обновляем поле с нормализованным путем
            set_entry_text $path_entry $normalized_path
            
            # Показываем уведомление
            show_notification "Путь сохранен"
        } else {
            # Показываем уведомление об ошибке
            show_notification "Файл не существует: $entered_path" 3000
            
            # Оставляем поле редактируемым
            $path_entry configure -state normal
        }
    }
    
    # Установка текста в readonly entry
    proc set_entry_text {entry text} {
        # Если виджет не существует, выходим
        if {![winfo exists $entry]} {
            return
        }
        
        # Временно делаем поле редактируемым
        $entry configure -state normal
        
        # Очищаем текущее содержимое и устанавливаем новый текст
        $entry delete 0 end
        $entry insert 0 $text
        
        # Возвращаем состояние "только чтение"
        $entry configure -state readonly
    }
    
    # Процедура создания всплывающей подсказки
    proc tooltip {widget text} {
        bind $widget <Enter> [list after 500 [list ::plugin::path_display::show_tooltip %W $text]]
        bind $widget <Leave> [list destroy .path_tooltip]
        bind $widget <ButtonPress> [list destroy .path_tooltip]
    }
    
    # Показать всплывающую подсказку
    proc show_tooltip {widget text} {
        # Проверяем, существует ли виджет
        if {![winfo exists $widget]} {
            return
        }
        
        if {[winfo exists .path_tooltip]} {
            destroy .path_tooltip
        }
        set x [expr {[winfo rootx $widget] + [winfo width $widget] / 2}]
        set y [expr {[winfo rooty $widget] - 30}]
        
        toplevel .path_tooltip -bd 1 -relief solid
        wm overrideredirect .path_tooltip 1
        
        label .path_tooltip.label -text $text -justify left -background "#FFFFCC" \
            -relief flat -padx 5 -pady 2
        pack .path_tooltip.label
        
        wm geometry .path_tooltip +$x+$y
        raise .path_tooltip
        
        # Автоматически закрываем через 2 секунды
        after 2000 {catch {destroy .path_tooltip}}
    }
    
    # Настройка контекстного меню для панели пути
    proc setup_context_menu {} {
        variable path_entry
        
        # Если виджет еще не создан, выходим
        if {![winfo exists $path_entry]} {
            after 500 ::plugin::path_display::setup_context_menu
            return
        }
        
        # Создаем контекстное меню
        menu .path_context_menu -tearoff 0
        
        # Добавляем опции
        .path_context_menu add command -label "Выделить всё" -command [list $path_entry selection range 0 end]
        .path_context_menu add command -label "Копировать путь" -command ::plugin::path_display::copy_path_to_clipboard
        .path_context_menu add command -label "Открыть папку" -command ::plugin::path_display::open_containing_folder
        .path_context_menu add separator
        .path_context_menu add command -label "Обновить путь" -command ::plugin::path_display::update_path_display
        .path_context_menu add command -label "Ввести путь вручную" -command [list ::plugin::path_display::enable_manual_input]
        .path_context_menu add command -label "Скрыть панель" -command ::plugin::path_display::hide_path_panel
        
        # Привязываем контекстное меню к правой кнопке мыши
        bind $path_entry <Button-3> {
            tk_popup .path_context_menu %X %Y
        }
    }
    
    # Включение ручного ввода пути
    proc enable_manual_input {} {
        variable path_entry
        
        # Проверяем, существует ли виджет
        if {![winfo exists $path_entry]} {
            return
        }
        
        # Делаем поле редактируемым
        $path_entry configure -state normal
        
        # Выделяем весь текст
        $path_entry selection range 0 end
        
        # Фокус на поле ввода
        focus $path_entry
        
        # Добавляем обработчик ввода
        bind $path_entry <Return> ::plugin::path_display::handle_manual_path
        
        # Показываем уведомление
        show_notification "Введите полный путь к файлу и нажмите Enter"
    }
    
    # Копирование пути в буфер обмена
    proc copy_path_to_clipboard {} {
        variable path_entry
        
        # Проверяем, существует ли виджет
        if {![winfo exists $path_entry]} {
            return
        }
        
        # Получаем текст из поля
        set path_text [$path_entry get]
        
        # Проверяем, не пустой ли текст
        if {$path_text ne "" && 
            $path_text ne "Нет открытого файла" && 
            ![string match "Путь к файлу не найден*" $path_text]} {
            # Копируем в буфер обмена
            clipboard clear
            clipboard append $path_text
            
            # Показываем уведомление
            show_notification "Путь скопирован в буфер обмена"
        }
    }
    
    # Открытие папки, содержащей файл
    proc open_containing_folder {} {
        variable path_entry
        
        # Проверяем, существует ли виджет
        if {![winfo exists $path_entry]} {
            return
        }
        
        # Получаем текст из поля
        set path_text [$path_entry get]
        
        # Проверяем, не пустой ли текст
        if {$path_text ne "" && 
            $path_text ne "Нет открытого файла" && 
            ![string match "Путь к файлу не найден*" $path_text]} {
            
            # Проверяем существование файла или директории
            if {[file exists $path_text]} {
                # Получаем папку, содержащую файл
                if {[file isfile $path_text]} {
                    set folder_path [file dirname $path_text]
                } else {
                    set folder_path $path_text
                }
                
                # Пытаемся открыть папку (зависит от ОС)
                if {$::tcl_platform(platform) eq "windows"} {
                    exec {*}[auto_execok start] "" $folder_path &
                } elseif {$::tcl_platform(os) eq "Darwin"} {
                    exec open $folder_path &
                } else {
                    # Предполагаем Linux/Unix
                    catch {exec xdg-open $folder_path &}
                }
                
                # Показываем уведомление
                show_notification "Открываем папку: $folder_path"
            } else {
                # Показываем уведомление об ошибке
                show_notification "Путь не существует: $path_text" 3000
            }
        }
    }
    
    # Показать уведомление
    proc show_notification {message {duration 2000}} {
        # Создаем окно уведомления
        if {[winfo exists .notification]} {
            destroy .notification
        }
        
        toplevel .notification -bg "#333333" -bd 0
        wm overrideredirect .notification 1
        wm attributes .notification -topmost 1
        
        # Создаем метку с сообщением
        label .notification.message -text $message -bg "#333333" -fg "#FFFFFF" \
            -font "TkDefaultFont" -padx 10 -pady 5
        pack .notification.message -fill both -expand 1
        
        # Вычисляем позицию (в нижнем правом углу)
        set screen_width [winfo screenwidth .]
        set screen_height [winfo screenheight .]
        set win_width [winfo reqwidth .notification]
        set win_height [winfo reqheight .notification]
        
        set x [expr {$screen_width - $win_width - 20}]
        set y [expr {$screen_height - $win_height - 40}]
        
        # Размещаем окно
        wm geometry .notification +$x+$y
        
        # Автоматически закрываем через указанное время
        after $duration {catch {destroy .notification}}
    }
}

# Инициализация плагина при загрузке
::plugin::path_display::init

# Настройка контекстного меню через секунду после инициализации
after 1000 ::plugin::path_display::setup_context_menu

# Добавим несколько обработчиков событий с задержками для надежности
after 1500 {
    # Пытаемся привязать обработчик к заметным событиям
    bind . <Map> {
        if {$::plugin::path_display::is_path_panel_visible} {
            after 100 ::plugin::path_display::update_path_display
        }
    }
    
    # Пытаемся привязаться к событиям создания и удаления вкладок
    if {[winfo exists .tabs]} {
        bind .tabs <Map> {
            if {$::plugin::path_display::is_path_panel_visible} {
                after 100 ::plugin::path_display::update_path_display
            }
        }
    }
}
