## Updated: 20-05-2025 плагин hotkeys.tcl . Добавлена поддержка кириллической клавиши для Ctrl+S (сохранение)

## Обновление: 14-05-2025 плагин hotkeys.tcl . Добавлены привязки для кириллической раскладки с использованием корректных keysyms

## Обновление-13-05-25 -syntax_basic.tcl плагин подсветки синтаксиса для C, C++, Python и Lua к прежней для tcl, sh.
Также добавил архив с новым главным скриптом и плагином  `TED2+_PUB-UPDATE-highlighting_ver-12_05_25-.tar` с этими изменениями

## Обновил дополнительно ядро до main-core-1_5.tcl
- улучщил работу открытия документа в редакторе из контекстного меню ФМ, прежнее обновление открывала новый экзэмпляр редактора, теперь открывает из контекстного меню ФМ аргументом
в новой вкладке открытого уже редактора. Теперь это работает как и должно!

## Обновление-13_05_25- Обновлено ядро редактора main-core-1_3.tcl 
- исправил фокус, при открытии фокус на новый файл, что принудит переключится на нужный, 
также добавил возможность открывать файлы аргументом из контекстного меню фйалового менеджера,поместите этот файл в каталог проекта, и поправьте полный путь до него 
в desktop файле редактора.
  Следующим обновлением добавлю подсветку синтаксиса для языков програмирования C,C++,python,lua, также обеспечу запуск скриптовых языков
из перечисленых.

# TED2+
TED2+ - Lightweight Modular Text Editor in Tcl/Tk
# TED2+ - Модульный текстовый редактор на Tcl/Tk

