# block.tcl - Минималистичный плагин для блочного выделения
# Rewritten: 2026-01-14 - Полностью безмодальное решение

namespace eval ::plugin::block {
    # Переменные для отслеживания состояния
    variable selection_mode 0  ;# 0=выключено, 1=жду начальную, 2=жду конечную
    variable start_pos {}      ;# Начальная позиция выделения
    variable end_pos {}        ;# Конечная позиция выделения
    variable last_widget {}    ;# Последний текстовый виджет, в котором кликали
    
    # Инициализация плагина
    proc init {} {
        # Регистрируем горячие клавиши для активации режима выделения
        # (пользователь будет использовать Ctrl+Shift+клик, как описано)
        
        # Привязываем Ctrl+Shift+клик ко всем текстовым виджетам вкладок
        bind_all_text_widgets
        
        # Также привязываем глобально для новых вкладок
        bind .tabs <<NotebookTabChanged>> "::plugin::block::bind_all_text_widgets"
        
        # Выводим информационное сообщение при запуске
        puts "Плагин Block активирован. Используйте Ctrl+Shift+клик для выделения блоков."
        
        return 1
    }
    
    # Привязка ко всем текстовым виджетам
    proc bind_all_text_widgets {} {
        # Удаляем старые привязки
        foreach tab [.tabs tabs] {
            set txt $tab.text
            if {[winfo exists $txt]} {
                bind $txt <Control-Shift-Button-1> {}
                bind $txt <ButtonRelease-Control-Shift-Button-1> {}
            }
        }
        
        # Добавляем новые привязки
        foreach tab [.tabs tabs] {
            set txt $tab.text
            if {[winfo exists $txt]} {
                # При нажатии Ctrl+Shift+кнопка мыши
                bind $txt <Control-Shift-Button-1> \
                    "+::plugin::block::handle_click_start %W %x %y"
                
                # При отпускании - фиксируем позицию
                bind $txt <ButtonRelease-Control-Shift-Button-1> \
                    "+::plugin::block::handle_click_end %W %x %y"
            }
        }
    }
    
    # Обработка начала клика
    proc handle_click_start {widget x y} {
        variable selection_mode
        variable last_widget
        
        # Запоминаем виджет
        set last_widget $widget
        
        # Если это первый клик (режим 0), переходим в режим ожидания начальной точки
        if {$selection_mode == 0} {
            set selection_mode 1
            # Показываем подсказку в статусной строке (если есть)
            show_status "Выберите начальную точку выделения (отпустите Ctrl+Shift)"
            return
        }
    }
    
    # Обработка окончания клика (когда отпускают клавиши)
    proc handle_click_end {widget x y} {
        variable selection_mode
        variable start_pos
        variable end_pos
        variable last_widget
        
        # Получаем позицию в тексте
        set pos [$widget index @$x,$y]
        
        if {$selection_mode == 1} {
            # Устанавливаем начальную позицию
            set start_pos $pos
            set selection_mode 2
            show_status "Начальная точка установлена. Выберите конечную точку (отпустите Ctrl+Shift)"
            
        } elseif {$selection_mode == 2} {
            # Устанавливаем конечную позицию и выделяем текст
            set end_pos $pos
            perform_selection $widget
            set selection_mode 0
            
            # Показываем краткое подтверждение
            show_status "Блок выделен. Используйте стандартные операции (Ctrl+C, Ctrl+X, Ctrl+V)"
            
            # Даём визуальную обратную связь - мигаем выделением
            flash_selection $widget
            
            # Фокус на виджет для немедленного использования горячих клавиш
            focus $widget
        }
    }
    
    # Выполнение выделения
    proc perform_selection {widget} {
        variable start_pos
        variable end_pos
        
        # Очищаем предыдущие выделения
        $widget tag remove sel 1.0 end
        
        # Определяем порядок (чтобы start <= end)
        if {[$widget compare $start_pos > $end_pos]} {
            set temp $start_pos
            set start_pos $end_pos
            set end_pos $temp
        }
        
        # Выделяем текст
        $widget tag add sel $start_pos $end_pos
        
        # Устанавливаем курсор в начало выделения
        $widget mark set insert $start_pos
        
        # Прокручиваем к началу выделения
        $widget see $start_pos
        
        # Обновляем отображение
        update idletasks
    }
    
