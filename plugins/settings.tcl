# settings.tcl - Плагин настроек редактора с восстановлением сессии
# Created: 2025-05-06 06:22:42 by totiks2012

namespace eval ::plugin::settings {
    # Устанавливаем порядок кнопки - шестая после базовых кнопок
    variable button_order 6
    
    # Переменные плагина
    variable session_file [file normalize [file join [file dirname [info script]] ".." "session.conf"]]
    variable last_autosave [clock seconds]
    variable settings_file [file normalize [file join [pwd] ".nte2rc"]]
    variable initialized 0
    variable auto_save_id ""
    variable button_registered 0
    variable welcome_file ""
    variable first_run_flag_file [file normalize [file join [file dirname [info script]] ".welcome_shown"]]
    
    # Добавляем переменную для трассировки изменений вкладок
    variable tab_monitor_id ""
    
    # Описание плагина
    variable plugin_info
    array set plugin_info {
        name "Settings"
        version "1.0"
        description "Плагин настроек редактора с восстановлением сессии"
        author "totiks2012"
    }
    
    # Инициализация плагина
    proc init {} {
        variable button_order
        variable last_autosave
        variable initialized
        variable settings_file
        variable session_file
        variable auto_save_id
        variable button_registered
        variable welcome_file
        variable tab_monitor_id
        variable first_run_flag_file
        
        # Защита от повторной инициализации
        if {$button_registered} {
            return 1
        }
        
        # Вывод информации о пути к файлу сессии для отладки
        puts "Путь к файлу сессии: $session_file"
        
        # Регистрируем кнопку в панели инструментов
        set settings_button [::core::register_plugin_button "settings" "⚙️ Настройки" ::plugin::settings::show_settings "" $button_order]
        set button_registered 1
        
        # Загружаем сохраненные настройки
        load_settings
        
        # Применяем тему интерфейса после загрузки настроек
        after 200 ::plugin::settings::apply_interface_theme
        
        # Определяем путь к файлу welcome.txt
        set welcome_file [file normalize [file join [file dirname [info script]] "welcome.txt"]]
        
        # Создаем файл welcome.txt с ASCII-логотипом, если он не существует
        create_welcome_file
        
        # Загружаем сессию
        if {[info exists ::core::config(restore_session)] && $::core::config(restore_session)} {
            after 500 ::plugin::settings::load_session_direct
        }
        
        # Проверяем, запускается ли редактор в первый раз
        set is_first_run [expr {![file exists $first_run_flag_file]}]
        
        # Открываем welcome.txt только при первом запуске
        if {$is_first_run} {
            after 700 {
                if {[file exists $::plugin::settings::welcome_file]} {
                    # Используем функцию core::create_tab для открытия файла
                    ::core::create_tab $::plugin::settings::welcome_file
                    
                    # Создаем флаг-файл, чтобы отметить, что welcome.txt уже был показан
                    set f [open $::plugin::settings::first_run_flag_file w]
                    puts $f [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]
                    close $f
                }
            }
        }
        
        # Запускаем автосохранение, если включено
        if {[info exists ::core::config(autosave)] && $::core::config(autosave)} {
            set auto_save_id [after 2000 ::plugin::settings::auto_save_session]
        }
        
        # Регистрируем протокол закрытия окна
        # Важно: всегда сохраняем сессию при закрытии, независимо от настройки автосохранения
        wm protocol . WM_DELETE_WINDOW {
            if {[::plugin::settings::check_unsaved_changes]} {
                # Всегда сохраняем сессию при закрытии приложения
                ::plugin::settings::save_session true
                ::plugin::settings::save_settings
                exit
            }
        }
        
        # Биндим события для мониторинга изменений вкладок
        # NotebookTabClosed срабатывает при закрытии вкладки
        bind .tabs <<NotebookTabClosed>> {
            # Сохраняем сессию после закрытия вкладки только если активно автосохранение
            if {[info exists ::core::config(autosave)] && $::core::config(autosave)} {
                after 100 ::plugin::settings::save_session
            }
        }
        
        # Переопределяем обработчик правого клика на вкладке
        bind .tabs <ButtonPress-3> {
            set tab [.tabs identify tab %x %y]
            if {$tab != ""} {
                # Выбираем вкладку под курсором и закрываем её
                .tabs select $tab
                ::core::close_current_tab
                # Обновляем сессию после закрытия, только если активно автосохранение
                if {[info exists ::core::config(autosave)] && $::core::config(autosave)} {
                    after 100 ::plugin::settings::save_session
                }
            }
        }
        
        # Дополнительно мониторим изменения только если включено автосохранение
        if {[info exists ::core::config(autosave)] && $::core::config(autosave)} {
            set tab_monitor_id [after 5000 ::plugin::settings::monitor_tabs]
        }
        
        # Устанавливаем флаг инициализации
        set initialized 1
        
        return 1
    }
    
