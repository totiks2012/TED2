# hex.tcl - Плагин для работы с HEX-цветами (исправленная версия)
# Created: 2025-05-07 11:51:17 by totiks2012

namespace eval ::plugin::hex {
    # Устанавливаем порядок кнопки - пятая после базовых кнопок
    variable button_order 5
    
    # Переменные плагина
    variable color_picker_win ""      ;# Окно выбора цвета
    variable current_color "#FFFFFF"  ;# Текущий выбранный цвет
    variable hue 0                    ;# Оттенок (0-360)
    variable saturation 0             ;# Насыщенность (0-100)
    variable brightness 100           ;# Яркость (0-100)
    variable current_tab ""           ;# Текущая вкладка, в которой вызван выбор цвета
    variable selection_start ""       ;# Начало выделения текста
    variable selection_end ""         ;# Конец выделения текста
    variable color_history [list]     ;# История выбранных цветов
    variable max_history 10           ;# Максимальное количество цветов в истории
    variable color_wheel_size 200     ;# Размер круглой палитры в пикселях
    variable brightness_bar_width 20  ;# Ширина столбца яркости
    variable brightness_bar_height 200 ;# Высота столбца яркости
    variable drag_active 0            ;# Флаг активности перетаскивания
    variable color_wheel_canvas ""    ;# Канвас для круглой палитры
    variable brightness_canvas ""     ;# Канвас для столбца яркости
    
    # Флаг для отслеживания статуса инициализации
    variable initialized 0
    
    # Описание плагина
    variable plugin_info
    array set plugin_info {
        name "HexColor"
        version "2.0"
        description "Плагин для выбора и вставки HEX-цветов с круглой палитрой"
        author "totiks2012"
    }
    
    # Инициализация плагина
    proc init {} {
        variable button_order
        variable initialized
        
        # Проверяем, не был ли плагин уже инициализирован
        if {$initialized} {
            puts "Плагин HEX уже инициализирован. Предотвращение повторной регистрации кнопки."
            return 1
        }
        
        # Регистрируем кнопку в панели инструментов только один раз
        set hex_button [::core::register_plugin_button "hex" "🎨 Hex" ::plugin::hex::show_color_picker "" $button_order]
        
        # Регистрируем горячие клавиши
        bind . <Control-H> { ::plugin::hex::show_color_picker }
        bind . <Control-Shift-h> { ::plugin::hex::show_color_picker }
        
        # Устанавливаем флаг инициализации
        set initialized 1
        puts "Плагин HEX успешно инициализирован (версия 2.0)."
        
        return 1
    }
    
