# syntax_basic.tcl - Базовая подсветка с автоматическим определением языка
# Created: 2025-05-07 10:08:32 by totiks2012

namespace eval ::plugin::syntax_basic {
    # Переменная для отслеживания инициализации
    variable initialized 0
    
    # Инициализация плагина
    proc init {} {
        variable initialized
        
        # Защита от повторной инициализации
        if {$initialized} {
            return 1
        }
        
        # Регистрируем обработчики событий для автоматической подсветки
        bind .tabs <<NotebookTabChanged>> ::plugin::syntax_basic::tab_changed
        
        # Добавляем обработчик события создания новой вкладки
        # Нам нужно перехватить момент создания вкладки и привязать обработчик
        # к текстовому виджету для автоматической подсветки
        if {[info commands ::core::create_tab] ne ""} {
            # Переопределяем функцию создания вкладки
            rename ::core::create_tab ::core::create_tab_original
            proc ::core::create_tab {args} {
                set tab [uplevel 1 [list ::core::create_tab_original {*}$args]]
                if {$tab ne "" && [winfo exists $tab]} {
                    # После создания вкладки, применяем подсветку
                    after idle [list ::plugin::syntax_basic::highlight_tab $tab]
                }
                return $tab
            }
        }
        
        # Добавляем в меню если оно существует
        if {[winfo exists .menubar]} {
            if {![winfo exists .menubar.tools]} {
                menu .menubar.tools -tearoff 0
                .menubar add cascade -label "Инструменты" -menu .menubar.tools
            }
            
            # Проверяем, нет ли уже пункта для очистки подсветки
            if {![winfo exists .menubar.tools.clear_syntax]} {
                .menubar.tools add command -label "Очистить подсветку синтаксиса" \
                    -command ::plugin::syntax_basic::clear_highlight
            }
        }
        
        set initialized 1
        
        # Применяем подсветку к уже открытым вкладкам
        foreach tab [.tabs tabs] {
            highlight_tab $tab
        }
        
        return 1
    }
    
    # Обработчик события смены вкладки
    proc tab_changed {} {
        # Получаем текущую вкладку
        set tab [.tabs select]
        if {$tab ne "" && [winfo exists $tab.text]} {
            # Проверяем, нужно ли применить подсветку к этой вкладке
            highlight_tab $tab
        }
    }
    
    # Подсветка для вкладки с определением языка
    proc highlight_tab {tab} {
        # Проверяем существование вкладки
        if {$tab eq "" || ![winfo exists $tab.text]} {
            return
        }
        
        # Определяем язык файла на основе расширения и содержимого
        set language [detect_language $tab]
        
        # Применяем подсветку соответствующего языка
        if {$language eq "tcl"} {
            highlight_tcl_full_internal $tab.text
        } elseif {$language eq "bash"} {
            highlight_bash_full_internal $tab.text
        }
        # Здесь можно добавить другие языки в будущем
    }
    
    # Определение языка по расширению и содержимому файла
    proc detect_language {tab} {
        # Проверяем, есть ли информация о файле
        if {[info exists ::core::tab_files($tab)]} {
            set filepath $::core::tab_files($tab)
            
            # Получаем расширение файла
            set extension [string tolower [file extension $filepath]]
            
            # Определяем язык по расширению
            switch -- $extension {
                ".tcl" - ".tk" {
                    return "tcl"
                }
                ".sh" - ".bash" {
                    return "bash"
                }
                default {
                    # Если расширение не помогло, проверяем содержимое
                    return [detect_language_by_content $tab.text]
                }
            }
        } else {
            # Если нет информации о файле, определяем язык по содержимому
            return [detect_language_by_content $tab.text]
        }
    }
    
