#!/usr/bin/wish
encoding system utf-8

# ==============================================================================
# TED3+ QUANTUM_CORE - Version 3.9.2 (GROK_MUTATED_HARMONY)
# FIX: Removed duplicate Button-3 binding (handled by hotkeys plugin)
# FIX: Removed check_modified stub, call update_ui_state directly
# FIX: Improved single instance with stale cleanup
# ==============================================================================

package require Tk
package require ctext

namespace eval ::core {
    variable config
    array set config {
        version "3.9.2"
        theme "dark"
        font_family "Courier"
        font_size 12
        bg "#1E1E1E"
        fg "#D4D4D4"
        accent "#264F78"
    }
    variable tab_counter 0
    variable tab_files; array set tab_files {}
    variable modified_tabs; array set modified_tabs {}
}

# --- 1. API ПЛАГИНОВ ---
proc ::core::register_plugin_button {name label command {icon ""} args} {
    if {![winfo exists .toolbar.plugins]} {
        ttk::frame .toolbar.plugins
        pack .toolbar.plugins -side left -padx 5 -after .toolbar.core
    }
    set btn_id ".toolbar.plugins.btn_$name"
    if {[winfo exists $btn_id]} { destroy $btn_id }
    ttk::button $btn_id -text $label -command $command -style Toolbutton
    pack $btn_id -side left -padx 2
}

# --- 2. ДИАЛОГИ ---
namespace eval ::core::dialogs {
    variable current_dir [pwd]
    variable selected_result ""
    variable input_res ""
}

proc ::core::dialogs::refresh_list {w} {
    variable current_dir
    set tree $w.center.tree
    $tree delete [$tree children {}]
    $tree insert {} end -text "⬆️ .." -values [list "directory" [file dirname $current_dir]] -tags {dir}
    
    foreach item [lsort -dictionary [glob -nocomplain -directory $current_dir *]] {
        set type [expr {[file isdirectory $item] ? "directory" : "file"}]
        set name [file tail $item]
        set icon [expr {$type eq "directory" ? "📂" : "📝"}] 
        if {[file extension $name] eq ".tcl"} { set icon "👾" }
        $tree insert {} end -text "$icon $name" -values [list $type $item] -tags $type
    }
    $w.top.path_ent delete 0 end; $w.top.path_ent insert 0 $current_dir
}

proc ::core::dialogs::create_folder {w} {
    variable current_dir
    set d .input_dialog
    if {[winfo exists $d]} {destroy $d}
    toplevel $d; wm title $d "New Folder"; wm transient $d .
    label $d.l -text "Name:"; entry $d.e -width 30
    frame $d.b
    button $d.b.ok -text "✅ Create" -command "set ::core::dialogs::input_res \[$d.e get\]; destroy $d"
    button $d.b.can -text "❌ Cancel" -command "set ::core::dialogs::input_res \"\"; destroy $d"
    pack $d.l $d.e -padx 10 -pady 5; pack $d.b -fill x
    pack $d.b.ok $d.b.can -side left -expand 1
    focus $d.e; bind $d <Return> "$d.b.ok invoke"
    grab $d; tkwait window $d
    if {$::core::dialogs::input_res ne ""} {
        set path [file join $current_dir $::core::dialogs::input_res]
        if {[catch {file mkdir $path} err]} { tk_messageBox -icon error -message "$err" }
        refresh_list $w
    }
}