    # Мигание выделением для визуальной обратной связи
    proc flash_selection {widget} {
        variable start_pos
        variable end_pos
        
        if {$start_pos eq "" || $end_pos eq ""} { return }
        
        # Сохраняем текущие цвета выделения
        set old_bg [$widget cget -selectbackground]
        set old_fg [$widget cget -selectforeground]
        
        # Меняем цвет на 200 мс
        $widget configure -selectbackground "#FF9900" -selectforeground "#000000"
        update idletasks
        after 200 [list $widget configure -selectbackground $old_bg -selectforeground $old_fg]
    }
    
    # Показать статус (если есть строка состояния, иначе в консоль)
    proc show_status {message} {
        # Попробуем найти или создать простую строку состояния
        if {![winfo exists .status]} {
            # Создаем простую строку состояния внизу окна
            ttk::frame .status -relief sunken -borderwidth 1
            ttk::label .status.label -textvariable ::status_message
            pack .status.label -fill both -expand 1 -padx 2 -pady 1
            pack .status -side bottom -fill x
            set ::status_message ""
        }
        
        set ::status_message $message
        
        # Автоматически очищаем через 3 секунды
        after 3000 {set ::status_message ""}
        
        # Также выводим в консоль для отладки
        puts "Block: $message"
    }
    
    # Очистка выделения (может быть вызвана из других мест)
    proc clear_selection {} {
        variable selection_mode
        variable start_pos
        variable end_pos
        
        set selection_mode 0
        set start_pos {}
        set end_pos {}
        
        # Очищаем выделение во всех текстовых виджетах
        foreach tab [.tabs tabs] {
            set txt $tab.text
            if {[winfo exists $txt]} {
                $txt tag remove sel 1.0 end
            }
        }
        
        show_status "Выделение очищено"
    }
    
    # Показать справку
    proc show_help {} {
        set help_text "Блочное выделение - минималистичный плагин

Использование:
1. Нажмите и удерживайте Ctrl+Shift
2. Кликните левой кнопкой мыши в начальной точке
3. Отпустите Ctrl+Shift
4. Перейдите к конечной точке
5. Снова нажмите и удерживайте Ctrl+Shift
6. Кликните в конечной точке
7. Отпустите Ctrl+Shift

Текст между точками будет автоматически выделен.
После этого можно использовать стандартные операции:
• Ctrl+C - копировать
• Ctrl+X - вырезать  
• Ctrl+V - вставить (заменить выделенное)
• Delete - удалить

Для отмены выделения:
• Просто выделите другой текст обычным способом
• Или нажмите Ctrl+Shift+клик вне текста
"
        tk_messageBox -title "Справка - Блочное выделение" \
            -message $help_text -icon info
    }
}

# Автоматическая инициализация при загрузке плагина
::plugin::block::init

# Добавляем кнопку в панель инструментов для справки (опционально)
# и глобальную горячую клавишу для очистки выделения
namespace eval ::plugin::block {
    # Регистрируем кнопку справки (если нужно)
    if {[info commands ::core::register_plugin_button] ne ""} {
        ::core::register_plugin_button "block" "🧱 Block" \
            ::plugin::block::show_help "" 4
    }
    
    # Горячая клавиша для очистки выделения
    bind . <Control-Shift-Escape> "::plugin::block::clear_selection"
    
    # Также очищаем выделение при обычном клике без модификаторов
    # (но только если мы не в процессе выбора второй точки)
    proc check_clear_on_normal_click {} {
        variable selection_mode
        if {$selection_mode == 0} {
            clear_selection
        }
    }
    
    # Привязываем проверку ко всем текстовым виджетам
    foreach tab [.tabs tabs] {
        set txt $tab.text
        if {[winfo exists $txt]} {
            bind $txt <Button-1> "+::plugin::block::check_clear_on_normal_click"
        }
    }
}