    # Процедура мониторинга вкладок
    proc monitor_tabs {} {
        variable tab_monitor_id
        
        # Сохраняем текущую сессию, только если автосохранение включено
        if {[info exists ::core::config(autosave)] && $::core::config(autosave)} {
            save_session
            
            # Планируем следующую проверку через 5 секунд
            set tab_monitor_id [after 5000 ::plugin::settings::monitor_tabs]
        }
    }
    
    # Создание файла welcome.txt, если он не существует
    proc create_welcome_file {} {
        variable welcome_file
        
        if {![file exists $welcome_file]} {
            puts "Файл приветствия не найден: $welcome_file"
            
            # Создаем ASCII-логотип для TED2+
            set welcome_content {
  _____ _____ ____ ____        
 |_   _| ____|  _ \___ \  _    
   | | |  _| | | | |__) || |_  
   | | | |___| |_| / __/_   _| 
   |_| |_____|____/_____||_|   
                               
            
      Текстовый редактор для разработчиков

Добро пожаловать в TED2+ - многофункциональный текстовый редактор!

Возможности редактора:
• Подсветка синтаксиса для разных языков программирования
• Автосохранение сессии и восстановление открытых файлов
• Индивидуальные настройки внешнего вида
• Возможность расширения через систему плагинов

Для начала работы вы можете:
1. Создать новый файл или открыть существующий
2. Настроить редактор через кнопку "Настройки"
3. Использовать подсветку синтаксиса для удобства редактирования кода

Автор: totiks2012
Версия: 1.8
Дата: 2025-05-06
            }
            
            if {[catch {
                set f [open $welcome_file w]
                fconfigure $f -encoding utf-8
                puts $f $welcome_content
                close $f
                puts "Создан файл приветствия: $welcome_file"
            } err]} {
                puts stderr "Ошибка создания файла приветствия: $err"
            }
        }
    }
    
    # Прямая загрузка сессии
    proc load_session_direct {} {
        variable session_file
        variable welcome_file
        puts "Прямая загрузка сессии из файла: $session_file"
        
        # Проверяем существование файла сессии
        if {![file exists $session_file]} {
            puts "Файл сессии не найден: $session_file"
            return
        }
        
        # Загружаем сессию
        if {[catch {
            set f [open $session_file r]
            fconfigure $f -encoding utf-8
            set lines [split [read $f] "\n"]
            close $f
            
            # Получаем список файлов для открытия из сессии
            set files_to_open {}
            set current_file ""
            set current_data {}
            
            foreach line $lines {
                if {$line eq "" || [string match "#*" $line]} {
                    continue
                }
                if {$line eq "---"} {
                    # Конец блока одного файла
                    if {$current_file ne "" && [file exists $current_file] && $current_file ne $welcome_file} {
                        lappend files_to_open [list $current_file {*}$current_data]
                    }
                    set current_file ""
                    set current_data {}
                    continue
                }
                if {[string match "FILE:*" $line]} {
                    set current_file [string range $line 5 end]
                    continue
                }
                if {[string match "CURSOR:*" $line]} {
                    lappend current_data "cursor" [string range $line 7 end]
                    continue
                }
                if {[string match "VIEW:*" $line]} {
                    lappend current_data "view" [string range $line 5 end]
                    continue
                }
            }
            
            # Открываем все файлы
            set files_loaded 0
            
            foreach file_data $files_to_open {
                set filepath [lindex $file_data 0]
                
                # Открываем файл с помощью функции ядра
                if {[file exists $filepath]} {
                    # Используем core::create_tab для открытия файла
                    set tab [::core::create_tab $filepath]
                    
                    if {$tab ne ""} {
                        incr files_loaded
                        
                        # Устанавливаем позицию курсора и прокрутки
                        array set pos_data {}
                        foreach {key value} [lrange $file_data 1 end] {
                            set pos_data($key) $value
                        }
                        
                        if {[info exists pos_data(cursor)] && $pos_data(cursor) ne ""} {
                            $tab.text mark set insert $pos_data(cursor)
                            $tab.text see insert
                        }
                        
                        if {[info exists pos_data(view)] && $pos_data(view) ne ""} {
                            $tab.text yview moveto $pos_data(view)
                        }
                    }
                }
            }
            
            puts "Сессия успешно загружена (загружено файлов: $files_loaded)"
            
        } err]} {
            puts stderr "Ошибка загрузки сессии: $err"
        }
    }
    
    # Процедура загрузки настроек
    proc load_settings {} {
        variable settings_file
        
        # Инициализация массива config, если он еще не существует
        if {![info exists ::core::config]} {
            array set ::core::config {}
        }
        
        # Проверяем существование файла настроек
        if {[file exists $settings_file]} {
            if {[catch {
                set f [open $settings_file r]
                fconfigure $f -encoding utf-8
                array set ::core::config [read $f]
                close $f
                
                # Устанавливаем значения по умолчанию для отсутствующих настроек
                if {![info exists ::core::config(theme)]} {
                    set ::core::config(theme) "light"
                }
                if {![info exists ::core::config(font_family)]} {
                    set ::core::config(font_family) "Courier"
                }
                if {![info exists ::core::config(font_size)]} {
                    set ::core::config(font_size) 12
                }
                if {![info exists ::core::config(restore_session)]} {
                    set ::core::config(restore_session) 1
                }
                if {![info exists ::core::config(autosave)]} {
                    set ::core::config(autosave) 1
                }
                if {![info exists ::core::config(create_backups)]} {
                    set ::core::config(create_backups) 1
                }
                if {$::tcl_platform(platform) eq "unix" && ![info exists ::core::config(terminal)]} {
                    set ::core::config(terminal) "xterm"
                }
                
                puts "Настройки успешно загружены из $settings_file"
            } err]} {
                puts stderr "Ошибка загрузки настроек: $err"
                # Устанавливаем настройки по умолчанию
                set_default_settings
            }
        } else {
            # Устанавливаем настройки по умолчанию
            set_default_settings
            # Сохраняем настройки в файл
            save_settings
        }
    }
    
    # Установка настроек по умолчанию
    proc set_default_settings {} {
        # Создаем настройки по умолчанию
        set ::core::config(theme) "light"
        set ::core::config(font_family) "Courier"
        set ::core::config(font_size) 12
        set ::core::config(restore_session) 1
        set ::core::config(autosave) 1
        set ::core::config(create_backups) 1
        if {$::tcl_platform(platform) eq "unix"} {
            set ::core::config(terminal) "xterm"
        }
        
        puts "Установлены настройки по умолчанию"
    }
    
    # Процедура сохранения настроек
    proc save_settings {} {
        variable settings_file
        
        if {[catch {
            set f [open $settings_file w]
            fconfigure $f -encoding utf-8
            puts $f [array get ::core::config]
            close $f
            puts "Настройки успешно сохранены в $settings_file"
        } err]} {
            puts stderr "Ошибка сохранения настроек: $err"
            tk_messageBox -icon error -title "Ошибка" \
                -message "Не удалось сохранить настройки: $err"
        }
    }
    
    # Процедура показа окна настроек
    proc show_settings {} {
        # Создаем модальное окно настроек
        set w .settings_dialog
        catch {destroy $w}
        toplevel $w
        wm title $w "Настройки"
        wm transient $w .
        wm resizable $w 0 0
        
        # Определяем цвета в зависимости от текущей темы
        if {$::core::config(theme) eq "dark"} {
            set bg "#2D2D2D"
            set fg "#767070"
            set input_bg "#404040"
            set input_fg "#FFFFFF"
            set frame_bg "#1A1A1A"
        } else {
            set bg "#FFFFFF"
            set fg "#000000"
            set input_bg "#FFFFFF"
            set input_fg "#000000"
            set frame_bg "#F5F5F5"
        }
        
        # Настраиваем стили для ttk виджетов
        ttk::style configure SettingsFrame.TFrame \
            -background $bg
        
        ttk::style configure SettingsLabel.TLabelframe \
            -background $bg
        
        ttk::style configure SettingsLabel.TLabelframe.Label \
            -background $bg \
            -foreground $fg
        
        ttk::style configure Settings.TRadiobutton \
            -background $bg \
            -foreground $fg
        
        ttk::style configure Settings.TButton \
            -background $frame_bg
        
        ttk::style configure Settings.TSpinbox \
            -fieldbackground $input_bg \
            -foreground $input_fg
            
        ttk::style configure Settings.TCombobox \
            -fieldbackground $input_bg \
            -foreground $input_fg
            
        ttk::style configure Settings.TCheckbutton \
            -background $bg \
            -foreground $fg
        
        # Создаем и размещаем элементы управления
        ttk::frame $w.f -style SettingsFrame.TFrame -padding "10 10 10 10"
        pack $w.f -expand 1 -fill both
        
        # Выбор темы
        ttk::labelframe $w.f.theme -text "Тема" -padding "5 5 5 5" \
            -style SettingsLabel.TLabelframe
        pack $w.f.theme -fill x -pady 5
        
        ttk::radiobutton $w.f.theme.light -text "Светлая" \
            -variable ::core::config(theme) -value "light" \
            -style Settings.TRadiobutton
        ttk::radiobutton $w.f.theme.dark -text "Тёмная" \
            -variable ::core::config(theme) -value "dark" \
            -style Settings.TRadiobutton
        
        pack $w.f.theme.light $w.f.theme.dark -side left -padx 5
        
        # Семейство шрифта
        ttk::labelframe $w.f.fontfamily -text "Шрифт" -padding "5 5 5 5" \
            -style SettingsLabel.TLabelframe
        pack $w.f.fontfamily -fill x -pady 5
        
        # Получаем список доступных шрифтов
        set font_list [lsort [font families]]
        
        ttk::combobox $w.f.fontfamily.combo \
            -textvariable ::core::config(font_family) \
            -values $font_list \
            -style Settings.TCombobox
            
        ttk::button $w.f.fontfamily.preview -text "Предпросмотр" \
            -command ::plugin::settings::show_font_preview \
            -style Settings.TButton
        
        pack $w.f.fontfamily.combo -side left -padx 5 -fill x -expand 1
        pack $w.f.fontfamily.preview -side left -padx 5
        
        # Размер шрифта
        ttk::labelframe $w.f.font -text "Размер шрифта" -padding "5 5 5 5" \
            -style SettingsLabel.TLabelframe
        pack $w.f.font -fill x -pady 5
        
        ttk::spinbox $w.f.font.size -from 8 -to 72 \
            -textvariable ::core::config(font_size) -width 5 \
            -style Settings.TSpinbox
        ttk::button $w.f.font.apply -text "Применить" \
            -command ::plugin::settings::apply_font_settings \
            -style Settings.TButton
        
        pack $w.f.font.size $w.f.font.apply -side left -padx 5
        
        # Выбор терминала (только для Unix)
        if {$::tcl_platform(platform) eq "unix"} {
            ttk::labelframe $w.f.term -text "Терминал" -padding "5 5 5 5" \
                -style SettingsLabel.TLabelframe
            pack $w.f.term -fill x -pady 5
            
            ttk::combobox $w.f.term.name \
                -textvariable ::core::config(terminal) \
                -values [list "xterm" "lxterminal" "xfce4-terminal" "gnome-terminal" "konsole"] \
                -style Settings.TCombobox
            
            pack $w.f.term.name -fill x -padx 5
        }
        
        # Настройки сессии
        ttk::labelframe $w.f.session -text "Сессия" -padding "5 5 5 5" \
            -style SettingsLabel.TLabelframe
        pack $w.f.session -fill x -pady 5
        
        ttk::checkbutton $w.f.session.restore -text "Восстанавливать открытые вкладки при запуске" \
            -variable ::core::config(restore_session) \
            -style Settings.TCheckbutton
        
        ttk::checkbutton $w.f.session.autosave -text "Автосохранение сессии (каждые 5 минут)" \
            -variable ::core::config(autosave) \
            -command ::plugin::settings::autosave_toggle \
            -style Settings.TCheckbutton
        
        ttk::frame $w.f.session.buttons
        ttk::button $w.f.session.buttons.save -text "Сохранить сессию" \
            -command ::plugin::settings::save_session \
            -style Settings.TButton
        ttk::button $w.f.session.buttons.load -text "Загрузить сессию" \
            -command ::plugin::settings::load_session_direct \
            -style Settings.TButton
        
        pack $w.f.session.restore $w.f.session.autosave -anchor w -padx 5 -pady 2
        pack $w.f.session.buttons -fill x -padx 5 -pady 2
        pack $w.f.session.buttons.save $w.f.session.buttons.load -side left -padx 5 -fill x -expand 1
        
        # Прочие настройки
        ttk::labelframe $w.f.other -text "Прочие настройки" -padding "5 5 5 5" \
            -style SettingsLabel.TLabelframe
        pack $w.f.other -fill x -pady 5
        
        ttk::checkbutton $w.f.other.backup -text "Создавать резервные копии файлов" \
            -variable ::core::config(create_backups) \
            -style Settings.TCheckbutton
        
        pack $w.f.other.backup -anchor w -padx 5
        
        # Кнопки
        ttk::frame $w.f.buttons -style SettingsFrame.TFrame -padding "0 5 0 0"
        pack $w.f.buttons -fill x -pady 5
        
        ttk::button $w.f.buttons.save -text "Сохранить" \
            -command {
                ::plugin::settings::apply_font_settings
                ::plugin::settings::apply_settings
                ::plugin::settings::save_settings
                destroy .settings_dialog
            } \
            -style Settings.TButton
            
        ttk::button $w.f.buttons.cancel -text "Отмена" \
            -command {destroy .settings_dialog} \
            -style Settings.TButton
        
        grid $w.f.buttons.save $w.f.buttons.cancel -padx 5 -pady 5 -sticky ew
        grid columnconfigure $w.f.buttons 0 -weight 1
        grid columnconfigure $w.f.buttons 1 -weight 1
        
        # Настраиваем цвет фона для toplevel окна
        $w configure -background $bg
        
        # Центрируем окно
        center_window $w
    }
    
    # Обработчик переключения галки автосохранения
    proc autosave_toggle {} {
        variable auto_save_id
        variable tab_monitor_id
        
        # Проверяем текущее состояние галки автосохранения
        if {[info exists ::core::config(autosave)] && $::core::config(autosave)} {
            # Автосохранение включено - запускаем таймеры
            if {$auto_save_id eq "" || ![string is integer [lindex [after info $auto_save_id] 0]]} {
                # Запускаем автосохранение
                set auto_save_id [after 1000 ::plugin::settings::auto_save_session]
                puts "Запущен таймер автосохранения: $auto_save_id"
            }
            
            # Проверяем, запущен ли мониторинг вкладок
            if {$tab_monitor_id eq "" || ![string is integer [lindex [after info $tab_monitor_id] 0]]} {
                # Запускаем мониторинг вкладок
                set tab_monitor_id [after 1000 ::plugin::settings::monitor_tabs]
                puts "Запущен мониторинг вкладок: $tab_monitor_id"
            }
        } else {
            # Автосохранение выключено - останавливаем таймеры
            if {$auto_save_id ne ""} {
                after cancel $auto_save_id
                set auto_save_id ""
                puts "Остановлен таймер автосохранения"
            }
            
            # Останавливаем мониторинг вкладок
            if {$tab_monitor_id ne ""} {
                after cancel $tab_monitor_id
                set tab_monitor_id ""
                puts "Остановлен мониторинг вкладок"
            }
        }
    }
    
    # Процедура для показа предпросмотра шрифта
    proc show_font_preview {} {
        # Создаем окно предпросмотра шрифта
        set preview .font_preview
        catch {destroy $preview}
        toplevel $preview
        wm title $preview "Предпросмотр шрифта"
        wm transient $preview .settings_dialog
        
        # Устанавливаем цвета в зависимости от темы
        if {$::core::config(theme) eq "dark"} {
            set bg "#2D2D2D"
            set fg "#CCCACA"
        } else {
            set bg "#FFFFFF"
            set fg "#000000"
        }
        
        text $preview.text -width 40 -height 10 -wrap word \
            -font [list $::core::config(font_family) $::core::config(font_size)] \
            -background $bg -foreground $fg
            
        $preview.text insert end "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ\n"
        $preview.text insert end "абвгдеёжзийклмнопрстуфхцчшщъыьэюя\n"
        $preview.text insert end "ABCDEFGHIJKLMNOPQRSTUVWXYZ\n"
        $preview.text insert end "abcdefghijklmnopqrstuvwxyz\n"
        $preview.text insert end "1234567890\n"
        $preview.text insert end "!@#$%^&*()_+-={}[]"
        
        $preview.text configure -state disabled
        
        # Добавляем кнопку закрытия
        ttk::button $preview.close -text "Закрыть" -command [list destroy $preview]
        
        # Размещаем элементы
        pack $preview.text -padx 10 -pady 10 -fill both -expand 1
        pack $preview.close -pady 5
        
        # Центрируем окно
        center_window $preview
    }
    
    # Процедура для применения настроек шрифта
    proc apply_font_settings {} {
        # Проверяем, что переменные существуют
        if {![info exists ::core::config(font_family)]} {
            set ::core::config(font_family) "Courier"
        }
        if {![info exists ::core::config(font_size)]} {
            set ::core::config(font_size) 12
        }
        
        # Создаем спецификацию шрифта
        set font_spec [list $::core::config(font_family) $::core::config(font_size)]
        
        # Применяем шрифт ко всем текстовым виджетам в открытых вкладках
        foreach tab [.tabs tabs] {
            if {[winfo exists $tab.text]} {
                $tab.text configure -font $font_spec
            }
            if {[winfo exists $tab.linenumbers]} {
                $tab.linenumbers configure -font $font_spec
            }
        }
        
        # Обновляем нумерацию строк после изменения шрифта
        if {[info commands ::core::show_line_numbers] ne ""} {
            ::core::show_line_numbers
        }
    }
    
    # Процедура применения настроек
    proc apply_settings {} {
        # Применяем тему интерфейса
        apply_interface_theme
        
        # Применяем шрифт и размер шрифта
        apply_font_settings
        
        # Применяем настройки автосохранения
        autosave_toggle
    }
    
    # Процедура применения темы интерфейса
    proc apply_interface_theme {} {
        puts "Применение темы: $::core::config(theme)"
        
        # Определяем цвета в зависимости от темы
        if {$::core::config(theme) eq "dark"} {
            # Основные цвета для темной темы
            set bg "#2D2D2D"
            set fg "#767070"
            set text_fg "#CCCACA"
            set select_bg "#0F6FBF"
            set select_fg "#FFFFFF"
            set inactive_bg "#404040"
            set inactive_fg "#808080"
            set active_bg "#2D2D2D"
            set active_fg "#FFFFFF"
            
            # Настройка стилей ttk
            ttk::style configure . \
                -background $bg \
                -foreground $fg
                
            # Настройка стиля вкладок
            ttk::style configure TNotebook.Tab \
                -background $inactive_bg \
                -foreground $inactive_fg
            
            ttk::style map TNotebook.Tab \
                -background [list selected $active_bg !selected $inactive_bg] \
                -foreground [list selected $active_fg !selected $inactive_fg]
            
            # Применяем цвета к текстовым виджетам
            foreach tab [.tabs tabs] {
                if {[winfo exists $tab.text]} {
                    $tab.text configure \
                        -background $bg \
                        -foreground $text_fg \
                        -insertbackground $text_fg \
                        -selectbackground $select_bg \
                        -selectforeground $select_fg
                }
                
                # Обновляем цвета номеров строк, если они есть
                if {[winfo exists $tab.linenumbers]} {
                    $tab.linenumbers configure \
                        -background $bg \
                        -foreground "#666666"
                }
            }
            
        } else {
            # Основные цвета для светлой темы
            set bg "#FFFFFF"
            set fg "#000000"
            set text_fg "#000000"
            set select_bg "#0060C0"
            set select_fg "#FFFFFF"
            set inactive_bg "#F0F0F0"
            set inactive_fg "#505050"
            set active_bg "#FFFFFF"
            set active_fg "#000000"
            
            # Настройка стилей ttk
            ttk::style configure . \
                -background $bg \
                -foreground $fg
                
            # Настройка стиля вкладок
            ttk::style configure TNotebook.Tab \
                -background $inactive_bg \
                -foreground $inactive_fg
            
            ttk::style map TNotebook.Tab \
                -background [list selected $active_bg !selected $inactive_bg] \
                -foreground [list selected $active_fg !selected $inactive_fg]
            
            # Применяем цвета к текстовым виджетам
            foreach tab [.tabs tabs] {
                if {[winfo exists $tab.text]} {
                    $tab.text configure \
                        -background $bg \
                        -foreground $text_fg \
                        -insertbackground $text_fg \
                        -selectbackground $select_bg \
                        -selectforeground $select_fg
                }
                
                # Обновляем цвета номеров строк, если они есть
                if {[winfo exists $tab.linenumbers]} {
                    $tab.linenumbers configure \
                        -background "#F0F0F0" \
                        -foreground "#808080"
                }
            }
        }
        
        # Обновляем нумерацию строк после смены темы
        if {[info commands ::core::show_line_numbers] ne ""} {
            ::core::show_line_numbers
        }
        
        puts "Тема применена: $::core::config(theme)"
    }
    
    # Процедура сохранения сессии
    proc save_session {{force false}} {
        variable session_file
        variable welcome_file
        
        # Если сохранение принудительное или автосохранение включено
        if {$force || [info exists ::core::config(autosave)] && $::core::config(autosave)} {
            # Получаем информацию о всех открытых вкладках
            set session_data {}
            
            # Создаем заголовок файла
            lappend session_data "# Файл сессии, сгенерирован: [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
            lappend session_data "# Не редактируйте этот файл вручную!"
            lappend session_data ""
            
            foreach tab [.tabs tabs] {
                if {[winfo exists $tab.text]} {
                    # Получаем путь к файлу
                    set filepath ""
                    if {[info exists ::core::tab_files($tab)]} {
                        set filepath $::core::tab_files($tab)
                    } else {
                        # Получаем заголовок вкладки
                        set tab_title [.tabs tab $tab -text]
                        # Удаляем маркер модификации
                        set clean_title [string map {"•" ""} $tab_title]
                        set clean_title [string trim $clean_title]
                        if {![string match "Untitled*" $clean_title] && 
                            ![string match "Новый*" $clean_title]} {
                            set filepath $clean_title
                        }
                    }
                    
                    # Если это реальный файл, но не welcome.txt, сохраняем его в сессии
                    if {$filepath ne "" && [file exists $filepath] && $filepath ne $welcome_file} {
                        # Получаем позицию курсора
                        set cursor_pos [$tab.text index insert]
                        # Получаем позицию прокрутки
                        set view_pos [$tab.text yview]
                        set view_pos [lindex $view_pos 0]
                        
                        # Добавляем в список сессии
                        lappend session_data "FILE:$filepath"
                        lappend session_data "CURSOR:$cursor_pos"
                        lappend session_data "VIEW:$view_pos"
                        lappend session_data "---"
                    }
                }
            }
            
            # Сохраняем сессию в файл
            if {[catch {
                # Проверяем и создаем директорию, если нужно
                set session_dir [file dirname $session_file]
                if {![file exists $session_dir]} {
                    file mkdir $session_dir
                }
                
                # Сохраняем файл сессии
                set f [open $session_file w]
                fconfigure $f -encoding utf-8
                puts $f [join $session_data "\n"]
                close $f
                
                # Выводим сообщение только при принудительном сохранении или отладке
                if {$force} {
                    puts "Сессия сохранена в $session_file"
                }
            } err]} {
                puts stderr "Ошибка сохранения сессии: $err"
            }
        }
    }
    
    # Процедура автосохранения сессии
    proc auto_save_session {} {
        variable last_autosave
        variable auto_save_id
        
        # Проверяем, включено ли автосохранение
        if {[info exists ::core::config(autosave)] && $::core::config(autosave)} {
            # Получаем текущее время
            set current_time [clock seconds]
            
            # Сохраняем каждые 5 минут (300 секунд)
            if {$current_time - $last_autosave >= 300} {
                save_session
                set last_autosave $current_time
            }
            
            # Планируем следующее автосохранение через минуту
            set auto_save_id [after 60000 ::plugin::settings::auto_save_session]
        }
    }
    
    # Процедура проверки несохраненных изменений
    proc check_unsaved_changes {} {
        variable welcome_file
        
        # Проверяем наличие несохраненных изменений
        set has_unsaved false
        
        foreach tab [.tabs tabs] {
            if {[info exists ::core::modified_tabs($tab)] && $::core::modified_tabs($tab)} {
                # Проверяем, является ли этот файл welcome.txt
                set is_welcome false
                if {[info exists ::core::tab_files($tab)] && 
                    $::core::tab_files($tab) eq $welcome_file} {
                    set is_welcome true
                }
                
                # Если это не welcome.txt и файл изменен, устанавливаем флаг
                if {!$is_welcome} {
                    set has_unsaved true
                    break
                }
            }
        }
        
        if {$has_unsaved} {
            set answer [tk_messageBox -icon question -type yesnocancel \
                -title "Несохраненные изменения" \
                -message "Есть несохраненные изменения. Сохранить перед выходом?"]
            
            switch -- $answer {
                yes {
                    # Сохраняем все измененные файлы
                    foreach tab [.tabs tabs] {
                        # Пропускаем welcome.txt
                        if {[info exists ::core::tab_files($tab)] && 
                            $::core::tab_files($tab) eq $welcome_file} {
                            continue
                        }
                        
                        if {[info exists ::core::modified_tabs($tab)] && $::core::modified_tabs($tab)} {
                            .tabs select $tab
                            ::core::save_current_file
                            # Если файл все еще отмечен как измененный, значит, сохранение не удалось
                            if {[info exists ::core::modified_tabs($tab)] && $::core::modified_tabs($tab)} {
                                return 0
                            }
                        }
                    }
                    return 1
                }
                no { return 1 }
                cancel { return 0 }
            }
        }
        
        return 1
    }
    
    # Центрирование окна
    proc center_window {w} {
        wm withdraw $w
        update idletasks
        
        # Получаем размеры экрана
        set screenwidth [winfo screenwidth .]
        set screenheight [winfo screenheight .]
        
        # Получаем размеры окна
        set reqwidth [winfo reqwidth $w]
        set reqheight [winfo reqheight $w]
        
        # Вычисляем координаты для центрирования
        set x [expr {($screenwidth - $reqwidth) / 2}]
        set y [expr {($screenheight - $reqheight) / 2}]
        
        # Устанавливаем геометрию и показываем окно
        wm geometry $w +$x+$y
        wm deiconify $w
    }
}

# Загружаем плагин
::plugin::settings::init