proc ::core::dialogs::show {mode} {
    variable current_dir
    variable selected_result
    set selected_result ""
    set w .file_manager
    if {[winfo exists $w]} {destroy $w}
    toplevel $w
    wm title $w [expr {$mode eq "save" ? "💾 Save As..." : "📂 Open File"}]
    wm geometry $w "700x500"; wm transient $w .
    
    frame $w.top; entry $w.top.path_ent
    button $w.top.newdir -text "➕📂" -command "::core::dialogs::create_folder $w"
    pack $w.top.path_ent -side left -fill x -expand 1; pack $w.top.newdir -side right
    pack $w.top -fill x -padx 5 -pady 5

    frame $w.center
    ttk::treeview $w.center.tree -columns {type path} -show {tree} -selectmode browse
    scrollbar $w.center.vsb -command "$w.center.tree yview"
    $w.center.tree configure -yscrollcommand "$w.center.vsb set"
    pack $w.center.tree -side left -fill both -expand 1
    pack $w.center.vsb -side right -fill y
    pack $w.center -fill both -expand 1

    frame $w.bottom; entry $w.bottom.ent
    button $w.bottom.ok -text "OK"; button $w.bottom.can -text "Cancel" -command "destroy $w"
    pack $w.bottom.ent -side left -fill x -expand 1; pack $w.bottom.ok $w.bottom.can -side right
    pack $w.bottom -fill x -padx 5 -pady 5

    set press_ok [list apply {{w mode} {
        set val [$w.bottom.ent get]
        set fullpath [file join $::core::dialogs::current_dir $val]
        if {[file isdirectory $fullpath]} {
            set ::core::dialogs::current_dir $fullpath
            ::core::dialogs::refresh_list $w
            $w.bottom.ent delete 0 end
        } else {
            set ::core::dialogs::selected_result $fullpath
            destroy $w
        }
    }} $w $mode]
    $w.bottom.ok configure -command $press_ok; bind $w <Return> $press_ok
    
    bind $w.center.tree <<TreeviewSelect>> {
        set item [%W selection]
        if {[%W set $item type] eq "file"} {
            .file_manager.bottom.ent delete 0 end
            .file_manager.bottom.ent insert 0 [file tail [%W set $item path]]
        }
    }
    bind $w.center.tree <Double-1> {
        set item [%W selection]
        set path [%W set $item path]
        if {[%W set $item type] eq "directory"} {
            set ::core::dialogs::current_dir $path
            ::core::dialogs::refresh_list .file_manager; .file_manager.bottom.ent delete 0 end
        } else {
            set ::core::dialogs::selected_result $path; destroy .file_manager
        }
    }
    refresh_list $w; grab $w; tkwait window $w
    return $selected_result
}

# --- 3. CORE LOGIC ---

proc ::core::create_tab {{filename ""} {pos "end"}} {
    if {$filename ne "" && [file isdirectory $filename]} { return }
    variable tab_counter; incr tab_counter
    set f [ttk::frame ".tabs.tab$tab_counter"]
    ctext $f.text -undo 1 -font [list $::core::config(font_family) $::core::config(font_size)] \
        -bg $::core::config(bg) -fg $::core::config(fg) -insertbackground white \
        -yscrollcommand [list $f.yscroll set] -xscrollcommand [list $f.xscroll set]
    
    ttk::scrollbar $f.yscroll -orient vertical -command [list $f.text yview]
    ttk::scrollbar $f.xscroll -orient horizontal -command [list $f.text xview]
    grid $f.text -row 0 -column 0 -sticky nsew
    grid $f.yscroll -row 0 -column 1 -sticky ns
    grid $f.xscroll -row 1 -column 0 -sticky ew
    grid columnconfigure $f 0 -weight 1
    grid rowconfigure $f 0 -weight 1

    bind $f.text <<Modified>> {
        set val [%W edit modified]
        set ::core::modified_tabs([winfo parent %W]) $val
        ::core::update_ui_state
    }

    # Атомарная вставка: insert в notebook ПЕРЕД загрузкой для гармонии
    .tabs insert $pos $f -text [expr {$filename eq "" ? "New $tab_counter" : [file tail $filename]}]

    # Загрузка файла с декодированием URI
    if {$filename ne ""} {
        set path [string map {"%20" " " "file://" "" "file:" ""} $filename]
        set path [file normalize [string trim $path]]
        if {[file exists $path]} {
            if {[catch {
                set fd [open $path r]; fconfigure $fd -encoding utf-8
                $f.text insert 1.0 [read $fd]; close $fd
                set ::core::tab_files($f) $path
                .tabs tab $f -text [file tail $path]
            } err]} { tk_messageBox -icon error -message "Error: $err"; return }
        }
    }
    
    $f.text edit modified 0
    set ::core::modified_tabs($f) 0

    # Poetic фокус: bind <Visibility> для adaptive harmony
    bind $f <Visibility> {
        if {[winfo viewable %W]} {
            .tabs select %W
            focus %W.text
            ::core::update_ui_state
        }
    }

    # Синхронизация с idle tasks для плавного потока
    update idletasks

    return $f
}