## О проекте:
TED2+ изначально создавался как учебный проект для изучения возможностей Tcl/Tk, но со временем превратился в полноценный инструмент для работы с кодом. 
  Редактор основан на проекте [TIDE](https://github.com/ALANVF/Tide) и значительно расширен. **<u>Смотри раздел CHANGELOG</u>** 
проект TIDE использует лицензию Non-Profit Open Software License 3.0 (NPOSL-3.0)
и так как мой проект использует  TIDE  в качестве ядра и активно использует его API , а плагины при своей работе обращаются к нему
то он по сути на данный момент является производным от TIDE и потому автоматически наследует лицензию NPOSL-3.0
Вкратце она позволяет использовать код как хотите, менять его преобразовывать , использовать в своих проектах ровно до момента пока вы 
не решите зарабатывать на нём,лицензия напрямую это запрещает,а так код можно менять, улучшать, дарить, это копилефтная некомерчекская лицензия,и по этой причине TED2+ унаследовал эту же лицензию, NPOSL-3.0. 
Исходный код TIDE как того требует лицензия , приведен в каталоге src_Tide .

## Особенности:
- Простой и понятный интерфейс без лишней перегруженности
- Многовкладочный интерфейс
- Поддержка плагинов
- Автоматическая загрузка плагинов из каталога `plugins/`
- Встроенная подсветка синтаксиса для Tcl и Bash

## Установка и запуск:

### Требования:
- Tcl/Tk версии 8.6 или выше
- пакет ctext для подсветки синтаксиса

### Установка зависимостей и редактора TED2+

#### Для Debian/Ubuntu и производных:
```bash
# Обновление списка пакетов
sudo apt update

# Установка Tcl/Tk
sudo apt install tcl tk

# Установка пакета ctext
sudo apt install tcllib

# Проверка версии Tcl
tclsh
puts $tcl_version
# Нажмите Ctrl+D для выхода

# Проверка наличия ctext
echo "package require ctext" | tclsh
```
#### Для Arch Linux и производных (Manjaro):
```
# Обновление системы
sudo pacman -Syu

# Установка Tcl/Tk
sudo pacman -S tk

# Установка ctext
sudo pacman -S tcllib

# Проверка версии Tcl
tclsh
puts $tcl_version
# Нажмите Ctrl+D для выхода

# Проверка наличия ctext
echo "package require ctext" | tclsh
```
#### Для Fedora и производных (RHEL, CentOS):
```
# Обновление системы
sudo dnf upgrade --refresh

# Установка Tcl/Tk
sudo dnf install tk

# Установка ctext
sudo dnf install tcllib

# Проверка версии Tcl
tclsh
puts $tcl_version
# Нажмите Ctrl+D для выхода

# Проверка наличия ctext
echo "package require ctext" | tclsh
``` 
### Установка редактора TED2+
**<u>Скачайте из этой ветки архив TED2+_pubV.tar</u>** 
и распакуйте в любом удобном каталоге,далее
открываем терминал по пути катлога в которм распаковали архив с редактором
и производим командой:
```
#### Запуск редактора

./main-core-1_1.tcl
```


## Структура каталогов:
```
/editor-root
    main-core.tcl      - Основной файл редактора
    plugins/           - Каталог плагинов
        hotkeys.tcl    - Плагин горячих клавиш
        block.tcl      - Поиск/замена по блокам кода
        chmod.tcl      - Управление правами файлов
        hex.tcl        - Выбор цвета HEX
        ...            - Другие плагины
    LICENSE            - Файл лицензии
    CHANGELOG.md       - файл с логом изменений в TED2+ относительно TIDE
    README.md          - Документация
```

## Создание плагинов:

### Пошаговое руководство:

1. **Создание файла плагина:**
   - Создайте новый файл в каталоге `plugins/` с именем `имя_плагина.tcl`
   - Например: `plugins/my_plugin.tcl`

2. **Базовая структура плагина:**

```tcl
namespace eval ::plugin::my_plugin {
    # Информация о плагине
    variable plugin_info
    array set plugin_info {
        name "Мой Плагин"
        version "1.0"
        description "Этот плагин делает что-то полезное"
        author "Ваше Имя"
    }
    
    # Переменная для отслеживания инициализации
    variable initialized 0
    
    # Процедура инициализации (обязательна)
    proc init {} {
        variable initialized
        if {$initialized} { return 1 }
        
        # Регистрация кнопки (опционально)
        ::core::register_plugin_button \
            "my_plugin" \
            "Текст кнопки" \
            "::plugin::my_plugin::my_command" \
            "иконка.png" \
            50
        
        # Настраиваем привязки (если нужно)
        bind . <Control-m> {::plugin::my_plugin::my_command}
        
        puts "Плагин ${plugin_info(name)} v${plugin_info(version)} загружен"
        set initialized 1
        return 1
    }
    
    # Пример команды плагина
    proc my_command {} {
        tk_messageBox -message "Привет из моего плагина!"
    }
}

# Инициализация при загрузке
::plugin::my_plugin::init
```

3. **Основные моменты при создании плагина:**

- **Именование:**
  - Все плагины должны быть помещены в пространство имен `::plugin::<имя_плагина>`
  - Имя файла должно соответствовать имени плагина и находиться в каталоге `plugins/`
  
- **Процедура init:**
  - Должна быть определена как `::plugin::<имя_плагина>::init`
  - Должна возвращать 1 при успешной инициализации
  - Должна проверять, не была ли уже выполнена инициализация
  
- **Регистрация кнопок:**
```tcl
::core::register_plugin_button \
    "<имя_плагина>" \
    "Текст кнопки" \
    "<команда>" \
    "<иконка>" \
    <порядок>
```
Где:
- `<порядок>` - целое число, определяющее позицию кнопки (чем меньше число, тем левее кнопка)

4. **Доступ к текущей вкладке:**

```tcl
set current_tab [.tabs select]
if {$current_tab ne ""} {
    set text_widget $current_tab.text
    # Теперь можно работать с текстовым виджетом
}
```

5. **Использование API:**
```tcl
# Получение текущего текста
set text [::core::get_text]

# Установка нового текста
::core::set_text "Новый текст"

# Получение пути к текущему файлу
set file_path [::core::get_file_path]
```

## Горячие клавиши:

### Закрытие вкладки правой кнопкой мыши.

### Общие:
- `Ctrl+N` - Новая вкладка
- `Ctrl+O` - Открыть файл
- `Ctrl+S` - Сохранить
- `Ctrl+Shift+S` - Сохранить как
- `Ctrl+W` - Закрыть текущую вкладку
- `Ctrl+Q` - Выйти из редактора
- `Ctrl+,` - Настройки
- `Ctrl+T` - Создать новую вкладку
- `Ctrl+Tab` - Следующая вкладка
- `Ctrl+Shift+Tab` - Предыдущая вкладка
- `Ctrl+1` до `Ctrl+9` - Переключение между вкладками

### Редактирование:
- `Ctrl+Z` - Отменить действие
- `Ctrl+Y` или `Ctrl+Shift+Z` - Повторить действие
- `Ctrl+X` - Вырезать
- `Ctrl+C` - Копировать
- `Ctrl+V` - Вставить
- `Ctrl+A` - Выделить всё
- `Ctrl+D` - Удалить строку
- `Ctrl+L` - Дублировать строку
- `Ctrl+/` - Комментарий/раскомментирование строки
- `Alt+Z` - Переключение переноса текста

### Навигация:
- `Ctrl+F` - Поиск
- `Ctrl+H` - Замена
- `F3` - Следующее совпадение
- `Shift+F3` - Предыдущее совпадение
- `Home` - Перейти к началу строки/первому символу
- `Ctrl+Left` - Перейти к предыдущему слову
- `Ctrl+Right` - Перейти к следующему слову

## API для плагинов:

### Основные методы:
```tcl
::core::create_tab ?filename?      - Создание новой вкладки
::core::close_tab                  - Закрытие текущей вкладки
::core::get_current_tab            - Получение текущей вкладки
::core::get_current_text           - Получение текущего текстового виджета
::core::get_text                   - Получение текущего текста
::core::set_text text              - Установка нового текста
::core::get_file_path              - Получение пути к текущему файлу
::core::get_config key             - Получение значения конфигурации
::core::set_config key value       - Установка значения конфигурации
::core::register_button params...  - Регистрация кнопки плагина
```

### Пример использования:
```tcl
# Создание новой вкладки с текстом
proc ::plugin::demo::create_demo_tab {} {
    set tab [::core::create_tab]
    after idle "$tab.text insert 1.0 \"Это демонстрационная вкладка\""
}

# Добавление текста в текущую вкладку
proc ::plugin::demo::append_text {text} {
    set current_tab [.tabs select]
    if {$current_tab ne ""} {
        $current_tab.text insert end "\n$text"
    }
}
```

## Лицензия:

```
TED2+ - Модульный текстовый редактор

Эта программа является свободным программным обеспечением: вы можете 
распространять и/или модифицировать её согласно условиям 
Лицензии NPOSL-3.0 :
Это некоммерческая открытая лицензия для программного обеспечения.
Она запрещает коммерческое использование и модификацию условий лицензии.
Лицензия предоставляет права на копирование, модификацию и распространение ПО, но только в некоммерческих целях.
Включает положения об отказе от гарантий и ограничении ответственности, включая прямые убытки.
Требует сохранения авторских и лицензионных уведомлений при распространении производных работ.
Основные условия :
Запрет на использование имён авторов или владельцев для продвижения производных продуктов без явного разрешения.
Обязательство предоставлять исходный код при распространении ПО.
Лицензия автоматически прекращается при нарушении её условий или подаче иска о нарушении патентов.
Все споры регулируются законами юрисдикции владельца лицензии.
Эта лицензия подходит для проектов, которые стремятся оставаться полностью некоммерческими и свободными от любых форм монетизации.

Эта программа распространяется в надежде, что она будет полезной,
но БЕЗ КАКИХ-ЛИБО ГАРАНТИЙ; 

```

## Известные ограничения:

1. Требуется Tcl/Tk версии 8.6+
2. Не все функции работают корректно с очень большими файлами (>100MB)
3. Возможно случайное дублирование привязок клавиш между плагинами
4. Нет встроенного менеджера плагинов

## Планы по развитию:

1. Добавить новые возможности:
   - Поддержку дополнительных языков программирования
   - Автоматическое завершение кода

2. Улучшить производительность:
   - Оптимизация работы с большими файлами
   - Ленивая загрузка плагинов
   - Кэширование результатов подсветки синтаксиса

3. Реализовать дополнительные плагины:
   - Интерактивная консоль


При возникновении вопросов или проблем, пожалуйста, создавайте issue в репозитории проекта.
```