    # Проверка, является ли строка валидным HEX-кодом цвета
    proc is_valid_hex_code {code} {
        # Удаляем пробелы и переводим в верхний регистр
        set code [string trim [string toupper $code]]
        # Проверяем формат: #RGB или #RRGGBB
        if {[regexp {^#[0-9A-F]{3}$|^#[0-9A-F]{6}$} $code]} {
            return 1
        }
        return 0
    }
    
    # Преобразование HSB (HSV) в RGB
    proc hsb_to_rgb {h s v} {
        # H: 0-360, S: 0-100, V: 0-100
        # Нормализуем значения
        set h [expr {double($h) / 360.0}]
        set s [expr {double($s) / 100.0}]
        set v [expr {double($v) / 100.0}]
        
        if {$s == 0.0} {
            # Если насыщенность равна нулю, то это оттенок серого
            set r $v
            set g $v
            set b $v
        } else {
            # Вычисляем RGB на основе HSB
            set h [expr {$h * 6.0}]
            set i [expr {int(floor($h))}]
            set f [expr {$h - $i}]
            set p [expr {$v * (1.0 - $s)}]
            set q [expr {$v * (1.0 - $s * $f)}]
            set t [expr {$v * (1.0 - $s * (1.0 - $f))}]
            
            switch -- [expr {$i % 6}] {
                0 {
                    set r $v
                    set g $t
                    set b $p
                }
                1 {
                    set r $q
                    set g $v
                    set b $p
                }
                2 {
                    set r $p
                    set g $v
                    set b $t
                }
                3 {
                    set r $p
                    set g $q
                    set b $v
                }
                4 {
                    set r $t
                    set g $p
                    set b $v
                }
                5 {
                    set r $v
                    set g $p
                    set b $q
                }
            }
        }
        
        # Преобразуем в диапазон 0-255 и возвращаем как список
        return [list [expr {int(round($r * 255))}] \
                    [expr {int(round($g * 255))}] \
                    [expr {int(round($b * 255))}]]
    }
    
    # Преобразование RGB в HEX
    proc rgb_to_hex {r g b} {
        return [format "#%02X%02X%02X" $r $g $b]
    }
    
    # Преобразование HEX в RGB
    proc hex_to_rgb {hex} {
        if {[string length $hex] == 4} {
            # Расширяем короткую форму #RGB в #RRGGBB
            set r [string range $hex 1 1]
            set g [string range $hex 2 2]
            set b [string range $hex 3 3]
            set r "$r$r"
            set g "$g$g"
            set b "$b$b"
        } else {
            set r [string range $hex 1 2]
            set g [string range $hex 3 4]
            set b [string range $hex 5 6]
        }
        return [list [scan $r %x] [scan $g %x] [scan $b %x]]
    }
    
    # Преобразование RGB в HSB
    proc rgb_to_hsb {r g b} {
        # Нормализуем RGB в диапазон 0-1
        set r [expr {double($r) / 255.0}]
        set g [expr {double($g) / 255.0}]
        set b [expr {double($b) / 255.0}]
        
        set max_val [expr {max($r, max($g, $b))}]
        set min_val [expr {min($r, min($g, $b))}]
        set delta [expr {$max_val - $min_val}]
        
        # Вычисляем яркость
        set v $max_val
        
        # Вычисляем насыщенность
        if {$max_val == 0.0} {
            set s 0.0
        } else {
            set s [expr {$delta / $max_val}]
        }
        
        # Вычисляем оттенок
        if {$delta == 0.0} {
            set h 0.0
        } else {
            if {$max_val == $r} {
                set h [expr {($g - $b) / $delta}]
                if {$g < $b} {
                    set h [expr {$h + 6.0}]
                }
            } elseif {$max_val == $g} {
                set h [expr {2.0 + ($b - $r) / $delta}]
            } else {
                set h [expr {4.0 + ($r - $g) / $delta}]
            }
            set h [expr {$h * 60.0}]
        }
        
        # Возвращаем HSB как список в диапазонах H: 0-360, S: 0-100, V: 0-100
        return [list [expr {int(round($h))}] \
                    [expr {int(round($s * 100))}] \
                    [expr {int(round($v * 100))}]]
    }
    
    # Преобразование HEX в HSB
    proc hex_to_hsb {hex} {
        set rgb [hex_to_rgb $hex]
        return [rgb_to_hsb [lindex $rgb 0] [lindex $rgb 1] [lindex $rgb 2]]
    }
    
    # Преобразование HSB в HEX
    proc hsb_to_hex {h s v} {
        set rgb [hsb_to_rgb $h $s $v]
        return [rgb_to_hex [lindex $rgb 0] [lindex $rgb 1] [lindex $rgb 2]]
    }
    
    # Создание цветового колеса
    proc create_color_wheel {canvas size} {
        variable hue
        variable saturation
        variable brightness
        
        # Очищаем канвас
        $canvas delete all
        
        # Центр колеса
        set center [expr {$size / 2}]
        set radius [expr {($size - 20) / 2}]
        
        # Создаем изображение для цветового колеса
        set wheel_image [image create photo -width $size -height $size]
        
        # Создаем фон для канваса (серый)
        $canvas configure -bg "#F0F0F0"
        
        # Создаем круг с заливкой в качестве фона
        $canvas create oval 10 10 [expr {$size - 10}] [expr {$size - 10}] \
            -fill white -outline "#CCCCCC" -width 1 -tags wheel_bg
        
        # Используем максимальную яркость для отображения всей цветовой гаммы
        set max_brightness 100
        
        # Заполняем изображение пикселями
        for {set y 0} {$y < $size} {incr y} {
            for {set x 0} {$x < $size} {incr x} {
                # Вычисляем расстояние от центра
                set dx [expr {$x - $center}]
                set dy [expr {$y - $center}]
                set distance [expr {sqrt($dx * $dx + $dy * $dy)}]
                
                # Если точка внутри круга
                if {$distance <= $radius} {
                    # Вычисляем угол и насыщенность
                    set angle [expr {atan2($dy, $dx) * 180 / 3.14159265359}]
                    if {$angle < 0} {
                        set angle [expr {$angle + 360}]
                    }
                    
                    # Нормализуем расстояние для насыщенности (0-100%)
                    set sat [expr {$distance / $radius * 100}]
                    
                    # Получаем RGB значения для текущего пикселя с максимальной яркостью
                    # Используем max_brightness вместо текущей brightness переменной
                    set rgb [hsb_to_rgb $angle $sat $max_brightness]
                    set r [lindex $rgb 0]
                    set g [lindex $rgb 1]
                    set b [lindex $rgb 2]
                    
                    # Устанавливаем цвет пикселя
                    set color [format "#%02X%02X%02X" $r $g $b]
                    $wheel_image put $color -to $x $y
                }
            }
        }
        
        # Отображаем изображение на канвасе
        $canvas create image [expr {$size / 2}] [expr {$size / 2}] -image $wheel_image -tags wheel
        
        # Сохраняем изображение в переменной для использования позже
        set ::plugin::hex::wheel_image $wheel_image
        
        # Добавляем маркер текущего цвета
        update_color_wheel_marker
    }
    
    # Обновление маркера текущего цвета на колесе
    proc update_color_wheel_marker {} {
        variable color_wheel_canvas
        variable hue
        variable saturation
        variable brightness
        variable color_wheel_size
        
        # Если канвас не существует, выходим
        if {![winfo exists $color_wheel_canvas]} {
            return
        }
        
        # Удаляем существующий маркер
        $color_wheel_canvas delete marker
        
        # Центр колеса
        set center [expr {$color_wheel_size / 2}]
        set radius [expr {($color_wheel_size - 20) / 2}]
        
        # Вычисляем позицию маркера на основе текущих HSB значений
        set angle_rad [expr {$hue * 3.14159265359 / 180}]
        set distance [expr {$saturation * $radius / 100}]
        set x [expr {$center + cos($angle_rad) * $distance}]
        set y [expr {$center + sin($angle_rad) * $distance}]
        
        # Создаем маркер (кружок)
        set marker_size 8
        $color_wheel_canvas create oval \
            [expr {$x - $marker_size/2}] [expr {$y - $marker_size/2}] \
            [expr {$x + $marker_size/2}] [expr {$y + $marker_size/2}] \
            -outline black -width 2 -fill white -tags marker
    }
    
    # Создание столбца яркости
    proc create_brightness_bar {canvas width height} {
        variable hue
        variable saturation
        
        # Если канвас не существует, выходим
        if {![winfo exists $canvas]} {
            return
        }
        
        # Очищаем канвас
        $canvas delete all
        
        # Создаем градиент яркости
        for {set y 0} {$y < $height} {incr y} {
            # Вычисляем яркость: сверху (100%) - вниз (0%)
            set brightness [expr {100 - ($y * 100 / $height)}]
            
            # Получаем цвет для текущей яркости
            set rgb [hsb_to_rgb $hue $saturation $brightness]
            set r [lindex $rgb 0]
            set g [lindex $rgb 1]
            set b [lindex $rgb 2]
            set color [format "#%02X%02X%02X" $r $g $b]
            
            # Рисуем линию градиента
            $canvas create line 0 $y $width $y -fill $color -width 1 -tags bar
        }
        
        # Добавляем обрамление для столбца яркости
        $canvas create rectangle 0 0 $width $height -outline "#CCCCCC" -width 1 -tags border
        
        # Добавляем маркер текущей яркости
        update_brightness_marker
    }
    
    # Обновление маркера яркости
    proc update_brightness_marker {} {
        variable brightness_canvas
        variable brightness
        variable brightness_bar_width
        variable brightness_bar_height
        
        # Если канвас не существует, выходим
        if {![winfo exists $brightness_canvas]} {
            return
        }
        
        # Удаляем существующий маркер
        $brightness_canvas delete brightness_marker
        
        # Вычисляем позицию маркера яркости
        set y [expr {$brightness_bar_height * (100 - $brightness) / 100}]
        
        # Создаем маркер (треугольник)
        $brightness_canvas create polygon \
            -5 $y \
            -15 [expr {$y - 5}] \
            -15 [expr {$y + 5}] \
            -fill black -outline white -width 1 -tags brightness_marker
    }
    
    # Обновление текущего цвета на основе HSB значений
    proc update_current_color {} {
        variable current_color
        variable hue
        variable saturation
        variable brightness
        variable color_picker_win
        
        # Преобразуем HSB в HEX
        set current_color [hsb_to_hex $hue $saturation $brightness]
        
        # Обновляем отображение цвета
        if {[winfo exists $color_picker_win] && [winfo exists $color_picker_win.main.color_display.color]} {
            $color_picker_win.main.color_display.color configure -background $current_color
        }
        
        # Обновляем значение в поле HEX-кода
        if {[winfo exists $color_picker_win] && [winfo exists $color_picker_win.main.color_display.hex]} {
            $color_picker_win.main.color_display.hex delete 0 end
            $color_picker_win.main.color_display.hex insert 0 $current_color
        }
        
        # Добавляем отладочный вывод
        puts "Текущий цвет обновлен: $current_color (H=$hue, S=$saturation, B=$brightness)"
        
        return $current_color
    }
    
    # Обработка клика по цветовому колесу
    proc color_wheel_click {x y} {
        variable color_wheel_canvas
        variable color_wheel_size
        variable hue
        variable saturation
        variable current_color
        
        # Центр колеса
        set center [expr {$color_wheel_size / 2}]
        set radius [expr {($color_wheel_size - 20) / 2}]
        
        # Вычисляем расстояние от центра и угол
        set dx [expr {$x - $center}]
        set dy [expr {$y - $center}]
        set distance [expr {sqrt($dx * $dx + $dy * $dy)}]
        
        # Игнорируем клики вне круга
        if {$distance > $radius} {
            return
        }
        
        # Вычисляем угол (оттенок)
        set angle [expr {atan2($dy, $dx) * 180 / 3.14159265359}]
        if {$angle < 0} {
            set angle [expr {$angle + 360}]
        }
        
        # Устанавливаем новые значения оттенка и насыщенности
        set hue $angle
        set saturation [expr {$distance / $radius * 100}]
        
        # Обновляем маркер и текущий цвет
        update_color_wheel_marker
        set current_color [update_current_color]
        
        # Обновляем столбец яркости с новыми значениями оттенка и насыщенности
        create_brightness_bar $::plugin::hex::brightness_canvas \
            $::plugin::hex::brightness_bar_width \
            $::plugin::hex::brightness_bar_height
        
        # Отладочный вывод
        puts "Клик на колесе: x=$x, y=$y, hue=$hue, saturation=$saturation, color=$current_color"
    }
    
    # Обработка клика по столбцу яркости
    proc brightness_bar_click {y} {
        variable brightness_bar_height
        variable brightness
        variable current_color
        
        # Вычисляем яркость на основе позиции клика
        set new_brightness [expr {100 - ($y * 100 / $brightness_bar_height)}]
        
        # Ограничиваем значение в пределах 0-100
        if {$new_brightness < 0} {
            set new_brightness 0
        } elseif {$new_brightness > 100} {
            set new_brightness 100
        }
        
        # Устанавливаем новое значение яркости
        set brightness $new_brightness
        
        # Обновляем маркер и текущий цвет
        update_brightness_marker
        set current_color [update_current_color]
        
        # Отладочный вывод
        puts "Клик на столбце яркости: y=$y, brightness=$brightness, color=$current_color"
    }
    
    # Показать немодальное окно выбора цвета
    proc show_color_picker {} {
        variable color_picker_win
        variable current_color
        variable current_tab
        variable selection_start
        variable selection_end
        variable color_history
        variable color_wheel_size
        variable brightness_bar_width
        variable brightness_bar_height
        variable color_wheel_canvas
        variable brightness_canvas
        variable hue
        variable saturation
        variable brightness
        
        # Получаем текущую вкладку
        set current_tab [.tabs select]
        if {$current_tab eq ""} {
            tk_messageBox -icon warning -title "Выбор цвета" \
                -message "Нет открытой вкладки."
            return
        }
        
        # Получаем текстовый виджет
        set txt $current_tab.text
        
        # Определяем начальный цвет
        set current_color "#FFFFFF"  ;# По умолчанию белый
        set selection_start ""
        set selection_end ""
        
        # Проверяем, есть ли выделение, и если да, проверяем его на HEX-код
        if {![catch {set selection_start [$txt index sel.first]}] && 
            ![catch {set selection_end [$txt index sel.last]}]} {
            set selected_text [$txt get $selection_start $selection_end]
            set selected_text [string trim $selected_text]
            if {[is_valid_hex_code $selected_text]} {
                set current_color $selected_text
            }
        } else {
            # Если нет выделения, сохраняем позицию курсора
            set selection_start [$txt index insert]
            set selection_end $selection_start
        }
        
        # Преобразуем текущий цвет в HSB
        set hsb [hex_to_hsb $current_color]
        set hue [lindex $hsb 0]
        set saturation [lindex $hsb 1]
        set brightness [lindex $hsb 2]
        
        # Если окно уже существует, просто обновляем в нем текущий цвет
        if {[winfo exists $color_picker_win]} {
            update_current_color
            create_color_wheel $color_wheel_canvas $color_wheel_size
            create_brightness_bar $brightness_canvas $brightness_bar_width $brightness_bar_height
            wm deiconify $color_picker_win
            raise $color_picker_win
            return
        }
        
        # Создаем немодальное окно выбора цвета
        set color_picker_win .color_picker
        toplevel $color_picker_win
        wm title $color_picker_win "Выбор цвета"
        wm transient $color_picker_win .
        wm resizable $color_picker_win 0 0
        
        # Создаем и размещаем элементы управления
        ttk::frame $color_picker_win.main -padding "10 10 10 10"
        pack $color_picker_win.main -expand 1 -fill both
        
        # Фрейм для отображения текущего цвета
        ttk::frame $color_picker_win.main.color_display
        ttk::label $color_picker_win.main.color_display.label -text "Текущий цвет:"
        
        # Создаем фрейм для отображения цвета
        frame $color_picker_win.main.color_display.color -width 100 -height 50 \
            -background $current_color -relief sunken -borderwidth 2
            
        # Поле для отображения HEX-кода
        ttk::entry $color_picker_win.main.color_display.hex -width 10
        $color_picker_win.main.color_display.hex insert 0 $current_color
        
        # Размещаем элементы отображения цвета
        grid $color_picker_win.main.color_display.label -row 0 -column 0 -sticky w -padx 5 -pady 5
        grid $color_picker_win.main.color_display.color -row 0 -column 1 -padx 5 -pady 5
        grid $color_picker_win.main.color_display.hex -row 0 -column 2 -padx 5 -pady 5
        
        # Фрейм для палитры и яркости
        ttk::frame $color_picker_win.main.palette_frame
        
        # Создаем канвас для цветового колеса
        canvas $color_picker_win.main.palette_frame.wheel -width $color_wheel_size -height $color_wheel_size \
            -highlightthickness 0 -bg "#F0F0F0"
        set color_wheel_canvas $color_picker_win.main.palette_frame.wheel
        
        # Создаем канвас для столбца яркости
        canvas $color_picker_win.main.palette_frame.brightness -width $brightness_bar_width -height $brightness_bar_height \
            -highlightthickness 0 -bg white
        set brightness_canvas $color_picker_win.main.palette_frame.brightness
        
        # Инициализируем цветовое колесо и столбец яркости
        create_color_wheel $color_wheel_canvas $color_wheel_size
        create_brightness_bar $brightness_canvas $brightness_bar_width $brightness_bar_height
        
        # Размещаем канвасы горизонтально с отступом
        pack $color_wheel_canvas -side left -padx 5 -pady 5
        pack $brightness_canvas -side left -padx 5 -pady 5
        
        # История цветов
        ttk::labelframe $color_picker_win.main.history -text "История"
        
        # Создаем фрейм для прокрутки истории
        ttk::frame $color_picker_win.main.history.colors
        
        # Размещаем элементы
        pack $color_picker_win.main.color_display -fill x -pady 5
        pack $color_picker_win.main.palette_frame -fill x -pady 5
        pack $color_picker_win.main.history -fill x -pady 5
        pack $color_picker_win.main.history.colors -fill x -padx 5 -pady 5
        
        # Кнопки действий
        ttk::frame $color_picker_win.main.actions
        ttk::button $color_picker_win.main.actions.insert -text "Вставить" \
            -command ::plugin::hex::insert_color
        ttk::button $color_picker_win.main.actions.close -text "Закрыть" \
            -command [list destroy $color_picker_win]
        
        grid $color_picker_win.main.actions.insert -row 0 -column 0 -padx 5 -pady 5 -sticky ew
        grid $color_picker_win.main.actions.close -row 0 -column 1 -padx 5 -pady 5 -sticky ew
        
        # Настраиваем веса столбцов для равномерного распределения
        grid columnconfigure $color_picker_win.main.actions 0 -weight 1
        grid columnconfigure $color_picker_win.main.actions 1 -weight 1
        
        pack $color_picker_win.main.actions -fill x -pady 5
        
        # Обработчики событий для круговой палитры и столбца яркости
        bind $color_wheel_canvas <Button-1> {
            ::plugin::hex::color_wheel_click %x %y
            set ::plugin::hex::drag_active 1
        }
        bind $color_wheel_canvas <B1-Motion> {
            if {$::plugin::hex::drag_active} {
                ::plugin::hex::color_wheel_click %x %y
            }
        }
        bind $color_wheel_canvas <ButtonRelease-1> {
            set ::plugin::hex::drag_active 0
        }
        
        bind $brightness_canvas <Button-1> {
            ::plugin::hex::brightness_bar_click %y
            set ::plugin::hex::drag_active 1
        }
        bind $brightness_canvas <B1-Motion> {
            if {$::plugin::hex::drag_active} {
                ::plugin::hex::brightness_bar_click %y
            }
        }
        bind $brightness_canvas <ButtonRelease-1> {
            set ::plugin::hex::drag_active 0
        }
        
        # Привязки клавиш
        bind $color_picker_win <Return> ::plugin::hex::insert_color
        bind $color_picker_win <Escape> [list destroy $color_picker_win]
        
        # Обновляем историю цветов
        update_color_history
        
        # Следим за изменениями в поле HEX-кода
        bind $color_picker_win.main.color_display.hex <KeyRelease> {
            if {[::plugin::hex::is_valid_hex_code [%W get]]} {
                set ::plugin::hex::current_color [%W get]
                
                # Обновляем HSB значения на основе нового HEX-кода
                set hsb [::plugin::hex::hex_to_hsb $::plugin::hex::current_color]
                set ::plugin::hex::hue [lindex $hsb 0]
                set ::plugin::hex::saturation [lindex $hsb 1]
                set ::plugin::hex::brightness [lindex $hsb 2]
                
                # Обновляем отображение
                ::plugin::hex::update_color_wheel_marker
                ::plugin::hex::update_brightness_marker
                ::plugin::hex::create_brightness_bar $::plugin::hex::brightness_canvas \
                    $::plugin::hex::brightness_bar_width \
                    $::plugin::hex::brightness_bar_height
                    
                # Обновляем фон поля отображения цвета
                .color_picker.main.color_display.color configure -background $::plugin::hex::current_color
                
                # Отладочный вывод
                puts "Изменен HEX-код вручную: $::plugin::hex::current_color"
            }
        }
        
        # Центрируем окно
        center_window $color_picker_win
        
        # Установка фокуса на поле ввода HEX-кода
        focus $color_picker_win.main.color_display.hex
    }
    
    # Обновить историю цветов
    proc update_color_history {} {
        variable color_picker_win
        variable color_history
        
        if {![winfo exists $color_picker_win]} return
        
        # Удаляем существующие элементы истории
        foreach child [winfo children $color_picker_win.main.history.colors] {
            destroy $child
        }
        
        # Если история пуста, показываем сообщение
        if {[llength $color_history] == 0} {
            ttk::label $color_picker_win.main.history.colors.empty \
                -text "Нет недавно использованных цветов"
            pack $color_picker_win.main.history.colors.empty -padx 5 -pady 2
            return
        }
        
        # Создаем фреймы для каждого цвета из истории
        set col 0
        foreach hex_color $color_history {
            frame $color_picker_win.main.history.colors.h$col -width 30 -height 30 \
                -background $hex_color -relief raised -borderwidth 1
            pack $color_picker_win.main.history.colors.h$col -side left -padx 2 -pady 2
            
            # Привязываем событие клика к выбору цвета
            bind $color_picker_win.main.history.colors.h$col <Button-1> \
                [list ::plugin::hex::select_color $hex_color]
            
            # Подсказка при наведении
            tooltip $color_picker_win.main.history.colors.h$col $hex_color
            
            incr col
        }
    }
    
    # Выбрать цвет из истории
    proc select_color {color} {
        variable current_color
        variable color_picker_win
        
        # Устанавливаем выбранный цвет
        set current_color $color
        
        # Обновляем HSB значения
        set hsb [hex_to_hsb $color]
        set ::plugin::hex::hue [lindex $hsb 0]
        set ::plugin::hex::saturation [lindex $hsb 1]
        set ::plugin::hex::brightness [lindex $hsb 2]
        
        # Обновляем отображение
        update_color_wheel_marker
        update_brightness_marker
        create_brightness_bar $::plugin::hex::brightness_canvas \
            $::plugin::hex::brightness_bar_width \
            $::plugin::hex::brightness_bar_height
            
        # Обновляем отображение текущего цвета и поле ввода
        if {[winfo exists $color_picker_win.main.color_display.color]} {
            $color_picker_win.main.color_display.color configure -background $current_color
        }
        
        if {[winfo exists $color_picker_win.main.color_display.hex]} {
            $color_picker_win.main.color_display.hex delete 0 end
            $color_picker_win.main.color_display.hex insert 0 $current_color
        }
        
        # Добавляем в историю
        add_to_history $color
        
        # Отладочный вывод
        puts "Выбран цвет из истории: $color"
    }
    
    # Процедура создания всплывающей подсказки
    proc tooltip {widget text} {
        bind $widget <Enter> [list after 500 [list ::plugin::hex::show_tooltip %W $text]]
        bind $widget <Leave> [list destroy .tooltip]
        bind $widget <ButtonPress> [list destroy .tooltip]
    }
    
    # Показать всплывающую подсказку
    proc show_tooltip {widget text} {
        if {[winfo exists .tooltip]} {
            destroy .tooltip
        }
        set x [expr {[winfo rootx $widget] + [winfo width $widget] / 2}]
        set y [expr {[winfo rooty $widget] + [winfo height $widget] + 5}]
        
        toplevel .tooltip -bd 1 -relief solid
        wm overrideredirect .tooltip 1
        
        label .tooltip.label -text $text -justify left -background "#FFFFCC" \
            -relief flat -padx 5 -pady 2
        pack .tooltip.label
        
        wm geometry .tooltip +$x+$y
        raise .tooltip
        
        # Автоматически закрываем через 2 секунды
        after 2000 {catch {destroy .tooltip}}
    }
    
    # Добавить цвет в историю
    proc add_to_history {color} {
        variable color_history
        variable max_history
        
        # Удаляем цвет из истории, если он уже там есть
        set idx [lsearch -exact $color_history $color]
        if {$idx != -1} {
            set color_history [lreplace $color_history $idx $idx]
        }
        
        # Добавляем цвет в начало списка
        set color_history [linsert $color_history 0 $color]
        
        # Ограничиваем размер истории
        if {[llength $color_history] > $max_history} {
            set color_history [lrange $color_history 0 [expr {$max_history - 1}]]
        }
        
        # Обновляем отображение истории
        update_color_history
    }
    
    # Вставить выбранный цвет в текст
    proc insert_color {} {
        variable current_color
        variable current_tab
        variable selection_start
        variable selection_end
        variable color_picker_win
        
        # Получаем текущий HEX-код из поля ввода
        if {[winfo exists $color_picker_win] && [winfo exists $color_picker_win.main.color_display.hex]} {
            set entered_color [$color_picker_win.main.color_display.hex get]
            if {[is_valid_hex_code $entered_color]} {
                set current_color $entered_color
            }
        }
        
        # Проверяем, существует ли вкладка
        if {![winfo exists $current_tab]} {
            tk_messageBox -icon warning -title "Вставка цвета" \
                -message "Не найдена вкладка, в которую нужно вставить цвет."
            return
        }
        
        set txt $current_tab.text
        
        # Проверяем, валидный ли HEX-код
        if {![is_valid_hex_code $current_color]} {
            tk_messageBox -icon warning -title "Вставка цвета" \
                -message "Невалидный HEX-код цвета: $current_color"
            return
        }
        
        # Если было выделение, заменяем его
        if {$selection_start ne $selection_end} {
            $txt delete $selection_start $selection_end
        }
        
        # Вставляем HEX-код
        $txt insert $selection_start $current_color
        
        # Добавляем в историю
        add_to_history $current_color
        
        # Отмечаем файл как модифицированный
        if {[info exists ::core::modified_tabs($current_tab)]} {
            set ::core::modified_tabs($current_tab) 1
            if {[info commands ::core::check_modified] ne ""} {
                ::core::check_modified $current_tab
            }
        }
        
        # Отладочный вывод
        puts "Вставлен цвет в текст: $current_color"
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

# Инициализация плагина
::plugin::hex::init