proc ::core::close_tab {tab} {
    if {[info exists ::core::modified_tabs($tab)] && $::core::modified_tabs($tab)} {
        set resp [tk_messageBox -type yesnocancel -icon question -message "Save changes?" -parent .]
        if {$resp eq "cancel"} { return }
        if {$resp eq "yes"} {
            .tabs select $tab
            ::core::save_current_file
            if {$::core::modified_tabs($tab)} { return }
        }
    }
    if {[info exists ::core::tab_files($tab)]} { unset ::core::tab_files($tab) }
    if {[info exists ::core::modified_tabs($tab)]} { unset ::core::modified_tabs($tab) }
    destroy $tab
}

proc ::core::close_current_tab {} {
    set tab [.tabs select]
    if {$tab ne ""} { ::core::close_tab $tab }
}

proc ::core::save_current_file {} {
    set tab [.tabs select]; if {$tab eq ""} return
    if {![info exists ::core::tab_files($tab)]} { ::core::save_as_file; return }
    if {[catch {
        set fd [open $::core::tab_files($tab) w]; fconfigure $fd -encoding utf-8
        puts -nonewline $fd [$tab.text get 1.0 end-1c]; close $fd
    } err]} { tk_messageBox -icon error -message "$err"; return }
    $tab.text edit modified 0; set ::core::modified_tabs($tab) 0
    ::core::update_ui_state
}

proc ::core::save_as_file {} {
    set tab [.tabs select]; if {$tab eq ""} return
    set file [::core::dialogs::show "save"]; if {$file eq ""} return
    set ::core::tab_files($tab) [file normalize $file]
    if {[catch {
        set fd [open $file w]; fconfigure $fd -encoding utf-8
        puts -nonewline $fd [$tab.text get 1.0 end-1c]; close $fd
    } err]} { tk_messageBox -icon error -message "$err"; return }
    $tab.text edit modified 0; set ::core::modified_tabs($tab) 0
    .tabs tab $tab -text [file tail $file]
    ::core::update_ui_state
}

proc ::core::update_ui_state {} {
    set tab [.tabs select]; set base "TED3+"
    if {$tab ne ""} {
        set is_mod [expr {[info exists ::core::modified_tabs($tab)] && $::core::modified_tabs($tab)}]
        set txt [file tail [.tabs tab $tab -text]]; set txt [regsub { ●$} $txt ""]
        .tabs tab $tab -text [expr {$is_mod ? "$txt ●" : $txt}]
        wm title . [expr {$is_mod ? "* $base" : $base}]
    }
}

proc ::core::create_ui {} {
    wm title . "TED3+"; wm minsize . 800 600
    ttk::frame .toolbar; pack .toolbar -fill x
    ttk::frame .toolbar.core; pack .toolbar.core -side left
    ttk::frame .toolbar.plugins; pack .toolbar.plugins -side left -padx 10
    
    ttk::button .toolbar.core.new -text "📄 New" -command ::core::create_tab
    ttk::button .toolbar.core.open -text "📂 Open" -command { set f [::core::dialogs::show "open"]; if {$f ne ""} {::core::create_tab $f} }
    ttk::button .toolbar.core.save -text "💾 Save" -command ::core::save_current_file
    ttk::button .toolbar.core.saveas -text "💾📁 As..." -command ::core::save_as_file
    
    pack .toolbar.core.new .toolbar.core.open .toolbar.core.save .toolbar.core.saveas -side left -padx 2
    ttk::notebook .tabs; pack .tabs -expand 1 -fill both
    bind .tabs <<NotebookTabChanged>> { ::core::update_ui_state }
    
    bind .tabs <Button-3> {
        set x [expr {%X - [winfo rootx %W]}]
        set y [expr {%Y - [winfo rooty %W]}]
        set tab [%W identify tab $x $y]
        if {$tab ne ""} {
            set widget [lindex [%W tabs] $tab]
            ::core::close_tab $widget
        }
    }
}

# --- 4. SINGLE INSTANCE (lock-based с очисткой старых сессий) ---

set ::core::instance_base "/tmp/.ted3_instance"
set ::core::instance_dir "$::core::instance_base.[pid]"

