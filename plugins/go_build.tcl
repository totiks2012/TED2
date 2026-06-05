# go_build.tcl - Плагин для сборки Go проектов
# При нажатии кнопки: go mod init -> go mod tidy -> go build

namespace eval ::plugin::go_build {
    variable plugin_info
    array set plugin_info {
        name "Go Build"
        version "1.0"
        description "Инициализация, загрузка зависимостей и сборка Go проектов"
        author "totiks2012"
    }

    proc init {} {
        ::core::register_plugin_button "gobuild" "🔨 Go Build" ::plugin::go_build::build_go_project
        return 1
    }

    proc build_go_project {} {
        set current_tab [.tabs select]
        if {$current_tab eq ""} {
            tk_messageBox -icon warning -title "Go Build" -message "Нет открытой вкладки."
            return
        }

        set filepath ""
        if {[info exists ::core::tab_files($current_tab)]} {
            set filepath $::core::tab_files($current_tab)
            if {[info exists ::core::modified_tabs($current_tab)] && $::core::modified_tabs($current_tab)} {
                set answer [tk_messageBox -icon question -type yesnocancel \
                    -title "Go Build" -message "Сохранить изменения перед сборкой?"]
                if {$answer eq "yes"} {
                    ::core::save_current_file
                } elseif {$answer eq "cancel"} { return }
            }
        } else {
            tk_messageBox -icon warning -title "Go Build" -message "Файл не сохранён. Сохраните файл в Go проекте."
            return
        }

        if {![file exists $filepath]} return

        if {[file extension $filepath] ne ".go"} {
            tk_messageBox -icon warning -title "Go Build" \
                -message "Это не Go файл.\nПлагин работает только с .go файлами."
            return
        }

        set project_dir [file dirname $filepath]

        set cmd ""
        if {![file exists [file join $project_dir "go.mod"]]} {
            set answer [tk_messageBox -icon question -type yesno \
                -title "Go Build" -message "go.mod не найден. Выполнить go mod init?"]
            if {$answer eq "no"} { return }
            set module_name [file tail $project_dir]
            set cmd "go mod init $module_name 2>&1 && "
        }
        append cmd "go mod tidy 2>&1 && go build 2>&1"

        show_dialog
        set fd [open "|bash -c \"cd '$project_dir' && $cmd\"" r]
        fconfigure $fd -blocking 0
        set ::plugin::go_build::build_fd $fd
        set ::plugin::go_build::build_output ""
        fileevent $fd readable [list ::plugin::go_build::on_build_data]
        animate_dots
    }

    proc on_build_data {} {
        variable build_fd
        variable build_output

        if {[eof $build_fd]} {
            set err [catch {close $build_fd} exit_info]
            hide_dialog
            if {$err} {
                tk_messageBox -icon error -title "Go Build" \
                    -message "Ошибка сборки:\n$build_output"
            } else {
                tk_messageBox -icon info -title "Go Build" \
                    -message "Сборка Go проекта завершена успешно!"
            }
            return
        }
        append build_output [read $build_fd]
    }

    proc show_dialog {} {
        if {[winfo exists .go_build_dlg]} { destroy .go_build_dlg }

        set bg "#2D2D2D"
        set fg "#CCCCCC"
        if {[info exists ::core::config(theme)] && $::core::config(theme) ne "dark"} {
            set bg "#FFFFFF"
            set fg "#000000"
        }

        toplevel .go_build_dlg -background $bg -borderwidth 2 -relief solid
        wm overrideredirect .go_build_dlg 1
        wm title .go_build_dlg "Go Build"

        label .go_build_dlg.icon -text "🔨" -font {TkFixedFont 20} \
            -background $bg -foreground $fg
        label .go_build_dlg.msg -text "Go Build" -font {TkFixedFont 11 bold} \
            -background $bg -foreground $fg
        label .go_build_dlg.dots -text "·" -font {TkFixedFont 16 bold} \
            -background $bg -foreground "#FFA500"

        pack .go_build_dlg.icon -side top -pady {10 0}
        pack .go_build_dlg.msg -side top -pady {5 0}
        pack .go_build_dlg.dots -side bottom -pady {5 10}

        update idletasks
        set x [expr {[winfo rootx .] + [winfo width .] / 2 - [winfo reqwidth .go_build_dlg] / 2}]
        set y [expr {[winfo rooty .] + [winfo height .] / 2 - [winfo reqheight .go_build_dlg] / 2}]
        wm geometry .go_build_dlg +${x}+${y}
        raise .go_build_dlg
        grab set .go_build_dlg
        update
    }

    proc hide_dialog {} {
        if {[winfo exists .go_build_dlg]} {
            grab release .go_build_dlg
            destroy .go_build_dlg
        }
    }

    proc animate_dots {} {
        variable dots_idx
        if {![info exists dots_idx]} { set dots_idx 0 }
        if {![winfo exists .go_build_dlg]} { return }

        set frames {"·" "··" "···"}
        .go_build_dlg.dots configure -text [lindex $frames $dots_idx]
        set dots_idx [expr {($dots_idx + 1) % 3}]
        after 500 ::plugin::go_build::animate_dots
    }
}

::plugin::go_build::init