    # Определение языка по содержимому файла
    proc detect_language_by_content {text_widget} {
        # Получаем первые несколько строк файла
        set content [$text_widget get 1.0 "10.0"]
        
        # Проверяем на характерные признаки языков
        
        # Проверка на Tcl
        if {[regexp {^\s*#!\s*(/usr/bin/|/bin/|/usr/local/bin/)(tclsh|wish)} $content] || 
            [regexp {\s(proc|namespace\s+eval|package\s+require)\s} $content]} {
            return "tcl"
        }
        
        # Проверка на Bash
        if {[regexp {^\s*#!\s*(/usr/bin/|/bin/|/usr/local/bin/)(bash|sh)} $content] || 
            [regexp {\s(function\s+\w+\s*\(\)|\$\(\(|\[\[)} $content]} {
            return "bash"
        }
        
        # По умолчанию возвращаем пустую строку (язык не определен)
        return ""
    }
    
    # Подготовка тегов для подсветки
    proc prepare_tags {text_widget} {
        # Создаем теги для ключевых слов, комментариев, переменных и строк
        catch {$text_widget tag delete keyword}
        catch {$text_widget tag delete comment}
        catch {$text_widget tag delete variable}
        catch {$text_widget tag delete string}
        
        # Устанавливаем цвета в зависимости от темы
        if {[info exists ::core::config(theme)] && $::core::config(theme) eq "dark"} {
            # Темная тема
            $text_widget tag configure keyword -foreground "#F76D14"    ;# оранжевый
            $text_widget tag configure comment -foreground "#828997"    ;# серый
            $text_widget tag configure variable -foreground "#E5C07B"   ;# желтый
            $text_widget tag configure string -foreground "#98C379"     ;# зеленый
        } else {
            # Светлая тема
            $text_widget tag configure keyword -foreground "#0550AE"    ;# темно-синий
            $text_widget tag configure comment -foreground "#5F6368"    ;# серый
            $text_widget tag configure variable -foreground "#A05A00"   ;# коричневый
            $text_widget tag configure string -foreground "#188038"     ;# зеленый
        }
    }
    
    # Полная подсветка Tcl (внутренняя реализация)
    proc highlight_tcl_full_internal {text_widget} {
        # Подготавливаем теги
        prepare_tags $text_widget
        
        # Очищаем предыдущую подсветку
        clear_tags $text_widget
        
        # Порядок подсветки важен для правильной работы наложения тегов
        # Сначала подсвечиваем строки, затем комментарии, затем всё остальное
        highlight_tcl_strings_internal $text_widget
        highlight_tcl_comments_internal $text_widget
        highlight_tcl_keywords_internal $text_widget
        highlight_tcl_variables_internal $text_widget
    }
    
    # Полная подсветка Bash (внутренняя реализация)
    proc highlight_bash_full_internal {text_widget} {
        # Подготавливаем теги
        prepare_tags $text_widget
        
        # Очищаем предыдущую подсветку
        clear_tags $text_widget
        
        # Порядок подсветки важен для правильной работы наложения тегов
        # Сначала подсвечиваем строки, затем комментарии, затем всё остальное
        highlight_bash_strings_internal $text_widget
        highlight_bash_comments_internal $text_widget
        highlight_bash_keywords_internal $text_widget
        highlight_bash_variables_internal $text_widget
    }
    
    # Подсветка ключевых слов Tcl (внутренняя реализация)
    proc highlight_tcl_keywords_internal {text_widget} {
        # Список ключевых слов Tcl
        set keywords {
            proc if else elseif for foreach while switch continue break
            set return global namespace package array dict list catch
            error throw try finally upvar uplevel variable eval exec
            expr format scan string info clock after vwait update
        }
        
        # Подсвечиваем каждое ключевое слово
        foreach keyword $keywords {
            highlight_word $text_widget $keyword keyword
        }
    }
    
    # Подсветка комментариев Tcl (внутренняя реализация)
    proc highlight_tcl_comments_internal {text_widget} {
        set current_pos 1.0
        
        while {1} {
            # Ищем символ # в тексте
            set pos [$text_widget search -regexp {[^\\]#|^#} $current_pos end]
            if {$pos eq ""} {
                break
            }
            
            # Проверяем, не находится ли # внутри строки
            set line_start [$text_widget index "$pos linestart"]
            set line_end [$text_widget index "$pos lineend"]
            set line_text [$text_widget get $line_start $line_end]
            
            # Находим позицию # в строке
            set comment_pos [$text_widget index "$pos + 1 char"]
            if {[string index [$text_widget get $pos $comment_pos] 0] ne "#"} {
                set comment_pos $pos
            }
            
            # Проверяем, находится ли # внутри строки в двойных кавычках
            if {![is_inside_string $text_widget $comment_pos]} {
                # Устанавливаем тег от # до конца строки
                $text_widget tag add comment $comment_pos $line_end
            }
            
            # Переходим к следующей строке
            set current_pos [$text_widget index "$line_end + 1 char"]
        }
    }
    
    # Проверка, находится ли позиция внутри строки в двойных кавычках
    proc is_inside_string {text_widget pos} {
        # Получаем номер строки
        set line_num [lindex [split [$text_widget index $pos] .] 0]
        set line_start "$line_num.0"
        
        # Получаем текст от начала строки до указанной позиции
        set text_before [$text_widget get $line_start $pos]
        
        # Считаем количество неэкранированных двойных кавычек
        set count 0
        set in_escape 0
        
        for {set i 0} {$i < [string length $text_before]} {incr i} {
            set char [string index $text_before $i]
            
            if {$char eq "\\" && !$in_escape} {
                set in_escape 1
                continue
            }
            
            if {$char eq "\"" && !$in_escape} {
                incr count
            }
            
            set in_escape 0
        }
        
        # Если количество кавычек нечетное, значит мы внутри строки
        return [expr {$count % 2 == 1}]
    }
    
    # Подсветка переменных Tcl (внутренняя реализация)
    proc highlight_tcl_variables_internal {text_widget} {
        set current_pos 1.0
        
        while {1} {
            # Ищем символ $ в тексте
            set pos [$text_widget search "$" $current_pos end]
            if {$pos eq ""} {
                break
            }
            
            # Проверяем, не находится ли $ внутри комментария
            if {![is_inside_comment $text_widget $pos]} {
                # Получаем текст после символа $
                set line_end [$text_widget index "$pos lineend"]
                set line_text [$text_widget get $pos $line_end]
                
                # Определяем имя переменной
                if {[regexp {^\$([a-zA-Z0-9_:()]+)} $line_text -> varname]} {
                    set var_end [$text_widget index "$pos + [string length $varname] chars + 1 char"]
                    $text_widget tag add variable $pos $var_end
                    set current_pos $var_end
                } else {
                    # Если не смогли определить переменную, переходим к следующему символу
                    set current_pos [$text_widget index "$pos + 1 char"]
                }
            } else {
                # Если $ внутри комментария, пропускаем
                set current_pos [$text_widget index "$pos + 1 char"]
            }
        }
    }
    
    # Подсветка строк в двойных кавычках для Tcl (внутренняя реализация)
    proc highlight_tcl_strings_internal {text_widget} {
        set current_pos 1.0
        
        while {1} {
            # Ищем открывающую кавычку
            set start_pos [$text_widget search -regexp {[^\\]"|^"} $current_pos end]
            if {$start_pos eq ""} {
                break
            }
            
            # Проверяем, является ли кавычка первым символом или предыдущий символ не "\"
            set quote_char [$text_widget get $start_pos "$start_pos + 1 char"]
            if {$quote_char ne "\""} {
                set start_pos [$text_widget index "$start_pos + 1 char"]
            }
            
            # Ищем закрывающую кавычку
            set search_start [$text_widget index "$start_pos + 1 char"]
            set end_pos ""
            set current_line [lindex [split $start_pos .] 0]
            
            # Ищем закрывающую кавычку до конца файла, обрабатывая экранирование
            while {$search_start ne ""} {
                set next_quote [$text_widget search "\"" $search_start end]
                if {$next_quote eq ""} {
                    # Если не нашли закрывающую кавычку, подсвечиваем до конца строки
                    set end_pos [$text_widget index "$start_pos lineend"]
                    break
                }
                
                # Проверяем, не экранирована ли кавычка
                set prev_char [$text_widget get [$text_widget index "$next_quote - 1 char"] $next_quote]
                if {$prev_char ne "\\"} {
                    # Нашли неэкранированную закрывающую кавычку
                    set end_pos [$text_widget index "$next_quote + 1 char"]
                    break
                }
                
                # Проверяем, не экранирован ли сам слэш (случай \\")
                if {[$text_widget index "$next_quote - 2 char"] ne "1.0"} {
                    set prev_prev_char [$text_widget get [$text_widget index "$next_quote - 2 char"] [$text_widget index "$next_quote - 1 char"]]
                    if {$prev_prev_char eq "\\"} {
                        # Если слэш сам экранирован, значит кавычка не экранирована
                        set end_pos [$text_widget index "$next_quote + 1 char"]
                        break
                    }
                }
                
                # Продолжаем поиск дальше
                set search_start [$text_widget index "$next_quote + 1 char"]
                
                # Если перешли на другую строку, подсвечиваем до конца текущей строки
                set next_line [lindex [split $search_start .] 0]
                if {$next_line > $current_line} {
                    set end_pos [$text_widget index "$start_pos lineend"]
                    break
                }
            }
            
            # Если нашли закрывающую кавычку, подсвечиваем строку
            if {$end_pos ne ""} {
                $text_widget tag add string $start_pos $end_pos
                set current_pos $end_pos
            } else {
                # Если не нашли закрывающую кавычку, переходим к следующему символу
                set current_pos [$text_widget index "$start_pos + 1 char"]
            }
        }
    }
    
    # Проверка, находится ли позиция внутри комментария
    proc is_inside_comment {text_widget pos} {
        # Получаем номер строки
        set line_num [lindex [split [$text_widget index $pos] .] 0]
        set line_start "$line_num.0"
        set line_end [$text_widget index "$line_num.end"]
        
        # Получаем текст строки до указанной позиции
        set text_before [$text_widget get $line_start $pos]
        
        # Ищем символ # (не экранированный) до указанной позиции
        set comment_pos [string first "#" $text_before]
        if {$comment_pos == -1} {
            return 0
        }
        
        # Проверяем, не экранирован ли символ #
        if {$comment_pos > 0 && [string index $text_before [expr {$comment_pos - 1}]] eq "\\"} {
            return 0
        }
        
        # Проверяем, не находится ли # внутри строки
        set count_quotes 0
        for {set i 0} {$i < $comment_pos} {incr i} {
            set char [string index $text_before $i]
            if {$char eq "\"" && ($i == 0 || [string index $text_before [expr {$i - 1}]] ne "\\") } {
                incr count_quotes
            }
        }
        
        # Если # не внутри строки (четное количество кавычек до #),
        # и позиция после #, значит мы внутри комментария
        return [expr {$count_quotes % 2 == 0 && $comment_pos >= 0}]
    }
    
    # Подсветка ключевых слов Bash (внутренняя реализация)
    proc highlight_bash_keywords_internal {text_widget} {
        # Список ключевых слов Bash
        set keywords {
            if then else elif fi for while until do done
            case esac function return exit break continue
            shift source let declare local readonly export
        }
        
        # Подсвечиваем каждое ключевое слово
        foreach keyword $keywords {
            highlight_word $text_widget $keyword keyword
        }
    }
    
    # Подсветка комментариев Bash (внутренняя реализация)
    proc highlight_bash_comments_internal {text_widget} {
        # Для Bash используем модифицированный метод подсветки комментариев
        set current_pos 1.0
        
        while {1} {
            # Ищем символ # в тексте
            set pos [$text_widget search -regexp {[^\\]#|^#} $current_pos end]
            if {$pos eq ""} {
                break
            }
            
            # Проверяем, не находится ли # внутри строки
            set line_start [$text_widget index "$pos linestart"]
            set line_end [$text_widget index "$pos lineend"]
            set line_text [$text_widget get $line_start $line_end]
            
            # Находим позицию # в строке
            set comment_pos [$text_widget index "$pos + 1 char"]
            if {[string index [$text_widget get $pos $comment_pos] 0] ne "#"} {
                set comment_pos $pos
            }
            
            # Проверяем, находится ли # внутри строки в кавычках
            if {![is_inside_string $text_widget $comment_pos]} {
                # Устанавливаем тег от # до конца строки
                $text_widget tag add comment $comment_pos $line_end
            }
            
            # Переходим к следующей строке
            set current_pos [$text_widget index "$line_end + 1 char"]
        }
    }
    
    # Подсветка переменных Bash (внутренняя реализация)
    proc highlight_bash_variables_internal {text_widget} {
        set current_pos 1.0
        
        while {1} {
            # Ищем символ $ в тексте
            set pos [$text_widget search "$" $current_pos end]
            if {$pos eq ""} {
                break
            }
            
            # Проверяем, не находится ли $ внутри комментария
            if {![is_inside_comment $text_widget $pos]} {
                # Получаем текст после символа $
                set line_end [$text_widget index "$pos lineend"]
                set line_text [$text_widget get $pos $line_end]
                
                # Определяем имя переменной
                if {[regexp {^\$([a-zA-Z0-9_{}]+)} $line_text -> varname]} {
                    set var_end [$text_widget index "$pos + [string length $varname] chars + 1 char"]
                    $text_widget tag add variable $pos $var_end
                    set current_pos $var_end
                } else {
                    # Если не смогли определить переменную, переходим к следующему символу
                    set current_pos [$text_widget index "$pos + 1 char"]
                }
            } else {
                # Если $ внутри комментария, пропускаем
                set current_pos [$text_widget index "$pos + 1 char"]
            }
        }
    }
    
    # Подсветка строк в двойных кавычках для Bash (внутренняя реализация)
    proc highlight_bash_strings_internal {text_widget} {
        # Для Bash используем ту же функцию подсветки строк, что и для Tcl
        highlight_tcl_strings_internal $text_widget
    }
    
    # Подсветка отдельного слова
    proc highlight_word {text_widget word tag_name} {
        set current_pos 1.0
        
        while {1} {
            # Ищем слово в тексте
            set pos [$text_widget search -nocase -exact $word $current_pos end]
            if {$pos eq ""} {
                break
            }
            
            # Проверяем, не находится ли слово внутри комментария или строки
            if {![is_inside_comment $text_widget $pos] && ![is_inside_string $text_widget $pos]} {
                # Проверяем, что это отдельное слово
                set char_before ""
                if {[$text_widget compare $pos > "1.0"]} {
                    set char_before_pos [$text_widget index "$pos - 1 char"]
                    set char_before [$text_widget get $char_before_pos $pos]
                }
                
                set word_end [$text_widget index "$pos + [string length $word] chars"]
                set char_after [$text_widget get $word_end "$word_end + 1 char"]
                
                # Если это отдельное слово (не часть другого слова или идентификатора)
                if {($char_before eq "" || ![string is alnum $char_before] && $char_before ne "_") && 
                    ($char_after eq "" || ![string is alnum $char_after] && $char_after ne "_")} {
                    $text_widget tag add $tag_name $pos $word_end
                }
            }
            
            # Переходим к следующей позиции после найденного слова
            set current_pos [$text_widget index "$pos + [string length $word] chars"]
        }
    }
    
    # Очистка всех тегов подсветки
    proc clear_tags {text_widget} {
        $text_widget tag remove keyword 1.0 end
        $text_widget tag remove comment 1.0 end
        $text_widget tag remove variable 1.0 end
        $text_widget tag remove string 1.0 end
    }
    
    # Очистка подсветки
    proc clear_highlight {} {
        # Получаем текущую вкладку
        set tab [.tabs select]
        if {$tab eq "" || ![winfo exists $tab.text]} {
            return
        }
        
        # Удаляем все теги подсветки
        clear_tags $tab.text
    }
    
    # Обработчик изменения текста для повторной подсветки
    proc text_modified {tab} {
        # Получаем текстовый виджет
        if {$tab eq "" || ![winfo exists $tab.text]} {
            return
        }
        
        # Определяем язык и повторно применяем подсветку
        set language [detect_language $tab]
        
        # Применяем подсветку соответствующего языка
        if {$language eq "tcl"} {
            highlight_tcl_full_internal $tab.text
        } elseif {$language eq "bash"} {
            highlight_bash_full_internal $tab.text
        }
    }
}

# Загружаем плагин
::plugin::syntax_basic::init