proc ::core::is_pid_alive {pid} {
    if {$::tcl_platform(platform) eq "windows"} {
        catch {exec tasklist /FI "PID eq $pid" 2>&1} result
        return [string match "*$pid*" $result]
    }
    return [expr {![catch {exec kill -0 $pid 2>/dev/null}]}]
}

proc ::core::cleanup_stale_instances {} {
    variable instance_base
    foreach dir [glob -nocomplain -directory /tmp .ted3_instance.*] {
        set pidfile [file join $dir "pid"]
        if {![file exists $pidfile]} { catch {file delete -force $dir}; continue }
        set fd [open $pidfile r]; set pid [string trim [read $fd]]; close $fd
        if {$pid eq "" || $pid eq [pid]} { catch {file delete -force $dir}; continue }
        if {![::core::is_pid_alive $pid]} { catch {file delete -force $dir} }
    }
}

proc ::core::try_single_instance {argv} {
    variable instance_base
    ::core::cleanup_stale_instances
    foreach dir [lsort -dictionary [glob -nocomplain -directory /tmp .ted3_instance.*]] {
        set pidfile [file join $dir "pid"]
        if {![file exists $pidfile]} continue
        set fd [open $pidfile r]; set old_pid [string trim [read $fd]]; close $fd
        if {$old_pid eq "" || $old_pid eq [pid]} continue
        if {[::core::is_pid_alive $old_pid]} {
            set datafile [file join $dir "open_[clock milliseconds].tmp"]
            set fd [open $datafile w]
            foreach fname $argv {
                if {[file exists $fname] && ![file isdirectory $fname]} {
                    puts $fd $fname
                }
            }
            close $fd
            catch {exec kill -USR1 $old_pid 2>/dev/null}
            return 1
        }
    }
    return 0
}

proc ::core::start_instance_server {} {
    variable instance_dir
    file mkdir $instance_dir
    set fd [open [file join $instance_dir "pid"] w]
    puts $fd [pid]; close $fd
    if {$::tcl_platform(platform) ne "windows"} {
        catch {signal event sigusr1 {after 10 ::core::poll_open_files}}
    }
    after 300 ::core::poll_open_files
}

proc ::core::open_and_focus_tab {fname} {
    set tab [::core::create_tab $fname]
    if {$tab ne "" && [winfo exists $tab]} {
        .tabs select $tab
        focus $tab.text
        ::core::update_ui_state
        catch {wm deiconify .}
        catch {raise .}
        catch {focus -force .}
    }
}

proc ::core::poll_open_files {} {
    variable instance_dir
    if {![file exists $instance_dir]} { return }
    foreach f [glob -nocomplain -directory $instance_dir *.tmp] {
        set fd [open $f r]; set files [split [string trim [read $fd]] \n]; close $fd
        file delete $f
        foreach fname $files {
            if {$fname ne "" && [file exists $fname] && ![file isdirectory $fname]} {
                after idle [list ::core::open_and_focus_tab $fname]
            }
        }
    }
    after 300 ::core::poll_open_files
}

proc ::core::cleanup_instance {} {
    variable instance_dir
    catch {file delete -force $instance_dir}
}

# --- 5. ИНИЦИАЛИЗАЦИЯ ---

proc ::core::init {} {
    global argv argc

    if {[::core::try_single_instance $argv]} {
        exit
    }
    ::core::start_instance_server

    ::core::create_ui
    
    set script_path [file normalize [info script]]
    set pdir [file join [file dirname $script_path] "plugins"]
    if {[file exists $pdir]} {
        foreach f [glob -nocomplain -directory $pdir *.tcl] {
            if {[catch {
                source $f
                set p_name [file rootname [file tail $f]]
                if {[info commands ::plugin::${p_name}::init] ne ""} { ::plugin::${p_name}::init }
            } err]} { puts stderr "PLUGIN SKIP ($f): $err" }
        }
    }

    # Open With handling (for files passed on first launch)
    set opened 0
    if {$argc > 0} {
        foreach fname $argv {
            if {[file exists $fname] && ![file isdirectory $fname]} {
                ::core::create_tab $fname
                set opened 1
            }
        }
    }
    
    if {!$opened} {
        ::core::create_tab
    }
}

rename exit _ted3_exit
proc exit {{code 0}} {
    ::core::cleanup_instance
    _ted3_exit $code
}

::core::init