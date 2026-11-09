#Requires AutoHotkey v2.0
#SingleInstance Force
; v13.18: Crypt32/bcrypt загружаются один раз на весь процесс. DllCall к DLL,
; которую процесс не держит загруженной, на КАЖДЫЙ вызов делает LoadLibrary +
; FreeLibrary, а словарь кодирует base64 через Crypt32 на каждое слово —
; десятки тысяч загрузок/выгрузок DLL на старте и при каждом сохранении.
#DllLoad "*i crypt32"
#DllLoad "*i bcrypt"
#DllLoad "*i uxtheme" ; тёмная тема контролов панели (SetWindowTheme)
#DllLoad "*i dwmapi"  ; тёмные заголовки окон
; #Warn All, MsgBox ; временно включай в отдельной отладочной копии: на большой dev-версии может шуметь

; ==============================================================================
; TYPER: УМНЫЙ АССИСТЕНТ ПЕЧАТИ (Версия 13.21 · категории промптов, компактная вкладка «Промпты»)
; ==============================================================================
; ЛИЧНЫЙ РАБОЧИЙ СКРИПТ ДЛЯ УСКОРЕННОГО НАБОРА ТЕКСТА
; ------------------------------------------------------------------------------
; Этот файл — основная и актуальная версия личного Typer-скрипта.
; Он не предназначен как универсальный публичный продукт: логика и хоткеи
; заточены под конкретный рабочий набор приложений, личные привычки набора,
; шифрованное локальное хранение баз.
;
; Назначение:
; - ускорять повседневный набор слов, основ слов и типовых фраз;
; - подсказывать часто употребляемые записи по префиксу в OSD;
; - хранить отдельные основы слов, которые вставляются без пробела, чтобы
;   пользователь мог вручную дописать нужное окончание;
; - поддерживать автозамены, быстрые кавычки и точечный откат последней
;   искусственной подстановки;
; - хранить словари/фразы/автозамены в локальных контейнерах под мастер-паролем.
;
; Где обычно используется:
; - текстовые редакторы, IDE, браузеры, заметки и другие окна из группы TyperApps.
;
; Ключевые инварианты:
; - CurrentInput хранит только текущий отслеживаемый хвост ввода, а не весь текст поля;
; - основа всегда вставляется без пробела;
; - обычные слова по умолчанию вставляются с пробелом, но отдельные записи могут
;   использовать альтернативный режим вставки без пробела;
; - режим фраз — это отдельный слой поверх словаря, а не разновидность автозамен;
; - название "Фразы" условное: сюда можно хранить любые текстовые фрагменты, куски,
;   заготовки и короткие вставки, не только полноценные фразы;
; - Alt+Z — это не общий undo-стек редактора, а откат последней искусственной вставки.
; ------------------------------------------------------------------------------
; ИЗМЕНЕНИЯ 13.22 (поиск по коду: «v13.22»):
; - запись баз: .tmp сбрасывается на диск и проверяется (байты + расшифровка) ДО
;   ротации; .bak больше не удаляется заранее, основной → .bak и .tmp → основной
;   через MoveFileExW(WRITE_THROUGH). Неудачная запись не трогает ни основной, ни .bak;
; - окно пароля: MsgBox об ошибке первого запуска больше не закрывает Typer;
;   окно, которое Windows не пустила в фокус (автозагрузка, UAC), не выходит сразу —
;   3 с попыток активации, затем ждёт клика до 60 с;
; - первый запуск: мастер-пароль от 15 символов (как при смене);
; - возврат буфера после пароля из Данных: сравнение с учётом регистра;
; - Настройки → «Скрыть пароли»: в OSD «•••», в превью панели «••••••», в карточке
;   поле пароля со звёздочками (по умолчанию выкл.).
; ------------------------------------------------------------------------------
; ИЗМЕНЕНИЯ 13.21 (поиск по коду: «v13.21»):
; - категории промптов: Image / Video / LLM / Other. Хранятся в prm.bin строкой-
;   маркером «@cat|…» перед промптом; старые версии её пропускают (файл
;   совместим), промпты без маркера — Other;
; - Shift+F14: после захвата выделения — всплывашка у курсора с выбором
;   категории (1–4, I/V/L/O, ←/→ + Enter, клик; Esc — не сохранять; клик мимо —
;   в подсвеченную). Подсвечена текущая категория (если промпт уже есть) или
;   последняя выбранная;
; - окно Alt+Insert и правка промпта: ряд чипов категории + Ctrl+1…4;
; - вкладка «Промпты»: колонки «Исп.» больше нет. Над списком — фильтр-чипы
;   «Все · Image · Video · LLM · Other» со счётчиками (с учётом поиска) и
;   компактные кнопки «+ Новый / Править / Хоткей / Удалить» вместо крупного
;   ряда внизу; список стал выше. Во «Всех» — колонка «Кат.» и группы по
;   категориям, внутри — самые используемые сверху. Ctrl+0…4 — фильтр,
;   Alt+1…4 — категория выбранного, ПКМ — меню (правка, копия, категория,
;   хоткей, удаление); фильтр запоминается;
; - ширины колонок панели ставятся в физических пикселях: при масштабе 125–150 %
;   дотягивание последней колонки давало горизонтальный скроллбар, а сохранённые
;   ширины росли с каждым открытием;
; - удаление промпта в панели сохраняется сразу (раньше — только при выходе или
;   по 3-часовому автосохранению).
; ------------------------------------------------------------------------------
; ИЗМЕНЕНИЯ 13.20 (поиск по коду: «v13.20»):
; - панель F9, поиск: главная причина мерцания — после каждого обновления поиска
;   окно раскладывалось заново целиком (~80 переключений Visible, перекраска всех
;   кнопок разделов, полная перерисовка с RDW_ERASE). Теперь полная раскладка — только
;   при смене раздела/режима, а при наборе в поиске меняется только сам список;
; - поле секунд автоскрытия больше не переписывается на каждый поиск (это слало
;   EN_CHANGE → перепланирование автоскрытия и отложенное сохранение настроек);
; - кнопки разделов перекрашиваются только при смене состояния; кнопка «Удалить»
;   общего поиска — тоже (раньше мигала на каждый клик по строке);
; - общий поиск заполняется как вкладки (без перерисовки и без колбэка шапки),
;   подогнанная мышью ширина колонок больше не сбрасывается на каждую букву;
;   последняя колонка и скрытые колонки не трогаются, если ширина та же;
; - поиск по словам/фразам/промптам: по готовому ключу (нижний регистр) вместо
;   StrLower + RegExReplace каждого текста на каждую букву; в строку списка
;   промптов кладётся начало текста, а не весь промпт;
; - если раскладка панели падает с ошибкой, отрисовка окна всё равно
;   размораживается (раньше панель могла остаться «замёрзшей»);
; - тёмная тема списков панели применяется один раз (было дважды);
; - удаление слова из общего поиска сохраняет словарь отложенно, без подвисания;
; - плашка полного текста: без зелёной рамки (тонкая серая), показ сразу, без
;   паузы; наблюдатель наведения 40 мс и почти бесплатен, пока мышь стоит;
;   проверка «не влезает ли текст» меряет верным шрифтом (s10, было 9);
; - LShift/RShift tap в OSD фраз/промптов/ссылок вставляет вариант, выбранный «-»/«=»
;   (раньше LShift — всегда первый, RShift — ничего);
; - Alt+Z после длинного промпта стирает Backspace пачками по 200 (один SendInput на
;   тысячи нажатий упирался в системный лимит и захлёбывал веб-редакторы).
; ------------------------------------------------------------------------------
; ИЗМЕНЕНИЯ 13.19 (поиск по коду: «v13.19»):
; - OSD на каждую букву: контролы меняются только при реальном изменении текста,
;   цвета, места или видимости (раньше ~25 строк перерисовывались заново на каждую
;   букву + WinSetTransparent каждый раз); окно двигается, только если сменились
;   место/размер, и всегда через Show (Move «съёживал» OSD на 2 px со второй буквы);
; - раскладка строк фраз/промптов: кэш, текст режется до заведомо достаточной длины,
;   замер ширины — через один постоянный DC и кэш шрифтов (раньше GetDC + CreateFont
;   на каждый замер, а кэш ширин хранил целые промпты в ключах — десятки МБ);
; - подсказки слов: каждая следующая буква сужает прошлый список кандидатов, а не
;   перебирает весь бакет индекса; поиск 11/22 не копирует каждый промпт в StrLower;
;   превью в OSD не перезаливается, если текст не изменился;
; - #HotIf: дешёвые проверки (SuggestionVisible, режим) идут первыми — цифры, стрелки,
;   LShift, «-»/«=» при закрытом OSD больше не проверяют группу окон;
; - сохранение: база, содержимое которой не изменилось с последней записи/чтения (и
;   файл на диске тот же), не перешифровывается и не переписывается — выход и
;   автосохранения пишут только изменённое; смена пароля по-прежнему пишет всё;
; - поле «секунд» автоскрытия OSD сохраняет настройки с паузой, а не на каждую цифру;
; - OSD промптов: 8 вариантов (было 5); Ctrl+6..8 и Alt+6..8 — для фраз и промптов;
; - RShift: вручную добавленное слово сразу получает рейтинг 15 (ManualWordScore) и
;   встаёт выше авто-слов; известное слово поднимается до 15; Alt+Z откатывает точно;
; - F9: при включённом копировании по ЛКМ над промптами (вкладка «Промпты» и промпты
;   в общем поиске) курсор-«палец», подтверждение — вспышка строки вместо подсказки;
; - плашка полного текста в панели: размер по тексту, без скролла, прозрачна для мыши
;   (не мигает), монитор под курсором, верный DPI, Segoe UI (Данные — Consolas),
;   акцентная рамка, «… ещё строк: N», первый показ — после паузы 320 мс.
; ------------------------------------------------------------------------------
; ИЗМЕНЕНИЯ 13.18 (поиск по коду: «v13.18»):
; - долгий этап «словарь» на старте и «зависание» после «Удалить ≤ рейтинг»: каждое
;   слово кодируется base64 через Crypt32, а DllCall к DLL, которую процесс не держит
;   загруженной, делает LoadLibrary + FreeLibrary на КАЖДЫЙ вызов — по 2 на слово при
;   чтении и при каждом сохранении словаря (выход, автосохранение, чистка). Теперь
;   crypt32/bcrypt загружены один раз (#DllLoad), base64 строк — один вызов вместо двух,
;   текст словаря собирается в заранее выделенный буфер. Формат файлов прежний;
; - режим словаря (F9 → Настройки → «Словарь»): полный — как раньше; ручной — новые
;   слова только через RShift (у известных растёт рейтинг); выключен — словарь не
;   расшифровывается на старте, не подсказывает и не пишется на диск (файл не трогается);
;   фразы, промпты, ссылки, Данные, горячие вставки и автозамены работают как обычно;
; - смена пароля при выключенном словаре перешифровывает его файл как есть;
; - «Удалить ≤ рейтинг» показывает время чистки и сохранения; Настройки → «Справочно» —
;   время последнего старта по самым долгим этапам.
; ------------------------------------------------------------------------------
; ИЗМЕНЕНИЯ 13.17 (поиск по коду: «v13.17»):
; - F9: строится только видимая вкладка, остальные — при первом открытии (раньше до
;   показа окна заполнялись все 9 списков со всем словарём); большие списки заполняются
;   без перерисовки и без AHK-колбэка тёмной шапки на каждую строку;
; - F9 открывается на «Промптах» (настройка); ЛКМ по промпту — копия в буфер на вкладке
;   и в общем поиске (настройка); сортировка по заголовку больше не путает строки;
; - расшифровка баз: «крутилка», этап N/11 и полоса; F9 в окне пароля не закрывает Typer;
; - «Удалить ≤ рейтинг»: один проход и одна перестройка индексов под Critical (было O(k·n),
;   подвис и «кривой» OSD из полуразобранной базы);
; - «Исключённые» и общий поиск показывают записи целиком, без масок; превью длинных;
; - «\» снова фиксирует основу: хоткей по скан-коду (sc02B перекрывал vk-хоткей «\»);
; - Ctrl+\: края выделения сохраняются, замена одной вставкой, без Backspace перед
;   выделением; повтор снимает кавычки, Alt+Z возвращает как было; Ctrl+A и клики
;   с Shift/Ctrl сбрасывают хвост;
; - Delete/Insert в поле поиска панели — обычное редактирование; «Назначить хоткей»
;   для промпта берёт текст промпта (было — число из колонки «Исп.»).
; ------------------------------------------------------------------------------
; ИЗМЕНЕНИЯ 13.16 (поиск по коду: «v13.16»):
; - старт: соль сессии = соль lock → со второго запуска 1 прогон PBKDF2 вместо 3;
; - базы: не пишутся, пока не прочитаны с диска; пустая база больше не стирает .bak;
; - смена пароля: регистр учитывается, lock пишется последним, Critical, новая соль;
;   первый запуск — пароль дважды; потерянный lock восстанавливается по базам;
; - Enter/Tab: слово не запоминается, автозамена не срабатывает, хвост сбрасывается;
; - не-мгновенные автозамены стирают и завершающий символ (было «bbe right back»);
; - свои окна Typer (карточка Данных и др.) не обрабатываются как поле ввода;
; - «\» перехватывается только там, где работает Typer; Shift+\ родной (RU «/», EN «|»);
; - пароль в буфере не попадает в журнал Win+V и облачный буфер;
; - логины в OSD целиком, пароль — короткий намёк; в «Исключённых» пароли маской;
; - VS Code/терминалы: копирование через Ctrl+Insert, «копия строки» ≠ выделение;
; - стрелки вверх/вниз сбрасывают хвост; Alt+Z: эмодзи и скрытие промпта;
; - CapsLock при открытом OSD больше не перехватывается;
; - сортировка слиянием, WM_PASTE с таймаутом, общий поиск панели без лишней перерисовки.
; ------------------------------------------------------------------------------


; Приоритет High оставлен осознанно для отзывчивости ввода. Это не ускоритель, а подсказка планировщику Windows.
ProcessSetPriority("High")

if !A_IsAdmin {
    ; v13.16: перезапуск через сам интерпретатор (A_AhkPath) с ключом /restart:
    ; не зависит от того, чем открываются .ahk, и не зацикливает запрос UAC, если
    ; права так и не выдались. Отказ в UAC — по-прежнему тихий выход.
    if !RegExMatch(DllCall("GetCommandLine", "Str"), " /restart(?!\S)") {
        try {
            if A_IsCompiled
                Run('*RunAs "' A_ScriptFullPath '" /restart')
            else
                Run('*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"')
        }
        ExitApp
    }
}

AcquireTyperInstanceLock()

SetWinDelay(-1)
SetControlDelay(-1)
SendMode("Input")

; Полный дарк-мод процесса: разрешает системе применять DarkMode_*-темы
; (шапки ListView, скроллбары, контекстные меню) ко всем окнам Typer.
; ВАЖНО: никакого хука на Gui.Show — перехват каждого показа окна ронял скрипт
; каскадом ошибок. Окна затемняются явными вызовами ApplyDarkThemeToGui.
InitAppDarkMode()

; #EndRegion

; #Region ⚙️ КОНФИГУРАЦИЯ, ПУТИ И МАСКИРОВКА
DataDir        := A_ScriptDir "\svc_core"
DictFile       := DataDir "\cache.bin"
HotstringsFile := DataDir "\cfg.dat"
LockFile       := DataDir "\lock.sys"
MetaFile       := DataDir "\idx.bin"
SettingsFile   := DataDir "\opt.bin"
PhraseFile     := DataDir "\msg.bin"
PromptFile     := DataDir "\prm.bin"
DataFile       := DataDir "\sec.bin"
LinkFile       := DataDir "\lnk.bin"
HotInsertFile  := DataDir "\hotins.bin"

Global TyperInstanceMutexHandle := 0

Global MasterPassword := ""

Global LastActionType     := ""
Global LastAddedWord      := ""
Global LastAddedScore     := 0
Global LastHotstringAbbr  := ""
Global LastHotstringRepl  := ""
Global LastHotstringSpace := false
Global LastHiddenWord     := ""
Global LastDataClipboardStamp := 0
Global LastDataClipboardExpected := ""
Global LastDataClipboardBackup := 0
Global LastDataClipboardPasteSeenStamp := 0 ; защита: не планировать быстрый restore много раз на одно временное помещение пароля в буфер
Global DataClipboardSequence := 0
Global DataClipboardPastePollMs := 20 ; polling нужен, если F15 перехвачен другим AHK-скриптом и наш хоткей F15 не сработал
Global DataClipboardAutoClearMs := 30000 ; пароль из Данных восстанавливает прежний буфер после вставки или по таймеру, если пользователь не скопировал что-то другое
Global DataClipboardRestoreAfterPasteMs := 850 ; задержка после обычного Ctrl+V/Shift+Insert: даём приложению забрать временный пароль
Global DataClipboardRestoreAfterF15Ms := 1050 ; F15 часто сначала вызывает внешний скрипт, который уже шлёт Ctrl+V, поэтому ждём чуть дольше
Global LastHotstringCanUndo := false
Global LastHotstringTail := ""
Global LastInsertedText := ""
Global LastInsertedHadSpace := false
Global LastInsertedCanQuote := false
Global LastInsertedKind := "" ; WORD / STEM / QUOTED
Global LastQuoteHotkeyTick := 0
Global LastPhraseText := ""
Global LastPhraseSpace := false
Global LastPhraseCanUndo := false
Global LastPhraseTail := ""
Global LastPhraseKind := "" ; PHRASE / PROMPT / LINK / HOTKEY — для корректного текста Alt+Z
Global LastWordText := ""
Global LastWordSpace := false
Global LastWordCanUndo := false
Global LastWordTail := ""
Global LastWordKind := "" ; WORD / STEM / DATA
Global SuppressedSelectionChar := ""
Global SuppressedSelectionTick := 0
Global PhraseCaptureTargetHwnd := 0
Global PromptCaptureTargetHwnd := 0
Global DictPromptRowText := Map()
Global DictHiddenRowRefs := Map() ; v13.16: ref из скрытой колонки «Исключённых» → настоящий ключ записи
Global DictGlobalResultMap := Map()
Global DictGlobalFullTextMap := Map()
Global DictPanelPreviewGui := 0
Global DictPanelPreviewEdit := 0
Global DictPanelPreviewLastKey := ""
Global DictPanelPreviewFooter := 0      ; v13.19: строка «… ещё строк: N» плашки превью
Global DictPanelPreviewBorders := []    ; v13.19: рамка плашки (4 линии; v13.20 — нейтрально-серые)
Global DictPanelPreviewMono := -1       ; v13.19: текущий шрифт плашки (1 = Consolas)
Global DictViewUiSig := ""             ; v13.20: подпись раскладки панели (см. UpdateDictionaryViewUi)
Global DictTabStyleState := Map()       ; v13.20: hwnd кнопки раздела → её текущий стиль
Global DictGlobalDeleteBtnState := 0    ; v13.20: 1 — кнопка «Удалить» общего поиска активна
Global PanelPromptCatFilter := "ALL"    ; v13.21: фильтр вкладки «Промпты»: ALL или категория
Global PromptLastCaptureCat := "OTHER"  ; v13.21: категория по умолчанию для Shift+F14 / Alt+Insert
Global PromptParsePendingCat := ""      ; v13.21: категория из маркера «@cat|…» для следующей строки prm.bin
Global DictPromptCatChips := Map()      ; v13.21: фильтр-чипы «Промптов»: ALL/IMAGE/VIDEO/LLM/OTHER → контрол
Global DictPromptChipState := Map()     ; v13.21: hwnd чипа → «текст|цвет|фон» (перекраска только при смене)
Global DictPromptCatCounts := Map()     ; v13.21: счётчики чипов с учётом поиска
Global DictPromptToolButtons := []      ; v13.21: компактные кнопки вкладки «Промпты»
Global DictBtnClose := 0                ; v13.21: «Закрыть» (на «Промптах» скрыта — там Esc)
Global PromptCatPickerGui := 0          ; v13.21: всплывашка выбора категории после Shift+F14
Global PromptCatPickerState := 0
Global PromptCaptureCatRow := 0         ; v13.21: чипы категории в окне Alt+Insert
Global PromptCatRowsByHwnd := Map()     ; v13.21: hwnd диалога → его чипы категории (Ctrl+1…4)
Global PanelHandLvPrompts := 0          ; v13.19: hwnd списков с курсором-«пальцем»
Global PanelHandLvGlobal := 0
Global PanelRowFlashGui := 0            ; v13.19: вспышка строки после копирования
Global PanelRowFlashOwner := 0
Global PanelRowFlashStep := 0
Global OsdLabelCache := Map()           ; v13.19: последнее состояние контролов OSD
Global OsdWindowRect := ""              ; v13.19: последнее место/размер окна OSD
Global WordIndexVersion := 0            ; v13.19: растёт при каждом изменении индекса слов
Global WordMatchCachePrefix := ""       ; v13.19: сужающийся кэш кандидатов слов
Global WordMatchCacheKeys := []
Global WordMatchCacheVersion := -1
Global StoreSavedFingerprint := Map()   ; v13.19: отпечатки баз на момент записи/чтения
Global DictPanelColumnWidths := Map()
Global PermanentTyperWindowRules := Map()
Global DictDataRowIdMap := Map()
; v13.17: панель F9 строит списки лениво — только видимую вкладку.
Global DictActiveView := "HOME"
Global DictViewDirty := Map()        ; вкладка → true, если её список устарел
Global DictPromptRefText := Map()    ; ref из скрытой 3-й колонки «Промптов» → полный текст
Global DictGlobalRefs := Map()       ; ref из скрытой 4-й колонки общего поиска → {Item, Full}
Global PanelOpenPromptsByDefault := true ; F9 открывается на вкладке «Промпты»
Global PanelPromptClickCopy := true      ; ЛКМ по промпту — копия в буфер
Global DataPasswordsHidden := false      ; v13.22: пароли Данных без намёков (OSD, превью панели, карточка)
Global TyperStartupStep := 0             ; этап стартовой расшифровки (для индикатора)
Global TyperStartupSteps := 11
Global TyperStartupStage := ""
Global DictMode := "full"                ; v13.18: full — учит всё, manual — новые слова вручную, off — словарь не грузится
Global DictModeSelect := 0               ; v13.18: выпадающий список режима в Настройках
Global DictStartupTimingText := 0        ; v13.18: «Справочно» + время последнего старта
Global TyperStartupTimings := []         ; v13.18: [{Stage, Ms}] — длительность этапов старта
Global DarkHeaderDrawCb := 0             ; колбэк тёмной шапки ListView (см. AttachDarkHeader)
Global LastWordUndoRestoreText := ""     ; Alt+Z после Ctrl+\: что вернуть вместо вставки
Global LastWordUndoRestoreInput := ""
Global DictDecryptSpin := 0, DictDecryptNote := 0, DictDecryptBarFill := 0, DictDecryptBarRest := 0
Global DictLoadSpin := 0, DictLoadTitle := 0, DictLoadStage := 0, DictLoadBarFill := 0, DictLoadBarRest := 0, DictLoadHint := 0
Global DictShowFrequencyColumn := false
Global DictSearchIncludeWords := false
Global DictShowFrequencyCheck := 0
Global DictIncludeWordsCheck := 0
Global DictGlobalDeleteBtn := 0
Global DictWordAutoHideCheck := 0
Global DictWordAutoHideSecEdit := 0
Global DictPanelGui := 0
Global DictPanelTargetHwnd := 0 ; окно, откуда открыли F9, для вставки из панели по Enter
Global DictPanelTargetHasCaret := false ; true, если при открытии F9 обнаружена каретка; Enter вставляет только тогда, Ctrl+Enter — принудительно
Global DictPanelChildGuis := []
Global DictSearchDebounceMs := 220
Global DictPanelSortState := Map()
Global TyperSuspended := false ; Win+T: тотальная пауза Typer. Все режимы/хоткеи выключены, кроме повторного Win+T.
Global SnippetEditorGui := 0
Global SnippetEditorEdit := 0
Global SnippetEditorMode := ""
Global SnippetEditorIndex := 0
Global SnippetEditorTargetHwnd := 0
Global SnippetEditorSuppressChange := false
Global HotInsertCallbacks := Map()
Global RegisteredHotInsertCombos := Map()
Global RegisteredHotInsertAliasCombos := Map() ; дополнительные numpad-hotkeys для NumLock Off/On
Global DevAllowShortMasterPassword := false
Global MinMasterPasswordLen := 15 ; v13.22: и для первого запуска, и для смены пароля
; Флаг завершения автозагрузки: пока false, хоткеи занесения в базы (F14-семейство)
; не работают. Это защита от потери данных: раньше Shift+F14 во время загрузки
; добавлял промпт в ещё пустую PromptDB, падал на несозданном индексе, а последующее
; автосохранение перезаписывало базу почти пустым содержимым.
Global TyperStartupComplete := false
; Живые ссылки на окно/список менеджера автозамен для контекстного Enter.
Global HotstringMgrGui := 0
Global HotstringMgrLV := 0
; Момент последней прокрутки колесом в окнах скрипта: превью-вотчер панели
; пропускает тики во время скролла (см. WatchDictionaryPanelPreview).
Global PanelWheelLastTick := 0
OnMessage(0x020A, MarkPanelWheelActivity) ; WM_MOUSEWHEEL
MarkPanelWheelActivity(wParam, lParam, msg, hwnd) {
    global PanelWheelLastTick := A_TickCount
    ; ничего не возвращаем — сообщение обрабатывается как обычно
}
; Префиксные индексы создаём сразу, а не только в Rebuild*: любые ранние вызовы
; Learn*/AddTo*Indexes больше не падают на неинициализированной глобальной.
Global PrefixIndex1 := Map(), PrefixIndex2 := Map()
Global PhraseIndex1 := Map(), PhraseIndex2 := Map()
Global PromptIndex1 := Map(), PromptIndex2 := Map()
Global EnableLCtrlComma := true   ; LCtrl tap — запятая (опция в Настройках)
Global EnableRCtrlPeriod := true  ; RCtrl tap — точка-комбо (опция в Настройках)
Global PgKeysModeEnabled := false ; PgUp/PgDn как префиксы режимов 1/11 и 2/22 (тест)
; Молчаливая активация режимов PgUp/PgDn: цифры префикса живут только во внутреннем
; хвосте CurrentInput и НЕ печатаются в поле. PhantomInputLen — сколько первых символов
; CurrentInput являются такими "фантомными". При стирании набранного (Backspace-подсчёт
; перед вставкой фразы/промпта) фантомные символы вычитаются, иначе сотрутся лишние
; реальные символы в поле.
Global PhantomInputLen := 0
; Минимальная длина префикса для автовставки Данных (*pra): короткие *pr с кучей
; аккаунтов имеют иммунитет — по ним только список, без мгновенной вставки.
Global MinAutoInsertPrefixLen := 3
Global DictDataPileMode := "ALL"  ; фильтр вкладки Данные: ALL / NOPILE / PILE
Global DictDataPileSelect := 0

; --------------------------------------------------------------------------------
; ВАЖНО ПО АРХИТЕКТУРЕ СКРИПТА
; 1) CurrentInput хранит только внутреннее представление текущего непрерывного набора.
;    Это не "полный текст поля", а только тот хвост, который скрипт сейчас отслеживает.
; 2) Основа (stem) всегда вставляется БЕЗ пробела: идея в том, что пользователь вручную
;    дописывает окончание слова. Поэтому основа никогда не участвует в логике кавычек
;    как готовое слово.
; 3) Обычное слово может вставляться с пробелом или без пробела. Режим "без пробела"
;    хранится отдельно от основного словаря, чтобы не светить это явно в GUI/базе слов.
; 4) Alt+Z для автозамены работает по модели "последняя искусственная вставка + хвост
;    после неё". Это не полный стек редактирования поля, а безопасный частичный undo.
; --------------------------------------------------------------------------------

GroupAdd "TyperApps", "ahk_exe notepad++.exe"
GroupAdd "TyperApps", "ahk_exe Code.exe"
GroupAdd "TyperApps", "ahk_exe chrome.exe"
GroupAdd "TyperApps", "ahk_exe msedge.exe"
GroupAdd "TyperApps", "ahk_exe firefox.exe"
GroupAdd "TyperApps", "ahk_exe opera.exe"
GroupAdd "TyperApps", "ahk_exe brave.exe"
GroupAdd "TyperApps", "ahk_exe obsidian.exe"
GroupAdd "TyperApps", "ahk_exe AutoHotkey64.exe"
GroupAdd "TyperApps", "ahk_exe AutoHotkey32.exe"
GroupAdd "TyperApps", "ahk_exe AutoHotkey.exe"

MaxStems          := 5
MaxWords          := 5
MinTriggerLen     := 2
MinWordLen        := 6
MaxLearnedWordLen := 20 ; авто-словарь: длинные секреты/мусор не учим как слова, для длинного текста есть Фразы
MinUsageThreshold := 5
ManualWordScore   := 15 ; v13.19: рейтинг слова, добавленного вручную (RShift) — сразу выше авто-слов

ColorBackground := "1E1E1E"
ColorTextStems  := "569CD6"
ColorTextWords  := "D4D4D4"
; Акцентный цвет всего скрипта. По умолчанию зелёный; выбирается в Настройках
; (ключ accent_color в opt.bin). ColorHighlight остаётся именем-носителем,
; чтобы не трогать десятки мест использования.
ColorHighlight  := "5FD068"
FontSize        := 11
FontName        := "Consolas"

ShiftPressTime    := 0
CtrlPressTime     := 0
RCtrlPressTime    := 0
RShiftPressTime   := 0
TapThreshold      := 300
WordDB            := Map()
MyHotstrings      := Map()
NoSpaceWords      := Map()
PhraseDB          := Map()
PromptDB          := Map()
DataDB            := Map()
HotInsertDB       := Map()
LinkDB            := Map()
DataIndex1        := Map()
DataIndex2        := Map()
LinkIndex1        := Map()
LinkIndex2        := Map()
NextDataId        := 1
NextHotInsertId   := 1
NextLinkId        := 1
InsertCaptureEnabled := true
WordOsdAutoHideEnabled := true
WordOsdAutoHideMs := 4500
WordOsdLastActivityTick := 0
WordDigitLiteralMode := false
TypingIdleResetMs := 2500 ; если ввод давно не продолжался, следующий символ начинает новый внутренний хвост
LastTypingHwnd := 0
LastTypingCtrl := ""
LastTypingTick := 0
TemporaryTyperWindows := Map() ; Win+A временно разрешает Typer в конкретном активном окне до перезапуска скрипта
; PermanentTyperWindowRules уже объявлена выше в блоке Global —
; повторная инициализация здесь была дублем и удалена.
CurrentInput      := ""
CurrentRawInput   := "" ; сырой непрерывный хвост ввода для исключения логинов/паролей через AppsKey
SuggestionVisible := false
CurrentSuggestionMode := "WORDS"
PhraseCaptureMode := false
PhraseCaptureGuiObj := 0
PhraseCaptureEdit := 0
PromptCaptureMode := false
PromptCaptureGuiObj := 0
PromptCaptureEdit := 0

JustInsertedWord  := false
LastSpaceTime     := 0
CapitalizeMode    := 0
NextCharUpper     := false

CurrentStems      := []
CurrentWords      := []
SelectedStemIndex := 1
MaxPhrases        := 8
MaxPrompts        := 8 ; v13.19: было 5 (как у фраз — 8)
MaxDataItems      := 10
MaxLinks          := 8
MaxSuggestionRows := 10
OsdMarginX        := 20
OsdMarginY        := 20
OsdTransparency   := 232 ; 255 = непрозрачно; меньше = прозрачнее
LabelsStems       := []
LabelsWordPrefixes := []
LabelsWords       := []
CurrentDataItems  := []
SelectedPhraseIndex := 1
LastPhraseOsdInput := ""
PhrasePreviewHeight := 118 ; для фраз preview компактнее: больше места под список фрагментов
PromptPreviewHeight := 220 ; промптам оставляем большое поле полного текста
IsEditingHotstring := false
; #EndRegion

; #Region 🔐 ХРАНЕНИЕ ДАННЫХ (AES-256-GCM + PBKDF2 ЧЕРЕЗ CNG)
; Начиная с этой ветки файл хранения переведён на новый контейнерный формат.
; Скрипт работает с отдельной папкой данных, поэтому не зависит от старых файлов.
; Формат контейнера текстовый:
; 1) сигнатура
; 2) число итераций PBKDF2
; 3) salt (Base64)
; 4) nonce (Base64)
; 5) authentication tag (Base64)
; 6) ciphertext (Base64)
class Crypto {
    static Header := 'TSA2'
    static SaltSize := 16
    static NonceSize := 12
    static TagSize := 16
    static KeySize := 32
    static Iterations := 600000
    static MinIterations := 100000
    static MaxIterations := 5000000
    ; --- Кэш выведенных ключей -----------------------------------------------
    ; PBKDF2 (600К итераций) — намеренно медленная операция (~0.5–1 с на вызов).
    ; Раньше она выполнялась на КАЖДОЕ шифрование/расшифровку: 9 контейнеров
    ; на выходе × (запись + контрольная расшифровка) = 18 прогонов = долгие
    ; секунды при закрытии и старте. Ключ детерминирован парой (пароль, соль,
    ; итерации), поэтому кэшируем его в памяти процесса. Для шифрования соль
    ; генерируется один раз за сессию (SessionSalt) и переиспользуется всеми
    ; контейнерами — это безопасно: AES-GCM допускает один ключ для многих
    ; сообщений, пока nonce уникален (он по-прежнему случайный на каждую
    ; запись). Роль соли — защита от радужных таблиц — сохраняется полностью.
    static KeyCache := Map()
    static SessionSalt := ''

    static GetCachedKey(password, saltBuf, iterations) {
        cacheId := iterations '|' this.BinToBase64(saltBuf, saltBuf.Size) '|' password
        if this.KeyCache.Has(cacheId)
            return this.KeyCache[cacheId]
        keyBuf := this.DeriveKeyPBKDF2(password, saltBuf, this.KeySize, iterations)
        if keyBuf
            this.KeyCache[cacheId] := keyBuf
        return keyBuf
    }

    ; v13.16: соль сессии = соль уже открытого контейнера (lock). Ключ для неё
    ; выведен при проверке пароля, поэтому всё, что сохранит эта сессия, потом
    ; откроется тем же ключом из кэша. Раньше на старте было 3 прогона PBKDF2:
    ; lock, базы с солью прошлой сессии и новая случайная соль для self-test.
    static AdoptSessionSaltFromBlob(blob) {
        if (blob == '')
            return false
        if (SubStr(blob, 1, 1) = Chr(0xFEFF))
            blob := SubStr(blob, 2)
        lines := StrSplit(Trim(blob, '`r`n '), '`n', '`r')
        if (lines.Length < 6 || lines[1] != this.Header)
            return false
        try iterations := Integer(lines[2])
        catch
            return false
        if (iterations != this.Iterations)
            return false
        saltBuf := this.Base64ToBin(lines[3], &saltLen)
        if (saltLen != this.SaltSize || saltBuf.Size != this.SaltSize)
            return false
        this.SessionSalt := saltBuf
        return true
    }

    ; v13.16: после смены пароля выкидываем из кэша ключи старого пароля.
    static ForgetPassword(password) {
        if (password == '')
            return
        stale := []
        for cacheId in this.KeyCache {
            parts := StrSplit(cacheId, '|',, 3)
            if (parts.Length = 3 && parts[3] == password)
                stale.Push(cacheId)
        }
        for cacheId in stale
            this.KeyCache.Delete(cacheId)
    }

    static Encrypt(text, password) {
        this.LastError := ''
        if (text == '')
            return ''

        if (this.Iterations < this.MinIterations || this.Iterations > this.MaxIterations) {
            this.LastError := 'Configured PBKDF2 iterations out of range'
            return ''
        }

        plainBuf := this.Utf8ToBuffer(text)
        if (this.SessionSalt = '')
            this.SessionSalt := this.RandomBytes(this.SaltSize)
        saltBuf := this.SessionSalt
        nonceBuf := this.RandomBytes(this.NonceSize)
        if (!plainBuf || !saltBuf || !nonceBuf)
            return ''

        keyBuf := this.GetCachedKey(password, saltBuf, this.Iterations)
        if !keyBuf
            return ''

        encrypted := this.AesGcmEncrypt(plainBuf, keyBuf, nonceBuf, this.TagSize)
        if !IsObject(encrypted)
            return ''

        return this.Header '`n'
            . this.Iterations '`n'
            . this.BinToBase64(saltBuf, saltBuf.Size) '`n'
            . this.BinToBase64(nonceBuf, nonceBuf.Size) '`n'
            . this.BinToBase64(encrypted.Tag, encrypted.Tag.Size) '`n'
            . this.BinToBase64(encrypted.Cipher, encrypted.Cipher.Size)
    }

    static Decrypt(blob, password) {
        ; Симметрично Encrypt: сбрасываем LastError, чтобы диагностика не
        ; показывала ошибку от предыдущей операции.
        this.LastError := ''
        if (blob == '')
            return ''

        if (SubStr(blob, 1, 1) = Chr(0xFEFF))
            blob := SubStr(blob, 2)

        lines := StrSplit(Trim(blob, '`r`n '), '`n', '`r')
        if (lines.Length < 6)
            return ''
        if (lines[1] != this.Header)
            return ''

        try iterations := Integer(lines[2])
        catch
            return ''

        if (iterations < this.MinIterations || iterations > this.MaxIterations) {
            this.LastError := 'PBKDF2 iterations out of range'
            return ''
        }

        saltBuf := this.Base64ToBin(lines[3], &saltLen)
        nonceBuf := this.Base64ToBin(lines[4], &nonceLen)
        tagBuf := this.Base64ToBin(lines[5], &tagLen)
        cipherBuf := this.Base64ToBin(lines[6], &cipherLen)

        if (saltLen <= 0 || nonceLen <= 0 || tagLen <= 0 || cipherLen < 0)
            return ''

        keyBuf := this.GetCachedKey(password, saltBuf, iterations)
        if !keyBuf
            return ''

        plainBuf := this.AesGcmDecrypt(cipherBuf, keyBuf, nonceBuf, tagBuf)
        if !plainBuf
            return ''

        return StrGet(plainBuf, plainBuf.Size, 'UTF-8')
    }

    static Utf8ToBuffer(text) {
        byteLen := StrPut(text, 'UTF-8') - 1
        buf := Buffer(byteLen, 0)
        if (byteLen > 0)
            StrPut(text, buf, 'UTF-8')
        return buf
    }

    static RandomBytes(byteCount) {
        buf := Buffer(byteCount, 0)
        status := DllCall('bcrypt\BCryptGenRandom', 'Ptr', 0, 'Ptr', buf.Ptr, 'UInt', buf.Size, 'UInt', 0x00000002, 'Int')
        return (status = 0) ? buf : ''
    }

    static DeriveKeyPBKDF2(password, saltBuf, keySize, iterations) {
        hAlg := 0
        passBuf := this.Utf8ToBuffer(password)
        keyBuf := Buffer(keySize, 0)

        status := DllCall('bcrypt\BCryptOpenAlgorithmProvider', 'Ptr*', &hAlg, 'WStr', 'SHA256', 'Ptr', 0, 'UInt', 0x00000008, 'Int')
        if (status != 0) {
            this.LastError := 'BCryptOpenAlgorithmProvider(SHA256,HMAC)=' Format('0x{:08X}', status & 0xFFFFFFFF)
            return ''
        }

        try {
            status := DllCall('bcrypt\BCryptDeriveKeyPBKDF2'
                , 'Ptr', hAlg
                , 'Ptr', passBuf.Ptr
                , 'UInt', passBuf.Size
                , 'Ptr', saltBuf.Ptr
                , 'UInt', saltBuf.Size
                , 'Int64', iterations
                , 'Ptr', keyBuf.Ptr
                , 'UInt', keyBuf.Size
                , 'UInt', 0
                , 'Int')
            if (status != 0) {
                this.LastError := 'BCryptDeriveKeyPBKDF2=' Format('0x{:08X}', status & 0xFFFFFFFF)
                return ''
            }
            return keyBuf
        } finally {
            DllCall('bcrypt\BCryptCloseAlgorithmProvider', 'Ptr', hAlg, 'UInt', 0)
        }
    }

    static AesGcmEncrypt(plainBuf, keyBuf, nonceBuf, tagSize := 16) {
        hAlg := 0, hKey := 0
        keyObj := ''
        cipherBuf := ''
        tagBuf := Buffer(tagSize, 0)
        authInfo := ''
        resultSize := 0

        status := DllCall('bcrypt\BCryptOpenAlgorithmProvider', 'Ptr*', &hAlg, 'WStr', 'AES', 'Ptr', 0, 'UInt', 0, 'Int')
        if (status != 0) {
            this.LastError := 'BCryptOpenAlgorithmProvider(AES)=' Format('0x{:08X}', status & 0xFFFFFFFF)
            return ''
        }

        try {
            status := DllCall('bcrypt\BCryptSetProperty'
                , 'Ptr', hAlg
                , 'WStr', 'ChainingMode'
                , 'WStr', 'ChainingModeGCM'
                , 'UInt', (StrLen('ChainingModeGCM') + 1) * 2
                , 'UInt', 0
                , 'Int')
            if (status != 0) {
                this.LastError := 'BCryptSetProperty(GCM)=' Format('0x{:08X}', status & 0xFFFFFFFF)
                return ''
            }

            keyObjSize := this.GetUIntProperty(hAlg, 'ObjectLength')
            if (keyObjSize <= 0) {
                this.LastError := 'BCryptGetProperty(ObjectLength)=0'
                return ''
            }

            keyObj := Buffer(keyObjSize, 0)
            status := DllCall('bcrypt\BCryptGenerateSymmetricKey'
                , 'Ptr', hAlg
                , 'Ptr*', &hKey
                , 'Ptr', keyObj.Ptr
                , 'UInt', keyObj.Size
                , 'Ptr', keyBuf.Ptr
                , 'UInt', keyBuf.Size
                , 'UInt', 0
                , 'Int')
            if (status != 0) {
                this.LastError := 'BCryptGenerateSymmetricKey=' Format('0x{:08X}', status & 0xFFFFFFFF)
                return ''
            }

            cipherBuf := Buffer(plainBuf.Size, 0)
            authInfo := this.InitAuthModeInfo(nonceBuf, tagBuf)

            status := DllCall('bcrypt\BCryptEncrypt'
                , 'Ptr', hKey
                , 'Ptr', plainBuf.Ptr
                , 'UInt', plainBuf.Size
                , 'Ptr', authInfo.Ptr
                , 'Ptr', 0
                , 'UInt', 0
                , 'Ptr', cipherBuf.Ptr
                , 'UInt', cipherBuf.Size
                , 'UInt*', &resultSize
                , 'UInt', 0
                , 'Int')
            if (status != 0) {
                this.LastError := 'BCryptEncrypt=' Format('0x{:08X}', status & 0xFFFFFFFF)
                return ''
            }

            return {Cipher: cipherBuf, Tag: tagBuf}
        } finally {
            if hKey
                DllCall('bcrypt\BCryptDestroyKey', 'Ptr', hKey)
            if hAlg
                DllCall('bcrypt\BCryptCloseAlgorithmProvider', 'Ptr', hAlg, 'UInt', 0)
        }
    }

    static AesGcmDecrypt(cipherBuf, keyBuf, nonceBuf, tagBuf) {
        hAlg := 0, hKey := 0
        keyObj := ''
        plainBuf := ''
        authInfo := ''
        resultSize := 0

        status := DllCall('bcrypt\BCryptOpenAlgorithmProvider', 'Ptr*', &hAlg, 'WStr', 'AES', 'Ptr', 0, 'UInt', 0, 'Int')
        if (status != 0) {
            this.LastError := 'BCryptOpenAlgorithmProvider(AES)=' Format('0x{:08X}', status & 0xFFFFFFFF)
            return ''
        }

        try {
            status := DllCall('bcrypt\BCryptSetProperty'
                , 'Ptr', hAlg
                , 'WStr', 'ChainingMode'
                , 'WStr', 'ChainingModeGCM'
                , 'UInt', (StrLen('ChainingModeGCM') + 1) * 2
                , 'UInt', 0
                , 'Int')
            if (status != 0) {
                this.LastError := 'BCryptSetProperty(GCM)=' Format('0x{:08X}', status & 0xFFFFFFFF)
                return ''
            }

            keyObjSize := this.GetUIntProperty(hAlg, 'ObjectLength')
            if (keyObjSize <= 0) {
                this.LastError := 'BCryptGetProperty(ObjectLength)=0'
                return ''
            }

            keyObj := Buffer(keyObjSize, 0)
            status := DllCall('bcrypt\BCryptGenerateSymmetricKey'
                , 'Ptr', hAlg
                , 'Ptr*', &hKey
                , 'Ptr', keyObj.Ptr
                , 'UInt', keyObj.Size
                , 'Ptr', keyBuf.Ptr
                , 'UInt', keyBuf.Size
                , 'UInt', 0
                , 'Int')
            if (status != 0) {
                this.LastError := 'BCryptGenerateSymmetricKey=' Format('0x{:08X}', status & 0xFFFFFFFF)
                return ''
            }

            plainBuf := Buffer(cipherBuf.Size, 0)
            authInfo := this.InitAuthModeInfo(nonceBuf, tagBuf)

            status := DllCall('bcrypt\BCryptDecrypt'
                , 'Ptr', hKey
                , 'Ptr', cipherBuf.Ptr
                , 'UInt', cipherBuf.Size
                , 'Ptr', authInfo.Ptr
                , 'Ptr', 0
                , 'UInt', 0
                , 'Ptr', plainBuf.Ptr
                , 'UInt', plainBuf.Size
                , 'UInt*', &resultSize
                , 'UInt', 0
                , 'Int')
            if (status != 0) {
                this.LastError := 'BCryptDecrypt=' Format('0x{:08X}', status & 0xFFFFFFFF)
                return ''
            }

            if (resultSize != plainBuf.Size) {
                trimmed := Buffer(resultSize, 0)
                DllCall('RtlMoveMemory', 'Ptr', trimmed.Ptr, 'Ptr', plainBuf.Ptr, 'UPtr', resultSize)
                return trimmed
            }
            return plainBuf
        } finally {
            if hKey
                DllCall('bcrypt\BCryptDestroyKey', 'Ptr', hKey)
            if hAlg
                DllCall('bcrypt\BCryptCloseAlgorithmProvider', 'Ptr', hAlg, 'UInt', 0)
        }
    }

    static GetUIntProperty(hObject, propName) {
        outBuf := Buffer(4, 0)
        cbResult := 0
        status := DllCall('bcrypt\BCryptGetProperty'
            , 'Ptr', hObject
            , 'WStr', propName
            , 'Ptr', outBuf.Ptr
            , 'UInt', outBuf.Size
            , 'UInt*', &cbResult
            , 'UInt', 0
            , 'Int')
        if (status != 0 || cbResult < 4)
            return 0
        return NumGet(outBuf, 0, 'UInt')
    }

    static InitAuthModeInfo(nonceBuf, tagBuf) {
        if (A_PtrSize = 8) {
            info := Buffer(88, 0)
            NumPut('UInt', 88, info, 0)
            NumPut('UInt', 1, info, 4)
            NumPut('Ptr', nonceBuf.Ptr, info, 8)
            NumPut('UInt', nonceBuf.Size, info, 16)
            NumPut('Ptr', 0, info, 24)
            NumPut('UInt', 0, info, 32)
            NumPut('Ptr', tagBuf.Ptr, info, 40)
            NumPut('UInt', tagBuf.Size, info, 48)
            NumPut('Ptr', 0, info, 56)
            NumPut('UInt', 0, info, 64)
            NumPut('UInt', 0, info, 68)
            NumPut('Int64', 0, info, 72)
            NumPut('UInt', 0, info, 80)
        } else {
            ; v13.16: в 32-битной сборке ULONGLONG cbData выровнен по 8 байт:
            ; cbData на смещении 48, dwFlags на 56, размер структуры 64 (было 44/52/56).
            info := Buffer(64, 0)
            NumPut('UInt', 64, info, 0)
            NumPut('UInt', 1, info, 4)
            NumPut('Ptr', nonceBuf.Ptr, info, 8)
            NumPut('UInt', nonceBuf.Size, info, 12)
            NumPut('Ptr', 0, info, 16)
            NumPut('UInt', 0, info, 20)
            NumPut('Ptr', tagBuf.Ptr, info, 24)
            NumPut('UInt', tagBuf.Size, info, 28)
            NumPut('Ptr', 0, info, 32)
            NumPut('UInt', 0, info, 36)
            NumPut('UInt', 0, info, 40)
            NumPut('Int64', 0, info, 48)
            NumPut('UInt', 0, info, 56)
        }
        return info
    }

    static BinToBase64(buf, len) {
        size := 0
        DllCall('Crypt32\CryptBinaryToStringW', 'Ptr', buf.Ptr, 'UInt', len, 'UInt', 0x40000001, 'Ptr', 0, 'UInt*', &size)
        strBuf := Buffer(size * 2)
        DllCall('Crypt32\CryptBinaryToStringW', 'Ptr', buf.Ptr, 'UInt', len, 'UInt', 0x40000001, 'Ptr', strBuf.Ptr, 'UInt*', &size)
        return StrGet(strBuf, 'UTF-16')
    }

    static Base64ToBin(b64, &outLen) {
        outLen := 0
        DllCall('Crypt32\CryptStringToBinaryW', 'Str', b64, 'UInt', 0, 'UInt', 1, 'Ptr', 0, 'UInt*', &outLen, 'Ptr', 0, 'Ptr', 0)
        buf := Buffer(outLen, 0)
        DllCall('Crypt32\CryptStringToBinaryW', 'Str', b64, 'UInt', 0, 'UInt', 1, 'Ptr', buf.Ptr, 'UInt*', &outLen, 'Ptr', 0, 'Ptr', 0)
        return buf
    }

    ; v13.18: base64 для построчных баз (словарь, фразы, настройки): один вызов
    ; Crypt32 вместо двух — размер результата известен заранее, первый вызов
    ; «узнать размер» не нужен. При неудаче — прежний двухшаговый путь.
    ; Шифрование контейнеров по-прежнему идёт через BinToBase64/Base64ToBin.
    static Utf8ToBase64(text) {
        bin := this.Utf8ToBuffer(text)
        len := bin.Size
        if (len <= 0)
            return ''
        size := ((len + 2) // 3) * 4 + 8
        strBuf := Buffer(size * 2)
        if DllCall('Crypt32\CryptBinaryToStringW', 'Ptr', bin.Ptr, 'UInt', len, 'UInt', 0x40000001, 'Ptr', strBuf.Ptr, 'UInt*', &size)
            return StrGet(strBuf, size, 'UTF-16')
        return this.BinToBase64(bin, len)
    }

    static Base64ToUtf8(b64) {
        n := StrLen(b64)
        if (n = 0)
            return ''
        outLen := (n * 3) // 4 + 4
        bin := Buffer(outLen)
        if !DllCall('Crypt32\CryptStringToBinaryW', 'Str', b64, 'UInt', 0, 'UInt', 1, 'Ptr', bin.Ptr, 'UInt*', &outLen, 'Ptr', 0, 'Ptr', 0)
            bin := this.Base64ToBin(b64, &outLen)
        if (outLen <= 0)
            return ''
        return StrGet(bin, outLen, 'UTF-8')
    }
}

; #EndRegion

; #Region 🧱 БЕЗОПАСНАЯ ЗАПИСЬ ФАЙЛОВ
; v13.22: порядок записи
;   1) .tmp пишется и сбрасывается на диск (FlushFileBuffers);
;   2) .tmp перечитывается: байты совпадают с text, и (если задан verifyFn)
;      содержимое проверяется — для контейнеров это расшифровка;
;   3) только теперь основной → .bak и .tmp → основной (MoveFileExW с
;      WRITE_THROUGH; каждое переименование в пределах тома атомарно).
; Раньше .bak удалялся ДО записи, а проверка шла ПОСЛЕ ротации: неудачная
; запись оставляла плохой основной файл, а следующая — вытесняла хороший .bak.
; Сбой между шагами 3a и 3b: основного нет, .bak — прошлая версия; чтение
; (ReadTextFileWithBak / ReadDecryptedTextWithBak) берёт .bak.
WriteTextFileAtomic(targetFile, text, verifyFn := 0) {
    tmpFile := targetFile ".tmp"
    bakFile := targetFile ".bak"
    static MOVE_FLAGS := 0x1 | 0x8 ; MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH

    try {
        if FileExist(tmpFile)
            FileDelete(tmpFile)

        f := FileOpen(tmpFile, "w", "UTF-8-RAW")
        if !IsObject(f)
            throw Error("FileOpen tmp")
        try {
            f.Write(text)
            ; f.Handle сначала сбрасывает внутренний буфер File (док. v2, File.Handle).
            if !DllCall("Kernel32\FlushFileBuffers", "Ptr", f.Handle)
                throw OSError(A_LastError, "FlushFileBuffers")
        } finally {
            f.Close()
        }

        onDisk := FileRead(tmpFile, "UTF-8")
        if (onDisk !== text)
            throw Error("tmp readback mismatch")
        if (verifyFn && !verifyFn(onDisk))
            throw Error("tmp verify failed")
    } catch {
        try {
            if FileExist(tmpFile)
                FileDelete(tmpFile)
        }
        return false
    }

    ; Новая версия на диске и проверена — только теперь трогаем основной и .bak.
    movedToBak := false
    if FileExist(targetFile) {
        if !DllCall("Kernel32\MoveFileExW", "WStr", targetFile, "WStr", bakFile, "UInt", MOVE_FLAGS) {
            try FileDelete(tmpFile)
            return false
        }
        movedToBak := true
    }
    if !DllCall("Kernel32\MoveFileExW", "WStr", tmpFile, "WStr", targetFile, "UInt", MOVE_FLAGS) {
        ; Возвращаем прежнюю версию на место; .tmp остаётся до CleanupTransientFiles.
        if (movedToBak && !FileExist(targetFile))
            DllCall("Kernel32\MoveFileExW", "WStr", bakFile, "WStr", targetFile, "UInt", MOVE_FLAGS)
        return false
    }
    return true
}
; #EndRegion

; #Region 📖 ЧТЕНИЕ С РЕЗЕРВНОЙ КОПИИ
ReadTextFileWithBak(targetFile) {
    ; Основной файл пробуем первым, .bak вторым. Если основной файл оказался нулевым,
    ; не считаем это валидным контейнером и даём шанс .bak.
    for filePath in [targetFile, targetFile ".bak"] {
        if FileExist(filePath) {
            try {
                data := FileRead(filePath, "UTF-8")
                if (data != "")
                    return data
            }
        }
    }
    return ""
}

WriteEncryptedTextVerified(targetFile, plainText, password, label := "") {
    enc := Crypto.Encrypt(plainText, password)
    if (enc = "")
        return false
    ; v13.22: расшифровка проверяется на .tmp, до ротации основного и .bak.
    verify(onDisk) {
        try return (Crypto.Decrypt(onDisk, password) == plainText)
        return false
    }
    return WriteTextFileAtomic(targetFile, enc, verify)
}

CryptoSelfTest() {
    global DataDir, MasterPassword
    probeFile := DataDir "\probe.tmp"
    probeText := "probe|" A_NowUTC "|" A_TickCount
    ok := WriteEncryptedTextVerified(probeFile, probeText, MasterPassword, "startup-probe")
    try {
        if FileExist(probeFile)
            FileDelete(probeFile)
        if FileExist(probeFile ".bak")
            FileDelete(probeFile ".bak")
        if FileExist(probeFile ".tmp")
            FileDelete(probeFile ".tmp")
    }
    return ok
}

; ---- Универсальные хелперы для зашифрованных контейнеров --------------------
; LoadEncryptedContainer/SaveEncryptedContainer — единая точка для всех баз.
; Если на старте контейнер не расшифровался (файл есть, но Decrypt вернул ""),
; хранилище помечается как "corrupt", и любые попытки Save* для него блокируются
; до перезапуска. Это спасает от ситуации, когда временный сбой расшифровки
; затирает рабочую базу пустым содержимым на ближайшем автосохранении.

Global StoreCorrupt := Map()
; v13.16: какие базы уже прочитаны с диска в этой сессии (или файла нет вовсе).
; Пока база не прочитана, в памяти она пустая — её запись затёрла бы файл.
Global StoreLoaded := Map()
; v13.16: зашифрованный маркер пустой базы. Пустую базу больше не удаляем
; вместе с .bak, а пишем этот маркер обычной атомарной записью.
Global EmptyStoreMarker := "~TYPER_EMPTY~"

MarkStoreLoaded(label) {
    global StoreLoaded
    if (label != "")
        StoreLoaded[label] := true
}

IsStoreLoaded(label) {
    global StoreLoaded
    return StoreLoaded.Has(label)
}

; v13.18: база выгружена из памяти (словарь в режиме «выключен») — снова
; «не прочитана», и автосохранение не запишет пустую базу поверх файла.
MarkStoreUnloaded(label) {
    global StoreLoaded
    if StoreLoaded.Has(label)
        StoreLoaded.Delete(label)
}

MarkStoreCorrupt(label, reason := "") {
    global StoreCorrupt
    StoreCorrupt[label] := (reason != "") ? reason : "ошибка загрузки"
}

ClearStoreCorrupt(label) {
    global StoreCorrupt
    if (label != "" && StoreCorrupt.Has(label))
        StoreCorrupt.Delete(label)
}

IsStoreCorrupt(label) {
    global StoreCorrupt
    return StoreCorrupt.Has(label)
}

HasCorruptStores() {
    global StoreCorrupt
    return StoreCorrupt.Count > 0
}

WarnIfStoresCorrupt() {
    global StoreCorrupt
    if !StoreCorrupt.Count
        return false
    names := ""
    for label, reason in StoreCorrupt
        names .= "  • " label (reason != "" ? " — " reason : "") "`n"
    MsgBox(
        "Не удалось безопасно загрузить контейнер(ы):`n`n" names "`n"
        . "Файл(ы) могут быть повреждены, устарели по формату или не распарсились. Запись этих баз`n"
        . "временно отключена, чтобы не затереть рабочие данные пустыми.`n`n"
        . "Перезапусти скрипт после восстановления .bak вручную.",
        "Typer — проблема с базой", "Iconx")
    return true
}

ReadDecryptedTextWithBak(filePath, password, &usedPath := "") {
    usedPath := "" ; v13.19: какой файл реально прочитан (основной или .bak)
    for candidate in [filePath, filePath ".bak"] {
        if !FileExist(candidate)
            continue
        try enc := FileRead(candidate, "UTF-8")
        catch
            continue
        if (enc = "")
            continue
        try plain := Crypto.Decrypt(enc, password)
        catch
            continue
        if (plain != "") {
            usedPath := candidate
            return plain
        }
    }
    return ""
}

LoadEncryptedContainer(filePath, label, lineHandler) {
    ; lineHandler вызывается для каждой непустой строки расшифрованного содержимого.
    ; Сначала проверяется основной файл, затем .bak. Это важно, если основной
    ; файл существует, но содержит повреждённый непустой контейнер.
    global MasterPassword, EmptyStoreMarker
    if !FileExist(filePath) && !FileExist(filePath ".bak") {
        MarkStoreLoaded(label)
        return true
    }
    usedPath := ""
    plain := ReadDecryptedTextWithBak(filePath, MasterPassword, &usedPath)
    if (plain = "") {
        MarkStoreCorrupt(label, "не расшифровался / неверный пароль / повреждение")
        return false
    }
    try {
        Loop Parse, plain, "`n", "`r" {
            if (A_LoopField = "" || A_LoopField == EmptyStoreMarker)
                continue
            lineHandler(A_LoopField)
        }
    } catch as e {
        MarkStoreCorrupt(label, "ошибка парсинга: " e.Message)
        return false
    }
    ClearStoreCorrupt(label)
    MarkStoreLoaded(label)
    ; v13.19: прочитан основной файл — запоминаем отпечаток (см. SaveEncryptedContainer)
    if (usedPath = filePath)
        RememberStoreFingerprint(label, filePath, StoreTextFingerprint(plain))
    return true
}

SaveEncryptedContainer(filePath, output, label) {
    ; Защита от перезаписи: если на старте контейнер не расшифровался —
    ; не трогаем файл вообще. Пользователь увидит MsgBox и сможет вмешаться.
    global MasterPassword, EmptyStoreMarker
    if IsStoreCorrupt(label)
        return false
    ; v13.16: базу, которая ещё не прочитана с диска (идёт стартовая
    ; расшифровка), не пишем: в памяти она пустая и затёрла бы файл.
    ; Так можно было потерять sec.bin, нажав «Сохранить сейчас» в панели F9.
    if !IsStoreLoaded(label)
        return false
    if (output = "") {
        ; v13.16: раньше пустая база удалялась вместе с .bak. Теперь пишем
        ; зашифрованный маркер «пусто» — прошлая версия остаётся в .bak.
        if !FileExist(filePath) && !FileExist(filePath ".bak")
            return true
        output := EmptyStoreMarker
    }
    ; v13.19: то же содержимое и тот же файл на диске — не перешифровываем.
    fp := StoreTextFingerprint(output)
    if IsStoreUnchangedOnDisk(label, filePath, fp)
        return true
    ok := WriteEncryptedTextVerified(filePath, output, MasterPassword, label)
    RememberStoreFingerprint(label, filePath, ok ? fp : "")
    return ok
}

; ---- v13.19: пропуск записи неизменившихся баз ------------------------------
; Каждое сохранение (выход, автосохранение, «Сохранить сейчас», правка любой
; базы через SaveAllData) заново шифровало и переписывало ВСЕ контейнеры, даже
; если в них ничего не поменялось: AES-GCM + атомарная запись + .bak + чтение и
; расшифровка для проверки. Теперь для каждой базы помнится отпечаток текста
; (SHA-256) и размер/время файла на момент последней записи или чтения. Тот же
; текст и тот же файл на диске — запись пропускается. Файл изменился снаружи
; (или пропал) — пишем как раньше.
StoreTextFingerprint(text) {
    static hAlg := 0
    try {
        if !hAlg {
            h := 0
            if (DllCall("bcrypt\BCryptOpenAlgorithmProvider", "Ptr*", &h, "WStr", "SHA256", "Ptr", 0, "UInt", 0, "UInt") != 0)
                return ""
            hAlg := h
        }
        hash := Buffer(32, 0)
        if (DllCall("bcrypt\BCryptHash", "Ptr", hAlg, "Ptr", 0, "UInt", 0, "Ptr", StrPtr(text), "UInt", StrLen(text) * 2, "Ptr", hash, "UInt", 32, "UInt") != 0)
            return ""
        hex := ""
        Loop 32
            hex .= Format("{:02X}", NumGet(hash, A_Index - 1, "UChar"))
        return StrLen(text) ":" hex
    } catch {
        return "" ; нет BCryptHash (старая Windows) — просто пишем всегда, как раньше
    }
}

StoreFileStamp(filePath) {
    try {
        if FileExist(filePath)
            return FileGetSize(filePath) "|" FileGetTime(filePath, "M")
    }
    return ""
}

RememberStoreFingerprint(label, filePath, textFingerprint) {
    global StoreSavedFingerprint
    stamp := (textFingerprint != "") ? StoreFileStamp(filePath) : ""
    if (stamp != "")
        StoreSavedFingerprint[label] := textFingerprint "|" stamp
    else if StoreSavedFingerprint.Has(label)
        StoreSavedFingerprint.Delete(label)
}

IsStoreUnchangedOnDisk(label, filePath, textFingerprint) {
    global StoreSavedFingerprint
    if (textFingerprint = "" || !StoreSavedFingerprint.Has(label))
        return false
    stamp := StoreFileStamp(filePath)
    return (stamp != "" && StoreSavedFingerprint[label] == textFingerprint "|" stamp)
}

ForgetStoreFingerprints() {
    ; Смена пароля: все контейнеры обязаны быть перешифрованы.
    global StoreSavedFingerprint
    StoreSavedFingerprint := Map()
}

; ---- Универсальный префиксный индекс ---------------------------------------
; Каждая база хранит индекс из двух уровней: idx1 — первая буква ключа,
; idx2 — первые две буквы. По префиксу из 1+ символов даём кандидатов за O(1),
; дальше идёт точная фильтрация. Phrase/Prompt/Word ставят value = key (ключ
; сам является значением), Data/Link ставят value = id (одна запись = несколько
; токенов в индексе).

PrefixIndexAdd(idx1, idx2, key, value) {
    if (key = "")
        return
    p1 := SubStr(key, 1, 1)
    if !idx1.Has(p1)
        idx1[p1] := Map()
    idx1[p1][value] := true
    if (StrLen(key) >= 2) {
        p2 := SubStr(key, 1, 2)
        if !idx2.Has(p2)
            idx2[p2] := Map()
        idx2[p2][value] := true
    }
}

PrefixIndexRemove(idx1, idx2, key, value) {
    if (key = "")
        return
    p1 := SubStr(key, 1, 1)
    if idx1.Has(p1) && idx1[p1].Has(value) {
        idx1[p1].Delete(value)
        if (idx1[p1].Count = 0)
            idx1.Delete(p1)
    }
    if (StrLen(key) >= 2) {
        p2 := SubStr(key, 1, 2)
        if idx2.Has(p2) && idx2[p2].Has(value) {
            idx2[p2].Delete(value)
            if (idx2[p2].Count = 0)
                idx2.Delete(p2)
        }
    }
}

PrefixIndexCandidates(idx1, idx2, prefix) {
    if (StrLen(prefix) >= 2) {
        p2 := SubStr(prefix, 1, 2)
        if idx2.Has(p2)
            return idx2[p2]
    }
    p1 := SubStr(prefix, 1, 1)
    if idx1.Has(p1)
        return idx1[p1]
    return Map()
}

PrefixIndexRemoveAllForValue(idx1, idx2, value) {
    ; Удаляем value из всех buckets, но сами ключи индекса удаляем после обхода,
    ; чтобы не менять Map верхнего уровня прямо во время enumeration.
    empty1 := []
    for prefix, bucket in idx1 {
        if bucket.Has(value)
            bucket.Delete(value)
        if (bucket.Count = 0)
            empty1.Push(prefix)
    }
    for _, prefix in empty1
        idx1.Delete(prefix)

    empty2 := []
    for prefix, bucket in idx2 {
        if bucket.Has(value)
            bucket.Delete(value)
        if (bucket.Count = 0)
            empty2.Push(prefix)
    }
    for _, prefix in empty2
        idx2.Delete(prefix)
}

; ---- Общая сортировка списков ----------------------------------------------
; Одна сортировка с компаратором вместо шести копий одинаковой сортировки по коду.
; Компаратор возвращает true, если left должен стоять ПОСЛЕ right (нужен обмен).
; v13.16: стабильная сортировка слиянием O(n log n) вместо пузырька O(n²):
; на «11»/«22» сортируются все фразы/промпты, при сотнях записей пузырёк тормозил.
; Равные элементы сохраняют исходный порядок — как и раньше.
SortRowsInPlace(rows, comparator) {
    n := rows.Length
    if (n <= 1)
        return rows
    src := rows.Clone()
    dst := rows.Clone()
    width := 1
    while (width < n) {
        lo := 1
        while (lo <= n) {
            mid := Min(lo + width, n + 1)
            hi := Min(lo + 2 * width, n + 1)
            a := lo, b := mid, k := lo
            while (a < mid && b < hi) {
                if comparator(src[a], src[b]) {
                    dst[k] := src[b]
                    b += 1
                } else {
                    dst[k] := src[a]
                    a += 1
                }
                k += 1
            }
            while (a < mid) {
                dst[k] := src[a]
                a += 1, k += 1
            }
            while (b < hi) {
                dst[k] := src[b]
                b += 1, k += 1
            }
            lo += 2 * width
        }
        tmp := src, src := dst, dst := tmp
        width *= 2
    }
    Loop n
        rows[A_Index] := src[A_Index]
    return rows
}

; Сниппеты: по частоте (убыв.), затем по тексту.
SnippetCountDescComparator(left, right) {
    if (left.Count != right.Count)
        return left.Count < right.Count
    return StrCompare(left.Text, right.Text) > 0
}

; Топ сниппетов для голого режима "11"/"22": только по частоте (как было).
TopSnippetCountDescComparator(left, right) {
    return left.Count < right.Count
}

; Поиск по вхождению: ранг совпадения, позиция, частота, текст.
SnippetContainsComparator(left, right) {
    if (left.Rank != right.Rank)
        return left.Rank > right.Rank
    if (left.Pos != right.Pos)
        return left.Pos > right.Pos
    if (left.Count != right.Count)
        return left.Count < right.Count
    return StrCompare(left.Text, right.Text) > 0
}

; Ссылки: позиция совпадения, затем частота, затем текст.
LinkRowComparator(left, right) {
    if (left.Pos != right.Pos)
        return left.Pos > right.Pos
    if (left.Count != right.Count)
        return left.Count < right.Count
    return StrCompare(left.Text, right.Text) > 0
}

; Карточки данных: частота (убыв.), затем ключ/логин по алфавиту.
DataRowComparator(left, right) {
    if (left.Count != right.Count)
        return left.Count < right.Count
    leftTitle := StrLower(left.Key != "" ? left.Key : left.Login)
    rightTitle := StrLower(right.Key != "" ? right.Key : right.Login)
    return StrCompare(leftTitle, rightTitle) > 0
}

; Вкладка Данные: по названию по алфавиту.
DataTitleAscComparator(left, right) {
    return StrCompare(StrLower(left.Title), StrLower(right.Title)) > 0
}
; -----------------------------------------------------------------------------
; #EndRegion

; #Region 🗂️ СЛУЖЕБНАЯ МЕТАИНФОРМАЦИЯ
LoadMetaInternal() {
    global NoSpaceWords, MetaFile
    NoSpaceWords := Map()
    LoadEncryptedContainer(MetaFile, "meta", AddMetaLine)
}

AddMetaLine(line) {
    global NoSpaceWords
    NoSpaceWords[StrLower(line)] := true
}

SaveMetaInternal() {
    global NoSpaceWords, MetaFile
    Output := ""
    for key, _ in NoSpaceWords
        Output .= key "`n"
    return SaveEncryptedContainer(MetaFile, Output, "meta")
}

SetNoSpaceWord(word, enabled := true) {
    global NoSpaceWords
    key := StrLower(word)
    if enabled
        NoSpaceWords[key] := true
    else if NoSpaceWords.Has(key)
        NoSpaceWords.Delete(key)
}

HasNoSpaceWord(word) {
    global NoSpaceWords
    return NoSpaceWords.Has(StrLower(word))
}
; #EndRegion


; #Region ⚙️ СЛУЖЕБНЫЕ ПАРАМЕТРЫ
LoadSettingsInternal() {
    global SettingsFile, InsertCaptureEnabled, WordOsdAutoHideEnabled, WordOsdAutoHideMs, DictShowFrequencyColumn, DictSearchIncludeWords, DictPanelColumnWidths, PermanentTyperWindowRules
    global EnableLCtrlComma, EnableRCtrlPeriod, PgKeysModeEnabled, PanelOpenPromptsByDefault, PanelPromptClickCopy, DictMode, PanelPromptCatFilter, PromptLastCaptureCat ; v13.21
    global DataPasswordsHidden ; v13.22
    DictShowFrequencyColumn := false
    DictSearchIncludeWords := false
    DictPanelColumnWidths := Map()
    PermanentTyperWindowRules := Map()
    WordOsdAutoHideEnabled := true
    WordOsdAutoHideMs := 4500
    EnableLCtrlComma := true
    EnableRCtrlPeriod := true
    PgKeysModeEnabled := false
    PanelOpenPromptsByDefault := true ; v13.17
    PanelPromptClickCopy := true      ; v13.17
    DataPasswordsHidden := false      ; v13.22
    DictMode := "full"                ; v13.18
    PanelPromptCatFilter := "ALL"     ; v13.21
    PromptLastCaptureCat := "OTHER"   ; v13.21
    LoadEncryptedContainer(SettingsFile, "settings", ParseSettingsLine)
}

ParseSettingsLine(line) {
    global InsertCaptureEnabled, WordOsdAutoHideEnabled, WordOsdAutoHideMs, DictShowFrequencyColumn, DictSearchIncludeWords, DictPanelColumnWidths, PermanentTyperWindowRules
    global EnableLCtrlComma, EnableRCtrlPeriod, PgKeysModeEnabled, PanelOpenPromptsByDefault, PanelPromptClickCopy, DictMode, PanelPromptCatFilter, PromptLastCaptureCat ; v13.21
    global DataPasswordsHidden ; v13.22
    parts := StrSplit(line, "=",, 2)
    if (parts.Length != 2)
        return
    key := parts[1], val := parts[2]
    if (key = "insert_capture")
        InsertCaptureEnabled := (val != "0")
    else if (key = "word_osd_autohide")
        WordOsdAutoHideEnabled := (val != "0")
    else if (key = "word_osd_autohide_ms") {
        try WordOsdAutoHideMs := Max(1000, Min(30000, Integer(val)))
    }
    else if (key = "panel_show_frequency")
        DictShowFrequencyColumn := (val = "1")
    else if (key = "panel_search_words")
        DictSearchIncludeWords := (val = "1")
    else if (key = "lctrl_comma")
        EnableLCtrlComma := (val != "0")
    else if (key = "rctrl_period")
        EnableRCtrlPeriod := (val != "0")
    else if (key = "pgkeys_mode")
        PgKeysModeEnabled := (val = "1")
    else if (key = "panel_open_prompts") ; v13.17
        PanelOpenPromptsByDefault := (val != "0")
    else if (key = "panel_prompt_click_copy") ; v13.17
        PanelPromptClickCopy := (val != "0")
    else if (key = "dict_mode") ; v13.18
        DictMode := NormalizeDictMode(val)
    else if (key = "data_passwords_hidden") ; v13.22
        DataPasswordsHidden := (val = "1")
    else if (key = "panel_prompt_cat") ; v13.21
        PanelPromptCatFilter := (val = "ALL") ? "ALL" : NormalizePromptCat(val)
    else if (key = "prompt_last_cat") ; v13.21
        PromptLastCaptureCat := NormalizePromptCat(val)
    else if (key = "accent_color") {
        global ColorHighlight
        if RegExMatch(val, "^[0-9A-Fa-f]{6}$")
            ColorHighlight := val
    }
    else if (key = "wina_rule") {
        ruleText := DecodePhraseText(val)
        partsRule := StrSplit(ruleText, "|",, 3)
        if (partsRule.Length >= 2) {
            ruleKey := StrLower(partsRule[1] "|" partsRule[2])
            PermanentTyperWindowRules[ruleKey] := {Exe: partsRule[1], Class: partsRule[2], Label: (partsRule.Length >= 3 ? partsRule[3] : partsRule[1] " / " partsRule[2])}
        }
    }
    else if RegExMatch(key, "^lv_(.+)_([0-9]+)$", &m) {
        try DictPanelColumnWidths[m[1] "_" m[2]] := Integer(val)
    }
}

BuildSettingsPlainText() {
    global InsertCaptureEnabled, WordOsdAutoHideEnabled, WordOsdAutoHideMs, DictShowFrequencyColumn, DictSearchIncludeWords, DictPanelColumnWidths, PermanentTyperWindowRules
    global EnableLCtrlComma, EnableRCtrlPeriod, PgKeysModeEnabled, ColorHighlight, PanelOpenPromptsByDefault, PanelPromptClickCopy, DictMode, PanelPromptCatFilter, PromptLastCaptureCat ; v13.21
    global DataPasswordsHidden ; v13.22
    output := "insert_capture=" (InsertCaptureEnabled ? "1" : "0") "`n"
        . "word_osd_autohide=" (WordOsdAutoHideEnabled ? "1" : "0") "`n"
        . "word_osd_autohide_ms=" WordOsdAutoHideMs "`n"
        . "panel_show_frequency=" (DictShowFrequencyColumn ? "1" : "0") "`n"
        . "panel_search_words=" (DictSearchIncludeWords ? "1" : "0") "`n"
        . "lctrl_comma=" (EnableLCtrlComma ? "1" : "0") "`n"
        . "rctrl_period=" (EnableRCtrlPeriod ? "1" : "0") "`n"
        . "pgkeys_mode=" (PgKeysModeEnabled ? "1" : "0") "`n"
        . "panel_open_prompts=" (PanelOpenPromptsByDefault ? "1" : "0") "`n"
        . "panel_prompt_click_copy=" (PanelPromptClickCopy ? "1" : "0") "`n"
        . "dict_mode=" DictMode "`n"
        . "data_passwords_hidden=" (DataPasswordsHidden ? "1" : "0") "`n"
        . "panel_prompt_cat=" PanelPromptCatFilter "`n"
        . "prompt_last_cat=" PromptLastCaptureCat "`n"
        . "accent_color=" ColorHighlight "`n"
    for key, rule in PermanentTyperWindowRules {
        if (rule.Exe != "" || rule.Class != "")
            output .= "wina_rule=" EncodePhraseText(rule.Exe "|" rule.Class "|" rule.Label) "`n"
    }
    for key, val in DictPanelColumnWidths {
        if (val != "")
            output .= "lv_" key "=" val "`n"
    }
    return output
}

SaveSettingsInternal() {
    global SettingsFile
    return SaveEncryptedContainer(SettingsFile, BuildSettingsPlainText(), "settings")
}

CleanupTransientFiles() {
    global DictFile, HotstringsFile, MetaFile, SettingsFile, PhraseFile, PromptFile, DataFile, LinkFile, HotInsertFile, LockFile, DataDir
    for filePath in [DictFile, HotstringsFile, MetaFile, SettingsFile, PhraseFile, PromptFile, DataFile, LinkFile, HotInsertFile, LockFile] {
        try {
            if FileExist(filePath ".tmp")
                FileDelete(filePath ".tmp")
            if FileExist(filePath ".rekey")
                FileDelete(filePath ".rekey")
        }
    }
    try {
        if FileExist(DataDir "\probe.tmp")
            FileDelete(DataDir "\probe.tmp")
        if FileExist(DataDir "\probe.tmp.bak")
            FileDelete(DataDir "\probe.tmp.bak")
    }
}
; #EndRegion

; #Region 💬 БАЗА ФРАЗ
SanitizePhraseText(text) {
    text := StrReplace(text, "`r", " ")
    text := StrReplace(text, "`n", " ")
    text := RegExReplace(text, "\s+", " ")
    return Trim(text)
}

EncodePhraseText(text) {
    ; v13.18: один вызов Crypt32 вместо двух (см. Crypto.Utf8ToBase64).
    if (text = "")
        return ""
    return Crypto.Utf8ToBase64(text)
}

DecodePhraseText(b64) {
    if (b64 = "")
        return ""
    return Crypto.Base64ToUtf8(b64)
}

LoadPhrasesInternal() {
    global PhraseDB, PhraseFile
    PhraseDB := Map()
    LoadEncryptedContainer(PhraseFile, "phrases", ParsePhraseLine)
}

ParsePhraseLine(line) {
    global PhraseDB
    parts := StrSplit(line, "|",, 3)
    if (parts.Length < 3)
        return
    count := Integer(parts[1])
    hidden := Integer(parts[2])
    phraseText := SanitizePhraseText(DecodePhraseText(parts[3]))
    if (phraseText = "")
        return
    PhraseDB[StrLower(phraseText)] := {Text: phraseText, Count: count, Hidden: hidden}
}

SavePhrasesInternal() {
    global PhraseDB, PhraseFile
    return SaveEncryptedContainer(PhraseFile, LoadPhrasesPlainText(), "phrases")
}

LoadPhrasesPlainText() {
    global PhraseDB
    out := ""
    for key, data in PhraseDB
        out .= data.Count "|" (data.HasOwnProp("Hidden") ? data.Hidden : 0) "|" EncodePhraseText(data.Text) "`n"
    return out
}

RebuildPhraseIndexes() {
    global PhraseDB, PhraseIndex1, PhraseIndex2
    PhraseIndex1 := Map()
    PhraseIndex2 := Map()
    for key, _ in PhraseDB
        AddPhraseToIndexes(key)
}

AddPhraseToIndexes(key) {
    global PhraseIndex1, PhraseIndex2
    PrefixIndexAdd(PhraseIndex1, PhraseIndex2, key, key)
}

RemovePhraseFromIndexes(key) {
    global PhraseIndex1, PhraseIndex2
    PrefixIndexRemove(PhraseIndex1, PhraseIndex2, key, key)
}

GetPhraseIndexedCandidates(prefix) {
    global PhraseIndex1, PhraseIndex2
    if (prefix = "")
        return Map()
    return PrefixIndexCandidates(PhraseIndex1, PhraseIndex2, prefix)
}

LearnPhrase(phraseText, scoreToAdd := 1) {
    global PhraseDB
    phraseText := SanitizePhraseText(phraseText)
    if (phraseText = "")
        return false

    key := StrLower(phraseText)
    if PhraseDB.Has(key) {
        PhraseDB[key].Count += scoreToAdd
        if !PhraseDB[key].HasOwnProp("Hidden")
            PhraseDB[key].Hidden := 0
    } else {
        PhraseDB[key] := {Text: phraseText, Count: Max(1, scoreToAdd), Hidden: 0}
        AddPhraseToIndexes(key)
    }
    return true
}

TruncatePhraseForOSD(text, maxLen := 58) {
    text := RegExReplace(text, "\s+", " ")
    if (StrLen(text) <= maxLen)
        return text
    return SubStr(text, 1, maxLen - 1) . "…"
}

TogglePhraseCapture() {
    global PhraseCaptureMode
    ; Insert работает как переключатель только для сохранения в базу.
    ; Вставка обратно в исходное окно привязана только к Enter.
    if PhraseCaptureMode
        SaveCapturedPhrase(false)
    else
        StartPhraseCapture()
}

StartPhraseCapture() {
    global PhraseCaptureMode, PhraseCaptureGuiObj, PhraseCaptureEdit, PhraseCaptureTargetHwnd, ColorHighlight
    ResetInput()
    HideSuggestions()

    if (PhraseCaptureMode && IsObject(PhraseCaptureGuiObj)) {
        try PhraseCaptureEdit.Focus()
        return
    }

    PhraseCaptureTargetHwnd := WinGetID("A")

    PhraseCaptureGuiObj := Gui("+AlwaysOnTop +ToolWindow -MinimizeBox", "Режим фразы")
    ApplyDarkWindowFrame(PhraseCaptureGuiObj)
    PhraseCaptureGuiObj.BackColor := "171717"
    PhraseCaptureGuiObj.SetFont("s10 cF0F0F0", "Segoe UI")
    PhraseCaptureGuiObj.MarginX := 12
    PhraseCaptureGuiObj.MarginY := 10
    PhraseCaptureGuiObj.OnEvent("Close", (*) => CancelPhraseCapture())
    PhraseCaptureGuiObj.OnEvent("Escape", (*) => CancelPhraseCapture())

    PhraseCaptureGuiObj.Add("Text", "w470 h22 c" ColorHighlight, "● Запись фразы")
    PhraseCaptureGuiObj.Add("Text", "w470 h18 cB8B8B8 y+2", "Insert — сохранить    Enter — сохранить и вставить    Esc — отменить")
    PhraseCaptureEdit := PhraseCaptureGuiObj.Add("Edit", "w470 h84 y+10 Background2D2D2D cF0F0F0")
    PhraseCaptureGuiObj.Show("AutoSize Center")
    try PhraseCaptureEdit.Focus()
    PhraseCaptureMode := true
}

SaveCapturedPhrase(insertAfterSave := true) {
    global PhraseCaptureMode, PhraseCaptureEdit
    if !PhraseCaptureMode
        return

    rawText := ""
    try rawText := PhraseCaptureEdit.Value
    phraseText := SanitizePhraseText(rawText)

    if (phraseText = "") {
        CancelPhraseCapture()
        return
    }

    savedOk := LearnPhrase(phraseText, 1)
    if savedOk
        SavePhrasesInternal()

    ClosePhraseCaptureGui()

    if savedOk {
        ToolTip("Фраза сохранена")
        SetTimer(() => ToolTip(), -900)
        if insertAfterSave
            InsertSavedPhraseToCapturedTarget(phraseText)
    }
}

InsertSavedPhraseToCapturedTarget(phraseText) {
    global PhraseCaptureTargetHwnd
    hwnd := PhraseCaptureTargetHwnd
    PhraseCaptureTargetHwnd := 0
    InsertSavedSnippetToTarget(hwnd, phraseText, "PHRASE")
}

InsertSavedSnippetToTarget(hwnd, snippetText, snippetKind) {
    ; Общая вставка сохранённой фразы/промпта в исходное окно
    ; (раньше код был продублирован для фраз и промптов).
    global JustInsertedWord, LastSpaceTime
    if !hwnd
        return
    try {
        if !WinExist("ahk_id " hwnd)
            return
        WinActivate("ahk_id " hwnd)
        WinWaitActive("ahk_id " hwnd, , 0.7)
        SendLevel 1
        SafeSendPhrase(snippetText . " ")
        RememberInsertedText(snippetText, true, snippetKind)
        StartPhraseUndo(snippetText, true, snippetKind)
        JustInsertedWord := true
        LastSpaceTime := A_TickCount
    }
}

CancelPhraseCapture() {
    global PhraseCaptureMode, PhraseCaptureTargetHwnd
    if !PhraseCaptureMode
        return
    PhraseCaptureTargetHwnd := 0
    ClosePhraseCaptureGui()
}

ClosePhraseCaptureGui() {
    global PhraseCaptureMode, PhraseCaptureGuiObj, PhraseCaptureEdit
    PhraseCaptureMode := false
    try {
        if IsObject(PhraseCaptureGuiObj)
            PhraseCaptureGuiObj.Destroy()
    }
    PhraseCaptureGuiObj := 0
    PhraseCaptureEdit := 0
}

AddSelectedTextAsPhraseGlobal() {
    selectedText := GetSelectedTextViaClipboard(0.7)
    if (Trim(selectedText) = "") {
        ToolTip("⚠️ Ничего не выделено")
        SetTimer(() => ToolTip(), -1200)
        return
    }

    text := SanitizePhraseText(selectedText)
    if (text = "") {
        ToolTip("⚠️ Пустое выделение")
        SetTimer(() => ToolTip(), -1200)
        return
    }

    if LearnPhrase(text, 1) {
        SavePhrasesInternal()
        ToolTip("💬 Фраза добавлена")
        SetTimer(() => ToolTip(), -1000)
    }
}
; #EndRegion

; #Region 🧾 БАЗА ПРОМПТОВ
SanitizePromptText(text) {
    text := StrReplace(text, "`r`n", "`n")
    text := StrReplace(text, "`r", "`n")
    return Trim(text, " `t`n")
}

; v13.21: категории промптов — Image / Video / LLM / Other. В prm.bin категория
; пишется строкой-маркером «@cat|IMAGE» ПЕРЕД строкой своего промпта (см.
; ParsePromptLine / LoadPromptsPlainText); у Other маркера нет. Старые версии
; такие строки пропускают (в них меньше трёх частей), так что файл совместим в
; обе стороны — только после сохранения старой версией категории сбросятся в Other.
GetPromptCatOrder() {
    static order := ["IMAGE", "VIDEO", "LLM", "OTHER"]
    return order
}

NormalizePromptCat(cat) {
    cat := StrUpper(Trim(cat ""))
    return (cat = "IMAGE" || cat = "VIDEO" || cat = "LLM") ? cat : "OTHER"
}

GetPromptCat(data) {
    try {
        if (IsObject(data) && data.HasOwnProp("Cat"))
            return NormalizePromptCat(data.Cat)
    }
    return "OTHER"
}

GetPromptCatName(cat) {
    switch NormalizePromptCat(cat) {
        case "IMAGE": return "Image"
        case "VIDEO": return "Video"
        case "LLM": return "LLM"
    }
    return "Other"
}

GetPromptCatRank(cat) {
    switch NormalizePromptCat(cat) {
        case "IMAGE": return 1
        case "VIDEO": return 2
        case "LLM": return 3
    }
    return 4
}

GetPromptCatByIndex(index) {
    order := GetPromptCatOrder()
    return (index >= 1 && index <= order.Length) ? order[index] : "OTHER"
}

SetPromptCategory(key, cat) {
    ; v13.21: true — категория действительно сменилась (сохранение отложенное).
    global PromptDB
    if !PromptDB.Has(key)
        return false
    cat := NormalizePromptCat(cat)
    if (GetPromptCat(PromptDB[key]) = cat)
        return false
    PromptDB[key].Cat := cat
    QueuePromptSave()
    return true
}

QueuePromptSave(delayMs := 600) {
    ; v13.21: правки промптов из панели (категория, удаление) — одно сохранение
    ; на серию; раньше удаление из панели попадало на диск только при выходе.
    SetTimer(SavePromptsInternal, 0)
    SetTimer(SavePromptsInternal, -Abs(delayMs))
}

RememberPromptCaptureCat(cat) {
    ; v13.21: последняя выбранная категория — по умолчанию для Shift+F14 / Alt+Insert.
    global PromptLastCaptureCat
    cat := NormalizePromptCat(cat)
    if (PromptLastCaptureCat = cat)
        return
    PromptLastCaptureCat := cat
    SetTimer(SaveSettingsInternal, -1500)
}

RefreshPanelAfterPromptChange() {
    ; v13.21: промпт добавлен/перенесён вне панели — открытая панель перестраивает
    ; видимую вкладку (остальные — лениво, при открытии).
    try PopulateDictListView()
}

; --- Ряд чипов категории (окна Alt+Insert и правки промпта) -------------------
CreatePromptCatChipRow(guiObj, firstPos, selectedCat, chipW := 92, chipH := 26) {
    chipRow := {Cat: NormalizePromptCat(selectedCat), Chips: Map()}
    for i, cat in GetPromptCatOrder() {
        pos := (i = 1) ? firstPos : "x+6 yp"
        chipRow.Chips[cat] := CreateFlatTextButton(guiObj, pos " w" chipW " h" chipH, GetPromptCatName(cat), PromptCatChipRowClicked.Bind(chipRow, cat))
    }
    PaintPromptCatChipRow(chipRow)
    return chipRow
}

PromptCatChipRowClicked(chipRow, cat, *) {
    SetPromptCatChipRow(chipRow, cat)
}

SetPromptCatChipRow(chipRow, cat) {
    chipRow.Cat := NormalizePromptCat(cat)
    PaintPromptCatChipRow(chipRow)
}

PaintPromptCatChipRow(chipRow) {
    ; Выбранный чип — как активный раздел панели: акцентный текст на тёмном фоне.
    global ColorHighlight
    for cat, ctrl in chipRow.Chips {
        isOn := (cat = chipRow.Cat)
        try {
            ctrl.Opt("c" (isOn ? ColorHighlight : "F0F0F0") " Background" (isOn ? "1A1A1A" : "2B2B2B"))
            ctrl.Redraw()
        }
    }
}

RegisterPromptCatRow(guiObj, chipRow) {
    ; v13.21: hwnd диалога → его ряд чипов: Ctrl+1…4 переключают категорию в
    ; активном окне (см. IsPromptCatRowWindowActive).
    global PromptCatRowsByHwnd
    try PromptCatRowsByHwnd[guiObj.Hwnd] := chipRow
}

UnregisterPromptCatRow(guiObj) {
    global PromptCatRowsByHwnd
    try {
        hwnd := guiObj.Hwnd
        if PromptCatRowsByHwnd.Has(hwnd)
            PromptCatRowsByHwnd.Delete(hwnd)
    }
}

IsPromptCatRowWindowActive(*) {
    global PromptCatRowsByHwnd
    if (PromptCatRowsByHwnd.Count = 0)
        return false
    hwnd := 0
    try hwnd := WinActive("A")
    return (hwnd && PromptCatRowsByHwnd.Has(hwnd)) ? true : false
}

PickPromptCatInActiveDialog(index) {
    global PromptCatRowsByHwnd
    hwnd := 0
    try hwnd := WinActive("A")
    if (hwnd && PromptCatRowsByHwnd.Has(hwnd))
        SetPromptCatChipRow(PromptCatRowsByHwnd[hwnd], GetPromptCatByIndex(index))
}

LoadPromptsInternal() {
    global PromptDB, PromptFile, PromptParsePendingCat
    PromptDB := Map()
    PromptParsePendingCat := "" ; v13.21
    LoadEncryptedContainer(PromptFile, "prompts", ParsePromptLine)
    PromptParsePendingCat := ""
}

ParsePromptLine(line) {
    global PromptDB, PromptParsePendingCat
    ; v13.21: «@cat|IMAGE» — категория СЛЕДУЮЩЕЙ строки-промпта (см. GetPromptCatOrder).
    if (SubStr(line, 1, 5) = "@cat|") {
        PromptParsePendingCat := NormalizePromptCat(SubStr(line, 6))
        return
    }
    promptCat := (PromptParsePendingCat != "") ? PromptParsePendingCat : "OTHER"
    PromptParsePendingCat := ""
    parts := StrSplit(line, "|",, 3)
    if (parts.Length < 3)
        return
    count := Integer(parts[1])
    hidden := Integer(parts[2])
    promptText := SanitizePromptText(DecodePhraseText(parts[3]))
    if (promptText = "")
        return
    PromptDB[StrLower(promptText)] := {Text: promptText, Count: count, Hidden: hidden, Cat: promptCat}
}

SavePromptsInternal() {
    global PromptFile
    return SaveEncryptedContainer(PromptFile, LoadPromptsPlainText(), "prompts")
}

LoadPromptsPlainText() {
    global PromptDB
    out := ""
    for key, data in PromptDB {
        promptCat := GetPromptCat(data)
        if (promptCat != "OTHER")
            out .= "@cat|" promptCat "`n" ; v13.21: маркер категории — перед своим промптом
        out .= data.Count "|" (data.HasOwnProp("Hidden") ? data.Hidden : 0) "|" EncodePhraseText(data.Text) "`n"
    }
    return out
}

RebuildPromptIndexes() {
    global PromptDB, PromptIndex1, PromptIndex2
    PromptIndex1 := Map()
    PromptIndex2 := Map()
    for key, _ in PromptDB
        AddPromptToIndexes(key)
}

AddPromptToIndexes(key) {
    global PromptIndex1, PromptIndex2
    PrefixIndexAdd(PromptIndex1, PromptIndex2, key, key)
}

RemovePromptFromIndexes(key) {
    global PromptIndex1, PromptIndex2
    PrefixIndexRemove(PromptIndex1, PromptIndex2, key, key)
}

GetPromptIndexedCandidates(prefix) {
    global PromptIndex1, PromptIndex2
    if (prefix = "")
        return Map()
    return PrefixIndexCandidates(PromptIndex1, PromptIndex2, prefix)
}

NormalizeSnippetContainsQuery(query) {
    ; Для 11.../22... пробел в конце запроса должен быть значимым: "не "
    ; отличается от "не" и должен подсвечиваться/искаться именно как два символа + пробел.
    query := StrLower(StrReplace(StrReplace(query, "`r", " "), "`n", " "))
    return query
}

GetSnippetContainsMatchRows(store, query, limit := 5) {
    rows := []
    query := NormalizeSnippetContainsQuery(query)
    if (Trim(query) = "")
        return rows

    for key, data in store {
        hidden := data.HasOwnProp("Hidden") ? data.Hidden : 0
        if hidden
            continue

        ; v13.19: ключ базы и есть StrLower(Text) — не создаём копию каждого
        ; промпта на каждую букву запроса (длина — дешёвая страховка).
        textLower := (StrLen(key) = StrLen(data.Text)) ? key : StrLower(data.Text)
        pos := InStr(textLower, query)
        if !pos
            continue

        static boundaryChars := [" ", "-", "_", "/", ".", ",", "(", "[", "{", "`n", "`r"]
        boundaryPos := 0
        for _, boundaryChar in boundaryChars {
            boundaryPos := InStr(textLower, boundaryChar . query)
            if boundaryPos
                break
        }

        matchRank := (pos = 1) ? 0 : (boundaryPos ? 1 : 2)
        rows.Push({Key: key, Text: data.Text, Count: data.Count, Rank: matchRank, Pos: pos})
    }

    if (rows.Length <= 1)
        return rows

    SortRowsInPlace(rows, SnippetContainsComparator)

    if (limit > 0 && rows.Length > limit) {
        trimmed := []
        Loop limit
            trimmed.Push(rows[A_Index])
        return trimmed
    }
    return rows
}

GetTopSnippetRows(store, limit := 5) {
    ; Топ записей по частоте для голого режима "11"/"22" без поискового запроса.
    rows := []
    for key, data in store {
        hidden := data.HasOwnProp("Hidden") ? data.Hidden : 0
        if hidden
            continue
        rows.Push({Key: key, Text: data.Text, Count: data.Count})
    }
    if (rows.Length > 1)
        SortRowsInPlace(rows, TopSnippetCountDescComparator)
    if (limit > 0 && rows.Length > limit)
        rows.Length := limit
    return rows
}

LearnPrompt(promptText, scoreToAdd := 1, cat := "") {
    ; v13.21: cat — категория. Пустая: новый промпт — Other, у существующего не меняется.
    global PromptDB
    promptText := SanitizePromptText(promptText)
    if (promptText = "")
        return false
    key := StrLower(promptText)
    if PromptDB.Has(key) {
        PromptDB[key].Count += scoreToAdd
        if !PromptDB[key].HasOwnProp("Hidden")
            PromptDB[key].Hidden := 0
        if (cat != "")
            PromptDB[key].Cat := NormalizePromptCat(cat)
        else if !PromptDB[key].HasOwnProp("Cat")
            PromptDB[key].Cat := "OTHER"
    } else {
        PromptDB[key] := {Text: promptText, Count: Max(1, scoreToAdd), Hidden: 0, Cat: (cat != "") ? NormalizePromptCat(cat) : "OTHER"}
        AddPromptToIndexes(key)
    }
    return true
}

AddSelectedTextAsPromptGlobal() {
    selectedText := GetSelectedTextViaClipboard(0.7)
    if (Trim(selectedText) = "") {
        ToolTip("⚠️ Ничего не выделено")
        SetTimer(() => ToolTip(), -1200)
        return
    }

    text := SanitizePromptText(selectedText)
    if (text = "") {
        ToolTip("⚠️ Пустое выделение")
        SetTimer(() => ToolTip(), -1200)
        return
    }

    ; v13.21: категорию выбирают во всплывашке; сохранение — после выбора
    ; (см. ShowPromptCatPicker / FinishPromptCatPicker).
    ShowPromptCatPicker(text)
}

; v13.21: Shift+F14 → всплывашка у курсора: в какую категорию положить промпт.
; 1–4 или I / V / L / O (по VK — работают и в RU-раскладке),
; ←/→ + Enter, клик по чипу; Esc — не сохранять. Клик мимо (окно потеряло
; фокус) — сохранить в подсвеченную: Shift+F14 и так означал «сохранить
; промпт». Подсвечена текущая категория, если промпт уже есть, иначе — последняя
; выбранная. Сохранение — только после выбора.
ShowPromptCatPicker(promptText) {
    global PromptCatPickerGui, PromptCatPickerState, PromptDB, PromptLastCaptureCat, ColorHighlight
    ClosePromptCatPicker()
    key := StrLower(promptText)
    exists := PromptDB.Has(key)
    startCat := exists ? GetPromptCat(PromptDB[key]) : NormalizePromptCat(PromptLastCaptureCat)
    targetHwnd := 0
    try targetHwnd := WinExist("A")

    pickW := 442, pickH := 126
    pg := Gui("+AlwaysOnTop +ToolWindow -Caption", "Typer · категория промпта")
    pg.BackColor := "1C1C1C"
    pg.MarginX := 0
    pg.MarginY := 0
    pg.SetFont("s10 c" ColorHighlight, "Segoe UI")
    pg.Add("Text", "x14 y10 w290 h20 +0x80", exists ? "Промпт уже есть — сменить категорию?" : "Сохранить промпт в категорию")
    pg.SetFont("s9 c7A7A7A", "Segoe UI")
    pg.Add("Text", "x304 y12 w124 h18 Right", "Esc — не сохранять")
    ; +0x80 (SS_NOPREFIX): «&» в тексте промпта не превращается в подчёркивание.
    pg.Add("Text", "x14 y34 w414 h18 +0x80 cA0A0A0", TruncatePhraseForOSD(RegExReplace(promptText, "\s+", " "), 72))
    pg.SetFont("s10 cF0F0F0", "Segoe UI")
    chips := Map()
    chipX := 14
    for i, cat in GetPromptCatOrder() {
        chips[cat] := CreateFlatTextButton(pg, "x" chipX " y60 w99 h32", i "  " GetPromptCatName(cat), PromptCatPickerChipClicked.Bind(cat))
        chipX += 105
    }
    pg.SetFont("s9 c6E6E6E", "Segoe UI")
    pg.Add("Text", "x14 y100 w414 h18", "1–4 или I · V · L · O — выбрать      ← →  Enter — подсвеченная")
    ; Рамка — 4 линии, как у плашки превью панели (нейтрально-серая).
    for _, spec in [[0, 0, pickW, 1], [0, pickH - 1, pickW, 1], [0, 0, 1, pickH], [pickW - 1, 0, 1, pickH]]
        pg.Add("Text", "x" spec[1] " y" spec[2] " w" spec[3] " h" spec[4] " Background3C3C3C", "")

    PromptCatPickerGui := pg
    PromptCatPickerState := {Text: promptText, Key: key, Exists: exists, Cat: startCat, Chips: chips, Target: targetHwnd, WasActive: false, ShownTick: A_TickCount}
    PaintPromptCatChipRow(PromptCatPickerState)

    ; Размер окна в физических пикселях узнаём после скрытого Show (w/h Gui
    ; масштабируются под DPI), затем ставим окно у курсора в пределах монитора.
    pg.Show("Hide w" pickW " h" pickH)
    winW := pickW, winH := pickH
    rc := Buffer(16, 0)
    if DllCall("User32\GetWindowRect", "Ptr", pg.Hwnd, "Ptr", rc.Ptr)
        winW := NumGet(rc, 8, "Int") - NumGet(rc, 0, "Int"), winH := NumGet(rc, 12, "Int") - NumGet(rc, 4, "Int")
    mx := 0, my := 0
    pt := Buffer(8, 0)
    if DllCall("User32\GetCursorPos", "Ptr", pt.Ptr)
        mx := NumGet(pt, 0, "Int"), my := NumGet(pt, 4, "Int")
    wa := GetWorkAreaAtPoint(mx, my)
    gx := mx - 24
    gy := my + 22
    if (gy + winH > wa.B - 4)
        gy := my - winH - 14
    gx := Max(wa.L + 4, Min(gx, wa.R - winW - 4))
    gy := Max(wa.T + 4, Min(gy, wa.B - winH - 4))
    OnMessage(0x0100, PromptCatPickerKeyDown) ; WM_KEYDOWN — см. PromptCatPickerKeyDown
    pg.Show("x" gx " y" gy)
    try WinActivate("ahk_id " pg.Hwnd)
    SetTimer(WatchPromptCatPicker, 100)
}

PromptCatPickerKeyDown(wParam, lParam, msg, hwnd) {
    ; Клавиши всплывашки — через WM_KEYDOWN её окна, а НЕ хоткеями: хоткеи на
    ; Space/Tab/буквы заставили бы хук клавиатуры сверять #HotIf на каждое
    ; нажатие при обычном наборе. VK букв от раскладки не зависят (в RU это
    ; Ш / М / Д / Щ). Вернуть 0 — клавиша обработана, дальше не идёт.
    global PromptCatPickerGui
    if !IsObject(PromptCatPickerGui)
        return
    pickHwnd := 0
    try pickHwnd := PromptCatPickerGui.Hwnd
    if !pickHwnd
        return
    if (hwnd != pickHwnd && DllCall("User32\GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr") != pickHwnd) ; GA_ROOT
        return
    switch wParam & 0xFF {
        case 0x31, 0x61, 0x49: SetTimer(PickPromptCatFromPicker.Bind(1), -1) ; 1 / Num1 / I
        case 0x32, 0x62, 0x56: SetTimer(PickPromptCatFromPicker.Bind(2), -1) ; 2 / Num2 / V
        case 0x33, 0x63, 0x4C: SetTimer(PickPromptCatFromPicker.Bind(3), -1) ; 3 / Num3 / L
        case 0x34, 0x64, 0x4F: SetTimer(PickPromptCatFromPicker.Bind(4), -1) ; 4 / Num4 / O
        case 0x25: MovePromptCatPicker(-1)                                    ; ←
        case 0x27: MovePromptCatPicker(1)                                     ; →
        case 0x09: MovePromptCatPicker(GetKeyState("Shift") ? -1 : 1)         ; Tab / Shift+Tab
        case 0x0D, 0x20: SetTimer(PickPromptCatFromPicker.Bind(0), -1)        ; Enter / Space
        case 0x1B: SetTimer(CancelPromptCatPicker, -1)                        ; Esc
        default: return
    }
    return 0
}

IsPromptCatPickerActive(*) {
    global PromptCatPickerGui
    if !IsObject(PromptCatPickerGui)
        return false
    try return WinActive("ahk_id " PromptCatPickerGui.Hwnd) ? true : false
    return false
}

PromptCatPickerChipClicked(cat, *) {
    FinishPromptCatPicker(cat)
}

PickPromptCatFromPicker(index := 0) {
    ; index 1…4 — категория по номеру; 0 — подсвеченная (Enter/Space).
    global PromptCatPickerState
    if !IsObject(PromptCatPickerState)
        return
    FinishPromptCatPicker((index >= 1) ? GetPromptCatByIndex(index) : PromptCatPickerState.Cat)
}

MovePromptCatPicker(delta) {
    global PromptCatPickerState
    pickState := PromptCatPickerState
    if !IsObject(pickState)
        return
    idx := Mod(GetPromptCatRank(pickState.Cat) + delta - 1 + 4, 4) + 1
    pickState.Cat := GetPromptCatByIndex(idx)
    PaintPromptCatChipRow(pickState)
}

FinishPromptCatPicker(cat, restoreFocus := true) {
    global PromptCatPickerState, PromptDB
    pickState := PromptCatPickerState
    if !IsObject(pickState)
        return
    cat := NormalizePromptCat(cat)
    ClosePromptCatPicker()
    ; Фокус — обратно в окно, где выделяли текст (после клика мимо фокус уже
    ; там, куда кликнули, — его не отнимаем).
    if (restoreFocus && pickState.Target) {
        try {
            if WinExist("ahk_id " pickState.Target)
                WinActivate("ahk_id " pickState.Target)
        }
    }
    oldCat := PromptDB.Has(pickState.Key) ? GetPromptCat(PromptDB[pickState.Key]) : ""
    if !LearnPrompt(pickState.Text, 1, cat)
        return
    SavePromptsInternal()
    RememberPromptCaptureCat(cat)
    RefreshPanelAfterPromptChange()
    catName := GetPromptCatName(cat)
    if (oldCat = "")
        msg := "🧾 Промпт добавлен · " catName
    else if (oldCat != cat)
        msg := "🧾 Промпт уже был — теперь " catName
    else
        msg := "🧾 Промпт уже есть · " catName
    ToolTip(msg)
    SetTimer(() => ToolTip(), -1200)
}

CancelPromptCatPicker() {
    global PromptCatPickerState
    pickState := PromptCatPickerState
    ClosePromptCatPicker()
    if (IsObject(pickState) && pickState.Target) {
        try {
            if WinExist("ahk_id " pickState.Target)
                WinActivate("ahk_id " pickState.Target)
        }
    }
    ToolTip("Промпт не сохранён")
    SetTimer(() => ToolTip(), -900)
}

ClosePromptCatPicker() {
    global PromptCatPickerGui, PromptCatPickerState
    SetTimer(WatchPromptCatPicker, 0)
    OnMessage(0x0100, PromptCatPickerKeyDown, 0)
    PromptCatPickerState := 0
    try {
        if IsObject(PromptCatPickerGui)
            PromptCatPickerGui.Destroy()
    }
    PromptCatPickerGui := 0
}

WatchPromptCatPicker() {
    ; Потеря фокуса после того, как окно было активным, — сохранить в
    ; подсвеченную. Если система так и не отдала окну фокус, клавиши до него не
    ; доходят — выбрать можно мышью; через 20 с без выбора окно закрывается.
    global PromptCatPickerGui, PromptCatPickerState
    pickState := PromptCatPickerState
    if (!IsObject(pickState) || !IsObject(PromptCatPickerGui)) {
        SetTimer(WatchPromptCatPicker, 0)
        return
    }
    isActive := false
    try isActive := WinActive("ahk_id " PromptCatPickerGui.Hwnd) ? true : false
    if isActive {
        pickState.WasActive := true
        return
    }
    if pickState.WasActive {
        FinishPromptCatPicker(pickState.Cat, false)
        return
    }
    if (A_TickCount - pickState.ShownTick > 20000) {
        ClosePromptCatPicker()
        ToolTip("Промпт не сохранён")
        SetTimer(() => ToolTip(), -1200)
    }
}

TogglePromptCapture() {
    global PromptCaptureMode
    if PromptCaptureMode
        SaveCapturedPrompt(false)
    else
        StartPromptCapture()
}

StartPromptCapture() {
    global PromptCaptureMode, PromptCaptureGuiObj, PromptCaptureEdit, PromptCaptureTargetHwnd, ColorHighlight, PromptCaptureCatRow, PromptLastCaptureCat
    ResetInput()
    HideSuggestions()

    if (PromptCaptureMode && IsObject(PromptCaptureGuiObj)) {
        try PromptCaptureEdit.Focus()
        return
    }

    PromptCaptureTargetHwnd := WinGetID("A")

    PromptCaptureGuiObj := Gui("+AlwaysOnTop +ToolWindow -MinimizeBox", "Режим промпта")
    ApplyDarkWindowFrame(PromptCaptureGuiObj)
    PromptCaptureGuiObj.BackColor := "171717"
    PromptCaptureGuiObj.SetFont("s10 cF0F0F0", "Segoe UI")
    PromptCaptureGuiObj.MarginX := 12
    PromptCaptureGuiObj.MarginY := 10
    PromptCaptureGuiObj.OnEvent("Close", (*) => CancelPromptCapture())
    PromptCaptureGuiObj.OnEvent("Escape", (*) => CancelPromptCapture())

    PromptCaptureGuiObj.Add("Text", "w560 h22 c" ColorHighlight, "● Запись промпта")
    PromptCaptureGuiObj.Add("Text", "w560 h18 cB8B8B8 y+2", "Alt+Insert — сохранить    Enter — сохранить и вставить    Esc — отменить")
    ; v13.21: категория — чипы или Ctrl+1…4 (по умолчанию — последняя выбранная).
    PromptCaptureGuiObj.Add("Text", "xm y+8 w86 h26 +0x200 cB8B8B8", "Категория:")
    PromptCaptureCatRow := CreatePromptCatChipRow(PromptCaptureGuiObj, "x+6 yp", PromptLastCaptureCat, 92, 26)
    PromptCaptureGuiObj.Add("Text", "x+10 yp w70 h26 +0x200 c6E6E6E", "Ctrl+1…4")
    RegisterPromptCatRow(PromptCaptureGuiObj, PromptCaptureCatRow)
    PromptCaptureEdit := PromptCaptureGuiObj.Add("Edit", "xm y+10 w560 h170 +Multi +VScroll Background2D2D2D cF0F0F0")
    ApplyDarkControlTheme(PromptCaptureEdit)
    PromptCaptureGuiObj.Show("AutoSize Center")
    try PromptCaptureEdit.Focus()
    PromptCaptureMode := true
}

SaveCapturedPrompt(insertAfterSave := true) {
    global PromptCaptureMode, PromptCaptureEdit, PromptCaptureCatRow, PromptLastCaptureCat
    if !PromptCaptureMode
        return

    rawText := ""
    try rawText := PromptCaptureEdit.Value
    promptText := SanitizePromptText(rawText)

    if (promptText = "") {
        CancelPromptCapture()
        return
    }

    promptCat := IsObject(PromptCaptureCatRow) ? PromptCaptureCatRow.Cat : PromptLastCaptureCat ; v13.21
    savedOk := LearnPrompt(promptText, 1, promptCat)
    if savedOk {
        SavePromptsInternal()
        RememberPromptCaptureCat(promptCat)
        RefreshPanelAfterPromptChange()
    }

    ClosePromptCaptureGui()

    if savedOk {
        ToolTip("Промпт сохранён")
        SetTimer(() => ToolTip(), -900)
        if insertAfterSave
            InsertSavedPromptToCapturedTarget(promptText)
    }
}

InsertSavedPromptToCapturedTarget(promptText) {
    global PromptCaptureTargetHwnd
    hwnd := PromptCaptureTargetHwnd
    PromptCaptureTargetHwnd := 0
    InsertSavedSnippetToTarget(hwnd, promptText, "PROMPT")
}

CancelPromptCapture() {
    global PromptCaptureMode, PromptCaptureTargetHwnd
    if !PromptCaptureMode
        return
    PromptCaptureTargetHwnd := 0
    ClosePromptCaptureGui()
}

ClosePromptCaptureGui() {
    global PromptCaptureMode, PromptCaptureGuiObj, PromptCaptureEdit, PromptCaptureCatRow
    PromptCaptureMode := false
    try {
        if IsObject(PromptCaptureGuiObj) {
            UnregisterPromptCatRow(PromptCaptureGuiObj) ; v13.21
            PromptCaptureGuiObj.Destroy()
        }
    }
    PromptCaptureGuiObj := 0
    PromptCaptureEdit := 0
    PromptCaptureCatRow := 0
}
; #EndRegion

; #Region ⌨️ НАЗНАЧАЕМЫЕ ГОРЯЧИЕ ВСТАВКИ

; #Region 🔗 БАЗА ССЫЛОК
SanitizeLinkField(text, keepSpaces := true) {
    text := StrReplace(text, "`r", keepSpaces ? " " : "")
    text := StrReplace(text, "`n", keepSpaces ? " " : "")
    if keepSpaces
        text := RegExReplace(text, "\s+", " ")
    return Trim(text)
}

SanitizeLinkUrl(urlText) {
    urlText := StrReplace(urlText, "`r", "")
    urlText := StrReplace(urlText, "`n", "")
    urlText := RegExReplace(urlText, "\s+", "")
    return Trim(urlText)
}

IsLikelyLinkText(text) {
    text := SanitizeLinkUrl(text)
    if (text = "")
        return false
    if RegExMatch(text, "i)^(https?://|www\.)")
        return true
    return !!RegExMatch(text, "i)^[a-z0-9а-яё][a-z0-9а-яё\-\.]*\.[a-zа-яё]{2,}(/.*)?$")
}

GuessLinkTitleFromUrl(urlText) {
    urlText := SanitizeLinkUrl(urlText)
    if (urlText = "")
        return ""
    clean := RegExReplace(urlText, "i)^https?://")
    clean := RegExReplace(clean, "i)^www\.")
    slashPos := InStr(clean, "/")
    if slashPos
        clean := SubStr(clean, 1, slashPos - 1)
    return clean
}

CreateLinkRecord(titleText := "", urlText := "", noteText := "", tagsText := "", count := 1, hidden := 0) {
    urlText := SanitizeLinkUrl(urlText)
    titleText := SanitizeLinkField(titleText)
    noteText := SanitizeLinkField(noteText)
    tagsText := SanitizeLinkField(tagsText)
    if (titleText = "")
        titleText := GuessLinkTitleFromUrl(urlText)
    return {Title: titleText, Url: urlText, Note: noteText, Tags: tagsText, Count: Max(1, count), Hidden: !!hidden}
}

LoadLinksInternal() {
    global LinkDB, LinkFile, NextLinkId
    LinkDB := Map()
    NextLinkId := 1
    LoadEncryptedContainer(LinkFile, "links", ParseLinkLine)
    RebuildLinkIndexes()
}

ParseLinkLine(line) {
    global LinkDB, NextLinkId
    parts := StrSplit(line, "|",, 7)
    if (parts.Length < 7)
        return
    id := parts[1]
    count := Integer(parts[2])
    hidden := Integer(parts[3])
    data := CreateLinkRecord(
        DecodePhraseText(parts[4]),
        DecodePhraseText(parts[5]),
        DecodePhraseText(parts[6]),
        DecodePhraseText(parts[7]),
        count,
        hidden
    )
    if (data.Url = "")
        return
    LinkDB[id] := data
    try {
        idNum := Integer(id)
        if (idNum >= NextLinkId)
            NextLinkId := idNum + 1
    }
}

SaveLinksInternal() {
    global LinkFile
    return SaveEncryptedContainer(LinkFile, LoadLinksPlainText(), "links")
}

LoadLinksPlainText() {
    global LinkDB
    out := ""
    for id, data in LinkDB {
        out .= id "|" data.Count "|" (data.Hidden ? 1 : 0) "|"
            . EncodePhraseText(data.Title) "|" EncodePhraseText(data.Url) "|"
            . EncodePhraseText(data.Note) "|" EncodePhraseText(data.Tags) "`n"
    }
    return out
}

GetNextLinkId() {
    global NextLinkId
    id := "" NextLinkId
    NextLinkId += 1
    return id
}

NormalizeLinkToken(text) {
    text := StrLower(SanitizeLinkField(text))
    return RegExReplace(text, "[^0-9a-zа-яё@._\-/:]+", "")
}

GetLinkSearchTokens(data) {
    tokens := Map()

    AddTokenValue(value) {
        if (value = "")
            return
        value := StrLower(value)
        tokenized := RegExReplace(value, "[^0-9a-zа-яё@._\-/:]+", " ")
        Loop Parse, tokenized, " " {
            token := Trim(A_LoopField)
            if (token = "")
                continue
            tokens[token] := true
            splitMore := RegExReplace(token, "[@._\-/:]+", " ")
            if (splitMore != token) {
                Loop Parse, splitMore, " " {
                    part := Trim(A_LoopField)
                    if (part != "")
                        tokens[part] := true
                }
            }
        }
    }

    AddTokenValue(data.Title)
    AddTokenValue(data.Url)
    AddTokenValue(data.Note)
    AddTokenValue(data.Tags)
    return tokens
}

GetLinkSearchBlob(data) {
    blob := data.Title " " data.Url " " data.Note " " data.Tags " "
    for token, _ in GetLinkSearchTokens(data)
        blob .= token " "
    return Trim(StrLower(blob))
}

RebuildLinkIndexes() {
    global LinkDB, LinkIndex1, LinkIndex2, NextLinkId
    LinkIndex1 := Map()
    LinkIndex2 := Map()
    maxSeenId := 0
    for id, _ in LinkDB {
        AddLinkToIndexes(id)
        try {
            numericId := Integer(id)
            if (numericId > maxSeenId)
                maxSeenId := numericId
        }
    }
    NextLinkId := maxSeenId + 1
    if (NextLinkId < 1)
        NextLinkId := 1
}

AddLinkToIndexes(id) {
    global LinkDB, LinkIndex1, LinkIndex2
    if !LinkDB.Has(id)
        return
    for token, _ in GetLinkSearchTokens(LinkDB[id])
        PrefixIndexAdd(LinkIndex1, LinkIndex2, token, id)
}

RemoveLinkFromIndexes(id) {
    global LinkIndex1, LinkIndex2
    PrefixIndexRemoveAllForValue(LinkIndex1, LinkIndex2, id)
}

GetLinkIndexedCandidates(prefix) {
    global LinkDB, LinkIndex1, LinkIndex2
    prefix := NormalizeLinkToken(prefix)
    if (prefix = "") {
        candidates := Map()
        for id, _ in LinkDB
            candidates[id] := true
        return candidates
    }
    return PrefixIndexCandidates(LinkIndex1, LinkIndex2, prefix)
}

BuildLinkDisplay(data) {
    title := data.Title != "" ? data.Title : GuessLinkTitleFromUrl(data.Url)
    domain := GuessLinkTitleFromUrl(data.Url)
    note := data.Note != "" ? " · " TruncatePhraseForOSD(data.Note, 22) : ""
    if (title = domain || domain = "")
        return TruncatePhraseForOSD(title, 54) note
    return TruncatePhraseForOSD(title, 34) " → " TruncatePhraseForOSD(domain, 28) note
}

BuildLinkListNote(data) {
    out := ""
    if (data.Tags != "")
        out .= "#" data.Tags
    if (data.Note != "")
        out .= (out != "" ? " · " : "") data.Note
    return out
}

GetTopLinkMatches(prefix, containsSearch := false, limit := 8) {
    global LinkDB
    rows := []
    query := StrLower(Trim(prefix))
    candidates := containsSearch ? Map() : GetLinkIndexedCandidates(query)
    if containsSearch {
        for id, _ in LinkDB
            candidates[id] := true
    } else if (query != "" && candidates.Count = 0) {
        ; Защита от устаревшего индекса: если токены URL/тегов есть, но индекс не пересобрался,
        ; всё равно пройдёмся по LinkDB. Для личной базы ссылок это дешево, а 3ima/3console не будут молчать.
        for id, _ in LinkDB
            candidates[id] := true
    }

    for id, _ in candidates {
        if !LinkDB.Has(id)
            continue
        data := LinkDB[id]
        if data.Hidden
            continue
        blob := GetLinkSearchBlob(data)
        if (query != "") {
            if containsSearch {
                if !InStr(blob, query)
                    continue
            } else if !HasLinkPrefixMatch(data, query) {
                continue
            }
        }
        pos := query = "" ? 1 : InStr(blob, query)
        if !pos
            pos := 9999
        rows.Push({Id: id, Data: data, Count: data.Count, Pos: pos, Text: BuildLinkDisplay(data)})
    }

    SortLinkRows(rows)
    if (limit > 0 && rows.Length > limit) {
        trimmed := []
        Loop limit
            trimmed.Push(rows[A_Index])
        return trimmed
    }
    return rows
}

HasLinkPrefixMatch(data, query) {
    if (query = "")
        return true
    for token, _ in GetLinkSearchTokens(data) {
        if (SubStr(token, 1, StrLen(query)) = query)
            return true
    }
    return false
}

SortLinkRows(rows) {
    SortRowsInPlace(rows, LinkRowComparator)
}

LearnLink(urlText, titleText := "", noteText := "", tagsText := "", scoreToAdd := 1) {
    global LinkDB
    urlText := SanitizeLinkUrl(urlText)
    if (urlText = "")
        return false
    oldId := ""
    for id, data in LinkDB {
        if (StrLower(data.Url) = StrLower(urlText)) {
            oldId := id
            break
        }
    }
    if (oldId != "") {
        data := LinkDB[oldId]
        data.Count += scoreToAdd
        if (titleText != "")
            data.Title := SanitizeLinkField(titleText)
        if (noteText != "")
            data.Note := SanitizeLinkField(noteText)
        if (tagsText != "")
            data.Tags := SanitizeLinkField(tagsText)
        data.Hidden := false
        RemoveLinkFromIndexes(oldId)
        LinkDB[oldId] := data
        AddLinkToIndexes(oldId)
        return oldId
    }

    id := GetNextLinkId()
    LinkDB[id] := CreateLinkRecord(titleText, urlText, noteText, tagsText, scoreToAdd, 0)
    AddLinkToIndexes(id)
    return id
}

QueueLinkSave(delayMs := 320) {
    SetTimer(SaveLinksInternal, 0)
    SetTimer(SaveLinksInternal, -Abs(delayMs))
}

ApplyLinkUrlEdit(index, newUrl) {
    global CurrentWords, LinkDB
    if (index < 1 || index > CurrentWords.Length)
        return false
    newUrl := SanitizeLinkUrl(newUrl)
    if (newUrl = "")
        return false
    row := CurrentWords[index]
    id := row.HasOwnProp("Id") ? row.Id : row.Key
    if !LinkDB.Has(id)
        return false
    RemoveLinkFromIndexes(id)
    LinkDB[id].Url := newUrl
    if (LinkDB[id].Title = "")
        LinkDB[id].Title := GuessLinkTitleFromUrl(newUrl)
    AddLinkToIndexes(id)
    CurrentWords[index].Full := newUrl
    CurrentWords[index].Url := newUrl
    CurrentWords[index].Display := BuildLinkDisplay(LinkDB[id])
    return true
}

AddSelectedTextAsLinkGlobal(*) {
    rawText := Trim(GetSelectedTextViaClipboard(0.7))
    if (rawText = "") {
        ShowLinkCaptureGui()
        return
    }
    if IsLikelyLinkText(rawText) {
        if LearnLink(rawText, GuessLinkTitleFromUrl(rawText), "", "", 1) {
            SaveLinksInternal()
            ToolTip("🔗 Ссылка добавлена")
            SetTimer(() => ToolTip(), -1000)
        }
    } else {
        ShowLinkCaptureGui(rawText)
    }
}

ShowLinkCaptureGui(prefillText := "", editId := "") {
    global LinkDB, ColorHighlight
    if !GuardTyperStartup()
        return
    isEdit := (editId != "" && LinkDB.Has(editId))
    source := isEdit ? LinkDB[editId] : 0
    titleValue := "", urlValue := "", noteValue := "", tagsValue := ""
    if isEdit {
        titleValue := source.Title, urlValue := source.Url, noteValue := source.Note, tagsValue := source.Tags
    } else if (prefillText != "") {
        if IsLikelyLinkText(prefillText) {
            urlValue := SanitizeLinkUrl(prefillText)
            titleValue := GuessLinkTitleFromUrl(urlValue)
        } else {
            titleValue := SanitizeLinkField(prefillText)
        }
    }

    LinkGui := CreateTyperDialog("+AlwaysOnTop +ToolWindow -MinimizeBox", isEdit ? "Правка ссылки" : "Новая ссылка")
    LinkGui.BackColor := "171717"
    LinkGui.SetFont("s10 cF0F0F0", "Segoe UI")
    LinkGui.MarginX := 12
    LinkGui.MarginY := 10
    LinkGui.OnEvent("Escape", (*) => LinkGui.Destroy())
    LinkGui.OnEvent("Close", (*) => LinkGui.Destroy())

    LinkGui.Add("Text", "w560 h22 c" ColorHighlight, isEdit ? "● Правка ссылки" : "● Запись ссылки")
    LinkGui.Add("Text", "w560 h18 cB8B8B8 y+2", "URL можно хранить с https:// или без него. Enter — сохранить, Esc — отмена.")
    LinkGui.Add("Text", "w560 h18 y+10", "Название / алиас:")
    EditTitle := LinkGui.Add("Edit", "w560 h26 Background2D2D2D cF0F0F0")
    EditTitle.Value := titleValue
    LinkGui.Add("Text", "w560 h18 y+8", "URL / домен:")
    EditUrl := LinkGui.Add("Edit", "w560 h26 Background2D2D2D cF0F0F0")
    EditUrl.Value := urlValue
    LinkGui.Add("Text", "w560 h18 y+8", "Теги:")
    EditTags := LinkGui.Add("Edit", "w560 h26 Background2D2D2D cF0F0F0")
    EditTags.Value := tagsValue
    LinkGui.Add("Text", "w560 h18 y+8", "Заметка:")
    EditNote := LinkGui.Add("Edit", "w560 h54 +Multi Background2D2D2D cF0F0F0")
    EditNote.Value := noteValue
    BtnSave := CreateFlatTextButton(LinkGui, "xm y+12 w150 h34", "Сохранить", SaveLink)
    BtnCancel := CreateFlatTextButton(LinkGui, "x+m yp w110 h34", "Отмена", (*) => LinkGui.Destroy())
    HiddenDefaultBtn := LinkGui.Add("Button", "x0 y0 w0 h0 Hidden Default", "OK")
    HiddenDefaultBtn.OnEvent("Click", SaveLink)
    LinkGui.Show("AutoSize Center")
    try {
        if (urlValue = "")
            SetEditCaretEnd(EditUrl)
        else
            SetEditCaretEnd(EditTitle)
    }

    SaveLink(*) {
        urlText := SanitizeLinkUrl(EditUrl.Value)
        if (urlText = "") {
            ToolTip("⚠️ URL пустой")
            SetTimer(() => ToolTip(), -1000)
            return
        }
        titleText := SanitizeLinkField(EditTitle.Value)
        noteText := SanitizeLinkField(EditNote.Value)
        tagsText := SanitizeLinkField(EditTags.Value)
        if isEdit {
            RemoveLinkFromIndexes(editId)
            LinkDB[editId].Title := (titleText != "") ? titleText : GuessLinkTitleFromUrl(urlText)
            LinkDB[editId].Url := urlText
            LinkDB[editId].Note := noteText
            LinkDB[editId].Tags := tagsText
            AddLinkToIndexes(editId)
        } else {
            LearnLink(urlText, titleText, noteText, tagsText, 1)
        }
        SaveLinksInternal()
        PopulateDictListView()
        LinkGui.Destroy()
        ToolTip(isEdit ? "🔗 Ссылка обновлена" : "🔗 Ссылка сохранена")
        SetTimer(() => ToolTip(), -900)
    }
}
; #EndRegion


NormalizeHotInsertText(text) {
    text := StrReplace(text, "`r`n", "`n")
    text := StrReplace(text, "`r", "`n")
    return text
}

LoadHotInsertsInternal() {
    global HotInsertDB, HotInsertFile, NextHotInsertId
    HotInsertDB := Map()
    NextHotInsertId := 1
    LoadEncryptedContainer(HotInsertFile, "hotinserts", ParseHotInsertLine)
}

ParseHotInsertLine(line) {
    global HotInsertDB, NextHotInsertId
    parts := StrSplit(line, "|",, 4)
    if (parts.Length < 4)
        return
    id := parts[1]
    combo := parts[2]
    label := DecodePhraseText(parts[3])
    hotText := DecodePhraseText(parts[4])
    if (combo = "" || hotText = "")
        return
    HotInsertDB[id] := {Label: label != "" ? label : combo, Combo: combo, Text: hotText}
    try {
        idNum := Integer(id)
        if (idNum >= NextHotInsertId)
            NextHotInsertId := idNum + 1
    }
}

SaveHotInsertsInternal() {
    global HotInsertFile
    return SaveEncryptedContainer(HotInsertFile, LoadHotInsertsPlainText(), "hotinserts")
}

LoadHotInsertsPlainText() {
    global HotInsertDB
    out := ""
    for id, data in HotInsertDB
        out .= id "|" data.Combo "|" EncodePhraseText(data.Label) "|" EncodePhraseText(data.Text) "`n"
    return out
}

ResolveHotInsertText(entry) {
    return entry.HasOwnProp("Text") ? entry.Text : ""
}

InsertHotInsertById(id) {
    global HotInsertDB
    if !HotInsertDB.Has(id)
        return
    text := ResolveHotInsertText(HotInsertDB[id])
    if (text = "")
        return
    SafeSendPhrase(text)
    RememberInsertedText(text, false, "HOTKEY")
    StartPhraseUndo(text, false, "HOTKEY")
}

GetHotInsertIdByCombo(comboText) {
    global HotInsertDB
    combo := CanonicalizeHotInsertCombo(comboText)
    if (combo = "")
        return ""
    for id, data in HotInsertDB {
        if (CanonicalizeHotInsertCombo(data.Combo) = combo)
            return id
    }
    return ""
}

HasHotInsertCombo(comboText) {
    return GetHotInsertIdByCombo(comboText) != ""
}

TryHotInsertByCombo(comboText, *) {
    id := GetHotInsertIdByCombo(comboText)
    if (id = "")
        return false
    InsertHotInsertById(id)
    return true
}

IsHotInsertContext(*) {
    global TyperSuspended, TyperStartupComplete
    return !TyperSuspended && TyperStartupComplete && IsTyperInputContext()
}

IsStaticWinNumpadFallbackCombo(combo) {
    return RegExMatch(combo, "^#Numpad(?:[0-9]|Dot)$")
}


GetNumpadNumLockTwinKey(keyName) {
    static twins := Map(
        "Numpad0", "NumpadIns", "NumpadIns", "Numpad0",
        "Numpad1", "NumpadEnd", "NumpadEnd", "Numpad1",
        "Numpad2", "NumpadDown", "NumpadDown", "Numpad2",
        "Numpad3", "NumpadPgDn", "NumpadPgDn", "Numpad3",
        "Numpad4", "NumpadLeft", "NumpadLeft", "Numpad4",
        "Numpad5", "NumpadClear", "NumpadClear", "Numpad5",
        "Numpad6", "NumpadRight", "NumpadRight", "Numpad6",
        "Numpad7", "NumpadHome", "NumpadHome", "Numpad7",
        "Numpad8", "NumpadUp", "NumpadUp", "Numpad8",
        "Numpad9", "NumpadPgUp", "NumpadPgUp", "Numpad9",
        "NumpadDot", "NumpadDel", "NumpadDel", "NumpadDot"
    )
    return twins.Has(keyName) ? twins[keyName] : ""
}

GetNumpadNumLockTwinCombo(combo) {
    ; AHK различает физическую клавишу numpad по состоянию NumLock: Numpad8 и NumpadUp — одна клавиша.
    ; Для пользовательских горячих вставок регистрируем пару, чтобы #Numpad8 работал и при NumLock Off.
    static keys := ["NumpadPgDn", "NumpadPgUp", "NumpadClear", "NumpadLeft", "NumpadRight", "NumpadDown", "NumpadHome", "NumpadEnd", "NumpadIns", "NumpadDel", "NumpadDot", "Numpad0", "Numpad1", "Numpad2", "Numpad3", "Numpad4", "Numpad5", "Numpad6", "Numpad7", "Numpad8", "Numpad9", "NumpadUp"]
    for _, keyName in keys {
        if (SubStr(combo, -StrLen(keyName)) = keyName) {
            twin := GetNumpadNumLockTwinKey(keyName)
            return (twin != "") ? SubStr(combo, 1, StrLen(combo) - StrLen(keyName)) twin : ""
        }
    }
    return ""
}

ForceHookHotkeyName(combo) {
    ; Для Win+Numpad alias-ов особенно важно принудительно использовать keyboard hook:
    ; иначе системные Win+Arrow иногда забирают клавишу раньше пользовательской горячей вставки.
    return (SubStr(combo, 1, 1) = "$") ? combo : "$" combo
}

RegisterHotInsertEntry(id) {
    global HotInsertDB, RegisteredHotInsertCombos, RegisteredHotInsertAliasCombos, HotInsertCallbacks
    if !HotInsertDB.Has(id)
        return false
    combo := CanonicalizeHotInsertCombo(HotInsertDB[id].Combo)
    if (combo = "")
        return false
    HotInsertDB[id].Combo := combo

    UnregisterHotInsertEntry(id)

    ; Эти сочетания уже покрываются статическим fallback-блоком ниже.
    ; Не регистрируем их динамически, иначе один Numpad-клик вызывает
    ; одновременно динамический и статический callback.
    if IsStaticWinNumpadFallbackCombo(combo)
        return true

    cb := HotInsertCallback.Bind(id)
    HotInsertCallbacks[id] := cb
    try {
        HotIf(IsHotInsertContext)
        hotCombo := ForceHookHotkeyName(combo)
        Hotkey(hotCombo, cb, "On")
        RegisteredHotInsertCombos[id] := hotCombo

        aliasList := []
        twinCombo := GetNumpadNumLockTwinCombo(combo)
        if (twinCombo != "" && twinCombo != combo) {
            try {
                hotTwinCombo := ForceHookHotkeyName(twinCombo)
                Hotkey(hotTwinCombo, cb, "On")
                aliasList.Push(hotTwinCombo)
            }
        }
        if (aliasList.Length > 0)
            RegisteredHotInsertAliasCombos[id] := aliasList
        HotIf()
        return true
    } catch {
        HotIf()
        return false
    }
}

RegisterAllHotInsertHotkeys() {
    global HotInsertDB
    UnregisterAllHotInsertHotkeys()
    failed := 0
    for id, _ in HotInsertDB {
        if !RegisterHotInsertEntry(id)
            failed += 1
    }
    if (failed > 0) {
        ; Один обобщённый сигнал на старте: подробности — в панели Typer (Win+F9 → Хоткеи).
        ToolTip("⚠️ " failed " хоткей(и) не назначены — конфликт?")
        SetTimer(() => ToolTip(), -2400)
    }
}

UnregisterHotInsertEntry(id) {
    ; Снимает основной хоткей И numpad-двойники записи. Раньше при удалении
    ; записи двойник (например #NumpadUp для #Numpad8) оставался захваченным
    ; до перезапуска скрипта и продолжал глотать клавишу.
    global RegisteredHotInsertCombos, RegisteredHotInsertAliasCombos, HotInsertCallbacks
    cb := HotInsertCallbacks.Has(id) ? HotInsertCallbacks[id] : 0
    HotIf(IsHotInsertContext)
    if RegisteredHotInsertCombos.Has(id) {
        if cb {
            try Hotkey(RegisteredHotInsertCombos[id], cb, "Off")
        } else {
            try Hotkey(RegisteredHotInsertCombos[id], "Off")
        }
        RegisteredHotInsertCombos.Delete(id)
    }
    if RegisteredHotInsertAliasCombos.Has(id) {
        for _, aliasCombo in RegisteredHotInsertAliasCombos[id] {
            if cb {
                try Hotkey(aliasCombo, cb, "Off")
            } else {
                try Hotkey(aliasCombo, "Off")
            }
        }
        RegisteredHotInsertAliasCombos.Delete(id)
    }
    HotIf()
    if HotInsertCallbacks.Has(id)
        HotInsertCallbacks.Delete(id)
}

UnregisterAllHotInsertHotkeys() {
    global RegisteredHotInsertCombos, RegisteredHotInsertAliasCombos, HotInsertCallbacks
    HotIf(IsHotInsertContext)
    for id, combo in RegisteredHotInsertCombos {
        cb := HotInsertCallbacks.Has(id) ? HotInsertCallbacks[id] : 0
        try Hotkey(combo, cb, "Off")
    }
    for id, aliasList in RegisteredHotInsertAliasCombos {
        cb := HotInsertCallbacks.Has(id) ? HotInsertCallbacks[id] : 0
        for _, aliasCombo in aliasList
            try Hotkey(aliasCombo, cb, "Off")
    }
    HotIf()
    RegisteredHotInsertCombos := Map()
    RegisteredHotInsertAliasCombos := Map()
    HotInsertCallbacks := Map()
}

HotInsertCallback(id, *) {
    if !IsHotInsertContext()
        return
    InsertHotInsertById(id)
}

BuildHotInsertComboFromParts(useWin, useCtrl, useAlt, useShift, keyName) {
    keyName := NormalizeHotInsertKeyName(keyName)
    if (keyName = "")
        return ""
    combo := ""
    if useCtrl
        combo .= "^"
    if useAlt
        combo .= "!"
    if useShift
        combo .= "+"
    if useWin
        combo .= "#"
    return combo keyName
}

GetHotInsertKeyChoices() {
    static choices := "A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z|0|1|2|3|4|5|6|7|8|9|F1|F2|F3|F4|F5|F6|F7|F8|F9|F10|F11|F12|F13|F14|F15|F16|F17|F18|F19|F20|F21|F22|F23|F24|Numpad0|Numpad1|Numpad2|Numpad3|Numpad4|Numpad5|Numpad6|Numpad7|Numpad8|Numpad9|NumpadDot|NumpadDiv|NumpadMult|NumpadAdd|NumpadSub|Insert|Delete|Home|End|PgUp|PgDn|Up|Down|Left|Right|Tab|Space|Enter|Backspace|Esc"
    return choices
}

NormalizeHotInsertKeyName(value) {
    value := Trim(value)
    if (value = "")
        return ""

    compact := StrReplace(value, " ", "")
    lower := StrLower(compact)
    aliases := Map(
        "num0", "Numpad0", "num1", "Numpad1", "num2", "Numpad2", "num3", "Numpad3", "num4", "Numpad4",
        "num5", "Numpad5", "num6", "Numpad6", "num7", "Numpad7", "num8", "Numpad8", "num9", "Numpad9",
        "numpad0", "Numpad0", "numpad1", "Numpad1", "numpad2", "Numpad2", "numpad3", "Numpad3", "numpad4", "Numpad4",
        "numpad5", "Numpad5", "numpad6", "Numpad6", "numpad7", "Numpad7", "numpad8", "Numpad8", "numpad9", "Numpad9",
        "num.", "NumpadDot", "numpad.", "NumpadDot", "numpaddot", "NumpadDot",
        "num/", "NumpadDiv", "numpad/", "NumpadDiv", "numpaddiv", "NumpadDiv",
        "num*", "NumpadMult", "numpad*", "NumpadMult", "numpadmult", "NumpadMult",
        "num+", "NumpadAdd", "numpad+", "NumpadAdd", "numpadadd", "NumpadAdd",
        "num-", "NumpadSub", "numpad-", "NumpadSub", "numpadsub", "NumpadSub",
        "numpadins", "Numpad0", "numpadend", "Numpad1", "numpaddown", "Numpad2", "numpadpgdn", "Numpad3",
        "numpadleft", "Numpad4", "numpadclear", "Numpad5", "numpadright", "Numpad6", "numpadhome", "Numpad7",
        "numpadup", "Numpad8", "numpadpgup", "Numpad9", "numpaddel", "NumpadDot",
        "pgup", "PgUp", "pageup", "PgUp", "pgdn", "PgDn", "pagedown", "PgDn",
        "esc", "Esc", "escape", "Esc", "del", "Delete", "delete", "Delete", "ins", "Insert", "insert", "Insert",
        "bs", "Backspace", "bksp", "Backspace", "backspace", "Backspace", "space", "Space", "spacebar", "Space", "enter", "Enter", "return", "Enter",
        "up", "Up", "down", "Down", "left", "Left", "right", "Right", "home", "Home", "end", "End", "tab", "Tab"
    )
    if aliases.Has(lower)
        return aliases[lower]
    if RegExMatch(lower, "^f([1-9]|1[0-9]|2[0-4])$")
        return StrUpper(lower)
    if RegExMatch(compact, "i)^vk[0-9a-f]{2}$") || RegExMatch(compact, "i)^sc[0-9a-f]{3}$")
        return compact
    if (StrLen(compact) = 1)
        return StrUpper(compact)
    return compact
}

CanonicalizeHotInsertCombo(comboText) {
    comboText := Trim(StrReplace(comboText, "＋", "+"))
    if (comboText = "")
        return ""
    if RegExMatch(comboText, "i)\b(win|windows|winkey|cmd|meta|ctrl|control|ctl|alt|shift|ralt|right\s*alt|lalt|left\s*alt|rctrl|right\s*ctrl|right\s*control|lctrl|left\s*ctrl|left\s*control|rshift|right\s*shift|lshift|left\s*shift|rwin|right\s*win|lwin|left\s*win|alt\s*gr|altgr)\b")
        return CanonicalizeHumanHotInsertCombo(comboText)
    return CanonicalizeSymbolHotInsertCombo(comboText)
}

CanonicalizeHumanHotInsertCombo(comboText) {
    comboText := RegExReplace(comboText, "\s*\+\s*", "+")
    parts := StrSplit(comboText, "+")
    prefix := ""
    keyToken := ""
    for part in parts {
        token := Trim(part)
        if (token = "")
            continue
        tokenKey := StrLower(RegExReplace(token, "\s+", ""))
        if (tokenKey = "win" || tokenKey = "windows" || tokenKey = "winkey" || tokenKey = "cmd" || tokenKey = "meta")
            prefix .= "#"
        else if (tokenKey = "ctrl" || tokenKey = "control" || tokenKey = "ctl")
            prefix .= "^"
        else if (tokenKey = "alt")
            prefix .= "!"
        else if (tokenKey = "shift")
            prefix .= "+"
        else if (tokenKey = "ralt" || tokenKey = "rightalt")
            prefix .= ">!"
        else if (tokenKey = "lalt" || tokenKey = "leftalt")
            prefix .= "<!"
        else if (tokenKey = "rctrl" || tokenKey = "rightctrl" || tokenKey = "rightcontrol")
            prefix .= ">^"
        else if (tokenKey = "lctrl" || tokenKey = "leftctrl" || tokenKey = "leftcontrol")
            prefix .= "<^"
        else if (tokenKey = "rshift" || tokenKey = "rightshift")
            prefix .= ">+"
        else if (tokenKey = "lshift" || tokenKey = "leftshift")
            prefix .= "<+"
        else if (tokenKey = "rwin" || tokenKey = "rightwin" || tokenKey = "rightwindows")
            prefix .= ">#"
        else if (tokenKey = "lwin" || tokenKey = "leftwin" || tokenKey = "leftwindows")
            prefix .= "<#"
        else if (tokenKey = "altgr")
            prefix .= "<^>!"
        else
            keyToken := token
    }

    keyName := NormalizeHotInsertKeyName(keyToken)
    return (prefix != "" && keyName != "") ? prefix keyName : ""
}

CanonicalizeSymbolHotInsertCombo(comboText) {
    comboText := StrReplace(Trim(comboText), " ", "")
    prefix := ""
    loop {
        if (comboText = "")
            break
        if (SubStr(comboText, 1, 4) = "<^>!") {
            prefix .= "<^>!"
            comboText := SubStr(comboText, 5)
            continue
        }
        two := SubStr(comboText, 1, 2)
        if (two = ">!" || two = "<!" || two = ">^" || two = "<^" || two = ">+" || two = "<+" || two = ">#" || two = "<#") {
            prefix .= two
            comboText := SubStr(comboText, 3)
            continue
        }
        ch := SubStr(comboText, 1, 1)
        if (ch = "#" || ch = "^" || ch = "!" || ch = "+" || ch = "*" || ch = "~" || ch = "$") {
            prefix .= ch
            comboText := SubStr(comboText, 2)
            continue
        }
        break
    }
    keyName := NormalizeHotInsertKeyName(comboText)
    return (prefix != "" && keyName != "") ? prefix keyName : keyName
}

ParseHotInsertCombo(comboText) {
    combo := CanonicalizeHotInsertCombo(comboText)
    result := {Win: 0, Ctrl: 0, Alt: 0, Shift: 0, Key: "", Combo: combo, HasDirectional: false}
    if (combo = "")
        return result

    rest := combo
    loop {
        if (rest = "")
            break
        if (SubStr(rest, 1, 4) = "<^>!") {
            result.Ctrl := 1
            result.Alt := 1
            result.HasDirectional := true
            rest := SubStr(rest, 5)
            continue
        }
        two := SubStr(rest, 1, 2)
        if (two = ">!" || two = "<!") {
            result.Alt := 1
            result.HasDirectional := true
            rest := SubStr(rest, 3)
            continue
        }
        if (two = ">^" || two = "<^") {
            result.Ctrl := 1
            result.HasDirectional := true
            rest := SubStr(rest, 3)
            continue
        }
        if (two = ">+" || two = "<+") {
            result.Shift := 1
            result.HasDirectional := true
            rest := SubStr(rest, 3)
            continue
        }
        if (two = ">#" || two = "<#") {
            result.Win := 1
            result.HasDirectional := true
            rest := SubStr(rest, 3)
            continue
        }
        ch := SubStr(rest, 1, 1)
        if (ch = "#")
            result.Win := 1
        else if (ch = "^")
            result.Ctrl := 1
        else if (ch = "!")
            result.Alt := 1
        else if (ch = "+")
            result.Shift := 1
        else if (ch = "*" || ch = "~" || ch = "$") {
            rest := SubStr(rest, 2)
            continue
        } else
            break
        rest := SubStr(rest, 2)
    }
    result.Key := NormalizeHotInsertKeyName(rest)
    return result
}

GetAccentColorChoices() {
    ; Палитра акцентов подобрана под тёмный фон: достаточно ярких для заголовков,
    ; но не кислотных. Зелёный — новый дефолт.
    static choices := [
        {Name: "Зелёный", Hex: "5FD068"},
        {Name: "Жёлтый", Hex: "FFD700"},
        {Name: "Голубой", Hex: "4FC3F7"},
        {Name: "Оранжевый", Hex: "FFA94D"},
        {Name: "Розовый", Hex: "F48FB1"},
        {Name: "Мятный", Hex: "6FE3C1"}
    ]
    return choices
}

ApplyAccentColorFromGui(ctrl, *) {
    global ColorHighlight
    choices := GetAccentColorChoices()
    idx := 0
    try idx := ctrl.Value
    if (idx < 1 || idx > choices.Length)
        return
    ColorHighlight := choices[idx].Hex
    SaveSettingsInternal()
    ; Немедленно перекрасить то, что уже на экране: активную вкладку панели.
    try UpdateDictionaryViewUi()
    try {
        global DictHintText
        DictHintText.Text := "Акцент: " choices[idx].Name ". Новые окна используют его сразу; полный перекрас — после перезапуска."
    }
}

; --- Слоты Ctrl+1…9 ----------------------------------------------------------
; Слоты живут в общей системе горячих вставок (HotInsertDB, комбо "^1".."^9"),
; то есть видны и в панели на вкладке Горячие. Ctrl+0 показывает интерактивную
; сводку: клик по строке открывает мини-конструктор с уже подставленным комбо.
; Пассивный OSD подсказок для этого не годится (он не принимает фокус и клики),
; поэтому сводка — обычное тёмное окно в стилистике остальных диалогов.

ShowCtrlSlotsSummary() {
    global ColorHighlight, HotInsertDB
    static SlotsGui := 0
    try {
        if IsObject(SlotsGui) {
            SlotsGui.Destroy()
            SlotsGui := 0
        }
    }
    SlotsGui := Gui("+AlwaysOnTop +ToolWindow -MinimizeBox", "Ctrl+1…9 — быстрые вставки")
    SlotsGui.BackColor := "171717"
    SlotsGui.SetFont("s10 cF0F0F0", "Segoe UI")
    SlotsGui.MarginX := 14
    SlotsGui.MarginY := 12
    SlotsGui.Add("Text", "w460 h20 c" ColorHighlight, "Слоты Ctrl+цифра — клик по строке назначает или правит")
    Loop 9 {
        slotNum := A_Index
        slotId := GetHotInsertIdByCombo("^" slotNum)
        slotDesc := "— свободно —"
        if (slotId != "") {
            try slotDesc := TruncatePhraseForOSD(ResolveHotInsertText(HotInsertDB[slotId]), 52)
            try if (HotInsertDB[slotId].Label != "" && HotInsertDB[slotId].Label != "^" slotNum)
                slotDesc := HotInsertDB[slotId].Label ":  " slotDesc
        }
        CreateFlatTextButton(SlotsGui, "xm y+6 w460 h30", "Ctrl+" slotNum "    " slotDesc, EditCtrlSlotFromSummary.Bind(slotNum, SlotsGui))
    }
    SlotsGui.Add("Text", "xm y+10 w460 h18 c8E8E8E", "Esc — закрыть. Слоты также видны в панели F9 → Горячие.")
    SlotsGui.OnEvent("Escape", (*) => SlotsGui.Destroy())
    SlotsGui.OnEvent("Close", (*) => SlotsGui.Destroy())
    ApplyDarkThemeToGui(SlotsGui)
    SlotsGui.Show("AutoSize Center")
}

EditCtrlSlotFromSummary(slotNum, summaryGui, *) {
    try summaryGui.Destroy()
    slotId := GetHotInsertIdByCombo("^" slotNum)
    if (slotId != "")
        ShowHotInsertEditGui(slotId)
    else
        ShowHotInsertEditGui("", Map("Combo", "^" slotNum, "Label", "Ctrl+" slotNum))
}

ShowHotInsertEditGui(entryId := "", preset := 0) {
    global HotInsertDB, NextHotInsertId, ColorHighlight
    if !GuardTyperStartup()
        return

    isEdit := (entryId != "" && HotInsertDB.Has(entryId))
    labelText := ""
    comboText := ""
    insertText := ""
    if isEdit {
        labelText := HotInsertDB[entryId].Label
        comboText := HotInsertDB[entryId].Combo
        insertText := HotInsertDB[entryId].Text
    }
    if IsObject(preset) {
        try if preset.Has("Label")
            labelText := preset["Label"]
        try if preset.Has("Combo")
            comboText := preset["Combo"]
        try if preset.Has("Text")
            insertText := preset["Text"]
    }

    GuiObj := CreateTyperDialog("+AlwaysOnTop +ToolWindow -MinimizeBox", isEdit ? "Правка горячей вставки" : "Новая горячая вставка")
    GuiObj.BackColor := "171717"
    GuiObj.SetFont("s10 cF0F0F0", "Segoe UI")
    GuiObj.MarginX := 12
    GuiObj.MarginY := 10

    GuiObj.Add("Text", "w660 h20 c" ColorHighlight, "Мини-конструктор: собери хоткей в стиле AHK v2 или поправь готовую строку вручную.")
    GuiObj.Add("Text", "xm y+12 w112 h20", "Название:")
    LabelEdit := GuiObj.Add("Edit", "x128 yp-2 w532 h24 Background2D2D2D cF0F0F0")
    LabelEdit.Value := labelText

    GuiObj.Add("Text", "xm y+14 w112 h20", "Модификаторы:")
    CbWin := GuiObj.Add("CheckBox", "x128 yp w58 h22 cF0F0F0", "Win")
    CbCtrl := GuiObj.Add("CheckBox", "x190 yp w58 h22 cF0F0F0", "Ctrl")
    CbAlt := GuiObj.Add("CheckBox", "x252 yp w54 h22 cF0F0F0", "Alt")
    CbShift := GuiObj.Add("CheckBox", "x310 yp w62 h22 cF0F0F0", "Shift")
    GuiObj.Add("Text", "x392 yp+2 w48 h20", "Клавиша:")
    KeyCombo := GuiObj.Add("ComboBox", "x444 yp-2 w216 Choose1 Background2D2D2D cF0F0F0", StrSplit(GetHotInsertKeyChoices(), "|"))

    GuiObj.Add("Text", "xm y+14 w112 h20", "Итоговый hotkey:")
    ComboEdit := GuiObj.Add("Edit", "x128 yp-2 w532 h24 Background2D2D2D cF0F0F0")
    ComboEdit.Value := comboText

    GuiObj.Add("Text", "xm y+14 w112 h20", "Захват клавиши:")
    HotkeyCapture := GuiObj.Add("Hotkey", "x128 yp-2 w220 h24")
    try if (comboText != "")
        HotkeyCapture.Value := comboText
    HotkeyCapture.OnEvent("Change", (*) => HotkeyCaptureChanged())
    GuiObj.Add("Text", "x360 yp+2 w300 h20 cB0B0B0", "Поле ловит Ctrl/Alt/Shift. Win добавляется чекбоксом слева.")

    GuiObj.Add("Text", "xm y+14 w660 h32 cB0B0B0", "Пример: для Win+Numpad9 отметь Win и нажми Numpad9 в поле захвата либо выбери Numpad9 в списке выше. Итоговая строка соберётся в формате AHK v2 вроде #Numpad9.")
    GuiObj.Add("Text", "xm y+12 w112 h20", "Что вставлять:")
    TextEdit := GuiObj.Add("Edit", "xm y+6 w660 h125 +Multi +VScroll Background2D2D2D cF0F0F0")
    ApplyDarkControlTheme(TextEdit)
    TextEdit.Value := insertText
    comboSyncBusy := false

    ApplyComboToControls(comboValue) {
        if comboSyncBusy
            return
        comboSyncBusy := true
        parsed := ParseHotInsertCombo(comboValue)
        CbWin.Value := parsed.Win
        CbCtrl.Value := parsed.Ctrl
        CbAlt.Value := parsed.Alt
        CbShift.Value := parsed.Shift
        if (parsed.Key != "")
            KeyCombo.Text := parsed.Key
        ComboEdit.Value := (parsed.Combo != "") ? parsed.Combo : BuildHotInsertComboFromParts(CbWin.Value, CbCtrl.Value, CbAlt.Value, CbShift.Value, KeyCombo.Text)
        comboSyncBusy := false
    }

    UpdateComboPreview(*) {
        if comboSyncBusy
            return
        comboSyncBusy := true
        ComboEdit.Value := BuildHotInsertComboFromParts(CbWin.Value, CbCtrl.Value, CbAlt.Value, CbShift.Value, KeyCombo.Text)
        comboSyncBusy := false
    }

    HotkeyCaptureChanged() {
        if comboSyncBusy
            return
        captured := CanonicalizeHotInsertCombo(HotkeyCapture.Value)
        if (captured = "")
            return
        comboSyncBusy := true
        parsed := ParseHotInsertCombo(captured)
        if parsed.Ctrl
            CbCtrl.Value := 1
        if parsed.Alt
            CbAlt.Value := 1
        if parsed.Shift
            CbShift.Value := 1
        if (parsed.Key != "")
            KeyCombo.Text := parsed.Key
        ComboEdit.Value := (parsed.Combo != "") ? parsed.Combo : BuildHotInsertComboFromParts(CbWin.Value, CbCtrl.Value, CbAlt.Value, CbShift.Value, KeyCombo.Text)
        comboSyncBusy := false
    }
    CbWin.OnEvent("Click", UpdateComboPreview)
    CbCtrl.OnEvent("Click", UpdateComboPreview)
    CbAlt.OnEvent("Click", UpdateComboPreview)
    CbShift.OnEvent("Click", UpdateComboPreview)
    KeyCombo.OnEvent("Change", UpdateComboPreview)
    ComboEdit.OnEvent("Change", (*) => ApplyComboToControls(ComboEdit.Value))
    if (comboText != "")
        ApplyComboToControls(comboText)

    SaveBtn := CreateFlatTextButton(GuiObj, "xm y+14 w160 h34", isEdit ? "Сохранить" : "Добавить", SaveHotInsert)
    CancelBtn := CreateFlatTextButton(GuiObj, "x+m yp w120 h34", "Отмена", (*) => GuiObj.Destroy())
    GuiObj.OnEvent("Escape", (*) => GuiObj.Destroy())
    GuiObj.Show("AutoSize Center")
    SetEditCaretEnd(LabelEdit)

    SaveHotInsert(*) {
        global HotInsertDB, NextHotInsertId
        labelVal := Trim(LabelEdit.Value)
        comboVal := CanonicalizeHotInsertCombo(ComboEdit.Value)
        ComboEdit.Value := comboVal
        textVal := NormalizeHotInsertText(TextEdit.Value)
        if (comboVal = "") {
            ToolTip("⚠️ Укажи горячую клавишу")
            SetTimer(() => ToolTip(), -1200)
            return
        }
        if (textVal = "") {
            ToolTip("⚠️ Пустой текст вставки")
            SetTimer(() => ToolTip(), -1200)
            return
        }
        if (labelVal = "")
            labelVal := comboVal

        localId := entryId
        backup := 0
        if isEdit
            backup := HotInsertDB[localId].Clone()
        else {
            localId := NextHotInsertId
            NextHotInsertId += 1
        }

        HotInsertDB[localId] := {Label: labelVal, Combo: comboVal, Text: textVal}
        if !RegisterHotInsertEntry(localId) {
            if isEdit
                HotInsertDB[localId] := backup
            else
                HotInsertDB.Delete(localId)
            ToolTip("⚠️ Не удалось назначить хоткей. Проверь запись или конфликт.")
            SetTimer(() => ToolTip(), -1800)
            return
        }
        SaveHotInsertsInternal()
        try PopulateDictListView()
        GuiObj.Destroy()
    }
}

GetSelectedHotInsertIdFromPanel() {
    global DictActiveView, LV_Hotkeys, HotInsertDB
    if (DictActiveView != "HOTKEYS")
        return ""
    row := LV_Hotkeys.GetNext(0)
    if !row
        return ""
    rowCombo := LV_Hotkeys.GetText(row, 2)
    rowLabel := LV_Hotkeys.GetText(row, 1)
    for id, data in HotInsertDB {
        if (data.Combo = rowCombo && data.Label = rowLabel)
            return id
    }
    return ""
}

EditSelectedHotInsertFromPanel(guiObj := 0, *) {
    id := GetSelectedHotInsertIdFromPanel()
    if (id = "")
        return
    ShowHotInsertEditGui(id)
}

CreateHotInsertFromSelectedPhrase(*) {
    global DictActiveView, LV_Phrases
    if (DictActiveView != "PHRASES")
        return
    row := LV_Phrases.GetNext(0)
    if !row
        return
    text := LV_Phrases.GetText(row, 1)
    ShowHotInsertEditGui("", Map("Label", TruncatePhraseForOSD(text, 36), "Text", text))
}

CreateHotInsertFromSelectedPrompt(*) {
    global DictActiveView, LV_Prompts, DictPromptRowText
    if (DictActiveView != "PROMPTS")
        return
    row := LV_Prompts.GetNext(0)
    if !row
        return
    ; v13.17: полный текст промпта (раньше бралась 2-я колонка — счётчик «Исп.»).
    text := DictPromptRowText.Has(row) ? DictPromptRowText[row] : LV_Prompts.GetText(row, 1)
    ShowHotInsertEditGui("", Map("Label", TruncatePhraseForOSD(RegExReplace(text, "\s+", " "), 36), "Text", text))
}
; #EndRegion

; #Region 🗃️ ИНДЕКС ПРЕФИКСОВ
; Индекс нужен только для ускорения поиска кандидатов по префиксу.
; Основной словарь остаётся единым источником правды, а индекс лишь уменьшает
; число записей, которые нужно просматривать при каждом показе OSD.
RebuildPrefixIndexes() {
    global WordDB, PrefixIndex1, PrefixIndex2, WordIndexVersion
    WordIndexVersion += 1 ; v13.19: сброс кэша кандидатов (GetWordPrefixMatches)
    PrefixIndex1 := Map()
    PrefixIndex2 := Map()
    for key, _ in WordDB
        AddWordToPrefixIndexes(key)
}

AddWordToPrefixIndexes(key) {
    global PrefixIndex1, PrefixIndex2, WordIndexVersion
    WordIndexVersion += 1 ; v13.19
    PrefixIndexAdd(PrefixIndex1, PrefixIndex2, key, key)
}

RemoveWordFromPrefixIndexes(key) {
    global PrefixIndex1, PrefixIndex2, WordIndexVersion
    WordIndexVersion += 1 ; v13.19
    PrefixIndexRemove(PrefixIndex1, PrefixIndex2, key, key)
}

GetIndexedCandidates(prefix) {
    global PrefixIndex1, PrefixIndex2
    if (prefix = "")
        return Map()
    return PrefixIndexCandidates(PrefixIndex1, PrefixIndex2, prefix)
}

GetWordPrefixMatches(prefixLower) {
    ; v13.19: каждая следующая буква сужает ПРОШЛЫЙ результат, а не весь
    ; двухбуквенный бакет индекса (в большом словаре это тысячи слов на каждую
    ; букву). Кэш сбрасывается, когда в индекс добавлено слово (WordIndexVersion):
    ; удалённые слова отсеивает проверка WordDB.Has у вызывающего, а Hidden/
    ; Count/IsStem читаются заново при каждом показе.
    global WordIndexVersion, WordMatchCachePrefix, WordMatchCacheKeys, WordMatchCacheVersion
    qLen := StrLen(prefixLower)
    if (qLen = 0)
        return []
    prevLen := StrLen(WordMatchCachePrefix)
    cacheValid := (prevLen > 0 && WordMatchCacheVersion = WordIndexVersion && SubStr(prefixLower, 1, prevLen) == WordMatchCachePrefix)
    if (cacheValid && prevLen = qLen)
        return WordMatchCacheKeys
    matched := []
    if (cacheValid && prevLen < qLen) {
        for _, key in WordMatchCacheKeys {
            if (SubStr(key, 1, qLen) == prefixLower)
                matched.Push(key)
        }
    } else {
        for key, _ in GetIndexedCandidates(prefixLower) {
            if (SubStr(key, 1, qLen) == prefixLower)
                matched.Push(key)
        }
    }
    WordMatchCachePrefix := prefixLower
    WordMatchCacheKeys := matched
    WordMatchCacheVersion := WordIndexVersion
    return matched
}
; #EndRegion

; #Region 🗃️ ДАННЫЕ (ЛОГИНЫ / ПАРОЛИ / КАРТОЧКИ)
SanitizeDataField(text, keepSpaces := false) {
    text := StrReplace(text, "`r", keepSpaces ? "" : " ")
    text := StrReplace(text, "`n", keepSpaces ? "" : " ")
    if !keepSpaces
        text := RegExReplace(text, "\s+", " ")
    return Trim(text)
}

NormalizeDataPrefix(prefix) {
    prefix := StrLower(SanitizeDataField(prefix))
    return RegExReplace(prefix, "[^\wа-яё@\-\.]+", "")
}

GetDataSearchTokens(data) {
    tokens := Map()

    AddTokenValue(value) {
        if (value = "")
            return
        value := StrLower(value)
        tokenized := RegExReplace(value, "[^0-9a-zа-яё@._\-]+", " ")
        Loop Parse, tokenized, " " {
            token := Trim(A_LoopField)
            if (token = "")
                continue
            tokens[token] := true

            splitMore := RegExReplace(token, "[@._\-]+", " ")
            if (splitMore != token) {
                Loop Parse, splitMore, " " {
                    part := Trim(A_LoopField)
                    if (part != "")
                        tokens[part] := true
                }
            }
        }
    }

    AddTokenValue(data.Key)
    AddTokenValue(data.Login)
    AddTokenValue(data.Note)
    AddTokenValue(data.Aliases)
    return tokens
}

GetDataSearchBlob(data) {
    blob := ""
    for token, _ in GetDataSearchTokens(data)
        blob .= token " "
    return Trim(blob)
}

RebuildDataIndexes() {
    global DataDB, DataIndex1, DataIndex2, NextDataId
    DataIndex1 := Map()
    DataIndex2 := Map()
    maxSeenId := 0

    for id, data in DataDB {
        AddDataToIndexes(id)
        try {
            numericId := Integer(id)
            if (numericId > maxSeenId)
                maxSeenId := numericId
        }
    }

    NextDataId := maxSeenId + 1
    if (NextDataId < 1)
        NextDataId := 1
}

AddDataToIndexes(id) {
    global DataDB, DataIndex1, DataIndex2
    if !DataDB.Has(id)
        return
    for token, _ in GetDataSearchTokens(DataDB[id])
        PrefixIndexAdd(DataIndex1, DataIndex2, token, id)
}

RemoveDataFromIndexes(id) {
    global DataIndex1, DataIndex2
    PrefixIndexRemoveAllForValue(DataIndex1, DataIndex2, id)
}

GetDataIndexedCandidates(prefix) {
    global DataDB, DataIndex1, DataIndex2
    prefix := NormalizeDataPrefix(prefix)
    if (prefix = "") {
        candidates := Map()
        for id, _ in DataDB
            candidates[id] := true
        return candidates
    }
    return PrefixIndexCandidates(DataIndex1, DataIndex2, prefix)
}

MaskDataLogin(login, maxLen := 32) {
    ; v13.16: логин больше не маскируем — показываем целиком. Слишком длинный
    ; режем посередине, чтобы были видны и начало, и домен.
    login := SanitizeDataField(login, true)
    if (login = "")
        return "—"
    if (StrLen(login) <= maxLen)
        return login
    headLen := Ceil((maxLen - 1) * 0.6)
    tailLen := maxLen - 1 - headLen
    return SubStr(login, 1, headLen) "…" SubStr(login, -tailLen)
}

TruncateDataText(text, maxLen := 22) {
    if (StrLen(text) <= maxLen)
        return text
    return SubStr(text, 1, maxLen - 1) "…"
}

MaskDataPasswordSparse(password, maxLen := 7) {
    ; v13.16: короткий намёк — каждый второй символ, не больше maxLen знаков
    ; (Qwerty123 → Q.e.t.1…). Многоточие — только если пароль длиннее.
    global DataPasswordsHidden
    password := SanitizeDataField(password, true)
    if (password = "")
        return ""
    if DataPasswordsHidden ; v13.22: скрытный режим — ни символов, ни длины
        return "•••"
    out := ""
    Loop Parse, password {
        if (StrLen(out) >= maxLen) {
            out .= "…"
            break
        }
        out .= (Mod(A_Index, 2) = 1) ? A_LoopField : "."
    }
    return out
}

GetDataInsertText(data) {
    ; Если есть логин — вставляем логин, а пароль кладём в буфер.
    ; Если логина нет, но есть пароль — это одиночная запись/свалка: вставляем сам пароль и буфер не трогаем.
    return data.Login != "" ? data.Login : (data.Password != "" ? data.Password : data.Key)
}

ShouldCopyDataPassword(data) {
    return (data.Login != "" && data.Password != "")
}

BuildDataDisplay(data) {
    ; v13.16: логин целиком (до 32 символов), пароль — короткий намёк.
    ; Если ключа нет, заголовком уже служит логин — второй раз его не повторяем.
    loginAsTitle := (data.Key = "" && data.Login != "")
    title := data.Key != "" ? data.Key : (data.Login != "" ? data.Login : (data.Password != "" ? "пароль" : "данные"))
    title := loginAsTitle ? MaskDataLogin(title) : TruncateDataText(title, 24)

    preview := ""
    if (data.Login != "" && !loginAsTitle)
        preview := MaskDataLogin(data.Login)
    if (data.Password != "")
        preview .= (preview != "" ? " · " : "") "🔒 " MaskDataPasswordSparse(data.Password)
    if (preview = "")
        preview := "—"

    notePreview := data.Note != "" ? " · " TruncateDataText(data.Note, 18) : ""
    return title " → " preview notePreview
}

GetNextDataId() {
    global NextDataId
    id := "" NextDataId
    NextDataId += 1
    return id
}

CreateDataRecord(keyText := "", loginText := "", passwordText := "", noteText := "", aliasesText := "", count := 1, isPile := 0, hidden := 0, autoInsert := 0) {
    return {
        Key: SanitizeDataField(keyText),
        Login: SanitizeDataField(loginText, true),
        Password: SanitizeDataField(passwordText, true),
        Note: SanitizeDataField(noteText),
        Aliases: SanitizeDataField(aliasesText),
        Count: Max(1, count),
        IsPile: !!isPile,
        Hidden: !!hidden,
        AutoInsert: !!autoInsert
    }
}

SaveDataInternal() {
    global DataFile
    return SaveEncryptedContainer(DataFile, LoadDataPlainText(), "data")
}

LoadDataInternal() {
    global DataDB, DataFile, NextDataId
    DataDB := Map()
    NextDataId := 1
    LoadEncryptedContainer(DataFile, "data", ParseDataLine)
    RebuildDataIndexes()
}

ParseDataLine(line) {
    global DataDB
    parts := StrSplit(line, "|")
    if (parts.Length < 9)
        return
    id := parts[1]
    count := Integer(parts[2])
    hidden := Integer(parts[3])
    isPile := Integer(parts[4])
    data := CreateDataRecord(
        DecodePhraseText(parts[5]),
        DecodePhraseText(parts[6]),
        DecodePhraseText(parts[7]),
        DecodePhraseText(parts[8]),
        DecodePhraseText(parts[9]),
        count,
        isPile,
        hidden,
        (parts.Length >= 10 ? Integer(parts[10]) : 0)
    )
    DataDB[id] := data
}

LoadDataPlainText() {
    global DataDB
    out := ""
    for id, data in DataDB {
        out .= id "|" data.Count "|" (data.Hidden ? 1 : 0) "|" (data.IsPile ? 1 : 0) "|"
            . EncodePhraseText(data.Key) "|" EncodePhraseText(data.Login) "|" EncodePhraseText(data.Password) "|"
            . EncodePhraseText(data.Note) "|" EncodePhraseText(data.Aliases) "|" (data.HasOwnProp("AutoInsert") && data.AutoInsert ? 1 : 0) "`n"
    }
    return out
}

DataRecordMatchesPrefix(data, prefix) {
    prefix := NormalizeDataPrefix(prefix)
    if (prefix = "")
        return true

    tokens := GetDataSearchTokens(data)
    for token, _ in tokens {
        if (SubStr(token, 1, StrLen(prefix)) = prefix)
            return true
    }
    return false
}

SortDataRows(rows) {
    return SortRowsInPlace(rows, DataRowComparator)
}

GetTopDataMatches(prefix := "") {
    global DataDB, MaxDataItems
    rows := []
    candidates := GetDataIndexedCandidates(prefix)

    for id, _ in candidates {
        if !DataDB.Has(id)
            continue
        data := DataDB[id]
        if (data.Hidden)
            continue
        if !DataRecordMatchesPrefix(data, prefix)
            continue

        rows.Push({
            Id: id,
            Display: BuildDataDisplay(data),
            Count: data.Count,
            Key: data.Key,
            Login: data.Login,
            Password: data.Password,
            Note: data.Note,
            Aliases: data.Aliases,
            IsPile: data.IsPile,
            AutoInsert: (data.HasOwnProp("AutoInsert") && data.AutoInsert)
        })
    }

    if (rows.Length > 1)
        rows := SortDataRows(rows)

    if (rows.Length > MaxDataItems)
        rows.Length := MaxDataItems

    return rows
}

FindExistingPileDataIdByLogin(loginText) {
    global DataDB
    loginKey := StrLower(SanitizeDataField(loginText, true))
    if (loginKey = "")
        return ""

    for id, data in DataDB {
        if (!data.IsPile)
            continue
        if (StrLower(data.Login) = loginKey)
            return id
    }
    return ""
}

EnsureDataEntryForWord(wordText) {
    global DataDB, WordDB
    wordText := SanitizeDataField(wordText, true)
    if (wordText = "")
        return ""

    wordKey := StrLower(wordText)
    if WordDB.Has(wordKey) {
        WordDB[wordKey].DataOnly := 1
        WordDB[wordKey].Hidden := 0
    }

    existingId := FindExistingPileDataIdByLogin(wordText)
    if (existingId != "") {
        DataDB[existingId].Count += 1
        QueueDataSave()
        return existingId
    }

    newId := GetNextDataId()
    DataDB[newId] := CreateDataRecord("", wordText, "", "", wordText, 1, 1, 0)
    AddDataToIndexes(newId)
    QueueDataSave()
    return newId
}

RedirectSuggestedWordToDataByIndex(index) {
    global CurrentSuggestionMode, CurrentWords, WordDB
    if (CurrentSuggestionMode != "WORDS")
        return
    if (index < 1 || index > CurrentWords.Length)
        return

    word := CurrentWords[index].Display
    key := StrLower(word)
    if WordDB.Has(key)
        WordDB[key].DataOnly := 1

    EnsureDataEntryForWord(word)
    ToolTip("🗃️ Перенаправлено в Данные")
    SetTimer(() => ToolTip(), -1300)
    ShowSuggestions()
}

IsDataSecretClipboardActive() {
    global LastDataClipboardStamp
    return LastDataClipboardStamp != 0
}

ClearSecretClipboardState(reason := "") {
    global LastDataClipboardStamp, LastDataClipboardExpected, LastDataClipboardBackup, LastDataClipboardPasteSeenStamp
    LastDataClipboardStamp := 0
    LastDataClipboardExpected := ""
    LastDataClipboardBackup := 0
    LastDataClipboardPasteSeenStamp := 0
    SetTimer(WatchSecretClipboardPasteKeys, 0)
}

RestoreSecretClipboardIfStillCurrent(expectedText := "", stamp := 0, reason := "timer", *) {
    global LastDataClipboardStamp, LastDataClipboardExpected, LastDataClipboardBackup
    if (stamp = 0)
        stamp := LastDataClipboardStamp
    if (expectedText = "")
        expectedText := LastDataClipboardExpected
    if (stamp = 0 || LastDataClipboardStamp != stamp || expectedText = "")
        return false

    try {
        ; Восстанавливаем только если пользователь за это время не скопировал что-то новое.
        ; Если буфер уже отличается от нашего временного пароля — не трогаем его.
        if (A_Clipboard !== expectedText) { ; v13.22: с учётом регистра (!= в v2 регистронезависим)
            ClearSecretClipboardState("changed-before-" reason)
            return false
        }

        if IsObject(LastDataClipboardBackup) {
            A_Clipboard := LastDataClipboardBackup
        } else {
            A_Clipboard := ""
        }
        ClearSecretClipboardState()
        return true
    } catch as e {
        ClearSecretClipboardState("restore-failed")
        return false
    }
}

ScheduleSecretClipboardRestoreAfterPaste(delayMs := 0, source := "paste", *) {
    global LastDataClipboardStamp, DataClipboardRestoreAfterPasteMs
    stamp := LastDataClipboardStamp
    if (stamp = 0)
        return
    if (delayMs <= 0)
        delayMs := DataClipboardRestoreAfterPasteMs
    ; Даём приложению время реально принять Ctrl+V / Shift+Insert, потом возвращаем прежний буфер.
    ; Важно: если вставка пришла через F15, другой AHK-скрипт сначала обрабатывает F15 и
    ; только затем шлёт Ctrl+V, поэтому для F15 используем отдельную более длинную задержку.
    SetTimer(RestoreSecretClipboardAfterPaste.Bind(stamp, source), -Abs(delayMs))
}

ScheduleSecretClipboardRestoreAfterF15(*) {
    global DataClipboardRestoreAfterF15Ms
    MarkSecretClipboardPasteIntent("f15-hotkey", DataClipboardRestoreAfterF15Ms)
}

StartSecretClipboardPasteWatcher() {
    global DataClipboardPastePollMs
    ; Некоторые пользователи вставляют пароль через F15, который обрабатывается другим AHK-скриптом.
    ; Если тот скрипт перехватывает F15 без ~ или срабатывает раньше, наш hotkey F15 может не увидеть событие.
    ; Поэтому на время жизни временного пароля дополнительно опрашиваем физическое состояние клавиш.
    SetTimer(WatchSecretClipboardPasteKeys, Abs(DataClipboardPastePollMs))
}

MarkSecretClipboardPasteIntent(source := "paste", delayMs := 0) {
    global LastDataClipboardStamp, LastDataClipboardPasteSeenStamp, DataClipboardRestoreAfterPasteMs
    stamp := LastDataClipboardStamp
    if (stamp = 0)
        return false
    if (LastDataClipboardPasteSeenStamp = stamp)
        return false
    LastDataClipboardPasteSeenStamp := stamp
    if (delayMs <= 0)
        delayMs := DataClipboardRestoreAfterPasteMs
    ScheduleSecretClipboardRestoreAfterPaste(delayMs, source)
    return true
}

WatchSecretClipboardPasteKeys(*) {
    global LastDataClipboardStamp, LastDataClipboardPasteSeenStamp, DataClipboardRestoreAfterPasteMs, DataClipboardRestoreAfterF15Ms
    if (LastDataClipboardStamp = 0) {
        SetTimer(WatchSecretClipboardPasteKeys, 0)
        return
    }
    if (LastDataClipboardPasteSeenStamp = LastDataClipboardStamp)
        return

    ctrlDown := GetKeyState("LControl", "P") || GetKeyState("RControl", "P")
    shiftDown := GetKeyState("LShift", "P") || GetKeyState("RShift", "P")

    ; Физический F15 ловим polling-ом: это спасает, если отдельный paste-скрипт съел F15-hotkey.
    if GetKeyState("F15", "P") {
        MarkSecretClipboardPasteIntent("f15-poll", DataClipboardRestoreAfterF15Ms)
        return
    }

    ; На всякий случай polling-ом ловим и обычные paste-сочетания, если #HotIf-hotkey не сработал.
    if (ctrlDown && GetKeyState("vk56", "P")) {
        MarkSecretClipboardPasteIntent("ctrl-v-poll", DataClipboardRestoreAfterPasteMs)
        return
    }

    if (shiftDown && (GetKeyState("Insert", "P") || GetKeyState("NumpadIns", "P"))) {
        MarkSecretClipboardPasteIntent("shift-insert-poll", DataClipboardRestoreAfterPasteMs)
        return
    }
}

RestoreSecretClipboardAfterPaste(stamp, source := "paste", *) {
    global LastDataClipboardStamp, LastDataClipboardExpected
    if (stamp = 0 || LastDataClipboardStamp != stamp)
        return
    RestoreSecretClipboardIfStillCurrent(LastDataClipboardExpected, stamp, source)
}

FindAutoDataPrefixOwner(prefixText, excludeId := "") {
    global DataDB
    prefixKey := NormalizeDataPrefix(prefixText)
    if (prefixKey = "")
        return ""
    for id, data in DataDB {
        if (excludeId != "" && id = excludeId)
            continue
        if !(data.HasOwnProp("AutoInsert") && data.AutoInsert)
            continue
        if (NormalizeDataPrefix(data.Key) = prefixKey)
            return id
    }
    return ""
}

TryAutoConfirmDataByPrefix() {
    global CurrentInput, CurrentDataItems, MinAutoInsertPrefixLen
    if !IsDataTriggerInput(CurrentInput) || StrLen(CurrentInput) < 2
        return false
    prefix := NormalizeDataPrefix(SubStr(CurrentInput, 2))
    if (prefix = "")
        return false
    ; Иммунитет коротких префиксов: автовставка срабатывает только от 3 символов.
    ; Иначе *pr с кучей акков на "pr" мгновенно вставлял бы первый попавшийся.
    ; Правило действует и для старых записей в базе с коротким ключом.
    if (StrLen(prefix) < MinAutoInsertPrefixLen)
        return false
    CurrentDataItems := GetTopDataMatches(prefix)
    for idx, item in CurrentDataItems {
        if (item.HasOwnProp("AutoInsert") && item.AutoInsert && NormalizeDataPrefix(item.Key) = prefix) {
            ConfirmDataSelection(idx)
            return true
        }
    }
    ; Если кандидат ровно один и его ключ совпадает с набранным префиксом целиком,
    ; вставляем и без флага автовставки: занёс один логин с префиксом — он и вставляется.
    if (CurrentDataItems.Length = 1 && NormalizeDataPrefix(CurrentDataItems[1].Key) = prefix) {
        ConfirmDataSelection(1)
        return true
    }
    return false
}

; v13.16: кладём текст в буфер с пометками Windows «не сохранять в журнал Win+V,
; не синхронизировать в облако, не отдавать менеджерам буфера» — так делают
; KeePass и Bitwarden. При любой ошибке возвращаем false, и вызывающий код
; пишет буфер обычным способом.
SetClipboardTextExcludedFromHistory(text) {
    static fmtExclude := DllCall("RegisterClipboardFormatW", "Str", "ExcludeClipboardContentFromMonitorProcessing", "UInt")
    static fmtViewerIgnore := DllCall("RegisterClipboardFormatW", "Str", "Clipboard Viewer Ignore", "UInt")
    static fmtHistory := DllCall("RegisterClipboardFormatW", "Str", "CanIncludeInClipboardHistory", "UInt")
    static fmtCloud := DllCall("RegisterClipboardFormatW", "Str", "CanUploadToCloudClipboard", "UInt")
    if (text = "")
        return false

    opened := false
    Loop 10 {
        if DllCall("OpenClipboard", "Ptr", A_ScriptHwnd) {
            opened := true
            break
        }
        Sleep(15)
    }
    if !opened
        return false

    ok := false
    try {
        if !DllCall("EmptyClipboard")
            return false
        hText := DllCall("GlobalAlloc", "UInt", 0x0042, "UPtr", (StrLen(text) + 1) * 2, "Ptr")
        if !hText
            return false
        pText := DllCall("GlobalLock", "Ptr", hText, "Ptr")
        if !pText {
            DllCall("GlobalFree", "Ptr", hText)
            return false
        }
        StrPut(text, pText, "UTF-16")
        DllCall("GlobalUnlock", "Ptr", hText)
        if !DllCall("SetClipboardData", "UInt", 13, "Ptr", hText, "Ptr") { ; CF_UNICODETEXT
            DllCall("GlobalFree", "Ptr", hText)
            return false
        }
        PutClipboardDwordFormat(fmtExclude, 0)
        PutClipboardDwordFormat(fmtViewerIgnore, 0)
        PutClipboardDwordFormat(fmtHistory, 0)
        PutClipboardDwordFormat(fmtCloud, 0)
        ok := true
    } finally {
        DllCall("CloseClipboard")
    }
    return ok
}

PutClipboardDwordFormat(fmt, value) {
    ; Вызывать только при открытом буфере обмена.
    if !fmt
        return false
    hMem := DllCall("GlobalAlloc", "UInt", 0x0042, "UPtr", 4, "Ptr")
    if !hMem
        return false
    pMem := DllCall("GlobalLock", "Ptr", hMem, "Ptr")
    if !pMem {
        DllCall("GlobalFree", "Ptr", hMem)
        return false
    }
    NumPut("UInt", value, pMem)
    DllCall("GlobalUnlock", "Ptr", hMem)
    if !DllCall("SetClipboardData", "UInt", fmt, "Ptr", hMem, "Ptr") {
        DllCall("GlobalFree", "Ptr", hMem)
        return false
    }
    return true
}

CopySecretToClipboard(passwordText) {
    global LastDataClipboardStamp, LastDataClipboardExpected, LastDataClipboardBackup, LastDataClipboardPasteSeenStamp, DataClipboardAutoClearMs, DataClipboardSequence
    passwordText := SanitizeDataField(passwordText, true)
    if (passwordText = "")
        return false

    ; Если прошлый пароль всё ещё лежит в буфере — сперва вернём то, что было до него.
    ; Если пользователь уже скопировал что-то новое — просто сбросим старое ожидание.
    if IsDataSecretClipboardActive()
        RestoreSecretClipboardIfStillCurrent(LastDataClipboardExpected, LastDataClipboardStamp, "replace")

    savedClip := 0
    try savedClip := ClipboardAll()
    catch {
        savedClip := 0
    }

    try {
        ; v13.16: пароль не должен оседать в журнале Win+V и облачном буфере.
        ; Если пометить не удалось — обычная запись, как раньше.
        if !SetClipboardTextExcludedFromHistory(passwordText) {
            A_Clipboard := ""
            Sleep(20)
            A_Clipboard := passwordText
        }
        if !ClipWait(0.75)
            throw Error("ClipWait timeout")
        if (A_Clipboard !== passwordText)
            throw Error("clipboard verify mismatch")

        DataClipboardSequence += 1
        LastDataClipboardStamp := DataClipboardSequence
        LastDataClipboardExpected := passwordText
        LastDataClipboardBackup := savedClip
        LastDataClipboardPasteSeenStamp := 0
        StartSecretClipboardPasteWatcher()
        if (DataClipboardAutoClearMs > 0)
            SetTimer(RestoreSecretClipboardIfStillCurrent.Bind(passwordText, LastDataClipboardStamp, "timeout"), -Abs(DataClipboardAutoClearMs))
        return true
    } catch {
        try {
            if IsObject(savedClip)
                A_Clipboard := savedClip
        }
        ClearSecretClipboardState("copy-failed")
        return false
    }
}

OpenDataCardGui(dataId := "", options := 0) {
    global DataDB, CurrentInput, ColorHighlight
    if !GuardTyperStartup()
        return
    editing := (dataId != "" && DataDB.Has(dataId))

    prefillKey := ""
    prefillLogin := ""
    prefillPassword := ""
    prefillNote := ""
    prefillAliases := ""
    prefillPile := 0
    prefillAutoInsert := 0
    prefillFocusKey := 0

    if editing {
        data := DataDB[dataId]
        prefillKey := data.Key
        prefillLogin := data.Login
        prefillPassword := data.Password
        prefillNote := data.Note
        prefillAliases := data.Aliases
        prefillPile := data.IsPile
        prefillAutoInsert := data.HasOwnProp("AutoInsert") ? data.AutoInsert : 0
    } else if IsObject(options) {
        try prefillKey := options.Has("Key") ? options["Key"] : ""
        try prefillLogin := options.Has("Login") ? options["Login"] : ""
        try prefillPassword := options.Has("Password") ? options["Password"] : ""
        try prefillNote := options.Has("Note") ? options["Note"] : ""
        try prefillAliases := options.Has("Aliases") ? options["Aliases"] : ""
        try prefillPile := options.Has("IsPile") ? options["IsPile"] : 0
        try prefillAutoInsert := options.Has("AutoInsert") ? options["AutoInsert"] : 0
        try prefillFocusKey := options.Has("FocusKey") ? options["FocusKey"] : 0
    }

    if (!editing && prefillLogin = "" && CurrentInput != "" && SubStr(CurrentInput, 1, 1) != "*" && !IsSnippetTriggerInput(CurrentInput))
        prefillLogin := CurrentInput

    DataGui := CreateTyperDialog("+AlwaysOnTop -MinimizeBox", editing ? "Данные — правка" : "Данные — новая запись")
    DataGui.BackColor := "171717"
    DataGui.SetFont("s10 cF0F0F0", "Segoe UI")
    DataGui.MarginX := 12
    DataGui.MarginY := 10
    DataGui.OnEvent("Escape", (*) => DataGui.Destroy())

    DataGui.Add("Text", "w520 h20 c" ColorHighlight, editing ? "Карточка данных" : "Новая запись в Данные")
    DataGui.Add("Text", "w520 h18 y+2 c8E8E8E", "Ключ/префикс помогает искать по *pr, *mail и т.п. Для временной свалки можно оставить пустым.")
    DataGui.Add("Text", "xm y+8 w520 h1 Background303030", "")

    DataGui.Add("Text", "xm y+10 w520 h18 cAFAFAF", "Ключ / префикс")
    EdKey := DataGui.Add("Edit", "xm y+4 w520 h26 Background2D2D2D cF0F0F0")
    EdKey.Value := prefillKey

    DataGui.Add("Text", "xm y+10 w520 h18 cAFAFAF", "Логин / вставка")
    EdLogin := DataGui.Add("Edit", "xm y+4 w520 h26 Background2D2D2D cF0F0F0")
    EdLogin.Value := prefillLogin

    DataGui.Add("Text", "xm y+10 w520 h18 cAFAFAF", "Пароль")
    EdPass := DataGui.Add("Edit", "xm y+4 w520 h26 Background2D2D2D cF0F0F0" (DataPasswordsHidden ? " Password" : ""))
    EdPass.Value := prefillPassword

    DataGui.Add("Text", "xm y+10 w520 h18 cAFAFAF", "Описание")
    EdNote := DataGui.Add("Edit", "xm y+4 w520 h26 Background2D2D2D cF0F0F0")
    EdNote.Value := prefillNote

    DataGui.Add("Text", "xm y+10 w520 h18 cAFAFAF", "Алиасы / доп. слова поиска")
    EdAliases := DataGui.Add("Edit", "xm y+4 w520 h26 Background2D2D2D cF0F0F0")
    EdAliases.Value := prefillAliases
    DataGui.Add("Text", "xm y+4 w520 h30 c8E8E8E", "Только слова для поиска (например proton mail work forum): помогают находить карточку по *prefix, но сами не вставляются.")

    DataGui.Add("Text", "xm y+10 w520 h1 Background303030", "")
    CbPile := DataGui.Add("CheckBox", "xm y+10 w520 h20 cF0F0F0 Checked" (prefillPile ? 1 : 0), "Оставить в общей свалке (*)")
    CbAutoInsert := DataGui.Add("CheckBox", "xm y+8 w520 h20 cF0F0F0 Checked" (prefillAutoInsert ? 1 : 0), "Автовставка по точному префиксу")
    DataGui.Add("Text", "xm y+4 w520 h30 c8E8E8E", "Если включено, *pra сразу вставит логин и положит пароль в буфер. Префикс: минимум 3 символа, уникальный среди автовставок.")

    DataGui.Add("Text", "xm y+10 w520 h1 Background303030", "")
    BtnSave := CreateFlatTextButton(DataGui, "xm y+12 w150 h32", "Сохранить", SaveDataCard)
    BtnCancel := CreateFlatTextButton(DataGui, "x+12 yp w110 h32", "Отмена", (*) => DataGui.Destroy())
    BtnDelete := CreateFlatTextButton(DataGui, "x+118 yp w130 h32", "Удалить запись", DeleteDataCard)
    HiddenDefaultBtn := DataGui.Add("Button", "x0 y0 w0 h0 Hidden Default", "OK")
    HiddenDefaultBtn.OnEvent("Click", SaveDataCard)
    if !editing
        BtnDelete.Visible := false

    ApplyDarkThemeToGui(DataGui)
    DataGui.Show("AutoSize Center")
    SetEditCaretEnd((editing || prefillFocusKey) ? EdKey : EdLogin)

    SaveDataCard(*) {
        global DataDB, MinAutoInsertPrefixLen
        keyValue := SanitizeDataField(EdKey.Value)
        loginValue := SanitizeDataField(EdLogin.Value, true)
        passValue := SanitizeDataField(EdPass.Value, true)
        noteValue := SanitizeDataField(EdNote.Value)
        aliasesValue := SanitizeDataField(EdAliases.Value)
        pileValue := !!CbPile.Value
        autoInsertValue := !!CbAutoInsert.Value

        if (autoInsertValue) {
            if (NormalizeDataPrefix(keyValue) = "") {
                ToolTip("⚠️ Для автовставки нужен непустой уникальный префикс")
                SetTimer(() => ToolTip(), -1600)
                return
            }
            if (StrLen(NormalizeDataPrefix(keyValue)) < MinAutoInsertPrefixLen) {
                ToolTip("⚠️ Префикс автовставки должен быть не короче " MinAutoInsertPrefixLen " символов")
                SetTimer(() => ToolTip(), -1800)
                return
            }
            ownerId := FindAutoDataPrefixOwner(keyValue, editing ? dataId : "")
            if (ownerId != "") {
                ; Префикс можно забрать у другой карточки, но только после наглядной сверки.
                owner := DataDB[ownerId]
                confirmMsg := "Префикс *" NormalizeDataPrefix(keyValue) " уже занят автовставкой другой карточки:`n`n"
                    . "Ключ:      " owner.Key "`n"
                    . "Логин:     " owner.Login "`n"
                    . "Описание:  " owner.Note "`n"
                    . "Алиасы:    " owner.Aliases "`n`n"
                    . "Забрать префикс для текущей карточки? У той карточки автовставка будет выключена."
                if (MsgBox(confirmMsg, "Typer — префикс занят", 0x34 + 0x40000) != "Yes")
                    return
                DataDB[ownerId].AutoInsert := 0
            }
        }

        if (keyValue = "" && loginValue = "" && passValue = "" && noteValue = "" && aliasesValue = "") {
            ToolTip("⚠️ Нечего сохранять")
            SetTimer(() => ToolTip(), -1200)
            return
        }

        if editing {
            RemoveDataFromIndexes(dataId)
            DataDB[dataId] := CreateDataRecord(keyValue, loginValue, passValue, noteValue, aliasesValue, DataDB[dataId].Count, pileValue, 0, autoInsertValue)
            AddDataToIndexes(dataId)
        } else {
            newId := GetNextDataId()
            DataDB[newId] := CreateDataRecord(keyValue, loginValue, passValue, noteValue, aliasesValue, 1, pileValue, 0, autoInsertValue)
            AddDataToIndexes(newId)
        }

        QueueDataSave()
        PopulateDictListView()
        if (CurrentInput != "")
            ShowSuggestions()
        DataGui.Destroy()
        ToolTip("✅ Данные сохранены")
        SetTimer(() => ToolTip(), -1100)
    }

    DeleteDataCard(*) {
        global DataDB
        if !editing
            return
        if DataDB.Has(dataId) {
            DataDB.Delete(dataId)
            RemoveDataFromIndexes(dataId)
            QueueDataSave()
            PopulateDictListView()
            if (CurrentInput != "")
                ShowSuggestions()
        }
        DataGui.Destroy()
        ToolTip("🗑️ Запись удалена")
        SetTimer(() => ToolTip(), -1100)
    }
}

OpenDataCardFromHotkey(*) {
    ; Win+* (Win+Shift+8 / Win+NumpadMult): единое окно добавления в Данные.
    ; Если выделено "login123 passw0rd [описание]" — поля заполняются автоматически
    ; и каретка ставится в "Ключ / префикс". Если выделения нет — пустая карточка.
    ; Защита: многострочное или слишком длинное выделение НЕ считаем парой
    ; логин/пароль (некоторые редакторы по Ctrl+C без выделения копируют всю
    ; строку — такой мусор в карточку не тянем).
    selectedText := Trim(GetSelectedTextViaClipboard(0.35), " `t`r`n")
    if (selectedText != "" && !InStr(selectedText, "`n") && StrLen(selectedText) <= 200) {
        parts := StrSplit(RegExReplace(selectedText, "\s+", " "), " ")
        loginText := parts.Length >= 1 ? parts[1] : ""
        passText := parts.Length >= 2 ? parts[2] : ""
        noteText := ""
        if (parts.Length > 2) {
            Loop parts.Length - 2
                noteText .= (A_Index > 1 ? " " : "") parts[A_Index + 2]
        }
        OpenDataCardGui("", Map("Login", loginText, "Password", passText, "Note", noteText, "FocusKey", true))
        return
    }
    OpenDataCardGui()
}

OpenSelectedDataFromOsd(index) {
    global CurrentSuggestionMode, CurrentDataItems, WordDigitLiteralMode
    if (CurrentSuggestionMode != "DATA")
        return
    if (index < 1 || index > CurrentDataItems.Length)
        return
    OpenDataCardGui(CurrentDataItems[index].Id)
}

ConfirmDataSelection(index) {
    global CurrentDataItems, CurrentInput, DataDB, DataClipboardAutoClearMs

    if (index < 1 || index > CurrentDataItems.Length)
        return

    item := CurrentDataItems[index]
    insertText := item.Login != "" ? item.Login : (item.Password != "" ? item.Password : item.Key)
    if (insertText = "")
        return

    shouldCopy := (item.Login != "" && item.Password != "")
    copied := shouldCopy ? CopySecretToClipboard(item.Password) : false
    backspaces := GetTypedBackspaceCount()
    HideSuggestions()
    SafeSend(insertText, backspaces)
    StartWordInsertUndo(insertText, false, "DATA")
    if copied
        ToolTip("✅ Логин вставлен, пароль в буфере")
    else if (item.Password != "" && item.Login = "")
        ToolTip("🔐 Пароль вставлен")
    else
        ToolTip("ℹ️ Вставлено")
    SetTimer(() => ToolTip(), -1200)

    if DataDB.Has(item.Id)
        DataDB[item.Id].Count += 1
    FinalizeTypingState(false, false)
    QueueDataSave()
}

; #EndRegion

; #Region 🔒 ЗАЩИТА ОТ ПАРАЛЛЕЛЬНОГО ЗАПУСКА
GetTyperMutexName() {
    ; Имя mutex привязываем к расположению именно этого набора данных,
    ; чтобы не ловить ложные совпадения с чужими копиями и другими скриптами.
    scope := StrLower(A_ScriptDir "\svc_core")
    hash := 2166136261
    Loop Parse, scope {
        hash := Mod((hash ^ Ord(A_LoopField)) * 16777619, 0x100000000)
    }
    return "Local\TyperSmartAssistant_" Format("{:08X}", hash)
}

AcquireTyperInstanceLock() {
    global TyperInstanceMutexHandle
    hMutex := DllCall("Kernel32\CreateMutexW", "Ptr", 0, "Int", 1, "WStr", GetTyperMutexName(), "Ptr")
    ; CreateMutexW возвращает валидный хэндл даже если объект уже существует;
    ; факт этого виден только через last error == ERROR_ALREADY_EXISTS (183).
    ; ВАЖНО: читаем A_LastError, а не второй DllCall GetLastError — между двумя
    ; DllCall внутренние вызовы AHK могут затереть last error потока, и проверка
    ; молча перестанет ловить второй экземпляр (документация DllCall, AHK v2).
    if (A_LastError = 183) {
        DllCall("Kernel32\CloseHandle", "Ptr", hMutex)
        MsgBox("Уже запущен другой экземпляр Typer.", "Typer", "Icon!")
        ExitApp()
    }
    TyperInstanceMutexHandle := hMutex
}

ReleaseTyperInstanceLock() {
    global TyperInstanceMutexHandle
    if !TyperInstanceMutexHandle
        return
    try DllCall("Kernel32\ReleaseMutex", "Ptr", TyperInstanceMutexHandle)
    try DllCall("Kernel32\CloseHandle", "Ptr", TyperInstanceMutexHandle)
    TyperInstanceMutexHandle := 0
}
; #EndRegion

; #Region 🛡️ АВТОРИЗАЦИЯ И ИНИЦИАЛИЗАЦИЯ
; v13.16: зашифрованные базы, которые реально лежат на диске (основной файл или .bak).
ListExistingEncryptedStoreFiles() {
    global DictFile, HotstringsFile, MetaFile, SettingsFile, PhraseFile, PromptFile, DataFile, LinkFile, HotInsertFile
    found := []
    for filePath in [SettingsFile, DataFile, DictFile, PhraseFile, PromptFile, LinkFile, HotInsertFile, HotstringsFile, MetaFile] {
        if FileExist(filePath) || FileExist(filePath ".bak")
            found.Push(filePath)
    }
    return found
}

; v13.16: берём соль у того варианта файла (основной или .bak), который реально
; открылся этим паролем, — ключ для неё уже в кэше Crypto.
AdoptSessionSaltFromVerifiedFile(filePath, password, expectedPlain := "") {
    for candidate in [filePath, filePath ".bak"] {
        try {
            if !FileExist(candidate)
                continue
            enc := FileRead(candidate, "UTF-8")
            if (enc = "")
                continue
            plain := Crypto.Decrypt(enc, password)
            if (plain = "" || (expectedPlain != "" && plain !== expectedPlain))
                continue
            return Crypto.AdoptSessionSaltFromBlob(enc)
        }
    }
    return false
}

AuthenticateUser() {
    global MasterPassword, DataDir, LockFile

    if !DirExist(DataDir)
        DirCreate(DataDir)

    IsFirstRun := !FileExist(LockFile) && !FileExist(LockFile ".bak")
    ; v13.16: lock мог пропасть (антивирус, ручная чистка), а базы остались.
    ; Тогда это не первый запуск: пароль проверяем по существующим базам.
    ExistingStores := IsFirstRun ? ListExistingEncryptedStoreFiles() : []
    ; Первый запуск: новый пароль вводится дважды. Объект — чтобы вложенная
    ; функция могла менять состояние между нажатиями Enter.
    ; v13.22: WasActive/ShownTick — для WatchAuthFocus (см. ниже).
    FirstRunState := {Pending: "", WasActive: false, ShownTick: 0}

    AuthGui := Gui("-Caption +AlwaysOnTop +ToolWindow +Border")
    AuthGui.MarginX := 10
    AuthGui.MarginY := 10

    PassEdit := AuthGui.Add("Edit", "w150 h22 Password Center -E0x200")
    Btn := AuthGui.Add("Button", "w0 h0 Hidden Default", "OK")

    AuthGui.OnEvent("Escape", (*) => ExitApp())
    AuthGui.OnEvent("Close", (*) => ExitApp())
    Btn.OnEvent("Click", CheckPassword)

    AuthGui.Show("AutoSize Center")
    FirstRunState.ShownTick := A_TickCount
    try WinActivate("ahk_id " AuthGui.Hwnd)
    SetTimer(WatchAuthFocus, 100)
    WinWaitClose("ahk_id " AuthGui.Hwnd)

    ; v13.22: MsgBox забирает фокус у окна пароля, и WatchAuthFocus закрывал Typer
    ; раньше, чем сообщение можно было прочитать. На время MsgBox наблюдатель выключен.
    AuthErrorBox(text) {
        SetTimer(WatchAuthFocus, 0)
        MsgBox(text, "Typer", "Iconx")
        try WinActivate("ahk_id " AuthGui.Hwnd)
        try PassEdit.Focus()
        SetTimer(WatchAuthFocus, 100)
    }

    CheckPassword(*) {
        global DevAllowShortMasterPassword, MinMasterPasswordLen
        EnteredPass := PassEdit.Value
        if (EnteredPass = "")
            return

        if (IsFirstRun && ExistingStores.Length) {
            ; Lock потерян, базы есть: пускаем, только если пароль открывает базу.
            ; Неверный пароль — тихий выход, как и при обычном входе.
            verifiedStore := ""
            for storePath in ExistingStores {
                if (ReadDecryptedTextWithBak(storePath, EnteredPass) != "") {
                    verifiedStore := storePath
                    break
                }
            }
            if (verifiedStore = "")
                ExitApp()
            AdoptSessionSaltFromVerifiedFile(verifiedStore, EnteredPass)
            if !WriteEncryptedTextVerified(LockFile, "VERIFIED_OK", EnteredPass, "lock:repair") {
                SetTimer(WatchAuthFocus, 0)
                MsgBox("Не удалось восстановить lock-контейнер. Проверь права на запись в svc_core.", "Typer", "Iconx")
                ExitApp()
            }
            MasterPassword := EnteredPass
            SetTimer(WatchAuthFocus, 0)
            AuthGui.Destroy()
            return
        }

        if (IsFirstRun) {
            ; v13.16: новый пароль — дважды и с учётом регистра.
            if (FirstRunState.Pending == "") {
                ; v13.22: минимальная длина — как при смене пароля.
                if (StrLen(EnteredPass) < MinMasterPasswordLen && !DevAllowShortMasterPassword) {
                    PassEdit.Value := ""
                    ToolTip("Пароль — минимум " MinMasterPasswordLen " символов", 0, 48)
                    SetTimer(() => ToolTip(), -2500)
                    return
                }
                FirstRunState.Pending := EnteredPass
                PassEdit.Value := ""
                ToolTip("Повторите новый пароль", 0, 48)
                SetTimer(() => ToolTip(), -2500)
                return
            }
            if (EnteredPass !== FirstRunState.Pending) {
                FirstRunState.Pending := ""
                PassEdit.Value := ""
                ToolTip("Пароли не совпали — введите новый пароль заново", 0, 48)
                SetTimer(() => ToolTip(), -2500)
                return
            }
            if !WriteEncryptedTextVerified(LockFile, "VERIFIED_OK", EnteredPass, "lock:first-run") {
                AuthErrorBox("Не удалось создать lock-контейнер. Проверь права на запись в svc_core.")
                return
            }

            if (ReadDecryptedTextWithBak(LockFile, EnteredPass) != "VERIFIED_OK") {
                AuthErrorBox("Не удалось проверить lock-контейнер после записи. Пароль не принят.")
                return
            }

            MasterPassword := EnteredPass
            SetTimer(WatchAuthFocus, 0)
            AuthGui.Destroy()
        } else {
            if (ReadDecryptedTextWithBak(LockFile, EnteredPass) == "VERIFIED_OK") {
                ; v13.16: соль lock становится солью сессии — один PBKDF2 на старте.
                AdoptSessionSaltFromVerifiedFile(LockFile, EnteredPass, "VERIFIED_OK")
                MasterPassword := EnteredPass
                SetTimer(WatchAuthFocus, 0)
                AuthGui.Destroy()
            } else {
                ExitApp()
            }
        }
    }

    WatchAuthFocus() {
        hwnd := AuthGui.Hwnd
        if !WinExist("ahk_id " hwnd)
            return
        if WinActive("ahk_id " hwnd) {
            FirstRunState.WasActive := true
            return
        }
        ; Окно уже было в фокусе и потеряло его — тихий выход (как раньше).
        if FirstRunState.WasActive
            ExitApp()
        ; v13.22: окно ни разу не получило фокус (автозагрузка, перезапуск после UAC:
        ; Windows не отдаёт фокус новому процессу) — раньше это был мгновенный выход.
        ; Первые 3 с пробуем активировать, дальше ждём клика; через 60 с — выход.
        elapsed := A_TickCount - FirstRunState.ShownTick
        if (elapsed < 3000) {
            try WinActivate("ahk_id " hwnd)
        } else if (elapsed > 60000) {
            ExitApp()
        }
    }
}

AuthenticateUser()
SetTyperStartupStage(1, "настройки")
LoadSettingsInternal()
CleanupTransientFiles()
SetTyperStartupStage(2, "проверка шифрования")
if !CryptoSelfTest() {
    MsgBox("Не прошёл встроенный тест сохранения/чтения. Проверь права доступа к папке svc_core.", "Typer", "Iconx")
    ExitApp()
}
; v13.17: этапы загрузки видны в панели F9 (индикатор расшифровки).
; v13.18: выключенный словарь не расшифровывается вовсе (см. SetDictionaryMode).
SetTyperStartupStage(3, (DictMode = "off") ? "словарь выключен" : "словарь")
if (DictMode != "off")
    LoadDictionary()
SetTyperStartupStage(4, "индекс слов")
if (DictMode != "off")
    RebuildPrefixIndexes()
SetTyperStartupStage(5, "фразы")
LoadPhrasesInternal()
RebuildPhraseIndexes()
SetTyperStartupStage(6, "промпты")
LoadPromptsInternal()
RebuildPromptIndexes()
SetTyperStartupStage(7, "ссылки")
LoadLinksInternal()
SetTyperStartupStage(8, "данные")
LoadDataInternal()
SetTyperStartupStage(9, "горячие вставки")
LoadHotInsertsInternal()
RegisterAllHotInsertHotkeys()
SetTyperStartupStage(10, "автозамены")
LoadHotstringsInternal()
SetTyperStartupStage(11, "служебные данные")
LoadMetaInternal()
WarnIfStoresCorrupt()
TyperStartupComplete := true
SetTyperStartupStage(0, "")

SuggGui := Gui("+AlwaysOnTop +ToolWindow -Caption +Owner +Border +E0x08000000", "TyperSuggestions")
SuggGui.BackColor := ColorBackground
SuggGui.SetFont("s" FontSize, FontName)
SuggGui.OnEvent("Escape", (*) => HideSuggestions())

Loop MaxStems {
    LabelsStems.Push(SuggGui.Add("Text", "x10 w470 h20 c" ColorTextStems " vStemText" A_Index, ""))
}
SepLine := SuggGui.Add("Text", "x10 w470 h1 Background3A3A3A", "")
Loop MaxSuggestionRows {
    LabelsWordPrefixes.Push(SuggGui.Add("Text", "x10 w42 h20 c" ColorTextWords " vWordPrefix" A_Index, ""))
    LabelsWords.Push(SuggGui.Add("Text", "x56 w700 h20 c" ColorTextWords " vWordText" A_Index, ""))
}
; Поле превью фразы/промпта в OSD — в общем стиле тёмных полей скрипта:
; фон чуть светлее окна (как у превью панели F9), рамки нет, тёмный скроллбар.
PhrasePreviewEdit := SuggGui.Add("Edit", "x10 w590 h0 +Multi +0x100 ReadOnly -WantReturn -E0x200 +VScroll Background242424 c" ColorTextWords " Hidden")
ApplyDarkControlTheme(PhrasePreviewEdit)
; Периодическое сохранение: каждые 3 часа, пока скрипт работает.
; На каждом сохранении данные пишутся через .tmp -> .bak -> основной файл.
; Это снижает шанс потерять базу при сбое записи. На выходе SaveAllData
; вызывается ещё раз через OnExit.
SetTimer(SaveAllData, 10800000)
OnExit(ExitFunc)
; #EndRegion

; #Region 🎧 INPUTHOOK (ПЕРЕХВАТ ВВОДА)
ih := InputHook("V L0")
ih.MinSendLevel := 2
ih.OnChar := OnCharInput
ih.OnKeyDown := OnKeyDownInput

; v13.16: «\» больше не глушится через InputHook во всей системе — его
; перехватывает горячая клавиша только в контексте Typer (HandleTyperBackslashKey).
ih.KeyOpt("{Backspace}", "+N")
ih.KeyOpt("{Left}{Right}{Up}{Down}{Home}{End}{PgUp}{PgDn}{Escape}{Enter}{Tab}", "+N")
ih.Start()
SetTimer(EnsureInputHookRunning, 5000)

IsCurrentWindowTemporarilyAllowed() {
    global TemporaryTyperWindows
    hwnd := WinExist("A")
    if !hwnd
        return false
    if TemporaryTyperWindows.Has(hwnd) {
        if IsLiveWindowHandle(hwnd)
            return true
        try TemporaryTyperWindows.Delete(hwnd)
    }
    return false
}

GetWindowRuleSignature(hwnd := 0) {
    if !hwnd
        hwnd := WinExist("A")
    exe := "", className := ""
    try exe := WinGetProcessName("ahk_id " hwnd)
    try className := WinGetClass("ahk_id " hwnd)
    return {Key: StrLower(exe "|" className), Exe: exe, Class: className}
}

IsCurrentWindowPermanentlyAllowed() {
    global PermanentTyperWindowRules
    sig := GetWindowRuleSignature()
    if (sig.Key = "|")
        return false
    return PermanentTyperWindowRules.Has(sig.Key)
}

IsTyperInputContext() {
    global TyperSuspended, TyperStartupComplete
    if TyperSuspended
        return false
    ; v13.16: пока базы расшифровываются, Typer в приложениях ничего не делает.
    if !TyperStartupComplete
        return false
    ; v13.16: собственные окна Typer (карточка «Данные», редакторы, панель) — не
    ; поле ввода: иначе автозамена и обучение срабатывали прямо в поле пароля карточки.
    if IsOwnTyperWindowActive()
        return false
    ; Основной фильтр для рабочих окон. Стандартные приложения входят в ahk_group TyperApps,
    ; а редкие/временные окна можно добавить вручную через Win+A на время текущего запуска.
    return WinActive("ahk_group TyperApps") || IsCurrentWindowTemporarilyAllowed() || IsCurrentWindowPermanentlyAllowed()
}

IsOwnTyperWindowActive() {
    static ownPid := DllCall("GetCurrentProcessId", "UInt")
    try return (WinGetPID("A") = ownPid)
    return false
}

GetFocusedControlSignature() {
    try return ControlGetFocus("A")
    return ""
}

UpdateTypingContextStamp() {
    global LastTypingHwnd, LastTypingCtrl, LastTypingTick
    LastTypingHwnd := WinExist("A")
    LastTypingCtrl := GetFocusedControlSignature()
    LastTypingTick := A_TickCount
}

PrepareTypingContextForChar() {
    global CurrentInput, SuggestionVisible, LastTypingHwnd, LastTypingCtrl, LastTypingTick, TypingIdleResetMs
    hwnd := WinExist("A")
    ctrl := GetFocusedControlSignature()

    ; Если активное окно/Win32-контрол сменились, внутренний хвост нельзя переносить туда.
    ; В браузерах DOM-поля не всегда видны как отдельные Win32-контролы, поэтому ниже есть
    ; ещё idle-reset: после паузы новый ввод начинается с чистого состояния.
    ; ВАЖНО: ControlGetFocus иногда сбоит (занятый поток целевого окна, характерно для
    ; Scintilla/Notepad++) и возвращает "". Пустая сигнатура — это "не удалось узнать",
    ; а не "другой контрол": при том же hwnd не считаем это сменой контекста, иначе
    ; режимы фраз/промптов случайно сбрасываются посреди набора.
    ctrlChanged := (ctrl != LastTypingCtrl) && (ctrl != "") && (LastTypingCtrl != "")
    if (hwnd != LastTypingHwnd || ctrlChanged) {
        if (CurrentInput != "" || SuggestionVisible)
            ResetInput()
    } else if (LastTypingTick && A_TickCount - LastTypingTick > TypingIdleResetMs && !SuggestionVisible) {
        if (CurrentInput != "")
            ResetInput()
    }

    LastTypingHwnd := hwnd
    if (ctrl != "")
        LastTypingCtrl := ctrl
    LastTypingTick := A_TickCount
}

EnsureInputHookRunning(*) {
    global ih, TyperSuspended
    if TyperSuspended
        return
    try {
        if !ih.InProgress
            ih.Start()
    } catch as e {
        try ih.Start()
    }
}

ToggleActiveWindowTyperAllowance(permanent := false, *) {
    global TemporaryTyperWindows, PermanentTyperWindowRules
    hwnd := WinExist("A")
    if !hwnd
        return

    ; Свои окна Typer не добавляем: они и так обслуживаются отдельными условиями.
    try {
        title := WinGetTitle("ahk_id " hwnd)
    } catch {
        title := ""
    }
    if (title = "Панель Typer" || title = "Менеджер автозамен" || title = "Режим фразы" || title = "Режим промпта" || title = "Новая ссылка" || title = "Правка ссылки") {
        ToolTip("Typer: это служебное окно уже обрабатывается отдельно")
        SetTimer(() => ToolTip(), -1600)
        return
    }

    if permanent {
        sig := GetWindowRuleSignature(hwnd)
        if (sig.Key = "|") {
            ToolTip("Typer: не удалось определить exe/class окна")
            SetTimer(() => ToolTip(), -1600)
            return
        }
        if PermanentTyperWindowRules.Has(sig.Key) {
            PermanentTyperWindowRules.Delete(sig.Key)
            SaveSettingsInternal()
            ResetInput()
            ToolTip("Typer: постоянный доступ отключён`n" sig.Exe " / " sig.Class)
        } else {
            PermanentTyperWindowRules[sig.Key] := {Exe: sig.Exe, Class: sig.Class, Label: title}
            SaveSettingsInternal()
            ResetInput()
            ToolTip("Typer: окно добавлено постоянно`n" sig.Exe " / " sig.Class "`nПовторный Win+A уберёт правило")
        }
    } else {
        if TemporaryTyperWindows.Has(hwnd) {
            TemporaryTyperWindows.Delete(hwnd)
            ResetInput()
            ToolTip("Typer: временный доступ отключён для этого окна")
        } else {
            TemporaryTyperWindows[hwnd] := {Title: title, AddedAt: A_Now}
            ResetInput()
            ToolTip("Typer: окно добавлено до перезапуска скрипта`nТеперь здесь работают режимы *, 1/2/3 и слова")
        }
    }
    SetTimer(() => ToolTip(), -2400)
}

ToggleTyperSuspended(*) {
    global TyperSuspended, ih
    if TyperSuspended {
        TyperSuspended := false
        Suspend(false)
        try ih.Start()
        ToolTip("Typer включён")
    } else {
        HideSuggestions()
        HidePanelPreviewOsd()
        ResetInput()
        TyperSuspended := true
        Suspend(true)
        ToolTip("Typer полностью остановлен. Win+T — включить обратно")
    }
    SetTimer(() => ToolTip(), -1400)
}

IsPhraseTriggerInput(text) {
    return (SubStr(text, 1, 1) = "1" && StrLen(text) >= 2 && RegExMatch(SubStr(text, 2, 1), "^[a-zA-Zа-яА-ЯёЁ]$"))
}

IsPromptTriggerInput(text) {
    return (SubStr(text, 1, 1) = "2" && StrLen(text) >= 2 && RegExMatch(SubStr(text, 2, 1), "^[a-zA-Zа-яА-ЯёЁ]$"))
}

IsLinkTriggerInput(text) {
    return (SubStr(text, 1, 1) = "3" && SubStr(text, 1, 2) != "33" && StrLen(text) >= 2 && RegExMatch(SubStr(text, 2, 1), "^\S$"))
}

; Голые "11"/"22"/"33" тоже считаются режимом: если стереть запрос обратно
; до префикса, OSD не пропадает, а показывает топ записей по частоте.
IsPhraseContentTriggerInput(text) {
    return (SubStr(text, 1, 2) = "11" && (StrLen(text) = 2 || RegExMatch(SubStr(text, 3, 1), "^\S$")))
}

IsPromptContentTriggerInput(text) {
    return (SubStr(text, 1, 2) = "22" && (StrLen(text) = 2 || RegExMatch(SubStr(text, 3, 1), "^\S$")))
}

IsLinkContentTriggerInput(text) {
    return (SubStr(text, 1, 2) = "33" && (StrLen(text) = 2 || RegExMatch(SubStr(text, 3, 1), "^\S$")))
}

IsSnippetContentTriggerInput(text) {
    return IsPhraseContentTriggerInput(text) || IsPromptContentTriggerInput(text) || IsLinkContentTriggerInput(text)
}

IsSnippetTriggerInput(text) {
    return IsPhraseTriggerInput(text) || IsPromptTriggerInput(text) || IsLinkTriggerInput(text) || IsSnippetContentTriggerInput(text)
}

IsDataTriggerInput(text) {
    return (SubStr(text, 1, 1) = "*")
}

IsSnippetSuggestionMode(mode := "") {
    global CurrentSuggestionMode
    if (mode = "")
        mode := CurrentSuggestionMode
    return (mode = "PHRASES" || mode = "PROMPTS" || mode = "LINKS")
}


IsRawInputChar(char) {
    ; Сырой хвост нужен не для подсказок, а для AppsKey: логины/пароли могут содержать 2/3/*/^/%/=/.
    ; Пробелы и переводы строк завершают текущий фрагмент.
    return (char != "" && !RegExMatch(char, "^\s$"))
}

TrackRawInputChar(char) {
    global CurrentRawInput
    if IsRawInputChar(char)
        CurrentRawInput .= char
}

BackspaceRawInput() {
    global CurrentRawInput
    if (StrLen(CurrentRawInput) > 0)
        CurrentRawInput := SubStr(CurrentRawInput, 1, -1)
}

GetCurrentRawOrInput() {
    global CurrentRawInput, CurrentInput
    raw := Trim(CurrentRawInput)
    if (raw != "")
        return raw
    return Trim(CurrentInput)
}

IsExcludedWordKey(key) {
    global WordDB
    key := StrLower(Trim(key))
    return (key != "" && WordDB.Has(key) && WordDB[key].HasOwnProp("Hidden") && WordDB[key].Hidden)
}

ExcludeWordToken(token, displayOverride := "") {
    global WordDB
    token := Trim(token)
    if (token = "")
        return false
    key := StrLower(token)
    display := displayOverride != "" ? displayOverride : token
    if WordDB.Has(key) {
        WordDB[key].Hidden := 1
        if !WordDB[key].HasOwnProp("Count")
            WordDB[key].Count := 1
        if !WordDB[key].HasOwnProp("IsStem")
            WordDB[key].IsStem := 0
        if !WordDB[key].HasOwnProp("DataOnly")
            WordDB[key].DataOnly := 0
    } else {
        WordDB[key] := {Display: display, Count: 1, Hidden: 1, IsStem: 0, DataOnly: 0}
        AddWordToPrefixIndexes(key)
    }
    SetNoSpaceWord(key, false)
    return true
}

ExcludeTextFromWordSuggestions(text, source := "", saveNow := true) {
    text := Trim(text, " `t`r`n")
    if (text = "")
        return 0
    count := 0
    ; Если выделили несколько слов — исключаем каждое. Если это пароль/логин без пробелов — уйдёт целиком.
    parts := StrSplit(RegExReplace(text, "\s+", " "), " ")
    for _, part in parts {
        part := Trim(part)
        if (part != "" && ExcludeWordToken(part))
            count += 1
    }
    if (count > 0 && saveNow) {
        SaveDictionary()
        SetTimer(() => PopulateDictListView(), -10)
    }
    return count
}

ExcludeCurrentOrSelectedFromSuggestions(*) {
    ; v13.18: исключения живут в словаре — при выключенном словаре их некуда писать.
    if !IsDictionaryActive() {
        ShowDictionaryOffTip()
        return
    }
    rawCandidate := GetCurrentRawOrInput()
    selected := ""
    source := "raw"

    ; Быстрый путь: если Typer уже видел сырой ввод, не трогаем clipboard вообще.
    ; Это убирает задержку Ctrl+C/ClipWait и быстрее показывает ToolTip.
    if (rawCandidate != "") {
        candidate := rawCandidate
    } else {
        selected := Trim(GetSelectedTextViaClipboard(0.25), " `t`r`n")
        candidate := selected
        source := "selection"
    }

    if (candidate = "") {
        ToolTip("⚠️ Нет выделения или текущего фрагмента для исключения")
        SetTimer(() => ToolTip(), -1500)
        return
    }
    added := ExcludeTextFromWordSuggestions(candidate, source, false)
    if (added > 0) {
        HideSuggestions()
        ResetInput()
        ToolTip("🚫 Исключено из выдачи: " added)
        SetTimer(() => ToolTip(), -1200)
        SetTimer(SaveDictionary, -10)
        SetTimer(() => PopulateDictListView(), -40)
    } else {
        ToolTip("⚠️ Нечего исключить")
        SetTimer(() => ToolTip(), -1200)
    }
}

LearnSelectedTextAsWords(*) {
    global ManualWordScore
    selected := Trim(GetSelectedTextViaClipboard(0.25), " `t`r`n")
    if (selected = "")
        return false
    added := 0
    parts := StrSplit(RegExReplace(selected, "\s+", " "), " ")
    for _, part in parts {
        part := Trim(part)
        if (part != "" && !IsExcludedWordKey(StrLower(part))) {
            LearnWordExact(part, GetManualLearnScore(part), true) ; v13.19
            added += 1
        }
    }
    if (added > 0) {
        ToolTip("✅ Добавлено выделенных слов: " added " (рейтинг ≥ " ManualWordScore ")")
        SetTimer(() => ToolTip(), -1400)
        return true
    }
    return false
}

IsTrackableInputChar(char) {
    global CurrentInput

    if (char = "*")
        return (CurrentInput = "")

    if IsDataTriggerInput(CurrentInput)
        return RegExMatch(char, "^[a-zA-Zа-яА-ЯёЁ0-9@._\-]$")

    if IsLinkTriggerInput(CurrentInput) || IsLinkContentTriggerInput(CurrentInput)
        return RegExMatch(char, "^[a-zA-Zа-яА-ЯёЁ0-9@._\-/:\?&=#% ]$")

    ; В режимах 1... и 2... пробел — часть поискового запроса, а не конец слова.
    ; Это позволяет искать не только по первому слову: например 2grungy analog.
    if IsPhraseTriggerInput(CurrentInput) || IsPromptTriggerInput(CurrentInput)
        return RegExMatch(char, "^[a-zA-Zа-яА-ЯёЁ0-9@._\-\!\?,:;() ]$")

    if IsSnippetContentTriggerInput(CurrentInput)
        return RegExMatch(char, "^[a-zA-Zа-яА-ЯёЁ0-9@._\-\!\?,:;() ]$")

    return RegExMatch(char, "^[a-zA-Zа-яА-ЯёЁ0-9\-\!\?]$")
}

OnCharInput(ihObj, char) {
    global CurrentInput, CurrentRawInput, JustInsertedWord, NextCharUpper, CapitalizeMode, MinTriggerLen, WordDigitLiteralMode, TyperSuspended

    if TyperSuspended
        return

    if ConsumeSuppressedSelectionChar(char)
        return

    if (char == "\")
        return


    if IsDetachedSnippetEditorActive()
        return

    if !IsTyperInputContext() && !WinActive("Менеджер автозамен") && !WinActive("Панель Typer") && !WinActive("Режим фразы") && !WinActive("Режим промпта") && !WinActive("Новая ссылка") && !WinActive("Правка ссылки") {
        if (CurrentInput != "")
            ResetInput()
        return
    }

    if WinActive("Менеджер автозамен") || WinActive("Панель Typer") || WinActive("Режим фразы") || WinActive("Режим промпта") || WinActive("Новая ссылка") || WinActive("Правка ссылки")
        return

    if IsPasswordFieldActive() {
        if (CurrentInput != "")
            ResetInput()
        return
    }

    PrepareTypingContextForChar()

    if (GetKeyState("Ctrl", "P") || GetKeyState("Alt", "P") || GetKeyState("LWin", "P") || GetKeyState("RWin", "P")) {
        ; После Ctrl+L/Alt+D/Win-команд не тащим старый CurrentInput в новое поле.
        ResetInput()
        UpdateTypingContextStamp()
        return
    }

    ; Сырой хвост фиксируем только в разрешённом контексте ввода, но до проверки
    ; "словарности" символа: AppsKey должен видеть и пароли с )(*#^&.
    TrackRawInputChar(char)

    if (NextCharUpper && RegExMatch(char, "^[a-zA-Zа-яА-ЯёЁ]$")) {
        InvalidateInsertedQuote()
        CapitalizeMode := 1
        NextCharUpper := false
        SendInput("{Backspace}" StrUpper(char))
        CurrentInput .= StrUpper(char)
        TrackHotstringTail(StrUpper(char))

        if (StrLen(CurrentInput) >= MinTriggerLen)
            ShowSuggestions()
        return
    }

    if IsTrackableInputChar(char) {
        InvalidateInsertedQuote()
        CurrentInput .= char
        TrackHotstringTail(char)
        JustInsertedWord := false
        NextCharUpper := false

        if (StrLen(CurrentInput) == 1 && RegExMatch(char, "^[A-ZА-ЯЁ]$"))
            CapitalizeMode := 1

        if !IsDataTriggerInput(CurrentInput) && !IsSnippetTriggerInput(CurrentInput) {
            if CheckAndFireHotstring(true)
                return
        }

        if (IsDataTriggerInput(CurrentInput) && TryAutoConfirmDataByPrefix())
            return

        if (WordDigitLiteralMode && !IsDataTriggerInput(CurrentInput) && !IsSnippetTriggerInput(CurrentInput)) {
            HideSuggestions()
        } else if (IsDataTriggerInput(CurrentInput) || StrLen(CurrentInput) >= MinTriggerLen)
            ShowSuggestions()
        else
            HideSuggestions()
    } else {
        ; v13.16: передаём завершающий символ — он уже напечатан в поле. По Enter/Tab
        ; автозамену не запускаем: сообщение уже ушло или фокус в другом поле.
        if !IsDataTriggerInput(CurrentInput) && !IsSnippetTriggerInput(CurrentInput) && !(char == "`n" || char == "`r" || char == "`t") {
            if CheckAndFireHotstring(false, char)
                return
        }

        InvalidateInsertedQuote()
        NextCharUpper := false
        CapitalizeMode := 0

        if (char == " ") {
            TrackHotstringTail(char)
            FinalizeTypingState(true, true, true)
        } else {
            if (char != "")
                TrackHotstringTail(char)
            ; Для OSD это уже не обычное слово, но для AppsKey это всё ещё часть
            ; одного сырого фрагмента. Поэтому CurrentInput завершаем, а CurrentRawInput
            ; сохраняем до настоящего разделителя: пробел/Enter/Tab/навигация/смена окна.
            FinalizeTypingState(false, false, false)
        }
    }
}

OnKeyDownInput(ihObj, vk, sc) {
    global CurrentInput, SuggestionVisible, SelectedStemIndex, SelectedPhraseIndex, CurrentStems, CurrentSuggestionMode
    global JustInsertedWord, NextCharUpper, CapitalizeMode, MinWordLen, MinTriggerLen, WordDigitLiteralMode, TyperSuspended
    global PhantomInputLen


    if TyperSuspended
        return

    if IsDetachedSnippetEditorActive()
        return

    if !IsTyperInputContext()
        return

    if IsPasswordFieldActive() {
        if (CurrentInput != "")
            ResetInput()
        return
    }

    switch vk {
        case 0x08: ; Backspace
            BackspaceRawInput()
            JustInsertedWord := false
            NextCharUpper := false
            InvalidateInsertedQuote()
            HandleHotstringBackspace()

            if GetKeyState("Ctrl", "P") {
                ResetInput()
                return
            }

            if (StrLen(CurrentInput) > 0) {
                CurrentInput := SubStr(CurrentInput, 1, -1)
                ; Фантомный префикс не может быть длиннее оставшегося хвоста.
                if (PhantomInputLen > StrLen(CurrentInput))
                    PhantomInputLen := StrLen(CurrentInput)
                if (StrLen(CurrentInput) == 0) {
                    CapitalizeMode := 0
                    WordDigitLiteralMode := false
                }

                if (StrLen(CurrentInput) >= MinTriggerLen)
                    ShowSuggestions()
                else
                    HideSuggestions()
            } else {
                HideSuggestions()
            }

        case 0x1B: ; Escape
            JustInsertedWord := false
            NextCharUpper := false
            ResetInput()

        case 0x0D, 0x09: ; Enter, Tab
            ; v13.16: Enter/Tab уже ушли в приложение — сообщение отправлено или
            ; фокус перешёл в другое поле. Поэтому слово не запоминаем (так в словарь
            ; попадали пароли из браузеров), автозамену не запускаем (её Backspace
            ; стёр бы чужой текст) и всегда сбрасываем хвост — даже при открытом OSD.
            InvalidateInsertedQuote()
            InvalidateHotstringUndo()
            JustInsertedWord := false
            FinalizeTypingState(false, false)

        case 0x25, 0x27, 0x26, 0x28, 0x24, 0x23, 0x21, 0x22, 0x2E: ; Навигация/Delete (v13.16: + Up/Down)
            if (vk = 0x2E && SuggestionVisible && IsSnippetSuggestionMode(CurrentSuggestionMode))
                return
            JustInsertedWord := false
            NextCharUpper := false
            InvalidateInsertedQuote()
            InvalidateHotstringUndo()
            ResetInput()
    }
}

ResetInput() {
    global CurrentInput, CurrentRawInput, CapitalizeMode, LastPhraseOsdInput, SelectedPhraseIndex, WordDigitLiteralMode, PhantomInputLen
    CurrentInput := ""
    CurrentRawInput := ""
    CapitalizeMode := 0
    LastPhraseOsdInput := ""
    SelectedPhraseIndex := 1
    WordDigitLiteralMode := false
    PhantomInputLen := 0
    HideSuggestions()
}

GetTypedBackspaceCount() {
    ; Сколько символов текущего хвоста реально напечатано в поле.
    ; Фантомные символы режимов PgUp/PgDn (PhantomInputLen) в поле не попадали,
    ; поэтому их нельзя стирать бэкспейсами перед вставкой.
    global CurrentInput, PhantomInputLen
    n := StrLen(CurrentInput) - PhantomInputLen
    return (n > 0) ? n : 0
}

SafeSend(textToSend, backspaceCount := 0) {
    SendLevel 1
    if (backspaceCount > 0)
        SendInput("{Backspace " backspaceCount "}")
    if (textToSend != "")
        SendText(textToSend)
}

NormalizeClipboardCompareText(text) {
    ; A_Clipboard может нормализовать переводы строк. Для проверки, что в буфере
    ; действительно наш текст, сравниваем с единым LF-форматом.
    return RegExReplace(text, "\R", "`n")
}

GetSelectedTextViaClipboard(timeoutSec := 0.7, restoreDelayMs := 35) {
    ; Единая безопасная точка для "взять выделение через Ctrl+C".
    ; Сохраняем полный буфер через ClipboardAll(), очищаем, копируем, читаем только текст
    ; и обязательно восстанавливаем исходный буфер. Если приложение не дало текст —
    ; возвращаем пустую строку, не подмешивая старое содержимое буфера.
    clipSaved := ""
    clipSavedOk := false
    selectedText := ""

    try {
        clipSaved := ClipboardAll()
        clipSavedOk := true
    } catch {
    }

    ; v13.16: VS Code и его форки по Ctrl+C без выделения копируют всю строку,
    ; а во встроенном терминале Ctrl+C без выделения прерывает процесс. Там
    ; (и в консолях) копируем через Ctrl+Insert, а «копию строки» не считаем выделением.
    lineCopyEditor := IsLineCopyEditorActive()
    copyKeys := (lineCopyEditor || IsTerminalWindowActive()) ? "^{Insert}" : "^{c}"

    try {
        A_Clipboard := ""
        Sleep(20)
        SendLevel 1
        SendInput(copyKeys)
        if ClipWait(timeoutSec) {
            try selectedText := A_Clipboard
            if (lineCopyEditor && selectedText != "" && IsClipboardWholeLineCopy(selectedText))
                selectedText := ""
        }
    } catch {
    }

    if clipSavedOk {
        Sleep(restoreDelayMs)
        try A_Clipboard := clipSaved
    }

    return selectedText
}

IsLineCopyEditorActive() {
    ; Редакторы, которые без выделения копируют текущую строку целиком.
    ; v13.17: + Visual Studio, Sublime Text и IDE JetBrains — там Ctrl+C без
    ; выделения тоже берёт строку, и Ctrl+\ вставлял её копию в кавычках.
    try {
        exe := StrLower(WinGetProcessName("A"))
        if (exe = "code.exe" || exe = "code - insiders.exe" || exe = "vscodium.exe" || exe = "cursor.exe" || exe = "windsurf.exe")
            return true
        if (exe = "devenv.exe" || exe = "sublime_text.exe")
            return true
        return RegExMatch(exe, "^(idea|pycharm|webstorm|phpstorm|clion|rider|goland|rubymine|datagrip|studio)(64)?\.exe$") ? true : false
    }
    return false
}

IsTerminalWindowActive() {
    try {
        cls := WinGetClass("A")
        return (cls = "ConsoleWindowClass" || cls = "CASCADIA_HOSTING_WINDOW_CLASS" || cls = "mintty")
    }
    return false
}

IsClipboardWholeLineCopy(text) {
    ; Точный признак: VS Code кладёт в буфер метаданные редактора, где прямо
    ; сказано, что это копия из пустого выделения.
    flag := GetVsCodeEmptySelectionFlag()
    if (flag != -1)
        return (flag = 1)
    ; Метаданных нет — эвристика: ровно одна строка с переводом строки в конце.
    return RegExMatch(text, "^[^\r\n]*\R\z") ? true : false
}

GetVsCodeEmptySelectionFlag() {
    ; Chromium хранит пользовательские типы буфера (vscode-editor-data) в одном
    ; формате-«пикле» в UTF-16. Ищем в нём флаг isFromEmptySelection.
    ; 1 — копия строки без выделения, 0 — было выделение, -1 — неизвестно.
    static fmt := DllCall("RegisterClipboardFormatW", "Str", "Chromium Web Custom MIME Data Format", "UInt")
    if !fmt || !DllCall("IsClipboardFormatAvailable", "UInt", fmt)
        return -1
    if !DllCall("OpenClipboard", "Ptr", A_ScriptHwnd)
        return -1
    found := -1
    try {
        hData := DllCall("GetClipboardData", "UInt", fmt, "Ptr")
        if hData {
            size := DllCall("GlobalSize", "Ptr", hData, "UPtr")
            pData := DllCall("GlobalLock", "Ptr", hData, "Ptr")
            if pData {
                hay := ""
                chars := Min(size // 2, 32768)
                Loop chars {
                    c := NumGet(pData, (A_Index - 1) * 2, "UShort")
                    hay .= (c < 32 || (c >= 0xD800 && c <= 0xDFFF)) ? " " : Chr(c)
                }
                DllCall("GlobalUnlock", "Ptr", hData)
                if InStr(hay, '"isFromEmptySelection":true')
                    found := 1
                else if InStr(hay, '"isFromEmptySelection":false')
                    found := 0
            }
        }
    } finally {
        DllCall("CloseClipboard")
    }
    return found
}

SafeSendPhrase(textToSend, backspaceCount := 0) {
    ; Фразы/промпты вставляем через буфер обмена и Ctrl+V: для длинных текстов это
    ; быстрее, чем посимвольная отправка. ВАЖНО: перед Ctrl+V проверяем, что в
    ; буфере именно наш текст, иначе при сбое можно случайно вставить старый буфер
    ; пользователя, например картинку/скриншот.
    if (textToSend = "")
        return

    clipSaved := ""
    clipSavedOk := false
    try clipSaved := ClipboardAll(), clipSavedOk := true

    SendLevel 1
    if (backspaceCount > 0)
        SendInput("{Backspace " backspaceCount "}")

    pasted := false
    try {
        A_Clipboard := ""
        Sleep(20)
        A_Clipboard := textToSend
        if ClipWait(0.75) {
            clipText := A_Clipboard
            if (NormalizeClipboardCompareText(clipText) = NormalizeClipboardCompareText(textToSend)) {
                ; Классическим Win32-редакторам (Scintilla/Notepad++, Edit, RichEdit)
                ; шлём WM_PASTE напрямую в контрол: синтезированный Ctrl+V там может
                ; теряться, когда физическая клавиша выбора ещё зажата или хук
                ; занят (проявлялось как "стёр набранное, но ничего не вставил").
                if PasteViaWmPaste()
                    pasted := true
                else {
                    SendInput("^v")
                    pasted := true
                }
            }
        }
    } catch {
    }

    if !pasted {
        ; Медленнее, но безопаснее: лучше посимвольно отправить текст, чем вставить
        ; старое содержимое буфера обмена.
        SendText(textToSend)
    }

    ; Восстановление откладываем: тяжёлые редакторы (IDE, Office) могут читать буфер
    ; дольше отведённого времени. Если рвануть restore сразу — приложение увидит
    ; старый clipboard вместо вставляемой фразы.
    if clipSavedOk
        SetTimer(RestoreClipboardSafely.Bind(clipSaved, textToSend), -400)
}

PasteViaWmPaste() {
    ; WM_PASTE (0x0302) — синхронная вставка для классических контролов. Возвращает
    ; true только если сфокусированный контрол точно её поддерживает; для браузеров
    ; и нестандартных полей остаётся путь Ctrl+V.
    try {
        focusedCtrl := ControlGetFocus("A")
        if !focusedCtrl
            return false
        focusedHwnd := ControlGetHwnd(focusedCtrl, "A")
        if !focusedHwnd
            return false
        cls := WinGetClass("ahk_id " focusedHwnd)
        if !RegExMatch(cls, "i)^(Edit|RichEdit|RICHEDIT|Scintilla)")
            return false
        ; v13.16: с таймаутом (SMTO_ABORTIFHUNG, 1.5 с) — если целевое окно зависло,
        ; Typer не виснет вместе с ним. Повторный Ctrl+V не шлём: сообщение уже
        ; отдано, иначе можно получить двойную вставку.
        pasteResult := 0
        DllCall("User32\SendMessageTimeoutW", "Ptr", focusedHwnd, "UInt", 0x0302, "Ptr", 0, "Ptr", 0, "UInt", 0x0002, "UInt", 1500, "Ptr*", &pasteResult, "Ptr")
        return true
    } catch {
        return false
    }
}

RestoreClipboardSafely(clipBackup, expectedText := "", *) {
    try {
        if (expectedText != "" && NormalizeClipboardCompareText(A_Clipboard) != NormalizeClipboardCompareText(expectedText))
            return
        A_Clipboard := clipBackup
    }
}

SendLiteralBackslash() {
    global CurrentInput, CurrentRawInput, JustInsertedWord, NextCharUpper, CapitalizeMode, WordDigitLiteralMode, PhantomInputLen
    InvalidateInsertedQuote()
    InvalidateHotstringUndo()
    CurrentInput := ""
    CurrentRawInput := ""
    PhantomInputLen := 0
    CapitalizeMode := 0
    WordDigitLiteralMode := false
    HideSuggestions()
    JustInsertedWord := false
    NextCharUpper := false
    SendLevel 1
    SendText("\")
}

; v13.16: обработчик «\» в контексте Typer (раньше это делал InputHook через
; KeyOpt +S, глуша клавишу во всей системе). Логика прежняя: в OSD фраз —
; редактор, при набранном фрагменте — фиксация основы, иначе — обычный «\».
HandleTyperBackslashKey() {
    global JustInsertedWord, CurrentInput, SuggestionVisible, CurrentSuggestionMode, SelectedPhraseIndex
    JustInsertedWord := false
    if (SuggestionVisible && IsSnippetSuggestionMode(CurrentSuggestionMode)) {
        OpenDetachedSnippetEditor(CurrentSuggestionMode, SelectedPhraseIndex)
        return
    }
    if (CurrentInput != "") {
        ; v13.18: словарь выключен — основу фиксировать некуда, печатаем «\».
        if !IsDictionaryActive() {
            SendLiteralBackslash()
            return
        }
        PinCurrentStem()
        return
    }
    SendLevel 1
    SendText("\")
}

HandleLeftCtrlTap() {
    global CurrentInput, CurrentRawInput, JustInsertedWord, LastSpaceTime, NextCharUpper, PhantomInputLen

    InvalidateHotstringUndo()

    if (CurrentInput != "") {
        if IsDataTriggerInput(CurrentInput) || IsSnippetTriggerInput(CurrentInput)
            return

        LearnWord(CurrentInput, 1, false)
        CurrentInput := ""
        CurrentRawInput := ""
        PhantomInputLen := 0
        HideSuggestions()
        JustInsertedWord := false
        NextCharUpper := false
        SendLevel 1
        SendText(", ")
        return
    }

    if (JustInsertedWord && (A_TickCount - LastSpaceTime < 3000)) {
        SendInput("{Backspace}, ")
        JustInsertedWord := false
        NextCharUpper := false
    }
}

RememberInsertedText(textValue, hadSpace := false, insertedKind := "WORD") {
    global LastInsertedText, LastInsertedHadSpace, LastInsertedCanQuote, LastInsertedKind
    LastInsertedText := textValue
    LastInsertedHadSpace := hadSpace
    LastInsertedCanQuote := (textValue != "")
    LastInsertedKind := insertedKind
}

InvalidateInsertedQuote() {
    global LastInsertedCanQuote, LastInsertedText, LastInsertedHadSpace, LastInsertedKind
    LastInsertedCanQuote := false
    LastInsertedText := ""
    LastInsertedHadSpace := false
    LastInsertedKind := ""
}

FinalizeTypingState(learnCurrent := false, markWordFinished := false, resetRaw := true) {
    global CurrentInput, CurrentRawInput, JustInsertedWord, LastSpaceTime, CapitalizeMode, WordDigitLiteralMode, PhantomInputLen

    if (learnCurrent && CurrentInput != "") && !IsSnippetTriggerInput(CurrentInput) && !IsDataTriggerInput(CurrentInput) && RegExMatch(CurrentInput, "^[a-zA-Zа-яА-ЯёЁ0-9\-]+$")
        LearnWord(CurrentInput, 1, false)

    CurrentInput := ""
    PhantomInputLen := 0
    if resetRaw
        CurrentRawInput := ""
    CapitalizeMode := 0
    WordDigitLiteralMode := false
    HideSuggestions()

    JustInsertedWord := markWordFinished
    if markWordFinished
        LastSpaceTime := A_TickCount
}

HandlePointerAction() {
    InvalidateInsertedQuote()
    InvalidateHotstringUndo()
    ResetInput()
}

InvalidateHotstringUndo() {
    global LastActionType, LastHotstringCanUndo, LastHotstringTail, LastPhraseCanUndo, LastPhraseTail, LastPhraseKind, LastWordCanUndo, LastWordTail, LastWordKind
    if (LastActionType == "HOTSTRING") {
        LastHotstringCanUndo := false
        LastHotstringTail := ""
    } else if (LastActionType == "PHRASE_INSERT") {
        LastPhraseCanUndo := false
        LastPhraseTail := ""
        LastPhraseKind := ""
    } else if (LastActionType == "WORD_INSERT") {
        LastWordCanUndo := false
        LastWordTail := ""
        LastWordKind := ""
    }
}

StartPhraseUndo(phraseText, addSpace := true, phraseKind := "PHRASE") {
    global LastActionType, LastPhraseText, LastPhraseSpace, LastPhraseCanUndo, LastPhraseTail, LastPhraseKind
    LastActionType := "PHRASE_INSERT"
    LastPhraseText := phraseText
    LastPhraseSpace := addSpace
    LastPhraseCanUndo := true
    LastPhraseTail := ""
    LastPhraseKind := phraseKind
}

StartWordInsertUndo(wordText, addSpace := true, wordKind := "WORD") {
    global LastActionType, LastWordText, LastWordSpace, LastWordCanUndo, LastWordTail, LastWordKind
    global LastWordUndoRestoreText, LastWordUndoRestoreInput
    LastActionType := "WORD_INSERT"
    LastWordText := wordText
    LastWordSpace := addSpace
    LastWordCanUndo := true
    LastWordTail := ""
    LastWordKind := wordKind
    ; v13.17: что вернуть по Alt+Z вместо вставки (задаёт только Ctrl+\).
    LastWordUndoRestoreText := ""
    LastWordUndoRestoreInput := ""
}

GetUndoInsertKindLabel(kind) {
    return (kind = "PROMPT") ? "промпта" : ((kind = "LINK") ? "ссылки" : ((kind = "HOTKEY") ? "горячей вставки" : ((kind = "WORD") ? "слова" : ((kind = "STEM") ? "основы" : "фразы"))))
}

GetUndoWordKindLabel(kind) {
    return (kind = "STEM") ? "основы" : ((kind = "DATA") ? "данных" : ((kind = "QUOTED") ? "кавычек" : "слова"))
}

TrackHotstringTail(char) {
    global LastActionType, LastHotstringCanUndo, LastHotstringTail, LastPhraseCanUndo, LastPhraseTail, LastWordCanUndo, LastWordTail
    if (LastActionType == "HOTSTRING" && LastHotstringCanUndo)
        LastHotstringTail .= char
    else if (LastActionType == "PHRASE_INSERT" && LastPhraseCanUndo)
        LastPhraseTail .= char
    else if (LastActionType == "WORD_INSERT" && LastWordCanUndo)
        LastWordTail .= char
}

HandleHotstringBackspace() {
    global LastActionType, LastHotstringCanUndo, LastHotstringTail, LastPhraseCanUndo, LastPhraseTail, LastWordCanUndo, LastWordTail
    if (LastActionType == "HOTSTRING" && LastHotstringCanUndo) {
        if (StrLen(LastHotstringTail) > 0)
            LastHotstringTail := SubStr(LastHotstringTail, 1, -1)
        else
            InvalidateHotstringUndo()
        return
    }
    if (LastActionType == "PHRASE_INSERT" && LastPhraseCanUndo) {
        if (StrLen(LastPhraseTail) > 0)
            LastPhraseTail := SubStr(LastPhraseTail, 1, -1)
        else
            InvalidateHotstringUndo()
        return
    }
    if (LastActionType == "WORD_INSERT" && LastWordCanUndo) {
        if (StrLen(LastWordTail) > 0)
            LastWordTail := SubStr(LastWordTail, 1, -1)
        else
            InvalidateHotstringUndo()
    }
}

SuppressSelectionChar(char) {
    global SuppressedSelectionChar, SuppressedSelectionTick
    SuppressedSelectionChar := char
    SuppressedSelectionTick := A_TickCount
}

ConsumeSuppressedSelectionChar(char) {
    global SuppressedSelectionChar, SuppressedSelectionTick
    if (SuppressedSelectionChar = "")
        return false

    if ((A_TickCount - SuppressedSelectionTick) > 400) {
        SuppressedSelectionChar := ""
        SuppressedSelectionTick := 0
        return false
    }

    if (char = SuppressedSelectionChar) {
        SuppressedSelectionChar := ""
        SuppressedSelectionTick := 0
        return true
    }

    return false
}

SelectWordOrSendDigit(index) {
    global CurrentWords, CurrentInput, CurrentRawInput, JustInsertedWord, NextCharUpper, MinTriggerLen, SuggestionVisible
    global CurrentSuggestionMode, CurrentDataItems, WordDigitLiteralMode

    ; Когда активны модификаторы, например Ctrl+1 для правки фразы,
    ; обычный выбор цифрой не должен срабатывать параллельно.
    if (GetKeyState("Ctrl", "P") || GetKeyState("Alt", "P") || GetKeyState("LWin", "P") || GetKeyState("RWin", "P"))
        return

    if SuggestionVisible && !WordDigitLiteralMode {
        if (CurrentSuggestionMode = "DATA" && index <= CurrentDataItems.Length) {
            SuppressSelectionChar((index = 10) ? "0" : ("" index))
            ConfirmDataSelection(index)
            return
        }
        if (CurrentSuggestionMode != "DATA" && index <= CurrentWords.Length) {
            SuppressSelectionChar((index = 10) ? "0" : ("" index))
            ConfirmAction("WORD", index)
            return
        }
    }

    digitText := (index = 10) ? "0" : ("" index)
    SendLevel 1
    SendText(digitText)
    CurrentInput .= digitText
    CurrentRawInput .= digitText
    JustInsertedWord := false
    NextCharUpper := false

    if (WordDigitLiteralMode && !IsDataTriggerInput(CurrentInput) && !IsSnippetTriggerInput(CurrentInput)) {
        HideSuggestions()
    } else if (IsDataTriggerInput(CurrentInput) || StrLen(CurrentInput) >= MinTriggerLen)
        ShowSuggestions()
    else
        HideSuggestions()
}

CycleStemSelection(step) {
    global SuggestionVisible, CurrentStems, SelectedStemIndex

    if !SuggestionVisible || CurrentStems.Length < 2
        return false

    SelectedStemIndex += step
    if (SelectedStemIndex < 1)
        SelectedStemIndex := CurrentStems.Length
    else if (SelectedStemIndex > CurrentStems.Length)
        SelectedStemIndex := 1

    UpdateUI()
    ScheduleWordOsdAutoHide() ; -/= — это активность пользователя в OSD слов, таймер не должен закрыть окно во время выбора основы.
    return true
}
CyclePhraseSelection(step) {
    global SuggestionVisible, CurrentSuggestionMode, CurrentWords, SelectedPhraseIndex

    if !SuggestionVisible || (!IsSnippetSuggestionMode(CurrentSuggestionMode)) || CurrentWords.Length = 0
        return false

    oldIndex := SelectedPhraseIndex
    if (SelectedPhraseIndex < 1 || SelectedPhraseIndex > CurrentWords.Length)
        SelectedPhraseIndex := 1
    else {
        SelectedPhraseIndex += step
        if (SelectedPhraseIndex < 1)
            SelectedPhraseIndex := CurrentWords.Length
        else if (SelectedPhraseIndex > CurrentWords.Length)
            SelectedPhraseIndex := 1
    }
    RefreshPhraseSelectionOnly(oldIndex, SelectedPhraseIndex)
    return true
}


RefreshPhraseSelectionOnly(oldIndex := 0, newIndex := 0) {
    global SuggestionVisible, CurrentSuggestionMode, CurrentWords, SelectedPhraseIndex
    global PhrasePreviewEdit, ColorHighlight, ColorTextWords

    if !SuggestionVisible || (!IsSnippetSuggestionMode(CurrentSuggestionMode)) || (CurrentWords.Length = 0)
        return

    if (oldIndex = 0)
        oldIndex := SelectedPhraseIndex
    if (newIndex = 0)
        newIndex := SelectedPhraseIndex

    if (oldIndex >= 1 && oldIndex <= CurrentWords.Length && oldIndex != newIndex)
        RefreshSinglePhraseRow(oldIndex, false)
    if (newIndex >= 1 && newIndex <= CurrentWords.Length)
        RefreshSinglePhraseRow(newIndex, true)

    if (newIndex >= 1 && newIndex <= CurrentWords.Length)
        UpdateSnippetPreviewControl(CurrentWords[newIndex])
}

GetCurrentSnippetPreviewHeight() {
    global CurrentSuggestionMode, PhrasePreviewHeight, PromptPreviewHeight
    return (CurrentSuggestionMode = "PROMPTS") ? PromptPreviewHeight : PhrasePreviewHeight
}

GetSuggestionWindowMetrics() {
    global CurrentStems, CurrentWords, CurrentDataItems, CurrentSuggestionMode, SelectedPhraseIndex, PhrasePreviewHeight

    CurrentH := 10
    if (CurrentStems.Length > 0)
        CurrentH += CurrentStems.Length * 22
    if (CurrentStems.Length > 0 && CurrentWords.Length > 0)
        CurrentH += 15
    if (CurrentSuggestionMode = "DATA") {
        if (CurrentDataItems.Length > 0)
            CurrentH += CurrentDataItems.Length * 22
        GuiW := 710 ; v13.16: шире под полные логины (было 560)
    } else if (IsSnippetSuggestionMode(CurrentSuggestionMode)) {
        if (CurrentWords.Length > 0) {
            phraseListH := 0
            for _, rowData in CurrentWords
                phraseListH += (rowData.HasOwnProp("RowHeight") ? rowData.RowHeight : 20) + 4
            CurrentH += phraseListH
        }
        if (SelectedPhraseIndex >= 1 && SelectedPhraseIndex <= CurrentWords.Length)
            CurrentH += GetCurrentSnippetPreviewHeight() + 16
        GuiW := 620
    } else {
        if (CurrentWords.Length > 0)
            CurrentH += CurrentWords.Length * 22
        GuiW := 250
    }
    CurrentH += 8
    return {W: GuiW, H: CurrentH}
}

MoveSuggestionWindow(guiW, guiH) {
    global OsdMarginX, OsdMarginY
    try {
        MonitorGetWorkArea(MonitorGetPrimary(), &WL, &WT, &WR, &WB)
        TargetX := WR - guiW - OsdMarginX
        TargetY := WB - guiH - OsdMarginY
    } catch {
        TargetX := A_ScreenWidth - guiW - OsdMarginX
        TargetY := A_ScreenHeight - guiH - OsdMarginY
    }
    if (TargetX < 0)
        TargetX := 0
    if (TargetY < 0)
        TargetY := 0
    return {X: TargetX, Y: TargetY}
}

QueuePhraseSave(delayMs := 320) {
    SetTimer(SaveQueuedPhrases, 0)
    SetTimer(SaveQueuedPhrases, -Abs(delayMs))
}

SaveQueuedPhrases(*) {
    SavePhrasesInternal()
    SavePromptsInternal()
    SaveLinksInternal()
}

QueueDataSave(delayMs := 320) {
    ; Дебаунс: каждый выбор/правка в "Данных" перешифровывает весь sec.bin
    ; (ключ PBKDF2 кэшируется с 13.16, но остаются AES-GCM, атомарная запись и
    ; проверочное чтение). Сглаживаем серию правок одним сохранением.
    SetTimer(SaveDataInternal, 0)
    SetTimer(SaveDataInternal, -Abs(delayMs))
}

ApplyPhraseTextEdit(index, newText, mode := "") {
    global CurrentWords, PhraseDB, PromptDB, CurrentSuggestionMode

    if (index < 1 || index > CurrentWords.Length)
        return false
    if (mode = "")
        mode := CurrentSuggestionMode

    if (mode = "LINKS")
        return ApplyLinkUrlEdit(index, newText)

    if (mode = "PROMPTS")
        newText := SanitizePromptText(newText)
    else
        newText := SanitizePhraseText(newText)
    if (newText = "")
        return false

    row := CurrentWords[index]
    oldKey := row.HasOwnProp("Key") ? row.Key : StrLower(GetPhraseFullText(row))
    store := (mode = "PROMPTS") ? PromptDB : PhraseDB
    if !store.Has(oldKey)
        return false

    oldData := store[oldKey]
    newKey := StrLower(newText)

    if (newKey != oldKey) {
        if (mode = "PROMPTS")
            RemovePromptFromIndexes(oldKey)
        else
            RemovePhraseFromIndexes(oldKey)
        store.Delete(oldKey)
        if store.Has(newKey) {
            merged := store[newKey]
            merged.Text := newText
            merged.Count := Max(merged.Count, oldData.Count)
            if !merged.HasOwnProp("Hidden")
                merged.Hidden := 0
            store[newKey] := merged
        } else {
            oldData.Text := newText
            if !oldData.HasOwnProp("Hidden")
                oldData.Hidden := 0
            store[newKey] := oldData
            if (mode = "PROMPTS")
                AddPromptToIndexes(newKey)
            else
                AddPhraseToIndexes(newKey)
        }
    } else {
        store[oldKey].Text := newText
    }

    CurrentWords[index].Full := newText
    CurrentWords[index].Display := TruncatePhraseForOSD(RegExReplace(newText, "\s+", " "))
    CurrentWords[index].Key := newKey
    return true
}

GetDetachedSnippetEditorHwnd() {
    global SnippetEditorGui
    if !IsObject(SnippetEditorGui)
        return 0
    try return SnippetEditorGui.Hwnd
    catch {
        return 0
    }
}

IsDetachedSnippetEditorActive() {
    hwnd := GetDetachedSnippetEditorHwnd()
    return hwnd ? WinExist("ahk_id " hwnd) : 0
}

OpenDetachedSnippetEditor(mode := "PHRASES", index := 0) {
    global SuggestionVisible, CurrentWords, SelectedPhraseIndex
    global SnippetEditorGui, SnippetEditorEdit, SnippetEditorMode, SnippetEditorIndex, SnippetEditorTargetHwnd, SnippetEditorSuppressChange
    global SuggGui, ColorBackground, FontSize, FontName, ColorHighlight, ColorTextWords

    if !SuggestionVisible
        return false
    if !IsSnippetSuggestionMode(mode)
        return false
    if (index < 1 || index > CurrentWords.Length)
        return false

    CloseDetachedSnippetEditor(false)

    SnippetEditorTargetHwnd := 0
    try SnippetEditorTargetHwnd := WinGetID("A")
    catch {
    }

    SnippetEditorMode := mode
    SnippetEditorIndex := index
    SnippetEditorSuppressChange := false

    editorText := GetPhraseFullText(CurrentWords[index])
    editorW := 760
    editorH := 300
    editorX := Round((A_ScreenWidth - editorW) / 2)
    editorY := Round((A_ScreenHeight - editorH) / 2)
    margin := 16

    try {
        WinGetPos(&sx, &sy, &sw, &sh, "ahk_id " SuggGui.Hwnd)
        editorX := sx + Round((sw - editorW) / 2)
        editorY := sy + sh + 14
        if (editorY + editorH > A_ScreenHeight - margin)
            editorY := sy + Round((sh - editorH) / 2)
    } catch {
    }

    if (editorX < margin)
        editorX := margin
    if (editorY < margin)
        editorY := margin
    if (editorX + editorW > A_ScreenWidth - margin)
        editorX := Max(margin, A_ScreenWidth - editorW - margin)
    if (editorY + editorH > A_ScreenHeight - margin)
        editorY := Max(margin, A_ScreenHeight - editorH - margin)

    title := (mode = "PROMPTS") ? "Typer Prompt Editor" : ((mode = "LINKS") ? "Typer Link Editor" : "Typer Snippet Editor")
    headerText := (mode = "PROMPTS") ? "Редактор промпта — Enter вставить, Esc вернуться" : ((mode = "LINKS") ? "Редактор ссылки — Enter вставить URL, Esc вернуться" : "Редактор фразы — Enter вставить, Esc вернуться")

    SnippetEditorGui := Gui("+AlwaysOnTop +ToolWindow +Border", title)
    ApplyDarkWindowFrame(SnippetEditorGui)
    SnippetEditorGui.BackColor := ColorBackground
    SnippetEditorGui.SetFont("s" FontSize, FontName)
    SnippetEditorGui.OnEvent("Close", (*) => CancelDetachedSnippetEditor())
    SnippetEditorGui.OnEvent("Escape", (*) => CancelDetachedSnippetEditor())

    SnippetEditorGui.Add("Text", "xm ym w740 h22 c" ColorHighlight, headerText)
    SnippetEditorEdit := SnippetEditorGui.Add("Edit", "xm y+8 w740 h246 +Multi -WantReturn +VScroll Background" ColorBackground " c" ColorTextWords)
    ApplyDarkControlTheme(SnippetEditorEdit)
    SnippetEditorEdit.Value := editorText
    SnippetEditorEdit.OnEvent("Change", OnDetachedSnippetEditorChange)

    SnippetEditorGui.Show("x" editorX " y" editorY " w" editorW " h" editorH)
    editorHwnd := GetDetachedSnippetEditorHwnd()
    if editorHwnd
        try WinActivate("ahk_id " editorHwnd)
    Sleep(30)
    try SnippetEditorEdit.Focus()
    if editorHwnd
        try ControlFocus(SnippetEditorEdit.Hwnd, "ahk_id " editorHwnd)
    try DllCall("User32\SendMessageW", "Ptr", SnippetEditorEdit.Hwnd, "UInt", 0x00B1, "Ptr", StrLen(editorText), "Ptr", StrLen(editorText), "Ptr")
    return true
}

OnDetachedSnippetEditorChange(ctrl, *) {
    global SnippetEditorSuppressChange, SnippetEditorMode, SnippetEditorIndex
    if SnippetEditorSuppressChange
        return
    if !IsDetachedSnippetEditorActive()
        return
    if !IsSnippetSuggestionMode(SnippetEditorMode)
        return

    newText := ctrl.Value
    if !ApplyPhraseTextEdit(SnippetEditorIndex, newText, SnippetEditorMode)
        return
    UpdatePhraseRowCache(SnippetEditorIndex, 540)
    RefreshSinglePhraseRow(SnippetEditorIndex, true)
    QueuePhraseSave(650)
}

CloseDetachedSnippetEditor(resetState := true) {
    global SnippetEditorGui, SnippetEditorEdit, SnippetEditorMode, SnippetEditorIndex, SnippetEditorTargetHwnd, SnippetEditorSuppressChange
    if IsDetachedSnippetEditorActive() {
        try SnippetEditorGui.Destroy()
    }
    SnippetEditorGui := 0
    SnippetEditorEdit := 0
    if resetState {
        SnippetEditorMode := ""
        SnippetEditorIndex := 0
        SnippetEditorTargetHwnd := 0
        SnippetEditorSuppressChange := false
    }
}

ConfirmDetachedSnippetEditorAndInsert() {
    global SnippetEditorEdit, SnippetEditorMode, SnippetEditorIndex, SnippetEditorTargetHwnd
    global CurrentInput
    if !IsDetachedSnippetEditorActive()
        return
    if !IsSnippetSuggestionMode(SnippetEditorMode)
        return

    mode := SnippetEditorMode
    index := SnippetEditorIndex
    targetHwnd := SnippetEditorTargetHwnd

    newText := (mode = "PROMPTS") ? SanitizePromptText(SnippetEditorEdit.Value) : ((mode = "LINKS") ? SanitizeLinkUrl(SnippetEditorEdit.Value) : SanitizePhraseText(SnippetEditorEdit.Value))
    if (newText = "") {
        ToolTip("⚠️ Пустую запись нельзя вставить")
        SetTimer(() => ToolTip(), -1200)
        return
    }
    if !ApplyPhraseTextEdit(index, newText, mode)
        return
    UpdatePhraseRowCache(index, 540)
    QueuePhraseSave(120)
    CloseDetachedSnippetEditor(true)
    HideSuggestions()
    if targetHwnd {
        try WinActivate("ahk_id " targetHwnd)
        Sleep(40)
    }
    SafeSendPhrase(newText . " ", GetTypedBackspaceCount())
    RememberInsertedText(newText, true, (mode = "PROMPTS") ? "PROMPT" : ((mode = "LINKS") ? "LINK" : "PHRASE"))
    StartPhraseUndo(newText, true, (mode = "PROMPTS") ? "PROMPT" : ((mode = "LINKS") ? "LINK" : "PHRASE"))
    if (mode = "PROMPTS")
        LearnPrompt(newText, 1)
    else if (mode = "LINKS")
        LearnLink(newText, "", "", "", 1)
    else
        LearnPhrase(newText, 1)
    FinalizeTypingState(false, true)
}

CancelDetachedSnippetEditor() {
    global SnippetEditorTargetHwnd, SuggestionVisible
    targetHwnd := SnippetEditorTargetHwnd
    CloseDetachedSnippetEditor(true)
    if targetHwnd {
        try WinActivate("ahk_id " targetHwnd)
        Sleep(30)
    }
    if SuggestionVisible
        try ShowSuggestions()
}

MeasureTextWidthPx(text, fontFace := "", fontPt := 0) {
    ; v13.19: один memory-DC и по одному шрифту на (имя, размер) на весь процесс.
    ; Раньше КАЖДЫЙ замер делал GetDC + CreateFont + DeleteObject + ReleaseDC, а
    ; раскладка строк OSD фраз/промптов замеряет текст сотни раз на одну букву.
    ; Длинный текст в кэш не кладём: ключом был сам текст, и 4000 ключей по
    ; несколько тысяч символов (промпты) держали в памяти десятки мегабайт.
    ; v13.19: БАГ прошлых версий — параметры назывались fontName/fontSize, а
    ; имена переменных в AHK без учёта регистра: «fontName := FontName» присваивал
    ; параметр сам себе. Без явного шрифта (все замеры строк OSD) мерилось
    ; шрифтом по умолчанию нулевой высоты, а не Consolas 11 из OSD, — отсюда
    ; строки, обрезанные краем окна вместо «…».
    global FontName, FontSize
    static widthCache := Map(), fontCache := Map(), memDC := 0, logPixelsY := 96
    static sizeBuf := Buffer(8, 0)

    face := (fontFace != "") ? fontFace : FontName
    pt := (fontPt != 0) ? fontPt : FontSize

    cacheable := (StrLen(text) <= 256)
    if cacheable {
        cacheKey := face "|" pt "|" text
        if widthCache.Has(cacheKey)
            return widthCache[cacheKey]
        if (widthCache.Count > 4000)
            widthCache.Clear()
    }

    if !memDC {
        memDC := DllCall("CreateCompatibleDC", "ptr", 0, "ptr")
        if !memDC
            return StrLen(text) * 8
        logPixelsY := DllCall("GetDeviceCaps", "ptr", memDC, "int", 90, "int")
    }

    fontKey := face "|" pt
    if fontCache.Has(fontKey) {
        hFont := fontCache[fontKey]
    } else {
        hFont := DllCall("CreateFontW"
            , "int", -Round(pt * logPixelsY / 72)
            , "int", 0
            , "int", 0
            , "int", 0
            , "int", 400
            , "uint", 0
            , "uint", 0
            , "uint", 0
            , "uint", 1
            , "uint", 0
            , "uint", 0
            , "uint", 0
            , "uint", 0
            , "str", face
            , "ptr")
        if !hFont
            return StrLen(text) * 8
        fontCache[fontKey] := hFont
    }

    DllCall("SelectObject", "ptr", memDC, "ptr", hFont, "ptr")
    NumPut("int", 0, sizeBuf, 0)
    DllCall("GetTextExtentPoint32W", "ptr", memDC, "str", text, "int", StrLen(text), "ptr", sizeBuf)
    width := NumGet(sizeBuf, 0, "int")

    if cacheable
        widthCache[cacheKey] := width
    return width
}

TruncateTextToWidthPx(text, maxWidthPx, reserveEllipsis := true) {
    text := RegExReplace(text, "\s+", " ")
    text := Trim(text)
    if (text = "")
        return ""

    ellipsis := reserveEllipsis ? " …" : ""
    ellipsisW := reserveEllipsis ? MeasureTextWidthPx(ellipsis) : 0
    if (MeasureTextWidthPx(text) <= maxWidthPx)
        return text

    targetWidth := Max(24, maxWidthPx - ellipsisW)
    low := 1
    ; v13.19: в targetWidth пикселей больше ~targetWidth/2 символов не влезет
    ; (самый узкий глиф шире 2 px) — бинарный поиск больше не идёт по всем
    ; тысячам символов длинного промпта.
    high := Min(StrLen(text), Floor(targetWidth / 2) + 2)
    best := ""

    while (low <= high) {
        mid := Floor((low + high) / 2)
        candidate := RTrim(SubStr(text, 1, mid))
        if (MeasureTextWidthPx(candidate) <= targetWidth) {
            best := candidate
            low := mid + 1
        } else {
            high := mid - 1
        }
    }

    if (best = "")
        return reserveEllipsis ? "…" : SubStr(text, 1, 1)

    cutPos := InStr(best, " ", true, -1) ; v13.19: последний пробел без посимвольного цикла
    if (cutPos >= 8)
        best := RTrim(SubStr(best, 1, cutPos - 1))

    return best . ellipsis
}

GetPhraseRowPrefix(index, isSelected := false) {
    marker := isSelected ? "▶" : " "
    prefix := (index = 10) ? "0." : index "."
    return marker " " prefix
}

GetPhraseFullText(rowData) {
    return rowData.HasOwnProp("Full") ? rowData.Full : rowData.Display
}


UpdateSnippetPreviewControl(rowData) {
    global PhrasePreviewEdit, CurrentInput
    ; v13.19: тот же текст и то же выделение — Edit не трогаем (каждая буква
    ; запроса раньше заново заливала в поле весь промпт на тысячи символов).
    static shownText := "", shownStart := -2, shownEnd := -2

    previewText := GetPhraseFullText(rowData)
    if (previewText = "")
        previewText := ""

    highlightStart := -1
    highlightEnd := -1

    if (IsPhraseContentTriggerInput(CurrentInput) || IsPromptContentTriggerInput(CurrentInput) || IsLinkContentTriggerInput(CurrentInput)) {
        query := NormalizeSnippetContainsQuery(SubStr(CurrentInput, 3))
        if (Trim(query) != "") {
            pos := InStr(StrLower(previewText), StrLower(query))
            if pos {
                qLen := StrLen(query)
                highlightStart := pos - 1
                highlightEnd := highlightStart + qLen
            }
        }
    }
    if (shownText == previewText && shownStart = highlightStart && shownEnd = highlightEnd)
        return
    try PhrasePreviewEdit.Value := previewText
    shownText := previewText, shownStart := highlightStart, shownEnd := highlightEnd

    if (highlightStart >= 0) {
        try DllCall("User32\SendMessageW", "Ptr", PhrasePreviewEdit.Hwnd, "UInt", 0x00B1, "Ptr", highlightStart, "Ptr", highlightEnd, "Ptr")
        try DllCall("User32\SendMessageW", "Ptr", PhrasePreviewEdit.Hwnd, "UInt", 0x00B7, "Ptr", 0, "Ptr", 0, "Ptr")
    } else {
        try DllCall("User32\SendMessageW", "Ptr", PhrasePreviewEdit.Hwnd, "UInt", 0x00B1, "Ptr", 0, "Ptr", 0, "Ptr")
    }
}

PreparePhraseRows(maxWidthPx := 540) {
    global CurrentWords
    for idx, _ in CurrentWords
        UpdatePhraseRowCache(idx, maxWidthPx)
}

UpdatePhraseRowCache(index, maxWidthPx := 540) {
    global CurrentWords
    if (index < 1 || index > CurrentWords.Length)
        return false
    previewInfo := BuildPhraseRowPreview(GetPhraseFullText(CurrentWords[index]), maxWidthPx)
    CurrentWords[index].PreviewText := previewInfo.Text
    CurrentWords[index].PreviewLines := previewInfo.Lines
    CurrentWords[index].RowHeight := previewInfo.Height
    return true
}

RefreshSinglePhraseRow(index, isSelected := false) {
    global SuggestionVisible, CurrentSuggestionMode, CurrentWords, LabelsWordPrefixes, LabelsWords, ColorHighlight, ColorTextWords
    if !SuggestionVisible || (!IsSnippetSuggestionMode(CurrentSuggestionMode))
        return
    if (index < 1 || index > CurrentWords.Length)
        return
    if !LabelsWords[index].Visible
        return
    rowData := CurrentWords[index]
    rowColor := isSelected ? ColorHighlight : ColorTextWords
    ; v13.19: через кэш OSD — без перерисовки, если ничего не изменилось
    OsdLabelUpdate(LabelsWordPrefixes[index], GetPhraseRowPrefix(index, isSelected), rowColor)
    OsdLabelUpdate(LabelsWords[index], rowData.HasOwnProp("PreviewText") ? rowData.PreviewText : rowData.Display, rowColor)
}

BuildPhraseRowPreview(text, maxWidthPx) {
    ; v13.19: раскладка строки OSD фразы/промпта (1–2 строки) — самая дорогая
    ; часть OSD на каждую букву: для длинного промпта перебирались все слова,
    ; на каждое заново склеивался весь остаток текста и бинарным поиском
    ; заново мерилась его ширина. Теперь: готовые раскладки кэшируются, текст
    ; заранее режется до длины, которая в две строки заведомо не влезает
    ; (результат тот же — вторая строка всё равно обрезается с «…»), а остаток
    ; берётся одним SubStr.
    static layoutCache := Map()
    ; Окно OSD масштабируется по DPI (ширина метки 540 — в «96-DPI» единицах), а
    ; MeasureTextWidthPx меряет в физических пикселях — переводим ширину.
    maxWidthPx := Round(maxWidthPx * A_ScreenDPI / 96) - 2
    text := RegExReplace(text, "\s+", " ")
    text := Trim(text)
    if (text = "")
        return {Text: "", Lines: 1, Height: 20}

    capChars := maxWidthPx + 40
    if (StrLen(text) > capChars)
        text := SubStr(text, 1, capChars)

    cacheKey := FontName "|" FontSize "|" maxWidthPx "|" text
    if layoutCache.Has(cacheKey)
        return layoutCache[cacheKey]
    if (layoutCache.Count > 400)
        layoutCache.Clear()

    result := ""
    if (MeasureTextWidthPx(text) <= maxWidthPx) {
        result := {Text: text, Lines: 1, Height: 20}
    } else {
        words := StrSplit(text, " ")
        if (words.Length < 2) {
            result := {Text: TruncateTextToWidthPx(text, maxWidthPx, true), Lines: 1, Height: 20}
        } else {
            bestLine1 := ""
            bestLine2 := ""
            bestScore := 0x7FFFFFFF
            line1 := ""

            Loop words.Length - 1 {
                idx := A_Index
                line1 := (line1 = "") ? words[idx] : (line1 " " words[idx])
                width1 := MeasureTextWidthPx(line1)
                if (width1 > maxWidthPx)
                    break

                ; Текст нормализован до одиночных пробелов, поэтому остаток после
                ; первых idx слов — это просто хвост строки.
                remainder := SubStr(text, StrLen(line1) + 2)
                line2 := TruncateTextToWidthPx(remainder, maxWidthPx, true)
                width2 := MeasureTextWidthPx(line2)
                slack1 := Max(0, maxWidthPx - width1)
                slack2 := Max(0, maxWidthPx - width2)
                score := Max(slack1, slack2) * 1000 + Abs(slack1 - slack2)
                if (score < bestScore) {
                    bestScore := score
                    bestLine1 := line1
                    bestLine2 := line2
                }
            }

            if (bestLine1 = "")
                result := {Text: TruncateTextToWidthPx(text, maxWidthPx, true), Lines: 1, Height: 20}
            else
                result := {Text: bestLine1 "`n" bestLine2, Lines: 2, Height: 36}
        }
    }

    layoutCache[cacheKey] := result
    return result
}

CreateFlatTextButton(guiObj, options, textValue, clickHandler) {
    ctrl := guiObj.Add("Text", options . " +0x200 Center Border Background2B2B2B cF0F0F0", textValue)
    ctrl.OnEvent("Click", clickHandler)
    return ctrl
}

InitAppDarkMode() {
    ; Разрешаем тёмный режим на уровне процесса. Без этого вызовы
    ; SetWindowTheme("DarkMode_...") Windows частично игнорирует: шапки колонок
    ; ListView и скроллбары остаются светлыми. Используются недокументированные
    ; ординалы uxtheme (стабильны с Win10 1809 по Win11):
    ;   135 = SetPreferredAppMode (2 = ForceDark)
    ;   104 = RefreshImmersiveColorPolicyState
    ;   136 = FlushMenuThemes (тёмные контекстные меню)
    static done := false
    if done
        return
    done := true
    try {
        hUx := DllCall("Kernel32\GetModuleHandleW", "Str", "uxtheme", "Ptr")
        if !hUx
            hUx := DllCall("Kernel32\LoadLibraryW", "Str", "uxtheme", "Ptr")
        if !hUx
            return
        fnSetMode := DllCall("Kernel32\GetProcAddress", "Ptr", hUx, "Ptr", 135, "Ptr")
        fnRefresh := DllCall("Kernel32\GetProcAddress", "Ptr", hUx, "Ptr", 104, "Ptr")
        fnFlush := DllCall("Kernel32\GetProcAddress", "Ptr", hUx, "Ptr", 136, "Ptr")
        if fnSetMode
            DllCall(fnSetMode, "Int", 2)
        if fnRefresh
            DllCall(fnRefresh)
        if fnFlush
            DllCall(fnFlush)
    }
}

AllowDarkModeForWindow(hwnd) {
    ; uxtheme ординал 133 = AllowDarkModeForWindow(hwnd, TRUE). БЕЗ этого вызова
    ; Windows игнорирует SetWindowTheme("DarkMode_...") для конкретного окна —
    ; именно поэтому кнопки, скроллбары и шапки оставались светлыми, хотя тема
    ; ставилась. Вызывается для каждого окна и каждого контрола перед темой.
    static fnAllow := 0
    try {
        if !fnAllow {
            hUx := DllCall("Kernel32\GetModuleHandleW", "Str", "uxtheme", "Ptr")
            if !hUx
                hUx := DllCall("Kernel32\LoadLibraryW", "Str", "uxtheme", "Ptr")
            if hUx
                fnAllow := DllCall("Kernel32\GetProcAddress", "Ptr", hUx, "Ptr", 133, "Ptr")
        }
        if fnAllow
            DllCall(fnAllow, "Ptr", hwnd, "Int", 1)
    }
}

ApplyDarkWindowFrame(guiObj) {
    ; Тёмный заголовок окна (DWMWA_USE_IMMERSIVE_DARK_MODE). Атрибут 20 для
    ; Win10 1903+/Win11, атрибут 19 — для ранних сборок 1809. Без этого у тёмных
    ; окон Typer остаётся ярко-белая системная шапка.
    try AllowDarkModeForWindow(guiObj.Hwnd)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", guiObj.Hwnd, "UInt", 20, "Int*", 1, "UInt", 4)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", guiObj.Hwnd, "UInt", 19, "Int*", 1, "UInt", 4)
}

ApplyDarkThemeToGui(guiObj) {
    ; Единая точка затемнения ВСЕХ контролов окна по их типу. Вызывается ЯВНО
    ; перед Show главных окон (панель, Win+F9, карточка Данных, сводка слотов).
    ; Без дедупликации по Hwnd: окна пересоздаются, hwnd переиспользуется
    ; системой, а повторное применение темы дёшево и идемпотентно.
    ApplyDarkWindowFrame(guiObj)
    try {
        for hwnd, ctrl in guiObj {
            try {
                switch ctrl.Type {
                    case "Button", "CheckBox", "Radio":
                        AllowDarkModeForWindow(ctrl.Hwnd)
                        ; pszSubIdList обязан быть NULL, иначе тема игнорируется.
                        DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                        DllCall("User32\SendMessageW", "Ptr", ctrl.Hwnd, "UInt", 0x031A, "Ptr", 0, "Ptr", 0)
                    case "Edit", "ListBox", "ListView":
                        ApplyDarkControlTheme(ctrl)
                    case "DDL", "ComboBox":
                        ApplyDarkControlTheme(ctrl, "DarkMode_CFD")
                }
            }
        }
    }
}

; --- Тёмная шапка колонок ListView -------------------------------------------
; Единственный надёжный канал для NM_CUSTOMDRAW шапки — сабклассинг ListView
; (Header шлёт уведомления родителю). OnMessage здесь НЕ ГОДИТСЯ: когда занят
; другой псевдопоток AHK (таймеры), монитор пропускает сообщение и система
; рисует шапку сама чёрным текстом — отсюда были мерцания и «чёрное на чёрном».
;
; АРХИТЕКТУРА МИНИМАЛЬНОГО РИСКА. Этот колбэк — единственный AHK-код, который
; исполняется на КАЖДОЕ сообщение списка (при скролле — тысячи в секунду),
; в том числе вложенно внутри других псевдопотоков (любой SendMessage списку
; из таймера синхронно проходит через него). Поэтому здесь нет НИЧЕГО, кроме
; целочисленных сравнений и DllCall:
;   - фон шапки НЕ рисуем — его корректно красит нативная тема
;     DarkMode_ItemsView (проверено: фон был тёмным, проблема была
;     только в чёрном тексте);
;   - на CDDS_ITEMPREPAINT лишь задаём цвет текста через SetTextColor и
;     возвращаем CDRF_DODEFAULT — текст рисует сама система (это же
;     делает эталонная реализация win32-darkmode);
;   - никаких Buffer, строк, Map, GetClientRect, FillRect, DrawText.

DarkHeaderDrawProc(hWnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) {
    static handCursor := DllCall("User32\LoadCursorW", "Ptr", 0, "Ptr", 32649, "Ptr") ; IDC_HAND
    if (uMsg = 0x4E && lParam && NumGet(lParam + 0, 0, "Ptr") = dwRefData
        && NumGet(lParam + 0, 2 * A_PtrSize, "Int") = -12) { ; WM_NOTIFY + NM_CUSTOMDRAW от нашей шапки
        drawStage := NumGet(lParam + 0, 3 * A_PtrSize, "UInt")
        if (drawStage = 0x1) ; CDDS_PREPAINT
            return 0x20 ; CDRF_NOTIFYITEMDRAW
        if (drawStage = 0x10001) { ; CDDS_ITEMPREPAINT: только цвет текста
            hdc := NumGet(lParam + 0, (3 * A_PtrSize) + (A_PtrSize = 8 ? 8 : 4), "Ptr")
            if hdc
                DllCall("gdi32\SetTextColor", "Ptr", hdc, "UInt", 0xE8E8E8)
            return 0x0 ; CDRF_DODEFAULT — систему не подменяем
        }
        return 0x0
    }
    ; v13.19: курсор-«палец» над строками, где ЛКМ копирует промпт. WM_SETCURSOR
    ; приходит сюда синхронно (OnMessage пропускал бы его, пока занят другой
    ; псевдопоток). Только над клиентской частью самого списка (не шапка, не
    ; скроллбар); проверка строки — один hit-test в PanelListWantsHandCursor.
    if (uMsg = 0x20 && wParam = hWnd && (lParam & 0xFFFF) = 1 && handCursor
        && PanelListWantsHandCursor(hWnd)) {
        DllCall("User32\SetCursor", "Ptr", handCursor, "Ptr")
        return 1
    }
    return DllCall("comctl32\DefSubclassProc", "Ptr", hWnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
}

AttachDarkHeader(lvCtrl, headerHwnd) {
    ; Повторный SetWindowSubclass с тем же id безвреден (обновляет dwRefData),
    ; но attached-карта избавляет даже от этого лишнего вызова при каждом
    ; повторном применении темы к тому же окну.
    static drawCb := 0, attached := Map()
    if attached.Has(lvCtrl.Hwnd)
        return
    global DarkHeaderDrawCb
    if !drawCb
        try drawCb := CallbackCreate(DarkHeaderDrawProc, "F", 6)
    DarkHeaderDrawCb := drawCb ; v13.17: нужен BeginPanelListBulk/EndPanelListBulk
    if drawCb {
        try {
            DllCall("comctl32\SetWindowSubclass", "Ptr", lvCtrl.Hwnd, "Ptr", drawCb, "Ptr", lvCtrl.Hwnd, "Ptr", headerHwnd)
            attached[lvCtrl.Hwnd] := true
            if (attached.Count > 64) ; окна пересоздаются — не копим мёртвые hwnd
                attached.Clear(), attached[lvCtrl.Hwnd] := true
        }
    }
}

; v13.19: списки панели, где ЛКМ по промпту копирует его (курсор-«палец»).
RegisterPanelHandCursorList(kind, lv) {
    global PanelHandLvPrompts, PanelHandLvGlobal
    if (kind = "PROMPTS")
        PanelHandLvPrompts := lv.Hwnd
    else
        PanelHandLvGlobal := lv.Hwnd
}

PanelListWantsHandCursor(hWnd) {
    ; Вызывается из колбэка сабкласса на каждое WM_SETCURSOR (каждое движение
    ; мыши над списком): только целые числа, статические буферы и один hit-test.
    global PanelPromptClickCopy, PanelHandLvPrompts, PanelHandLvGlobal, DictGlobalResultMap
    static pt := Buffer(8, 0), ht := Buffer(32, 0)
    if !PanelPromptClickCopy
        return false
    if (hWnd != PanelHandLvPrompts && hWnd != PanelHandLvGlobal)
        return false
    if !DllCall("User32\GetCursorPos", "Ptr", pt)
        return false
    if !DllCall("User32\ScreenToClient", "Ptr", hWnd, "Ptr", pt)
        return false
    NumPut("Int", NumGet(pt, 0, "Int"), "Int", NumGet(pt, 4, "Int"), "UInt", 0, "Int", -1, "Int", 0, "Int", 0, ht, 0)
    idx := DllCall("User32\SendMessageW", "Ptr", hWnd, "UInt", 0x1039, "Ptr", 0, "Ptr", ht, "Ptr") ; LVM_SUBITEMHITTEST
    if (idx < 0)
        return false
    if (hWnd = PanelHandLvPrompts)
        return true
    ; Общий поиск: «палец» только над промптами — остальные строки ЛКМ не копирует.
    row := idx + 1
    if !DictGlobalResultMap.Has(row)
        return false
    item := DictGlobalResultMap[row]
    return IsObject(item) && item.HasOwnProp("Kind") && (item.Kind = "PROMPT")
}

; v13.19: подтверждение копирования — короткая вспышка строки акцентным цветом
; вместо всплывающей подсказки. Накладка — окно панели-владельца, прозрачное
; для мыши (layered + WS_EX_TRANSPARENT): двойной клик по строке проходит
; в список как раньше.
FlashPanelListRow(lv, row) {
    global PanelRowFlashGui, PanelRowFlashOwner, PanelRowFlashStep, ColorHighlight
    if (row < 1)
        return
    try {
        lvHwnd := lv.Hwnd
        rc := Buffer(16, 0) ; RECT.left = LVIR_BOUNDS (0) — вся строка
        if !DllCall("User32\SendMessageW", "Ptr", lvHwnd, "UInt", 0x100E, "Ptr", row - 1, "Ptr", rc, "Ptr") ; LVM_GETITEMRECT
            return
        cl := Buffer(16, 0)
        DllCall("User32\GetClientRect", "Ptr", lvHwnd, "Ptr", cl)
        headerBottom := 0
        hdr := DllCall("User32\SendMessageW", "Ptr", lvHwnd, "UInt", 0x101F, "Ptr", 0, "Ptr", 0, "Ptr") ; LVM_GETHEADER
        if (hdr && DllCall("User32\IsWindowVisible", "Ptr", hdr)) {
            hr := Buffer(16, 0)
            if DllCall("User32\GetWindowRect", "Ptr", hdr, "Ptr", hr)
                headerBottom := NumGet(hr, 12, "Int") - NumGet(hr, 4, "Int")
        }
        left := Max(NumGet(rc, 0, "Int"), 0)
        top := Max(NumGet(rc, 4, "Int"), headerBottom)
        right := Min(NumGet(rc, 8, "Int"), NumGet(cl, 8, "Int"))
        bottom := Min(NumGet(rc, 12, "Int"), NumGet(cl, 12, "Int"))
        if (right - left < 4 || bottom - top < 2)
            return
        pt := Buffer(8, 0)
        NumPut("Int", left, "Int", top, pt, 0)
        DllCall("User32\ClientToScreen", "Ptr", lvHwnd, "Ptr", pt)

        ownerHwnd := DllCall("User32\GetAncestor", "Ptr", lvHwnd, "UInt", 2, "Ptr") ; GA_ROOT
        flashHwnd := 0
        try flashHwnd := PanelRowFlashGui.Hwnd
        if (!flashHwnd || PanelRowFlashOwner != ownerHwnd || !DllCall("User32\IsWindow", "Ptr", flashHwnd)) {
            try PanelRowFlashGui.Destroy()
            flashGui := Gui("-Caption +ToolWindow -DPIScale +E0x80000 +E0x20 +E0x08000000 +Owner" ownerHwnd)
            flashGui.MarginX := 0, flashGui.MarginY := 0
            PanelRowFlashGui := flashGui
            PanelRowFlashOwner := ownerHwnd
            flashHwnd := flashGui.Hwnd
        }
        PanelRowFlashGui.BackColor := ColorHighlight
        PanelRowFlashStep := 0
        DllCall("User32\SetLayeredWindowAttributes", "Ptr", flashHwnd, "UInt", 0, "UChar", 120, "UInt", 2) ; LWA_ALPHA
        PanelRowFlashGui.Show("NA x" NumGet(pt, 0, "Int") " y" NumGet(pt, 4, "Int") " w" (right - left) " h" (bottom - top))
        SetTimer(PanelRowFlashTick, 30)
    }
}

PanelRowFlashTick() {
    global PanelRowFlashGui, PanelRowFlashStep
    static levels := [120, 104, 88, 72, 56, 40, 26, 12]
    PanelRowFlashStep += 1
    if (PanelRowFlashStep > levels.Length) {
        SetTimer(PanelRowFlashTick, 0)
        try PanelRowFlashGui.Hide()
        return
    }
    try DllCall("User32\SetLayeredWindowAttributes", "Ptr", PanelRowFlashGui.Hwnd, "UInt", 0, "UChar", levels[PanelRowFlashStep], "UInt", 2)
    catch {
        SetTimer(PanelRowFlashTick, 0)
    }
}

ApplyDarkControlTheme(ctrl, themeName := "DarkMode_Explorer") {
    ; Тёмная тема для системных частей контролов, которые не красятся через
    ; Background/c-опции: скроллбары Edit/ListView и заголовки колонок ListView.
    ; ВАЖНО: третий параметр SetWindowTheme (pszSubIdList) обязан быть NULL
    ; ("Ptr", 0). Пустая строка ("Str", "") — НЕ NULL: Windows тихо игнорирует
    ; тему, поэтому кнопки и скроллбары оставались светлыми.
    try AllowDarkModeForWindow(ctrl.Hwnd)
    try DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Str", themeName, "Ptr", 0)
    ; WM_THEMECHANGED — заставляет контрол немедленно перечитать тему (скроллбары).
    try DllCall("User32\SendMessageW", "Ptr", ctrl.Hwnd, "UInt", 0x031A, "Ptr", 0, "Ptr", 0)
    ; У ListView заголовок колонок — отдельное дочернее окно SysHeader32.
    try {
        headerHwnd := DllCall("User32\SendMessageW", "Ptr", ctrl.Hwnd, "UInt", 0x101F, "Ptr", 0, "Ptr", 0, "Ptr") ; LVM_GETHEADER
        if headerHwnd {
            AllowDarkModeForWindow(headerHwnd)
            DllCall("uxtheme\SetWindowTheme", "Ptr", headerHwnd, "Str", "DarkMode_ItemsView", "Ptr", 0)
            AttachDarkHeader(ctrl, headerHwnd) ; полная отрисовка шапки, см. выше
            ; Двойная буферизация ListView: убирает мерцание при наведении,
            ; прокрутке и перетаскивании ширины колонок (LVS_EX_DOUBLEBUFFER).
            DllCall("User32\SendMessageW", "Ptr", ctrl.Hwnd, "UInt", 0x1036, "Ptr", 0x10000, "Ptr", 0x10000)
        }
    }
}

CreateTyperDialog(options, title, ownedByPanel := true) {
    global DictPanelGui, DictPanelChildGuis
    opts := options
    usePanelOwner := false
    panelHwnd := 0
    try panelHwnd := DictPanelGui.Hwnd
    try {
        ; Панельные дочерние окна не должны жить отдельной поверх-всего сущностью:
        ; если окно вызвано из активной панели, делаем его owned popup без +AlwaysOnTop.
        if ownedByPanel && panelHwnd && WinExist("ahk_id " panelHwnd) && WinActive("ahk_id " panelHwnd)
            usePanelOwner := true
    }
    if usePanelOwner
        opts := Trim(RegExReplace(opts, "i)(^|\s)\+AlwaysOnTop(?=\s|$)", "$1"))

    guiObj := Gui(opts, title)
    ApplyDarkWindowFrame(guiObj)
    if usePanelOwner {
        try guiObj.Opt("+Owner" panelHwnd)
        try DictPanelChildGuis.Push(guiObj)
    }
    return guiObj
}

DestroyPanelChildGuis() {
    global DictPanelChildGuis
    for childGui in DictPanelChildGuis {
        try childGui.Destroy()
    }
    DictPanelChildGuis := []
}

SetEditCaretEnd(editCtrl) {
    try {
        textLen := StrLen(editCtrl.Value)
        editCtrl.Focus()
        ; EM_SETSEL: caret в конец без выделения. Иначе Windows часто выделяет весь Edit
        ; при первом фокусе, что неудобно для правки длинных фраз/промптов.
        DllCall("User32\SendMessageW", "Ptr", editCtrl.Hwnd, "UInt", 0x00B1, "Ptr", textLen, "Ptr", textLen, "Ptr")
    }
}

IsPasswordFieldActive() {
    try {
        ctrl := ControlGetFocus("A")
        if !ctrl
            return false

        ctrlHwnd := ControlGetHwnd(ctrl, "A")
        if !ctrlHwnd
            return false

        ; Бит 0x20 — это ES_PASSWORD только у Edit-семейства. У других классов
        ; он означает другое (например BS_LEFTTEXT у кнопок) и давал ложные
        ; срабатывания «поле пароля» на обычных контролах.
        cls := WinGetClass("ahk_id " ctrlHwnd)
        if !InStr(cls, "Edit")
            return false

        style := ControlGetStyle(ctrl, "A")
        return !!(style & 0x20) ; ES_PASSWORD
    } catch {
        return false
    }
}

HideSuggestedWordByIndex(index) {
    global CurrentWords, WordDB, PhraseDB, PromptDB, LinkDB, CurrentSuggestionMode
    global LastActionType, LastHiddenWord

    if (index < 1 || index > CurrentWords.Length)
        return

    if (CurrentSuggestionMode = "DATA") {
        ConfirmDataSelection(index)
        return
    }

    if IsSnippetSuggestionMode(CurrentSuggestionMode) {
        snippetText := CurrentWords[index].HasOwnProp("Full") ? CurrentWords[index].Full : CurrentWords[index].Display
        key := StrLower(snippetText)
        if (CurrentSuggestionMode = "LINKS") {
            id := CurrentWords[index].HasOwnProp("Id") ? CurrentWords[index].Id : CurrentWords[index].Key
            if !LinkDB.Has(id)
                return
            LinkDB[id].Hidden := 1
            LastActionType := "HIDE_LINK"
            LastHiddenWord := id
            ToolTip("○ Ссылка скрыта из выдачи")
        } else {
            store := (CurrentSuggestionMode = "PROMPTS") ? PromptDB : PhraseDB
            if !store.Has(key)
                return
            store[key].Hidden := 1
            LastActionType := (CurrentSuggestionMode = "PROMPTS") ? "HIDE_PROMPT" : "HIDE_PHRASE"
            LastHiddenWord := key
            ToolTip((CurrentSuggestionMode = "PROMPTS") ? "○ Промпт скрыт из выдачи" : "○ Фраза скрыта из выдачи")
        }
        SetTimer(() => ToolTip(), -1200)
        ShowSuggestions()
        return
    }

    word := CurrentWords[index].Display
    key := StrLower(word)
    if !WordDB.Has(key)
        return
    WordDB[key].Hidden := 1
    LastActionType := "HIDE_WORD"
    LastHiddenWord := key
    ToolTip("○ Скрыто из выдачи")
    SetTimer(() => ToolTip(), -1200)
    ShowSuggestions()
}

EditSuggestedPhraseByIndex(index) {
    global CurrentWords, CurrentSuggestionMode, CurrentInput
    if !IsSnippetSuggestionMode(CurrentSuggestionMode)
        return
    if (index < 1 || index > CurrentWords.Length)
        return
    OpenDetachedSnippetEditor(CurrentSuggestionMode, index)
}

DeleteSuggestedPhraseByIndex(index) {
    global CurrentWords, CurrentSuggestionMode, PhraseDB, PromptDB, LinkDB, SelectedPhraseIndex, CurrentInput

    if !IsSnippetSuggestionMode(CurrentSuggestionMode)
        return
    if (index < 1 || index > CurrentWords.Length)
        return

    snippetText := CurrentWords[index].HasOwnProp("Full") ? CurrentWords[index].Full : CurrentWords[index].Display
    key := StrLower(snippetText)
    deleteMsg := "🗑️ Фраза удалена"

    if (CurrentSuggestionMode = "PROMPTS") {
        if !PromptDB.Has(key)
            return
        PromptDB.Delete(key)
        RemovePromptFromIndexes(key)
        deleteMsg := "🗑️ Промпт удалён"
    } else if (CurrentSuggestionMode = "LINKS") {
        id := CurrentWords[index].HasOwnProp("Id") ? CurrentWords[index].Id : CurrentWords[index].Key
        if !LinkDB.Has(id)
            return
        LinkDB.Delete(id)
        RemoveLinkFromIndexes(id)
        deleteMsg := "🗑️ Ссылка удалена"
    } else {
        if !PhraseDB.Has(key)
            return
        PhraseDB.Delete(key)
        RemovePhraseFromIndexes(key)
    }

    QueuePhraseSave(120)

    ToolTip(deleteMsg)
    SetTimer(() => ToolTip(), -1100)

    if (SelectedPhraseIndex > CurrentWords.Length - 1)
        SelectedPhraseIndex := Max(1, CurrentWords.Length - 1)

    if (CurrentInput != "")
        ShowSuggestions()
    else
        HideSuggestions()
}

HideSuggestedStemByIndex(index) {
    global CurrentStems, WordDB
    global LastActionType, LastHiddenWord

    if (index < 1 || index > CurrentStems.Length)
        return

    stem := CurrentStems[index].Display
    stem := RegExReplace(stem, "^\s*▶\s*")
    key := StrLower(stem)

    if !WordDB.Has(key)
        return

    WordDB[key].Hidden := 1
    LastActionType := "HIDE_WORD"
    LastHiddenWord := key

    ToolTip("○ Основа скрыта из выдачи")
    SetTimer(() => ToolTip(), -1200)
    ShowSuggestions()
}

GetQuotePair() {
    ; Берём раскладку не у потока самого скрипта, а у активного окна/потока ввода.
    ; Иначе можно получать постоянный один и тот же HKL и не видеть реальное
    ; переключение RU/EN в приложении, где сейчас печатает пользователь.
    hwnd := DllCall("User32\GetForegroundWindow", "Ptr")
    threadId := 0

    if hwnd
        threadId := DllCall("User32\GetWindowThreadProcessId", "Ptr", hwnd, "UInt*", 0, "UInt")

    hkl := DllCall("User32\GetKeyboardLayout", "UInt", threadId, "UPtr")
    langId := hkl & 0xFFFF
    primaryLang := langId & 0x3FF

    if (primaryLang = 0x19) ; LANG_RUSSIAN
        return ["«", "»"]
    return ["“", "”"]
}

WrapSelectionOrCurrentWordInQuotes() {
    ; v13.17: переписано. Порядок источников: (1) набираемое слово, (2) только
    ; что вставленное Typer'ом слово, (3) выделение. Хвост ввода сбрасывается
    ; стрелками, Home/End, кликами (теперь и с Shift/Ctrl) и Ctrl+A, поэтому при
    ; выделении (1) и (2) уже пусты и Backspace не стирает текст ПЕРЕД выделением.
    ; Повторный Ctrl+\ снимает только что поставленные кавычки (а не плодит ««»»),
    ; Alt+Z возвращает текст как был.
    global CurrentInput, JustInsertedWord, NextCharUpper, PhantomInputLen
    global LastInsertedText, LastInsertedHadSpace, LastInsertedCanQuote, LastInsertedKind
    global LastWordUndoRestoreText, LastWordUndoRestoreInput

    InvalidateHotstringUndo()

    quotes := GetQuotePair()
    leftQuote := quotes[1]
    rightQuote := quotes[2]

    ; 1) Текущее набираемое слово. Основа без окончания в кавычки не оборачивается.
    ; Фантомный префикс режимов PgUp/PgDn в поле не напечатан — его не берём.
    typed := (PhantomInputLen > 0) ? SubStr(CurrentInput, PhantomInputLen + 1) : CurrentInput
    if (typed != "") {
        if (LastInsertedKind = "STEM" && CurrentInput = LastInsertedText) {
            ToolTip("⚠️ Основа не оборачивается в кавычки")
            SetTimer(() => ToolTip(), -1200)
            return
        }

        quoted := leftQuote typed rightQuote
        SafeSend(quoted . " ", GetTypedBackspaceCount())
        ResetInput()
        JustInsertedWord := true
        NextCharUpper := false
        RememberInsertedText(quoted, true, "QUOTED")
        StartWordInsertUndo(quoted, true, "QUOTED")
        LastWordUndoRestoreText := typed
        LastWordUndoRestoreInput := typed
        return
    }

    ; 2) Только что вставленное слово. Пробел после него сохраняем как был.
    if (LastInsertedCanQuote && LastInsertedText != "") {
        if (LastInsertedKind = "STEM") {
            ToolTip("⚠️ Основа не оборачивается в кавычки")
            SetTimer(() => ToolTip(), -1200)
            return
        }

        rawText := LastInsertedText
        hadSpace := LastInsertedHadSpace ? true : false
        spaceText := hadSpace ? " " : ""
        backspaces := GetBackspaceCountForText(rawText) + (hadSpace ? 1 : 0)

        if (LastInsertedKind = "QUOTED") {
            ; Повторное нажатие — снять кавычки, поставленные только что.
            innerText := UnwrapQuotedText(rawText)
            if (innerText = "") {
                ToolTip("⚠️ Кавычки уже стоят")
                SetTimer(() => ToolTip(), -1200)
                return
            }
            SafeSend(innerText . spaceText, backspaces)
            JustInsertedWord := hadSpace
            NextCharUpper := false
            RememberInsertedText(innerText, hadSpace, "WORD")
            StartWordInsertUndo(innerText, hadSpace, "QUOTED")
            LastWordUndoRestoreText := rawText . spaceText
            LastWordUndoRestoreInput := ""
            ToolTip("Кавычки сняты")
            SetTimer(() => ToolTip(), -900)
            return
        }

        quotedText := leftQuote rawText rightQuote
        SafeSend(quotedText . spaceText, backspaces)
        JustInsertedWord := hadSpace
        NextCharUpper := false
        RememberInsertedText(quotedText, hadSpace, "QUOTED")
        StartWordInsertUndo(quotedText, hadSpace, "QUOTED")
        LastWordUndoRestoreText := rawText . spaceText
        LastWordUndoRestoreInput := ""
        return
    }

    ; 3) Выделение. Края (пробелы, переводы строк) остаются как были — кавычки
    ; ставятся вокруг сути. Замена — одной вставкой через буфер (выделение
    ; заменяется целиком): посимвольный набор ломали автозакрытие кавычек,
    ; автоотступы и Enter на переводах строк. Уже в кавычках — снимаем их.
    selectedText := GetSelectedTextViaClipboard(0.45)
    if (selectedText != "" && RegExMatch(selectedText, "s)^(\s*)(.*?)(\s*)\z", &m) && m[2] != "") {
        coreText := m[2]
        innerText := UnwrapQuotedText(coreText)
        newCore := (innerText != "") ? innerText : (leftQuote coreText rightQuote)
        SafeSendPhrase(m[1] newCore m[3], 0)
        ; Вставку выделения не переобрамляем и не откатываем по Alt+Z: для
        ; многострочного текста Backspace-откат ненадёжен (есть Ctrl+Z приложения).
        InvalidateInsertedQuote()
        ResetInput()
        JustInsertedWord := false
        NextCharUpper := false
        if (innerText != "") {
            ToolTip("Кавычки сняты")
            SetTimer(() => ToolTip(), -900)
        }
        return
    }

    ToolTip("⚠️ Нет слова или выделения для кавычек")
    SetTimer(() => ToolTip(), -1200)
}

UnwrapQuotedText(text) {
    ; v13.17: если text целиком в ОДНОЙ паре кавычек — вернуть содержимое, иначе "".
    ; «а» и «б» — не одна пара: первая кавычка закрывается раньше конца.
    if (StrLen(text) < 3)
        return ""
    first := SubStr(text, 1, 1)
    last := SubStr(text, -1)
    for _, pair in [["«", "»"], ["“", "”"], ["„", "“"], ['"', '"']] {
        if !(first == pair[1] && last == pair[2])
            continue
        inner := SubStr(text, 2, -1)
        if (pair[1] == pair[2])
            return InStr(inner, pair[1], true) ? "" : inner
        depth := 0
        Loop Parse, inner {
            if (A_LoopField == pair[1]) {
                depth += 1
            } else if (A_LoopField == pair[2]) {
                depth -= 1
                if (depth < 0)
                    return ""
            }
        }
        return (depth = 0) ? inner : ""
    }
    return ""
}
; #EndRegion

; #Region 🧠 ЛОГИКА СЛОВАРЯ И ПОДСКАЗОК
FormatWordCase(word, mode) {
    if (mode == 1) {
        return StrUpper(SubStr(word, 1, 1)) . SubStr(word, 2)
    } else if (mode == 2) {
        return StrUpper(word)
    }
    return word
}

NormalizeStemCandidate(word) {
    global MinWordLen

    wordLen := StrLen(word)
    if (wordLen < MinWordLen * 2)
        return word

    best := word
    Loop (wordLen - MinWordLen) {
        suffixLen := wordLen - A_Index
        if (suffixLen < MinWordLen)
            break
        suffix := SubStr(word, wordLen - suffixLen + 1)
        if (SubStr(word, 1, suffixLen) == suffix) {
            best := suffix
            break
        }
    }
    return best
}

PinCurrentStem() {
    global CurrentInput, WordDB, MinWordLen
    global LastActionType, LastAddedWord, LastAddedScore

    if !IsDictionaryActive() { ; v13.18
        ShowDictionaryOffTip()
        return
    }

    ; Основа не получает искусственный "миллионный" рейтинг.
    ; Она живёт в своём списке, но её обычный Count продолжает расти,
    ; чтобы основы конкурировали между собой по частоте использования.
    if (StrLen(CurrentInput) < MinWordLen) {
        ToolTip("⚠️ Основа слишком короткая (< " MinWordLen " симв.)")
        SetTimer(() => ToolTip(), -1500)
        return
    }

    stemText := NormalizeStemCandidate(CurrentInput)
    if (stemText != CurrentInput) {
        ToolTip("ℹ️ Основа нормализована")
        SetTimer(() => ToolTip(), -900)
    }

    Key := StrLower(stemText)
    if IsExcludedWordKey(Key) {
        ToolTip("🚫 Это слово исключено из выдачи")
        SetTimer(() => ToolTip(), -1200)
        ResetInput()
        return
    }

    if WordDB.Has(Key) {
        WordDB[Key].IsStem := 1
        if !WordDB[Key].HasOwnProp("Hidden")
            WordDB[Key].Hidden := 0
        if !WordDB[Key].HasOwnProp("Count")
            WordDB[Key].Count := 0
        if !WordDB[Key].HasOwnProp("DataOnly")
            WordDB[Key].DataOnly := 0
        WordDB[Key].Count += 1
    } else {
        WordDB[Key] := {Display: StrLower(stemText), Count: 1, Hidden: 0, IsStem: 1, DataOnly: 0}
        AddWordToPrefixIndexes(Key)
    }

    LastActionType := "PIN_STEM"
    LastAddedWord := Key
    LastAddedScore := 1

    ToolTip("⭐ Основа закреплена")
    SetTimer(() => ToolTip(), -1000)
    ShowSuggestions()
}

LearnWord(word, scoreToAdd := 1, rememberUndo := false) {
    LearnWordCore(word, scoreToAdd, rememberUndo, false)
}

LearnWordExact(word, scoreToAdd := 1, rememberUndo := true) {
    ; Как LearnWord, но Display запоминает регистр как введено.
    LearnWordCore(word, scoreToAdd, rememberUndo, true)
}

GetManualLearnScore(word) {
    ; v13.19: слово, добавленное вручную (RShift, выделение + RShift), сразу
    ; получает рейтинг ManualWordScore и встаёт в OSD выше авто-выученных.
    ; MinUsageThreshold (5) — только порог видимости: с ним новое слово
    ; оказывалось в самом низу списка. Известное слово поднимается до
    ; ManualWordScore (и, как раньше, минимум на MinUsageThreshold).
    ; Alt+Z вычитает ровно добавленное (LastAddedScore).
    global WordDB, ManualWordScore, MinUsageThreshold
    key := StrLower(Trim(word, "-"))
    if !WordDB.Has(key)
        return ManualWordScore
    current := 0
    try current := Integer(WordDB[key].Count)
    return Max(ManualWordScore - current, MinUsageThreshold)
}

LearnWordCore(word, scoreToAdd, rememberUndo, exactDisplay) {
    ; Общая логика LearnWord/LearnWordExact — раньше два почти одинаковых тела.
    global MinWordLen, MaxLearnedWordLen, WordDB, DictMode
    global LastAddedWord, LastAddedScore, LastActionType

    ; v13.18: словарь выключен (или ещё не прочитан) — запоминать некуда.
    if !IsDictionaryActive()
        return

    ; Дефис — символ слова (нужен для «кто-то», «как-нибудь»), поэтому после
    ; тире/разделителей без пробела в словарь попадал мусор вида «-----ну».
    ; Обрезаем краевые дефисы (внутренние сохраняются) и заново проверяем длину.
    word := Trim(word, "-")

    if (StrLen(word) < MinWordLen || StrLen(word) > MaxLearnedWordLen)
        return
    if (!exactDisplay && RegExMatch(word, "^[\-\d]+$"))
        return

    Key := StrLower(word)
    if IsExcludedWordKey(Key)
        return

    ; v13.18: ручной режим — новые слова только вручную (LearnWordExact: RShift,
    ; выделение + RShift); у уже известных рейтинг растёт как раньше.
    if (!exactDisplay && DictMode = "manual" && !WordDB.Has(Key))
        return

    if WordDB.Has(Key) {
        WordDB[Key].Count += scoreToAdd
        if exactDisplay
            WordDB[Key].Display := word
        if !WordDB[Key].HasOwnProp("Hidden")
            WordDB[Key].Hidden := 0
        if !WordDB[Key].HasOwnProp("IsStem")
            WordDB[Key].IsStem := 0
        if !WordDB[Key].HasOwnProp("DataOnly")
            WordDB[Key].DataOnly := 0
    } else {
        WordDB[Key] := {Display: exactDisplay ? word : Key, Count: scoreToAdd, Hidden: 0, IsStem: 0, DataOnly: 0}
        AddWordToPrefixIndexes(Key)
    }

    if rememberUndo {
        LastActionType := "LEARN_FORCED"
        LastAddedWord := Key
        LastAddedScore := scoreToAdd
    }
}

UpdateDataLists() {
    global CurrentInput, CurrentStems, CurrentWords, CurrentDataItems, WordDB, PhraseDB, PromptDB, LinkDB, CapitalizeMode, MinUsageThreshold
    global MaxStems, MaxWords, MaxPhrases, MaxPrompts, MaxLinks, CurrentSuggestionMode

    CurrentStems := []
    CurrentWords := []
    CurrentDataItems := []
    CurrentSuggestionMode := "WORDS"
    if (CurrentInput = "")
        return

    if IsDataTriggerInput(CurrentInput) {
        CurrentSuggestionMode := "DATA"
        dataPrefix := SubStr(CurrentInput, 2)
        CurrentDataItems := GetTopDataMatches(dataPrefix)
        return
    }

    if IsLinkTriggerInput(CurrentInput) || IsLinkContentTriggerInput(CurrentInput) {
        CurrentSuggestionMode := "LINKS"
        isContainsSearch := IsLinkContentTriggerInput(CurrentInput)
        query := SubStr(CurrentInput, isContainsSearch ? 3 : 2)
        rows := GetTopLinkMatches(query, isContainsSearch, MaxLinks)
        for _, row in rows {
            data := row.Data
            CurrentWords.Push({Display: BuildLinkDisplay(data), Full: data.Url, Url: data.Url, Count: data.Count, Key: row.Id, Id: row.Id})
        }
        return
    }

    if IsPhraseTriggerInput(CurrentInput) || IsPromptTriggerInput(CurrentInput) || IsPhraseContentTriggerInput(CurrentInput) || IsPromptContentTriggerInput(CurrentInput) {
        isPrompt := IsPromptTriggerInput(CurrentInput) || IsPromptContentTriggerInput(CurrentInput)
        isContainsSearch := IsPhraseContentTriggerInput(CurrentInput) || IsPromptContentTriggerInput(CurrentInput)
        query := StrLower(SubStr(CurrentInput, isContainsSearch ? 3 : 2))
        store := isPrompt ? PromptDB : PhraseDB
        limit := isPrompt ? MaxPrompts : MaxPhrases

        if isContainsSearch {
            rows := (Trim(query) = "") ? GetTopSnippetRows(store, limit) : GetSnippetContainsMatchRows(store, query, limit)
            if (rows.Length > 0) {
                CurrentSuggestionMode := isPrompt ? "PROMPTS" : "PHRASES"
                for _, row in rows
                    CurrentWords.Push({Display: TruncatePhraseForOSD(RegExReplace(row.Text, "\s+", " ")), Full: row.Text, Count: row.Count, Key: StrLower(row.Text)})
            }
            return
        }

        ; БЫЛО: кандидаты склеивались в строку "count`tтекст`n" и сортировались Sort().
        ; Многострочные промпты (и текст с табами) ломали формат: в OSD попадали
        ; обрывки строк, а вставка теряла часть текста. Теперь — массив + сортировка.
        rows := []
        candidates := isPrompt ? GetPromptIndexedCandidates(query) : GetPhraseIndexedCandidates(query)
        for key, _ in candidates {
            if !store.Has(key)
                continue
            data := store[key]
            hidden := data.HasOwnProp("Hidden") ? data.Hidden : 0
            if hidden
                continue
            if (SubStr(key, 1, StrLen(query)) = query)
                rows.Push({Text: data.Text, Count: data.Count})
        }

        if (rows.Length > 0) {
            CurrentSuggestionMode := isPrompt ? "PROMPTS" : "PHRASES"
            SortRowsInPlace(rows, SnippetCountDescComparator)
            for idx, row in rows {
                if (idx > limit)
                    break
                CurrentWords.Push({Display: TruncatePhraseForOSD(RegExReplace(row.Text, "\s+", " ")), Full: row.Text, Count: row.Count, Key: StrLower(row.Text)})
            }
        }
        return
    }

    PrefixLower := StrLower(CurrentInput)

    MatchStems := ""
    MatchWords := ""
    VarSetStrCapacity(&MatchStems, 1024)
    VarSetStrCapacity(&MatchWords, 1024)

    ; v13.19: кандидаты — из сужающегося кэша (GetWordPrefixMatches): точная
    ; проверка префикса уже сделана там, по всему бакету индекса — только когда
    ; запрос не продолжает прошлый.
    for _, key in GetWordPrefixMatches(PrefixLower) {
        if !WordDB.Has(key)
            continue

        data := WordDB[key]
        hidden := data.HasOwnProp("Hidden") ? data.Hidden : 0
        dataOnly := data.HasOwnProp("DataOnly") ? data.DataOnly : 0
        if (hidden || dataOnly)
            continue

        isStem := data.HasOwnProp("IsStem") ? data.IsStem : 0
        if isStem {
            MatchStems .= data.Count "`t" data.Display "`n"
        } else if (data.Count >= MinUsageThreshold) {
            if (StrLower(data.Display) == PrefixLower)
                continue
            MatchWords .= data.Count "`t" data.Display "`n"
        }
    }

    if (MatchStems != "") {
        MatchStems := Sort(MatchStems, "N R")
        Loop Parse, MatchStems, "`n", "`r" {
            if (A_Index > MaxStems || A_LoopField == "")
                break
            parts := StrSplit(A_LoopField, "`t")
            formattedWord := FormatWordCase(parts[2], CapitalizeMode)
            CurrentStems.Push({Display: formattedWord, Count: parts[1]})
        }
    }

    if (MatchWords != "") {
        MatchWords := Sort(MatchWords, "N R")
        Loop Parse, MatchWords, "`n", "`r" {
            if (A_Index > MaxWords || A_LoopField == "")
                break
            parts := StrSplit(A_LoopField, "`t")
            formattedWord := FormatWordCase(parts[2], CapitalizeMode)
            CurrentWords.Push({Display: formattedWord, Count: parts[1]})
        }
    }
}
ShowSuggestions() {
    global SuggestionVisible, CurrentStems, CurrentWords, CurrentDataItems, SelectedStemIndex, SuggGui, CurrentSuggestionMode, PhrasePreviewHeight
    global SelectedPhraseIndex, LastPhraseOsdInput, CurrentInput, OsdWindowRect

    UpdateDataLists()
    if (CurrentStems.Length == 0 && CurrentWords.Length == 0 && CurrentDataItems.Length == 0) {
        HideSuggestions()
        return
    }

    ; Каждый новый показ OSD начинается с топ-1 основы.
    SelectedStemIndex := CurrentStems.Length > 0 ? 1 : 0

    if (IsSnippetSuggestionMode(CurrentSuggestionMode)) {
        PreparePhraseRows(540)
        if (LastPhraseOsdInput != CurrentInput) {
            SelectedPhraseIndex := CurrentWords.Length > 0 ? 1 : 0
            LastPhraseOsdInput := CurrentInput
        }
    } else {
        SelectedPhraseIndex := 1
        LastPhraseOsdInput := ""
    }

    UpdateUI()

    metrics := GetSuggestionWindowMetrics()
    pos := MoveSuggestionWindow(metrics.W, metrics.H)

    ; v13.19: окно двигаем, только если место/размер правда изменились, и всегда
    ; через Show: Move задаёт размер внешней рамки, Show — клиентской области,
    ; поэтому со второй буквы OSD «съёживался» на 2 px (рамка +Border).
    rectKey := pos.X "," pos.Y "," metrics.W "," metrics.H
    if !SuggestionVisible {
        SuggGui.Show("NA x" pos.X " y" pos.Y " w" metrics.W " h" metrics.H)
        SuggestionVisible := true
        OsdWindowRect := rectKey
    } else if (rectKey != OsdWindowRect) {
        SuggGui.Show("NA x" pos.X " y" pos.Y " w" metrics.W " h" metrics.H)
        OsdWindowRect := rectKey
    }
    ApplySuggestionTransparency()
    ScheduleWordOsdAutoHide()
}


ScheduleWordOsdAutoHide() {
    global SuggestionVisible, CurrentSuggestionMode, WordOsdAutoHideEnabled, WordOsdAutoHideMs, WordOsdLastActivityTick
    if (!SuggestionVisible || CurrentSuggestionMode != "WORDS" || !WordOsdAutoHideEnabled) {
        SetTimer(WordOsdAutoHideTimer, 0)
        return
    }
    WordOsdLastActivityTick := A_TickCount
    SetTimer(WordOsdAutoHideTimer, -Max(1000, WordOsdAutoHideMs))
}

WordOsdAutoHideTimer(*) {
    global SuggestionVisible, CurrentSuggestionMode, WordOsdAutoHideEnabled, WordOsdAutoHideMs, WordOsdLastActivityTick
    if (!SuggestionVisible || CurrentSuggestionMode != "WORDS" || !WordOsdAutoHideEnabled)
        return
    if ((A_TickCount - WordOsdLastActivityTick) >= Max(1000, WordOsdAutoHideMs) - 60)
        HideSuggestions()
}

SuspendWordOsdDigitSelection(*) {
    global SuggestionVisible, CurrentSuggestionMode, WordDigitLiteralMode
    if (!SuggestionVisible || CurrentSuggestionMode != "WORDS")
        return false
    WordDigitLiteralMode := true
    HideSuggestions()
    ToolTip("⌨️ Цифры печатаются как текст до пробела/Enter")
    SetTimer(() => ToolTip(), -1100)
    return true
}

ApplySuggestionTransparency() {
    ; v13.19: прозрачность ставится один раз (и при смене настройки), а не на
    ; каждую букву: SetLayeredWindowAttributes заставляет перекомпоновать окно.
    global SuggGui, OsdTransparency
    static appliedHwnd := 0, appliedValue := ""
    if (SuggGui.Hwnd = appliedHwnd && OsdTransparency = appliedValue)
        return
    try {
        WinSetTransparent(OsdTransparency, "ahk_id " SuggGui.Hwnd)
        appliedHwnd := SuggGui.Hwnd
        appliedValue := OsdTransparency
    }
}

GetStemDisplayColor(index) {
    global ColorHighlight
    ; Первый (самый яркий) уровень — актуальный акцентный цвет, дальше затухание.
    palette := [ColorHighlight, "B9CDA8", "A9B8AE", "97A7B2", "8FAFD5"]
    if (index < 1)
        index := 1
    if (index > palette.Length)
        index := palette.Length
    return palette[index]
}

; ---- v13.19: строки OSD меняются только при реальном изменении ---------------
; Раньше UpdateUI на КАЖДУЮ букву заново ставил текст, цвет (Opt("c…") —
; принудительная перерисовка), позицию и видимость всем ~25 контролам OSD,
; даже если ничего не поменялось, а префиксы строк фраз ещё и прятал/показывал
; заново. На полупрозрачном окне это лишние перерисовки и мелкое мерцание.
; Теперь последнее состояние каждого контрола хранится в OsdLabelCache.
OsdLabelState(ctrl) {
    global OsdLabelCache
    if !OsdLabelCache.Has(ctrl)
        OsdLabelCache[ctrl] := {T: "", C: "", X: "", Y: "", W: "", H: "", V: -1}
    return OsdLabelCache[ctrl]
}

OsdLabelUpdate(ctrl, text, color := "") {
    st := OsdLabelState(ctrl)
    if !(st.T == text) {
        ctrl.Text := text
        st.T := text
    }
    if (color != "" && st.C != color) {
        ctrl.Opt("c" color)
        st.C := color
    }
}

OsdLabelPlace(ctrl, x, y, w, h) {
    st := OsdLabelState(ctrl)
    if (st.X != x || st.Y != y || st.W != w || st.H != h) {
        ctrl.Move(x, y, w, h)
        st.X := x, st.Y := y, st.W := w, st.H := h
    }
    if (st.V != 1) {
        ctrl.Visible := true
        st.V := 1
    }
}

OsdLabelHide(ctrl) {
    st := OsdLabelState(ctrl)
    if (st.V != 0) {
        ctrl.Visible := false
        st.V := 0
    }
}

UpdateUI() {
    global CurrentStems, CurrentWords, CurrentDataItems, LabelsStems, LabelsWordPrefixes, LabelsWords, SepLine, SelectedStemIndex, CurrentSuggestionMode
    global MaxStems, PhrasePreviewEdit, SelectedPhraseIndex, ColorHighlight, ColorTextWords, PhrasePreviewHeight

    ; v13.19: все изменения контролов — через OsdLabelUpdate/OsdLabelPlace/OsdLabelHide.
    isSnippet := IsSnippetSuggestionMode(CurrentSuggestionMode)
    ContentW := isSnippet ? 590 : ((CurrentSuggestionMode = "DATA") ? 680 : 230)
    phrasePrefixW := 42
    phraseBodyW := Max(220, ContentW - phrasePrefixW - 8)
    CurrentY := 10
    Loop MaxStems {
        if (CurrentSuggestionMode != "DATA" && A_Index <= CurrentStems.Length) {
            stemPrefix := (A_Index == SelectedStemIndex) ? "▶ " : "  "
            OsdLabelUpdate(LabelsStems[A_Index], stemPrefix CurrentStems[A_Index].Display, GetStemDisplayColor(A_Index))
            OsdLabelPlace(LabelsStems[A_Index], 10, CurrentY, ContentW, 20)
            CurrentY += 22
        } else {
            OsdLabelHide(LabelsStems[A_Index])
        }
    }

    rowsCount := (CurrentSuggestionMode = "DATA") ? CurrentDataItems.Length : CurrentWords.Length
    normalRowH := 22

    if (CurrentSuggestionMode != "DATA" && CurrentStems.Length > 0 && CurrentWords.Length > 0) {
        OsdLabelPlace(SepLine, 10, CurrentY + 2, ContentW, 1)
        CurrentY += 15
    } else {
        OsdLabelHide(SepLine)
    }

    Loop LabelsWords.Length {
        if (A_Index > rowsCount) {
            OsdLabelHide(LabelsWordPrefixes[A_Index])
            OsdLabelHide(LabelsWords[A_Index])
            continue
        }
        if (CurrentSuggestionMode = "DATA") {
            if !CurrentDataItems.Has(A_Index) {
                OsdLabelHide(LabelsWordPrefixes[A_Index])
                continue
            }
            rowData := CurrentDataItems[A_Index]
        } else {
            if !CurrentWords.Has(A_Index) {
                OsdLabelHide(LabelsWordPrefixes[A_Index])
                continue
            }
            rowData := CurrentWords[A_Index]
        }
        if isSnippet {
            isSelected := (A_Index = SelectedPhraseIndex)
            rowColor := isSelected ? ColorHighlight : ColorTextWords
            rowText := rowData.HasOwnProp("PreviewText") ? rowData.PreviewText : rowData.Display
            rowH := rowData.HasOwnProp("RowHeight") ? rowData.RowHeight : 20

            OsdLabelUpdate(LabelsWordPrefixes[A_Index], GetPhraseRowPrefix(A_Index, isSelected), rowColor)
            OsdLabelPlace(LabelsWordPrefixes[A_Index], 10, CurrentY, phrasePrefixW, rowH)
            OsdLabelUpdate(LabelsWords[A_Index], rowText, rowColor)
            OsdLabelPlace(LabelsWords[A_Index], 10 + phrasePrefixW + 4, CurrentY, phraseBodyW, rowH)
            CurrentY += rowH + 4
        } else {
            prefix := (CurrentSuggestionMode = "DATA" && A_Index = 10) ? "0." : A_Index "."
            OsdLabelHide(LabelsWordPrefixes[A_Index])
            OsdLabelUpdate(LabelsWords[A_Index], prefix rowData.Display, ColorTextWords)
            OsdLabelPlace(LabelsWords[A_Index], 10, CurrentY, ContentW, 20)
            CurrentY += normalRowH
        }
    }

    if (isSnippet && SelectedPhraseIndex >= 1 && SelectedPhraseIndex <= CurrentWords.Length) {
        UpdateSnippetPreviewControl(CurrentWords[SelectedPhraseIndex])
        OsdLabelPlace(PhrasePreviewEdit, 10, CurrentY + 6, ContentW, GetCurrentSnippetPreviewHeight())
    } else {
        OsdLabelHide(PhrasePreviewEdit)
    }
}

HideSuggestions() {
    global SuggestionVisible, SuggGui, PhrasePreviewEdit, LastPhraseOsdInput, LabelsWordPrefixes
    SetTimer(WordOsdAutoHideTimer, 0)
    try OsdLabelHide(PhrasePreviewEdit) ; v13.19: уже скрытое не трогаем
    for ctrl in LabelsWordPrefixes
        try OsdLabelHide(ctrl)
    LastPhraseOsdInput := ""
    if IsDetachedSnippetEditorActive()
        CloseDetachedSnippetEditor(false)
    if SuggestionVisible {
        SuggGui.Hide()
        SuggestionVisible := false
    }
}

; Подтверждение подсказки: слово или основа.
; Основа всегда вставляется без пробела, потому что после неё пользователь
; вручную дописывает окончание. Обычное слово может вставляться с пробелом
; или без пробела (если оно было специально запомнено как no-space).
ConfirmAction(Type, Index) {
    global CurrentInput, CurrentStems, CurrentWords, SelectedStemIndex, CurrentSuggestionMode, LinkDB, SelectedPhraseIndex

    if IsSnippetSuggestionMode(CurrentSuggestionMode) {
        ; v13.20: Shift tap (Type "STEM") вставляет вариант, выбранный «-»/«=»
        ; (подсвеченный в OSD), а не всегда первый. Цифры — по-прежнему свой номер.
        snippetIndex := Index
        if (Type = "STEM")
            snippetIndex := (SelectedPhraseIndex >= 1 && SelectedPhraseIndex <= CurrentWords.Length) ? SelectedPhraseIndex : 1
        if (snippetIndex < 1 || snippetIndex > CurrentWords.Length)
            return

        snippetText := CurrentWords[snippetIndex].HasOwnProp("Full") ? CurrentWords[snippetIndex].Full : CurrentWords[snippetIndex].Display
        Backspaces := GetTypedBackspaceCount()
        mode := CurrentSuggestionMode
        HideSuggestions()
        SafeSendPhrase(snippetText . " ", Backspaces)
        RememberInsertedText(snippetText, true, (mode = "PROMPTS") ? "PROMPT" : ((mode = "LINKS") ? "LINK" : "PHRASE"))
        StartPhraseUndo(snippetText, true, (mode = "PROMPTS") ? "PROMPT" : ((mode = "LINKS") ? "LINK" : "PHRASE"))
        if (mode = "PROMPTS")
            LearnPrompt(snippetText, 1)
        else if (mode = "LINKS") {
            linkId := CurrentWords[snippetIndex].HasOwnProp("Id") ? CurrentWords[snippetIndex].Id : ""
            if (linkId != "" && LinkDB.Has(linkId)) {
                LinkDB[linkId].Count += 1
                QueueLinkSave(320)
            } else {
                LearnLink(snippetText, "", "", "", 1)
                QueueLinkSave(320)
            }
        } else
            LearnPhrase(snippetText, 1)
        FinalizeTypingState(false, true)
        return
    }

    TargetWord := ""
    AddSpace := true
    IsStemInsert := false

    if (Type == "STEM") {
        if (CurrentStems.Length == 0 && CurrentWords.Length > 0) {
            TargetWord := CurrentWords[1].Display
            AddSpace := !HasNoSpaceWord(TargetWord)
            IsStemInsert := false
        } else {
            stemIndex := (Index >= 1) ? Index : SelectedStemIndex
            if (stemIndex < 1 || stemIndex > CurrentStems.Length)
                return
            SelectedStemIndex := stemIndex
            TargetWord := CurrentStems[stemIndex].Display
            AddSpace := false
            IsStemInsert := true
        }
    } else if (Type == "WORD") {
        if (Index > CurrentWords.Length)
            return
        TargetWord := CurrentWords[Index].Display
        AddSpace := !HasNoSpaceWord(TargetWord)
        IsStemInsert := false
    }

    if (TargetWord == "")
        return

    Backspaces := GetTypedBackspaceCount()
    HideSuggestions()
    SafeSend(TargetWord . (AddSpace ? " " : ""), Backspaces)
    RememberInsertedText(TargetWord, AddSpace, IsStemInsert ? "STEM" : "WORD")
    StartWordInsertUndo(TargetWord, AddSpace, IsStemInsert ? "STEM" : "WORD")

    if (IsStemInsert) {
        FinalizeTypingState(false, false)
    } else {
        LearnWord(TargetWord, 1)
        FinalizeTypingState(false, AddSpace)
    }
}
; #EndRegion

; #Region ⏪ ОТМЕНА ПОСЛЕДНЕГО ДЕЙСТВИЯ (Alt + Z)
; v13.16: сколько нажатий Backspace нужно, чтобы стереть text в обычном поле.
; StrLen считает UTF-16: эмодзи = 2, CRLF = 2, а редактор стирает их одним
; нажатием — из-за этого Alt+Z съедал лишний символ перед вставкой. Считаем
; «видимые символы»: суррогатная пара, CRLF, вариационные селекторы, модификаторы
; тона кожи, ZWJ-цепочки и пары флагов-индикаторов идут за один символ.
GetBackspaceCountForText(text) {
    count := 0
    len := StrLen(text)
    i := 1
    joinNext := false
    riOpen := false
    while (i <= len) {
        code := Ord(SubStr(text, i, 2))
        step := (code > 0xFFFF) ? 2 : 1
        if (code = 0x0D && SubStr(text, i + 1, 1) = "`n")
            step := 2
        isModifier := (code = 0xFE0E || code = 0xFE0F || code = 0x20E3 || (code >= 0x1F3FB && code <= 0x1F3FF) || (code >= 0xE0020 && code <= 0xE007F))
        isRegional := (code >= 0x1F1E6 && code <= 0x1F1FF)
        if (code = 0x200D) {
            joinNext := true
        } else if joinNext {
            joinNext := false
        } else if isModifier {
            ; входит в предыдущий символ
        } else if (isRegional && riOpen) {
            riOpen := false
        } else {
            count += 1
            riOpen := isRegional
        }
        i += step
    }
    return count
}

SendBackspaceBurst(count) {
    ; v13.20: Backspace для отката длинной вставки — пачками по 200 с паузой
    ; 15 мс. Один SendInput на тысячи нажатий упирается в системный лимит
    ; (в документации AHK — около 5000 символов на вызов, остальное молча
    ; теряется), а тяжёлые веб-редакторы не успевают переварить такую очередь.
    ; Короткая вставка — как раньше, одним вызовом.
    burstSize := 200
    while (count > 0) {
        burstNow := Min(count, burstSize)
        SendInput("{Backspace " burstNow "}")
        count -= burstNow
        if (count > 0)
            Sleep(15)
    }
}

#HotIf IsTyperInputContext()
!z::UndoLastAction()
#HotIf

UndoLastAction() {
    global WordDB, PhraseDB, PromptDB, LinkDB, LastActionType, CurrentInput, MinTriggerLen
    global LastAddedWord, LastAddedScore
    global LastHotstringAbbr, LastHotstringRepl, LastHotstringSpace, LastHotstringCanUndo, LastHotstringTail
    global LastPhraseText, LastPhraseSpace, LastPhraseCanUndo, LastPhraseTail, LastPhraseKind
    global LastWordText, LastWordSpace, LastWordCanUndo, LastWordTail, LastWordKind
    global LastWordUndoRestoreText, LastWordUndoRestoreInput
    global LastHiddenWord

    if (LastActionType == "LEARN_FORCED" && LastAddedWord != "" && WordDB.Has(LastAddedWord)) {
        WordDB[LastAddedWord].Count -= LastAddedScore
        if (WordDB[LastAddedWord].Count <= 0)
            WordDB.Delete(LastAddedWord)

        ToolTip("↩️ Отменено добавление")
        SetTimer(() => ToolTip(), -1500)

        LastAddedWord := "", LastAddedScore := 0, LastActionType := ""

        if (CurrentInput != "")
            ShowSuggestions()

    } else if (LastActionType == "PIN_STEM" && LastAddedWord != "" && WordDB.Has(LastAddedWord)) {
        WordDB[LastAddedWord].IsStem := 0
        WordDB[LastAddedWord].Count -= LastAddedScore
        if (WordDB[LastAddedWord].Count <= 0)
            WordDB.Delete(LastAddedWord)

        ToolTip("↩️ Отменено закрепление")
        SetTimer(() => ToolTip(), -1500)

        LastAddedWord := "", LastAddedScore := 0, LastActionType := ""

        if (CurrentInput != "")
            ShowSuggestions()

    } else if (LastActionType == "HOTSTRING" && LastHotstringAbbr != "") {
        if !LastHotstringCanUndo {
            ToolTip("⚠️ Точный откат уже невозможен")
            SetTimer(() => ToolTip(), -1500)
            return
        }

        insertedLen := GetBackspaceCountForText(LastHotstringRepl) + (LastHotstringSpace ? 1 : 0)
        tailLen := GetBackspaceCountForText(LastHotstringTail)

        SendLevel 1
        if (tailLen > 0) {
            SendInput("{Backspace " tailLen "}")
            Sleep(20)
        }
        SendInput("{Backspace " insertedLen "}")
        if (tailLen > 0)
            SendText(LastHotstringTail)

        CurrentInput := LastHotstringTail
        if (StrLen(CurrentInput) >= MinTriggerLen)
            ShowSuggestions()
        else
            HideSuggestions()

        ToolTip("↩️ Автозамена отменена")
        SetTimer(() => ToolTip(), -1500)

        LastHotstringAbbr := "", LastHotstringRepl := "", LastHotstringSpace := false, LastHotstringCanUndo := false, LastHotstringTail := "", LastActionType := ""

    } else if (LastActionType == "PHRASE_INSERT" && LastPhraseText != "") {
        if !LastPhraseCanUndo {
            ToolTip("⚠️ Точный откат уже невозможен")
            SetTimer(() => ToolTip(), -1500)
            return
        }

        insertedLen := GetBackspaceCountForText(LastPhraseText) + (LastPhraseSpace ? 1 : 0)
        tailLen := GetBackspaceCountForText(LastPhraseTail)

        SendLevel 1
        if (tailLen > 0) {
            SendBackspaceBurst(tailLen)
            Sleep(20)
        }
        SendBackspaceBurst(insertedLen) ; v13.20: длинный промпт — пачками (см. функцию)
        if (tailLen > 0)
            SendText(LastPhraseTail)

        CurrentInput := LastPhraseTail
        if (StrLen(CurrentInput) >= MinTriggerLen)
            ShowSuggestions()
        else
            HideSuggestions()

        ToolTip("↩️ Отменена вставка " GetUndoInsertKindLabel(LastPhraseKind))
        SetTimer(() => ToolTip(), -1500)

        LastPhraseText := "", LastPhraseSpace := false, LastPhraseCanUndo := false, LastPhraseTail := "", LastPhraseKind := "", LastActionType := ""

    } else if (LastActionType == "WORD_INSERT" && LastWordText != "") {
        if !LastWordCanUndo {
            ToolTip("⚠️ Точный откат уже невозможен")
            SetTimer(() => ToolTip(), -1500)
            return
        }

        insertedLen := GetBackspaceCountForText(LastWordText) + (LastWordSpace ? 1 : 0)
        tailLen := GetBackspaceCountForText(LastWordTail)
        ; v13.17: после Ctrl+\ возвращаем исходный текст, а не просто стираем
        ; слово в кавычках. Набранный после него хвост отделяем пробелом.
        restoreText := LastWordUndoRestoreText
        if (restoreText != "" && tailLen > 0 && !RegExMatch(restoreText, "\s$"))
            restoreText .= " "

        SendLevel 1
        if (tailLen > 0) {
            SendInput("{Backspace " tailLen "}")
            Sleep(20)
        }
        SendInput("{Backspace " insertedLen "}")
        if (restoreText != "")
            SendText(restoreText)
        if (tailLen > 0)
            SendText(LastWordTail)

        CurrentInput := (tailLen = 0 && LastWordUndoRestoreInput != "") ? LastWordUndoRestoreInput : LastWordTail
        if (StrLen(CurrentInput) >= MinTriggerLen)
            ShowSuggestions()
        else
            HideSuggestions()

        ToolTip("↩️ Отменена вставка " GetUndoWordKindLabel(LastWordKind))
        SetTimer(() => ToolTip(), -1500)

        LastWordText := "", LastWordSpace := false, LastWordCanUndo := false, LastWordTail := "", LastWordKind := "", LastActionType := ""
        LastWordUndoRestoreText := "", LastWordUndoRestoreInput := ""

    } else if (LastActionType == "HIDE_WORD" && LastHiddenWord != "" && WordDB.Has(LastHiddenWord)) {
        WordDB[LastHiddenWord].Hidden := 0

        ToolTip("↩️ Возвращено в выдачу")
        SetTimer(() => ToolTip(), -1500)

        LastHiddenWord := "", LastActionType := ""

        if (CurrentInput != "")
            ShowSuggestions()

    } else if (LastActionType == "HIDE_PHRASE" && LastHiddenWord != "" && PhraseDB.Has(LastHiddenWord)) {
        PhraseDB[LastHiddenWord].Hidden := 0

        ToolTip("↩️ Фраза возвращена в выдачу")
        SetTimer(() => ToolTip(), -1500)

        LastHiddenWord := "", LastActionType := ""

        if (CurrentInput != "")
            ShowSuggestions()

    } else if (LastActionType == "HIDE_PROMPT" && LastHiddenWord != "" && PromptDB.Has(LastHiddenWord)) {
        ; v13.16: раньше скрытие промпта через Alt+1…5 не отменялось.
        PromptDB[LastHiddenWord].Hidden := 0

        ToolTip("↩️ Промпт возвращён в выдачу")
        SetTimer(() => ToolTip(), -1500)

        LastHiddenWord := "", LastActionType := ""

        if (CurrentInput != "")
            ShowSuggestions()

    } else if (LastActionType == "HIDE_LINK" && LastHiddenWord != "" && LinkDB.Has(LastHiddenWord)) {
        LinkDB[LastHiddenWord].Hidden := 0

        ToolTip("↩️ Ссылка возвращена в выдачу")
        SetTimer(() => ToolTip(), -1500)

        LastHiddenWord := "", LastActionType := ""

        if (CurrentInput != "")
            ShowSuggestions()

    } else {
        ToolTip("⚠️ Нет действий для отмены")
        SetTimer(() => ToolTip(), -1200)
    }
}
; #EndRegion

; #Region 🔥 АВТОЗАМЕНЫ
; Обработчик горячей клавиши кавычек. Используем два биндинга для одной и той же
; OEM-клавиши, потому что на разных раскладках / клавиатурах она может приходить
; по-разному. Двойной вызов гасим через LastQuoteHotkeyTick.
HandleQuoteHotkey() {
    global LastQuoteHotkeyTick
    if (A_TickCount - LastQuoteHotkeyTick < 80)
        return
    LastQuoteHotkeyTick := A_TickCount
    hk := A_ThisHotkey
    WrapSelectionOrCurrentWordInQuotes()
    ; v13.17: ждём отпускания клавиши. Пока этот поток ждёт, автоповтор того же
    ; хоткея отбрасывается (#MaxThreadsPerHotkey = 1), поэтому зажатый Ctrl+\
    ; больше не оборачивает текст снова и снова («««…»»»).
    keyName := RegExReplace(hk, "^[\^!+#<>*~$]+")
    if (keyName != "")
        try KeyWait(keyName, "T3")
    LastQuoteHotkeyTick := A_TickCount
}

 #HotIf IsTyperInputContext()
^vkDC::HandleQuoteHotkey()
^sc02B::HandleQuoteHotkey()
!vkDC::SendLiteralBackslash()
!sc02B::SendLiteralBackslash()

^SC029:: {
    selectedText := GetSelectedTextViaClipboard(0.7)
    if (Trim(selectedText) = "") {
        ToolTip("⚠️ Текст не выделен!")
        SetTimer(() => ToolTip(), -1500)
        return
    }
    ShowHotstringGUI(selectedText)
}
#HotIf

LoadHotstringsInternal() {
    global MyHotstrings, HotstringsFile
    MyHotstrings := Map()
    LoadEncryptedContainer(HotstringsFile, "hotstrings", ParseHotstringLine)
}

ParseHotstringLine(line) {
    global MyHotstrings
    parts := StrSplit(line, "|",, 3)
    if (parts.Length == 3)
        MyHotstrings[parts[2]] := {Repl: StrReplace(parts[3], "``n", "`n"), Immediate: InStr(parts[1], "*"), AddSpace: InStr(parts[1], "S")}
}

SaveHotstringsToFile() {
    global HotstringsFile
    return SaveEncryptedContainer(HotstringsFile, LoadHotstringsPlainText(), "hotstrings")
}

CheckAndFireHotstring(isImmediateCheck, terminator := "") {
    global CurrentInput, MyHotstrings

    if (CurrentInput == "")
        return false

    if MyHotstrings.Has(CurrentInput) {
        data := MyHotstrings[CurrentInput]
        if (isImmediateCheck) {
            if (data.Immediate) {
                FireHotstring(CurrentInput, data.Repl, true, data.AddSpace)
                return true
            }
        } else {
            if (!data.Immediate) {
                FireHotstring(CurrentInput, data.Repl, false, data.AddSpace, terminator)
                return true
            }
        }
    }
    return false
}

FireHotstring(abbr, replacement, isImmediate, addSpace, terminator := "") {
    global LastActionType, LastHotstringAbbr, LastHotstringRepl, LastHotstringSpace, LastHotstringCanUndo, LastHotstringTail

    ; v13.16: у не-мгновенной автозамены завершающий символ (пробел, запятая…)
    ; к этому моменту уже напечатан. Стираем его вместе с сокращением и печатаем
    ; обратно после замены. Раньше стиралось на символ меньше: «brb␣» → «bbe right back».
    suffix := addSpace ? " " : ""
    eraseCount := StrLen(abbr)
    if (!isImmediate && terminator != "") {
        eraseCount += 1
        suffix := terminator
        if (addSpace && !RegExMatch(terminator, "^\s$"))
            suffix .= " "
    }

    LastActionType := "HOTSTRING"
    LastHotstringAbbr := abbr
    ; Для Alt+Z: вставка = замена + хвостовые символы, всё стирается одним счётом.
    LastHotstringRepl := replacement . suffix
    LastHotstringSpace := false
    LastHotstringCanUndo := true
    LastHotstringTail := ""

    SafeSend(replacement . suffix, eraseCount)
    if (suffix == "" || suffix == " ")
        RememberInsertedText(replacement, suffix == " ")
    else
        InvalidateInsertedQuote()
    FinalizeTypingState(false, SubStr(suffix, -1) == " ")
}
; #EndRegion

ToggleInsertCaptureEnabled(*) {
    global InsertCaptureEnabled
    InsertCaptureEnabled := !InsertCaptureEnabled
    SaveSettingsInternal()
    ToolTip(InsertCaptureEnabled ? "Insert захватывается Typer" : "Insert временно родной")
    SetTimer(() => ToolTip(), -1200)
    try UpdateDictionaryViewUi()
}


ToggleWordOsdAutoHideFromGui(ctrl, *) {
    global WordOsdAutoHideEnabled
    WordOsdAutoHideEnabled := !!ctrl.Value
    SaveSettingsInternal()
    if WordOsdAutoHideEnabled
        ScheduleWordOsdAutoHide()
    else
        SetTimer(WordOsdAutoHideTimer, 0)
}

UpdateWordOsdAutoHideSecondsFromGui(ctrl, *) {
    global WordOsdAutoHideMs, WordOsdAutoHideEnabled
    raw := Trim(ctrl.Value)
    raw := StrReplace(raw, ",", ".")
    if !RegExMatch(raw, "^[0-9]+(\.[0-9]+)?$")
        return
    seconds := Number(raw)
    if (seconds < 1)
        seconds := 1
    else if (seconds > 30)
        seconds := 30
    WordOsdAutoHideMs := Round(seconds * 1000)
    SetTimer(SaveSettingsInternal, -800) ; v13.19: не на каждую цифру в поле
    if WordOsdAutoHideEnabled
        ScheduleWordOsdAutoHide()
}

; #Region 👤 СЛУЧАЙНОЕ ИМЯ (Alt+N)
; База типичных английских имён и фамилий для быстрого заполнения форм.
; Alt+N в поле Name: печатает случайное имя, жмёт Tab и печатает случайную фамилию.
Global RandomFirstNames := [
    "Jack", "James", "John", "Michael", "David", "Daniel", "Matthew", "Andrew", "Ryan", "Kevin",
    "Brian", "Mark", "Paul", "Steven", "Eric", "Adam", "Nathan", "Scott", "Justin", "Brandon",
    "Tyler", "Aaron", "Jason", "Peter", "Thomas", "Charles", "Joseph", "Richard", "Robert", "William",
    "Henry", "George", "Edward", "Frank", "Patrick", "Dennis", "Gary", "Larry", "Keith", "Craig",
    "Derek", "Shane", "Travis", "Chad", "Marcus", "Vincent", "Oliver", "Ethan", "Lucas", "Owen",
    "Kate", "Emma", "Olivia", "Sophia", "Emily", "Anna", "Sarah", "Laura", "Megan", "Rachel",
    "Jessica", "Amanda", "Melissa", "Nicole", "Stephanie", "Rebecca", "Amber", "Brittany", "Danielle", "Heather",
    "Amy", "Angela", "Crystal", "Michelle", "Tiffany", "Christina", "Katherine", "Samantha", "Lauren", "Alyssa",
    "Hannah", "Kayla", "Alexis", "Victoria", "Natalie", "Julia", "Grace", "Claire", "Audrey", "Ellen",
    "Diana", "Karen", "Linda", "Susan", "Nancy", "Betty", "Helen", "Sandra", "Donna", "Carol"
]
Global RandomLastNames := [
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Wilson", "Anderson",
    "Taylor", "Thomas", "Moore", "Jackson", "Martin", "Lee", "Thompson", "White", "Harris", "Clark",
    "Lewis", "Robinson", "Walker", "Young", "Allen", "King", "Wright", "Scott", "Hill", "Green",
    "Adams", "Baker", "Nelson", "Carter", "Mitchell", "Roberts", "Turner", "Phillips", "Campbell", "Parker",
    "Evans", "Edwards", "Collins", "Stewart", "Morris", "Murphy", "Cook", "Rogers", "Morgan", "Peterson",
    "Cooper", "Reed", "Bailey", "Bell", "Kelly", "Howard", "Ward", "Cox", "Richardson", "Wood",
    "Watson", "Brooks", "Bennett", "Gray", "James", "Hughes", "Price", "Myers", "Long", "Foster",
    "Sanders", "Ross", "Powell", "Sullivan", "Russell", "Ortiz", "Jenkins", "Perry", "Butler", "Barnes",
    "Fisher", "Henderson", "Coleman", "Simmons", "Patterson", "Jordan", "Reynolds", "Hamilton", "Graham", "Wallace",
    "West", "Cole", "Hayes", "Gibson", "Bryant", "Ellis", "Stevens", "Murray", "Ford", "Winston"
]

PickRandomFullName() {
    global RandomFirstNames, RandomLastNames
    return [RandomFirstNames[Random(1, RandomFirstNames.Length)], RandomLastNames[Random(1, RandomLastNames.Length)]]
}

PrepareRandomNameInsert() {
    ; Общая подготовка перед вставкой имени: чистим внутренний хвост Тайпера
    ; и ждём, пока пользователь отпустит модификаторы хоткея (Alt/Ctrl), иначе
    ; зажатый Alt превратит вставку и Tab в Alt+буквы/Alt+Tab.
    ResetInput()
    InvalidateInsertedQuote()
    InvalidateHotstringUndo()
    KeyWait("Alt")
    KeyWait("Ctrl")
    Sleep(80) ; небольшая пауза, чтобы поле "устаканилось" после клика/хоткея
}

InsertRandomName(*) {
    ; Кликнул в поле Name -> Alt+N: имя + Tab + фамилия + Tab (на следующее поле).
    ; Шлём с SendLevel 1, чтобы InputHook Тайпера не съел этот текст.
    parts := PickRandomFullName()
    firstName := parts[1], lastName := parts[2]
    PrepareRandomNameInsert()
    SendLevel 1
    SendText(firstName)
    Sleep(60)
    SendInput("{Tab}")
    Sleep(90) ; даём странице обработать переход фокуса на поле фамилии
    SendText(lastName)
    Sleep(60)
    SendInput("{Tab}")
}

InsertRandomFullNameOneField(*) {
    ; Ctrl+Alt+N: форма с ОДНИМ полем "Full name" — вставляем "Имя Фамилия"
    ; целиком и переходим Tab'ом на следующее поле.
    parts := PickRandomFullName()
    fullName := parts[1] " " parts[2]
    PrepareRandomNameInsert()
    SendLevel 1
    SendText(fullName)
    Sleep(60)
    SendInput("{Tab}")
}

; #Region 💾 GUI МЕНЕДЖЕРА АВТОЗАМЕН (Win+F9)
#HotIf !TyperSuspended && TyperStartupComplete
!F14::AddSelectedTextAsPhraseGlobal()
+F14::AddSelectedTextAsPromptGlobal()
!n::InsertRandomName()
!m::InsertRandomFullNameOneField() ; Alt+M (был Ctrl+Alt+N — неудобно тянуться)
#HotIf

; v13.17: в поле поиска Delete/Insert — обычное редактирование текста.
#HotIf WinActive("Панель Typer") && !IsPanelTextFieldFocused()
Delete::DeleteFromDictionaryPanelHotkey()
Insert::RestoreHiddenWord(0)
#HotIf

#HotIf WinActive("Менеджер автозамен")
Enter::HandleHotstringManagerEnter()
#HotIf

#HotIf InsertCaptureEnabled && IsTyperInputContext()
Insert::TogglePhraseCapture()
!Insert::TogglePromptCapture()
#HotIf

#HotIf SuggestionVisible && (CurrentSuggestionMode = "WORDS") && IsTyperInputContext()
F9::SuspendWordOsdDigitSelection()
#HotIf

#HotIf TyperStartupComplete && IsTyperInputContext()
#Insert::ToggleInsertCaptureEnabled()
NumpadDiv::AddSelectedTextAsLinkGlobal()
!NumpadDiv::ShowLinkCaptureGui()
#HotIf

#HotIf !TyperSuspended && IsDataSecretClipboardActive()
~^v::MarkSecretClipboardPasteIntent("ctrl-v-hotkey")
~^vk56::MarkSecretClipboardPasteIntent("ctrl-v-vk-hotkey")
~^sc02F::MarkSecretClipboardPasteIntent("ctrl-v-sc-hotkey")
~+Insert::MarkSecretClipboardPasteIntent("shift-insert-hotkey")
~+NumpadIns::MarkSecretClipboardPasteIntent("shift-numpadins-hotkey")
~*F15::ScheduleSecretClipboardRestoreAfterF15()
#HotIf

#HotIf !TyperSuspended
F9::ShowDictionaryGUI()
#F9::ShowHotstringGUI()
#HotIf

; v13.21: Ctrl+1…4 — категория в окне Alt+Insert и в правке промпта.
#HotIf IsPromptCatRowWindowActive()
^1::PickPromptCatInActiveDialog(1)
^2::PickPromptCatInActiveDialog(2)
^3::PickPromptCatInActiveDialog(3)
^4::PickPromptCatInActiveDialog(4)
#HotIf

; v13.21: вкладка «Промпты»: Ctrl+0…4 — фильтр, Alt+1…4 — категория выбранного.
#HotIf WinActive("Панель Typer") && (DictActiveView = "PROMPTS") && !TyperSuspended
^0::SetPanelPromptCatFilter("ALL")
^1::SetPanelPromptCatFilter("IMAGE")
^2::SetPanelPromptCatFilter("VIDEO")
^3::SetPanelPromptCatFilter("LLM")
^4::SetPanelPromptCatFilter("OTHER")
!1::SetSelectedPromptCategoryFromPanel("IMAGE")
!2::SetSelectedPromptCategoryFromPanel("VIDEO")
!3::SetSelectedPromptCategoryFromPanel("LLM")
!4::SetSelectedPromptCategoryFromPanel("OTHER")
#HotIf

#HotIf PhraseCaptureMode && !IsPromptCatPickerActive() ; v13.21: Enter/Esc во всплывашке категории — её
Insert::SaveCapturedPhrase(false)
Enter::SaveCapturedPhrase(true)
Esc::CancelPhraseCapture()
#HotIf

#HotIf PromptCaptureMode && !IsPromptCatPickerActive() ; v13.21
!Insert::SaveCapturedPrompt(false)
Enter::SaveCapturedPrompt(true)
Esc::CancelPromptCapture()
#HotIf

ShowHotstringGUI(PreFillText := "") {
    global EditAbbr, EditRepl, CBImmediate, CBAddSpace, IsEditingHotstring, TyperStartupComplete
    if !TyperStartupComplete {
        ToolTip("⏳ Typer ещё расшифровывает базы — секунду…")
        SetTimer(() => ToolTip(), -1500)
        return
    }
    if WinExist("Менеджер автозамен") {
        WinActivate
        if (PreFillText != "")
            EditRepl.Value := PreFillText
        return
    }
    IsEditingHotstring := false
    GuiBg := "202020", ControlBg := "333333", TextCol := "F0F0F0"

    MyGui := CreateTyperDialog("+AlwaysOnTop -MinimizeBox", "Менеджер автозамен")
    MyGui.BackColor := GuiBg
    MyGui.SetFont("s10 c" TextCol, "Segoe UI")
    MyGui.OnEvent("Escape", (*) => MyGui.Destroy())

    MyGui.Add("Text", "x20 y20 h20", "Если напечатаю:")
    EditAbbr := MyGui.Add("Edit", "x20 y45 w300 h30 vAbbr Background" ControlBg " c" TextCol " -E0x200 +Border")

    MyGui.Add("Text", "x20 y85 h20", "Заменить на:")
    EditRepl := MyGui.Add("Edit", "x20 y110 w300 h120 vRepl Background" ControlBg " c" TextCol " -WantReturn -E0x200 +Border")

    if (PreFillText != "")
        EditRepl.Value := PreFillText

    CBImmediate := MyGui.Add("Checkbox", "x20 y245 vImmediate Checked1 c" TextCol, "Мгновенно (без пробела)")
    CBAddSpace := MyGui.Add("Checkbox", "x20 y270 vAddSpace Checked1 c" TextCol, "Добавить пробел в конце")

    MyGui.Add("Text", "x340 y20 h20", "Мои замены (Клик для ред.):")
    LV := MyGui.Add("ListView", "x340 y45 w430 h280 -Grid -E0x200 +Border Background" ControlBg " c" TextCol " -Multi", ["Сокр.", "Замена", "Опции"])
    try DllCall("uxtheme\SetWindowTheme", "Ptr", LV.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)

    LV.ModifyCol(1, 70), LV.ModifyCol(2, 260), LV.ModifyCol(3, 95)
    StretchLastListViewColumn(LV, 3) ; без пустого хвоста после "Опции"
    LV.OnEvent("Click", OnListViewClick)

    ; Плоские кнопки в общем стиле панели: у системных Button в тёмной теме
    ; остаётся светлая рамка (а у Default — двойная), выбивающаяся из дизайна.
    ; Enter обрабатывается контекстным хоткеем окна (см. HandleHotstringManagerEnter):
    ; поле "Заменить на" создано с -WantReturn, поэтому поведение прежнее —
    ; Enter сохраняет из любого места окна.
    global HotstringMgrGui := MyGui, HotstringMgrLV := LV
    CreateFlatTextButton(MyGui, "x20 y340 w145 h35", "СОХРАНИТЬ (Enter)", SaveHotstring.Bind(MyGui, LV))
    CreateFlatTextButton(MyGui, "x175 y340 w145 h35", "Отмена (Esc)", (*) => MyGui.Destroy())
    CreateFlatTextButton(MyGui, "x610 y340 w160 h35", "Удалить выбранное", DeleteHotstring.Bind(MyGui, LV))

    PopulateListView(LV)
    ; Прозрачность здесь убрана осознанно: это окно с полями ввода, и просвечивающий
    ; фон мешает читать текст. Лёгкая прозрачность оставлена только у пассивных OSD.
  ApplyDarkThemeToGui(MyGui)
  MyGui.Show("w790 h395")
  ; Прозрачность убрана: layered-окно конфликтует с WS_EX_COMPOSITED
  ; (см. подробный комментарий у создания панели F9).
  }

OnListViewClick(lvObj, RowNumber) {
    global MyHotstrings, EditAbbr, EditRepl, CBImmediate, CBAddSpace, IsEditingHotstring
    if (!RowNumber)
        return
    IsEditingHotstring := true
    Abbr := lvObj.GetText(RowNumber, 1)
    if MyHotstrings.Has(Abbr) {
        data := MyHotstrings[Abbr]
        EditAbbr.Value := Abbr
        EditRepl.Value := StrReplace(data.Repl, "``n", "`n")
        CBImmediate.Value := !!data.Immediate
        CBAddSpace.Value := !!data.AddSpace
    }
}

PopulateListView(lvObj) {
    global MyHotstrings
    lvObj.Delete()
    lvObj.Opt("-Redraw")
    for abbr, data in MyHotstrings {
        optsStr := ""
        if (data.Immediate)
            optsStr .= "Мгн"
        if (data.AddSpace)
            optsStr .= (optsStr = "" ? "" : " + ") . "Проб."
        lvObj.Add(, abbr, StrReplace(data.Repl, "`n", " "), optsStr)
    }
    lvObj.Opt("+Redraw")
}

HandleHotstringManagerEnter() {
    ; Замена опции Default у бывшей системной кнопки: Enter в менеджере
    ; автозамен сохраняет запись (плоские Text-кнопки Default не поддерживают).
    global HotstringMgrGui, HotstringMgrLV
    try {
        if (IsObject(HotstringMgrGui) && WinExist("ahk_id " HotstringMgrGui.Hwnd))
            SaveHotstring(HotstringMgrGui, HotstringMgrLV)
    }
}

SaveHotstring(guiObj, lvObj, *) {
    global MyHotstrings, EditAbbr, EditRepl, IsEditingHotstring
    Saved := guiObj.Submit(false)
    if (Saved.Abbr == "" || Saved.Repl == "")
        return
    MyHotstrings[Saved.Abbr] := {Repl: StrReplace(Saved.Repl, "`n", "``n"), Immediate: Saved.Immediate, AddSpace: Saved.AddSpace}
    SaveHotstringsToFile()
    PopulateListView(lvObj)
    EditAbbr.Value := "", EditRepl.Value := ""
    if (!IsEditingHotstring) {
        guiObj.Destroy()
    } else {
        IsEditingHotstring := false
    }
}

DeleteHotstring(guiObj, lvObj, *) {
    global MyHotstrings, EditAbbr, EditRepl
    RowNumber := lvObj.GetNext(0)
    if !RowNumber
        return
    AbbrToDelete := lvObj.GetText(RowNumber, 1)
    MyHotstrings.Delete(AbbrToDelete)
    SaveHotstringsToFile()
    PopulateListView(lvObj)
    EditAbbr.Value := "", EditRepl.Value := ""
}
; #EndRegion

; #Region 📖 ГЛАВНАЯ ПАНЕЛЬ СКРИПТА (Win + F9)
; ---- Статический fallback для Win+Numpad hot inserts ------------------------
; Dynamic Hotkey() alias-ы для #Numpad8/#NumpadUp на некоторых системах уступают
; shell-сочетаниям Win+Arrow. Этот блок повторяет рабочий принцип:
; NumpadUp:: / Numpad8:: одна и та же функция, но активен только если такой
; пользовательский hot insert реально существует.
#HotIf !TyperSuspended && TyperStartupComplete && IsTyperInputContext() && HasHotInsertCombo("#Numpad0")
$#NumpadIns::
$#Numpad0::TryHotInsertByCombo("#Numpad0")
#HotIf !TyperSuspended && TyperStartupComplete && IsTyperInputContext() && HasHotInsertCombo("#Numpad1")
$#NumpadEnd::
$#Numpad1::TryHotInsertByCombo("#Numpad1")
#HotIf !TyperSuspended && TyperStartupComplete && IsTyperInputContext() && HasHotInsertCombo("#Numpad2")
$#NumpadDown::
$#Numpad2::TryHotInsertByCombo("#Numpad2")
#HotIf !TyperSuspended && TyperStartupComplete && IsTyperInputContext() && HasHotInsertCombo("#Numpad3")
$#NumpadPgDn::
$#Numpad3::TryHotInsertByCombo("#Numpad3")
#HotIf !TyperSuspended && TyperStartupComplete && IsTyperInputContext() && HasHotInsertCombo("#Numpad4")
$#NumpadLeft::
$#Numpad4::TryHotInsertByCombo("#Numpad4")
#HotIf !TyperSuspended && TyperStartupComplete && IsTyperInputContext() && HasHotInsertCombo("#Numpad5")
$#NumpadClear::
$#Numpad5::TryHotInsertByCombo("#Numpad5")
#HotIf !TyperSuspended && TyperStartupComplete && IsTyperInputContext() && HasHotInsertCombo("#Numpad6")
$#NumpadRight::
$#Numpad6::TryHotInsertByCombo("#Numpad6")
#HotIf !TyperSuspended && TyperStartupComplete && IsTyperInputContext() && HasHotInsertCombo("#Numpad7")
$#NumpadHome::
$#Numpad7::TryHotInsertByCombo("#Numpad7")
#HotIf !TyperSuspended && TyperStartupComplete && IsTyperInputContext() && HasHotInsertCombo("#Numpad8")
$#NumpadUp::
$#Numpad8::TryHotInsertByCombo("#Numpad8")
#HotIf !TyperSuspended && TyperStartupComplete && IsTyperInputContext() && HasHotInsertCombo("#Numpad9")
$#NumpadPgUp::
$#Numpad9::TryHotInsertByCombo("#Numpad9")
#HotIf !TyperSuspended && TyperStartupComplete && IsTyperInputContext() && HasHotInsertCombo("#NumpadDot")
$#NumpadDel::
$#NumpadDot::TryHotInsertByCombo("#NumpadDot")
#HotIf

#SuspendExempt true
#t::ToggleTyperSuspended()
#SuspendExempt false

#HotIf !TyperSuspended
#q::ToggleActiveWindowTyperAllowance(false)
#a::ToggleActiveWindowTyperAllowance(true)
#HotIf

; Win+*: как и F14-семейству, карточка Данных требует завершённой автозагрузки баз,
; иначе сохранение из карточки могло бы перезаписать ещё не загруженную базу.
#HotIf !TyperSuspended && TyperStartupComplete
#+8::OpenDataCardFromHotkey()
#NumpadMult::OpenDataCardFromHotkey()
#HotIf

ShowDictionaryGUI() {
    global DictActiveView, DictSettingsPanel, GuiBg, ControlBg, TextCol, InsertCaptureEnabled, WordOsdAutoHideEnabled, WordOsdAutoHideMs, DictShowFrequencyColumn, DictSearchIncludeWords, DictPanelGui, DictPanelTargetHwnd, DictPanelTargetHasCaret
    global DictDataPileSelect, DictDataPileMode, EnableLCtrlComma, EnableRCtrlPeriod, PgKeysModeEnabled
    global LV_Words, LV_Stems, LV_Phrases, LV_Prompts, LV_Links, LV_Data, LV_Hidden, LV_Hotkeys, LV_GlobalSearch, DictHelpEdit, DictInfoTitle
    global DictTabHome, DictTabWords, DictTabStems, DictTabPhrases, DictTabPrompts, DictTabLinks, DictTabData, DictTabHotkeys, DictTabHidden, DictTabSettings
    global DictBtnRestore, DictBtnDelete, DictBtnPruneWords, DictBtnEditPhrase, DictBtnEditLink, DictBtnEditData, DictBtnAddData, DictBtnAddLink
    global DictBtnAssignPhraseHotkey, DictBtnAddHotkey, DictBtnEditHotkey, DictHintText, ColorHighlight, TyperStartupComplete
    global DictSearchLabel, DictSearchEdit, DictSearchClear, DictGlobalSearchLabel, DictGlobalSearchEdit, DictGlobalSearchClear, DictShowFrequencyCheck, DictIncludeWordsCheck, DictGlobalDeleteBtn, DictInsertCheck, DictWordAutoHideCheck, DictWordAutoHideSecEdit
    global MasterPassword, PanelOpenPromptsByDefault, PanelPromptClickCopy, DictViewDirty
    global DictMode, DictModeSelect, DictStartupTimingText ; v13.18
    global DictViewUiSig, DictTabStyleState, DictGlobalDeleteBtnState ; v13.20
    global DictPromptCatChips, DictPromptChipState, DictPromptToolButtons, DictBtnClose, PanelPromptCatFilter ; v13.21

    ; v13.17: пока открыто окно мастер-пароля, панель не создаём: окно пароля
    ; закрывает скрипт при потере фокуса, и F9 в этот момент выключал Typer.
    if (MasterPassword = "" && !TyperStartupComplete) {
        ToolTip("🔒 Сначала введи мастер-пароль")
        SetTimer(() => ToolTip(), -1500)
        return
    }

  ; Панель открывается сразу, даже пока расшифровка баз не завершена: внизу
  ; столбца разделов — индикатор с этапом, на месте списков — крупный индикатор;
  ; таймер PanelDecryptWatch по готовности строит видимую вкладку.

  activeBeforePanel := WinExist("A")
  if !(WinActive("Панель Typer") || WinActive("Менеджер автозамен")) {
  DictPanelTargetHwnd := activeBeforePanel
  DictPanelTargetHasCaret := PanelTargetHasCaretNow()
  }

    if WinExist("Панель Typer") {
        WinActivate
        return
    }

    ; v13.17: стартовая вкладка — из Настроек (по умолчанию «Промпты»).
    DictActiveView := PanelOpenPromptsByDefault ? "PROMPTS" : "HOME"
    DictViewDirty := Map()
    DictSettingsPanel := []
    ; v13.20: новое окно — первая раскладка всегда полная, кнопки в исходном стиле.
    DictViewUiSig := ""
    DictTabStyleState := Map()
    DictGlobalDeleteBtnState := 0
    DictPromptChipState := Map() ; v13.21

    GuiBg := "151515"
    ControlBg := "242424"
    TextCol := "F0F0F0"

    ; Анти-мерцание на уровне стилей окна:
    ;   +0x02000000 WS_CLIPCHILDREN   — родитель не закрашивает фон под контролами;
    ;   +0x04000000 WS_CLIPSIBLINGS   — контролы не рисуют друг по другу.
    ; WS_EX_COMPOSITED здесь ПОСТОЯННО НЕ ставится: composited-окно
    ; перерисовывается целиком при инвалидации любого ребёнка, а шапки
    ; колонок с hot-track инвалидируются при каждом движении мыши — получалось
    ; высокочастотное моргание заголовков. Вместо этого composited включается
    ; ВРЕМЕННО только на миг перестройки раздела (см. UpdateDictionaryViewUi),
    ; где он собирает стирание+отрисовку в один кадр.
    ; КРИТИЧЕСКОЕ УСЛОВИЕ ОСТАЁТСЯ: никаких WinSetTransparent для этого окна —
    ; layered несовместим с composited (даже временным) и вернёт мерцание.
    DictGui := Gui("-MinimizeBox +0x02000000 +0x04000000", "Панель Typer")
    DictPanelGui := DictGui
    ApplyDarkWindowFrame(DictGui)
    DictGui.BackColor := GuiBg
    DictGui.SetFont("s10 c" TextCol, "Segoe UI")
    DictGui.MarginX := 0
    DictGui.MarginY := 0
    DictGui.OnEvent("Escape", CloseDictionaryPanel)
    DictGui.OnEvent("Close", CloseDictionaryPanel)
    DictGui.OnEvent("Size", OnDictionaryPanelSize)

    DictGui.Add("Text", "x18 y14 w120 h22 cFFFFFF", "Typer")
    DictGui.Add("Text", "x150 y14 w720 h22 c8E8E8E", "Личная панель баз, хоткеев и справки. Глобально открывается F9.")
    DictGui.Add("Text", "x136 y0 w1 h548 Background303030", "")
    DictGui.Add("Text", "x150 y44 w720 h1 Background404040", "")

    DictTabHome     := CreateFlatTextButton(DictGui, "x18 y48 w100 h28", "Справка", (*) => SwitchDictionaryView("HOME"))
    DictTabWords    := CreateFlatTextButton(DictGui, "x18 y82 w100 h28", "Слова", (*) => SwitchDictionaryView("WORDS"))
    DictTabStems    := CreateFlatTextButton(DictGui, "x18 y116 w100 h28", "Основы", (*) => SwitchDictionaryView("STEMS"))
    DictTabPhrases  := CreateFlatTextButton(DictGui, "x18 y150 w100 h28", "Фразы", (*) => SwitchDictionaryView("PHRASES"))
    DictTabPrompts  := CreateFlatTextButton(DictGui, "x18 y184 w100 h28", "Промпты", (*) => SwitchDictionaryView("PROMPTS"))
    DictTabLinks    := CreateFlatTextButton(DictGui, "x18 y218 w100 h28", "Ссылки", (*) => SwitchDictionaryView("LINKS"))
    DictTabData     := CreateFlatTextButton(DictGui, "x18 y252 w100 h28", "Данные", (*) => SwitchDictionaryView("DATA"))
    DictTabHotkeys  := CreateFlatTextButton(DictGui, "x18 y286 w100 h28", "Горячие", (*) => SwitchDictionaryView("HOTKEYS"))
    DictTabHidden   := CreateFlatTextButton(DictGui, "x18 y320 w100 h28", "Исключённые", (*) => SwitchDictionaryView("HIDDEN"))
    DictTabSettings := CreateFlatTextButton(DictGui, "x18 y354 w100 h28", "Настройки", (*) => SwitchDictionaryView("SETTINGS"))

    ; v13.17: индикатор фоновой расшифровки. Компактный — внизу столбца разделов:
    ; «крутилка», этап N/M и полоса. Крупный — на месте списков (пока базы
    ; пустые, списки не показываем). По готовности PanelDecryptWatch строит
    ; видимую вкладку и на пару секунд пишет «Базы готовы».
    global DictDecryptSpin, DictDecryptNote, DictDecryptBarFill, DictDecryptBarRest
    global DictLoadSpin, DictLoadTitle, DictLoadStage, DictLoadBarFill, DictLoadBarRest, DictLoadHint
    DictDecryptSpin := DictGui.Add("Text", "x18 y436 w112 h18 c" ColorHighlight " Hidden", "●  ○  ○")
    DictDecryptNote := DictGui.Add("Text", "x18 y456 w116 h36 c8E8E8E Hidden", "Идёт расшифровка баз…")
    DictDecryptBarFill := DictGui.Add("Text", "x18 y496 w0 h3 Background" ColorHighlight " Hidden", "")
    DictDecryptBarRest := DictGui.Add("Text", "x18 y496 w100 h3 Background303030 Hidden", "")
    DictLoadSpin := DictGui.Add("Text", "x150 y180 w720 h28 Center c" ColorHighlight " Hidden", "●  ○  ○")
    try DictLoadSpin.SetFont("s14")
    DictLoadTitle := DictGui.Add("Text", "x150 y212 w720 h30 Center cF0F0F0 Hidden", "Идёт расшифровка баз")
    try DictLoadTitle.SetFont("s13")
    DictLoadStage := DictGui.Add("Text", "x150 y246 w720 h22 Center c8E8E8E Hidden", "")
    DictLoadBarFill := DictGui.Add("Text", "x330 y278 w0 h3 Background" ColorHighlight " Hidden", "")
    DictLoadBarRest := DictGui.Add("Text", "x330 y278 w360 h3 Background303030 Hidden", "")
    DictLoadHint := DictGui.Add("Text", "x150 y294 w720 h40 Center c6E6E6E Hidden", "Списки появятся сами, как только базы будут готовы.`nСправка и настройки уже работают.")
    if !TyperStartupComplete {
        for ctrl in [DictDecryptSpin, DictDecryptNote, DictDecryptBarFill, DictDecryptBarRest]
            ctrl.Visible := true
        UpdatePanelDecryptIndicator()
        SetTimer(PanelDecryptWatch, 150)
    }

    DictSearchLabel := DictGui.Add("Text", "x150 y58 w52 h20 cAFAFAF Hidden", "Поиск:")
    DictSearchEdit := DictGui.Add("Edit", "x206 y54 w560 h26 Background" ControlBg " c" TextCol " Hidden")
    DictSearchEdit.OnEvent("Change", ScheduleDictionarySearchRefresh)
    DictSearchClear := CreateFlatTextButton(DictGui, "x774 y54 w96 h26 Hidden", "Сброс", (*) => ClearDictionarySearch())

    DictGlobalSearchLabel := DictGui.Add("Text", "x150 y58 w52 h20 cAFAFAF Hidden", "Поиск:")
    DictGlobalSearchEdit := DictGui.Add("Edit", "x206 y54 w560 h26 Background" ControlBg " c" TextCol " Hidden")
    DictGlobalSearchEdit.OnEvent("Change", HandleGlobalSearchChanged)
    DictGlobalSearchClear := CreateFlatTextButton(DictGui, "x774 y54 w96 h26 Hidden", "Сброс", (*) => ClearGlobalSearch())
    DictGlobalDeleteBtn := CreateFlatTextButton(DictGui, "x650 y470 w110 h28 Hidden Disabled c808080", "Удалить", (*) => DeleteSelectedGlobalSearchResult())
    DictIncludeWordsCheck := DictGui.Add("CheckBox", "x150 y474 w78 h22 cF0F0F0 Hidden Checked" (DictSearchIncludeWords ? 1 : 0), "Слова")
    DictIncludeWordsCheck.OnEvent("Click", ToggleGlobalSearchWordsColumn)
    DictShowFrequencyCheck := DictGui.Add("CheckBox", "x236 y474 w122 h22 cF0F0F0 Hidden Checked" (DictShowFrequencyColumn ? 1 : 0), "Частотность")
    DictShowFrequencyCheck.OnEvent("Click", ToggleGlobalSearchFrequencyColumn)

    ; Обычный Edit в AHK удобен для поиска/выделения/скролла справки, но не для rich-разметки.
    ; Поэтому оставляем справку простым моноширинным текстом без декоративных цветных чипов.
    DictHelpEdit := DictGui.Add("Edit", "x150 y88 w720 h360 ReadOnly -Tabstop +Multi +VScroll Background" ControlBg " c" TextCol)
    try DictHelpEdit.SetFont("s9 c" TextCol, "Consolas")
    DictHelpEdit.Value := BuildMainHelpText()

    LV_GlobalSearch := DictGui.Add("ListView", "x150 y88 w720 h360 -Grid -E0x200 +Border Background" ControlBg " c" TextCol " -Multi Hidden", ["Тип", "Запись", "Частота", "ref"])
    LV_GlobalSearch.OnEvent("DoubleClick", (*) => OpenSelectedGlobalSearchResult(DictGui))
    LV_GlobalSearch.OnEvent("Click", HandleGlobalSearchClick) ; v13.17: ЛКМ по промпту — в буфер
    LV_GlobalSearch.OnEvent("ContextMenu", PanelContextEdit.Bind("GLOBAL"))
    LV_GlobalSearch.OnEvent("ColClick", HandlePanelListViewColClick)
    RegisterPanelHandCursorList("GLOBAL", LV_GlobalSearch) ; v13.19: «палец» над промптами
    try LV_GlobalSearch.OnEvent("ItemSelect", (*) => UpdateGlobalDeleteButtonState())

    LV_Words := DictGui.Add("ListView", "x150 y88 w720 h360 -Grid -E0x200 +Border Background" ControlBg " c" TextCol " -Multi Hidden", ["Слово", "Рейтинг"])
    LV_Words.OnEvent("ColClick", HandlePanelListViewColClick)
    LV_Stems := DictGui.Add("ListView", "x150 y88 w720 h360 -Grid -E0x200 +Border Background" ControlBg " c" TextCol " -Multi Hidden", ["Основа", "Исп."])
    LV_Stems.OnEvent("ColClick", HandlePanelListViewColClick)
    LV_Phrases := DictGui.Add("ListView", "x150 y88 w720 h360 -Grid -E0x200 +Border Background" ControlBg " c" TextCol " -Multi Hidden", ["Фраза", "Исп."])
    LV_Phrases.OnEvent("DoubleClick", (*) => EditSelectedPhraseFromPanel(DictGui))
    LV_Phrases.OnEvent("ContextMenu", PanelContextEdit.Bind("PHRASES"))
    LV_Phrases.OnEvent("ColClick", HandlePanelListViewColClick)
    ; v13.21: «Промпты» — над списком строка фильтр-чипов категорий и компактных
    ; кнопок (y88), сам список ниже и выше прежнего (до подсказки): крупного ряда
    ; кнопок внизу на этой вкладке больше нет. Вместо «Исп.» — «Кат.» (видна
    ; только в фильтре «Все»); 3-я колонка — по-прежнему скрытый ref.
    DictPromptCatChips := Map()
    chipX := 150
    for _, chipCat in ["ALL", "IMAGE", "VIDEO", "LLM", "OTHER"] {
        chipW := (chipCat = "ALL") ? 70 : ((chipCat = "LLM") ? 74 : 84)
        DictPromptCatChips[chipCat] := CreateFlatTextButton(DictGui, "x" chipX " y88 w" chipW " h26 Hidden", (chipCat = "ALL") ? "Все" : GetPromptCatName(chipCat), SetPanelPromptCatFilter.Bind(chipCat))
        chipX += chipW + 4
    }
    DictPromptToolButtons := []
    DictPromptToolButtons.Push(CreateFlatTextButton(DictGui, "x586 y88 w64 h26 Hidden", "+ Новый", (*) => ShowPromptEditGui("")))
    DictPromptToolButtons.Push(CreateFlatTextButton(DictGui, "x654 y88 w72 h26 Hidden", "Править", (*) => EditSelectedPromptFromPanel(DictGui)))
    DictPromptToolButtons.Push(CreateFlatTextButton(DictGui, "x730 y88 w66 h26 Hidden", "Хоткей", CreateHotInsertFromSelectedPrompt))
    DictPromptToolButtons.Push(CreateFlatTextButton(DictGui, "x800 y88 w70 h26 Hidden", "Удалить", (*) => DeleteWordFromDict(DictGui)))
    LV_Prompts := DictGui.Add("ListView", "x150 y120 w720 h382 -Grid -E0x200 +Border Background" ControlBg " c" TextCol " -Multi Hidden", ["Промпт", "Кат.", "ref"])
    try LV_Prompts.ModifyCol(2, "Center")
    LV_Prompts.OnEvent("DoubleClick", (*) => EditSelectedPromptFromPanel(DictGui))
    LV_Prompts.OnEvent("Click", HandlePromptListClick) ; v13.17: ЛКМ — копия в буфер
    LV_Prompts.OnEvent("ContextMenu", PanelContextEdit.Bind("PROMPTS"))
    LV_Prompts.OnEvent("ColClick", HandlePanelListViewColClick)
    RegisterPanelHandCursorList("PROMPTS", LV_Prompts) ; v13.19
    LV_Links := DictGui.Add("ListView", "x150 y88 w720 h360 -Grid -E0x200 +Border Background" ControlBg " c" TextCol " -Multi Hidden", ["Название", "URL", "Теги / заметка", "Исп."])
    LV_Links.OnEvent("DoubleClick", (*) => EditSelectedLinkFromPanel(DictGui))
    LV_Links.OnEvent("ContextMenu", PanelContextEdit.Bind("LINKS"))
    LV_Links.OnEvent("ColClick", HandlePanelListViewColClick)
    LV_Data := DictGui.Add("ListView", "x150 y88 w720 h360 -Grid -E0x200 +Border Background" ControlBg " c" TextCol " -Multi Hidden", ["Ключ / логин", "Описание", "Состояние", "Исп.", "ID"])
    LV_Data.OnEvent("DoubleClick", (*) => EditSelectedDataFromPanel(DictGui))
    LV_Data.OnEvent("ContextMenu", PanelContextEdit.Bind("DATA"))
    LV_Data.OnEvent("ColClick", HandlePanelListViewColClick)
    LV_Hotkeys := DictGui.Add("ListView", "x150 y88 w720 h360 -Grid -E0x200 +Border Background" ControlBg " c" TextCol " -Multi Hidden", ["Название", "Хоткей", "Что вставляет"])
    LV_Hotkeys.OnEvent("DoubleClick", (*) => EditSelectedHotInsertFromPanel(DictGui))
    LV_Hotkeys.OnEvent("ContextMenu", PanelContextEdit.Bind("HOTKEYS"))
    LV_Hotkeys.OnEvent("ColClick", HandlePanelListViewColClick)
    ; v13.16: 3-я колонка (ширина 0) — ref на настоящий ключ: видимый текст может быть маской.
    LV_Hidden := DictGui.Add("ListView", "x150 y88 w720 h360 -Grid -E0x200 +Border Background" ControlBg " c" TextCol " -Multi Hidden", ["Исключённая запись", "Тип", "ref"])
    LV_Hidden.OnEvent("ColClick", HandlePanelListViewColClick)
    ApplyPanelListViewWidths()

    ; Тёмные скроллбары и шапки колонок списков и справки ставит
    ; ApplyDarkThemeToGui перед Show. v13.20: отдельный проход здесь убран —
    ; тема применялась дважды (SetWindowTheme + WM_THEMECHANGED на 10 контролов),
    ; а сабкласс шапки, поставленный до заполнения, всё равно снимался на время
    ; заполнения (BeginPanelListBulk).

    DictInfoTitle := DictGui.Add("Text", "x150 y92 w720 h24 cFFFFFF Hidden", "Настройки и управление")

    ; --- Секция: Управление -------------------------------------------------
    ; v13.17: секции уплотнены — освободилось место под секцию «ПАНЕЛЬ F9».
    DictSettingsPanel.Push(DictGui.Add("Text", "x150 y124 w720 h16 c8E8E8E Hidden", "УПРАВЛЕНИЕ"))
    DictSettingsPanel.Push(DictGui.Add("Text", "x150 y142 w720 h1 Background303030 Hidden", ""))
    DictBtnPass := CreateFlatTextButton(DictGui, "x150 y150 w180 h32 Hidden", "Сменить пароль", (*) => ChangePasswordGUI())
    DictBtnHotstrings := CreateFlatTextButton(DictGui, "x342 y150 w180 h32 Hidden", "Автозамены (Win+F9)", (*) => ShowHotstringGUI())
    DictBtnSaveNow := CreateFlatTextButton(DictGui, "x534 y150 w180 h32 Hidden", "Сохранить сейчас", (*) => SaveAllDataFromGui())
    ; Важно: кнопки настроек тоже должны входить в DictSettingsPanel.
    ; Иначе они созданы с Hidden, но при переключении на вкладку "Настройки" не показываются.
    DictSettingsPanel.Push(DictBtnPass)
    DictSettingsPanel.Push(DictBtnHotstrings)
    DictSettingsPanel.Push(DictBtnSaveNow)
    ; v13.22: скрытный режим паролей Данных (по умолчанию выкл. — намёк виден).
    DictDataPasswordsHiddenCheck := DictGui.Add("CheckBox", "x728 y155 w142 h22 cF0F0F0 Hidden Checked" (DataPasswordsHidden ? 1 : 0), "Скрыть пароли")
    DictDataPasswordsHiddenCheck.OnEvent("Click", ToggleDataPasswordsHiddenFromGui)
    DictSettingsPanel.Push(DictDataPasswordsHiddenCheck)

    ; --- Секция: Ввод и хоткеи ----------------------------------------------
    ; v13.18: секции сдвинуты — добавлен выбор режима словаря.
    DictSettingsPanel.Push(DictGui.Add("Text", "x150 y192 w720 h16 c8E8E8E Hidden", "ВВОД И ХОТКЕИ"))
    DictSettingsPanel.Push(DictGui.Add("Text", "x150 y210 w720 h1 Background303030 Hidden", ""))
    DictInsertCheck := DictGui.Add("CheckBox", "x150 y218 w420 h22 cF0F0F0 Hidden Checked" (InsertCaptureEnabled ? 1 : 0), "Захватывать Insert для записи фраз (Win+Insert)")
    DictInsertCheck.OnEvent("Click", ToggleInsertCaptureFromGui)
    DictLCtrlCommaCheck := DictGui.Add("CheckBox", "x150 y244 w340 h22 cF0F0F0 Hidden Checked" (EnableLCtrlComma ? 1 : 0), "LCtrl tap — вставлять запятую")
    DictLCtrlCommaCheck.OnEvent("Click", ToggleLCtrlCommaFromGui)
    DictRCtrlPeriodCheck := DictGui.Add("CheckBox", "x510 y244 w300 h22 cF0F0F0 Hidden Checked" (EnableRCtrlPeriod ? 1 : 0), "RCtrl tap — точка-комбо")
    DictRCtrlPeriodCheck.OnEvent("Click", ToggleRCtrlPeriodFromGui)
    DictPgKeysCheck := DictGui.Add("CheckBox", "x150 y270 w720 h22 cF0F0F0 Hidden Checked" (PgKeysModeEnabled ? 1 : 0), "PgUp/PgDn — молчаливые режимы: клик = 1/2, второй клик = 11/22, третий — выход (тест)")
    DictPgKeysCheck.OnEvent("Click", TogglePgKeysModeFromGui)
    DictSettingsPanel.Push(DictInsertCheck)
    DictSettingsPanel.Push(DictLCtrlCommaCheck)
    DictSettingsPanel.Push(DictRCtrlPeriodCheck)
    DictSettingsPanel.Push(DictPgKeysCheck)

    ; --- Секция: Словарь и OSD слов -------------------------------------------
    DictSettingsPanel.Push(DictGui.Add("Text", "x150 y302 w720 h16 c8E8E8E Hidden", "СЛОВАРЬ И OSD СЛОВ"))
    DictSettingsPanel.Push(DictGui.Add("Text", "x150 y320 w720 h1 Background303030 Hidden", ""))
    ; v13.18: режим словаря — полный / ручной / выключен (см. SetDictionaryMode).
    TxtDictMode := DictGui.Add("Text", "x150 y330 w66 h20 cB0B0B0 Hidden", "Словарь:")
    DictModeSelect := DictGui.Add("DropDownList", "x218 y326 w400 Background" ControlBg " c" TextCol " Hidden Choose" GetDictModeIndex(DictMode), GetDictModeChoices())
    DictModeSelect.OnEvent("Change", ApplyDictModeFromGui)
    ApplyDarkControlTheme(DictModeSelect, "DarkMode_CFD")
    DictSettingsPanel.Push(TxtDictMode)
    DictSettingsPanel.Push(DictModeSelect)
    DictWordAutoHideCheck := DictGui.Add("CheckBox", "x150 y356 w310 h22 cF0F0F0 Hidden Checked" (WordOsdAutoHideEnabled ? 1 : 0), "Скрывать OSD слов при неактивности")
    DictWordAutoHideCheck.OnEvent("Click", ToggleWordOsdAutoHideFromGui)
    TxtWordAutoHideA := DictGui.Add("Text", "x470 y358 w44 h20 cB0B0B0 Hidden", "через")
    DictWordAutoHideSecEdit := DictGui.Add("Edit", "x518 y354 w58 h24 Background2D2D2D cF0F0F0 Hidden", Format("{:.1f}", WordOsdAutoHideMs / 1000))
    DictWordAutoHideSecEdit.OnEvent("Change", UpdateWordOsdAutoHideSecondsFromGui)
    TxtWordAutoHideB := DictGui.Add("Text", "x582 y358 w40 h20 cB0B0B0 Hidden", "сек.")
    DictSettingsPanel.Push(DictWordAutoHideCheck)
    DictSettingsPanel.Push(TxtWordAutoHideA)
    DictSettingsPanel.Push(DictWordAutoHideSecEdit)
    DictSettingsPanel.Push(TxtWordAutoHideB)
    ; Выбор акцентного цвета всего скрипта (заголовки, активная вкладка, выделение в OSD).
    TxtAccent := DictGui.Add("Text", "x640 y358 w52 h20 cB0B0B0 Hidden", "Акцент:")
    accentIdx := 1
    for i, entry in GetAccentColorChoices() {
        if (entry.Hex = ColorHighlight)
            accentIdx := i
    }
    accentNames := []
    for _, entry in GetAccentColorChoices()
        accentNames.Push(entry.Name)
    DictAccentSelect := DictGui.Add("DropDownList", "x698 y354 w130 Background" ControlBg " c" TextCol " Hidden Choose" accentIdx, accentNames)
    DictAccentSelect.OnEvent("Change", ApplyAccentColorFromGui)
    ApplyDarkControlTheme(DictAccentSelect, "DarkMode_CFD")
    DictSettingsPanel.Push(TxtAccent)
    DictSettingsPanel.Push(DictAccentSelect)

    ; --- Секция: Панель F9 (v13.17) ---------------------------------------------
    DictSettingsPanel.Push(DictGui.Add("Text", "x150 y386 w720 h16 c8E8E8E Hidden", "ПАНЕЛЬ F9"))
    DictSettingsPanel.Push(DictGui.Add("Text", "x150 y404 w720 h1 Background303030 Hidden", ""))
    DictOpenPromptsCheck := DictGui.Add("CheckBox", "x150 y412 w340 h22 cF0F0F0 Hidden Checked" (PanelOpenPromptsByDefault ? 1 : 0), "Открывать на вкладке «Промпты»")
    DictOpenPromptsCheck.OnEvent("Click", TogglePanelOpenPromptsFromGui)
    DictPromptClickCopyCheck := DictGui.Add("CheckBox", "x510 y412 w360 h22 cF0F0F0 Hidden Checked" (PanelPromptClickCopy ? 1 : 0), "ЛКМ по промпту — копировать в буфер")
    DictPromptClickCopyCheck.OnEvent("Click", TogglePanelPromptClickCopyFromGui)
    DictSettingsPanel.Push(DictOpenPromptsCheck)
    DictSettingsPanel.Push(DictPromptClickCopyCheck)

    ; --- Секция: Справочно ------------------------------------------------------
    DictSettingsPanel.Push(DictGui.Add("Text", "x150 y444 w720 h16 c8E8E8E Hidden", "СПРАВОЧНО"))
    DictSettingsPanel.Push(DictGui.Add("Text", "x150 y462 w720 h1 Background303030 Hidden", ""))
    ; Про Win+Q/Win+A рассказывает подсказка внизу панели (DictHintText), про
    ; Win+Insert — подпись чекбокса выше; здесь только то, чего там нет.
    ; v13.18: вторая строка — сколько занял последний старт по этапам.
    DictStartupTimingText := DictGui.Add("Text", "x150 y468 w720 h38 c8E8E8E Hidden", BuildSettingsInfoText())
    DictSettingsPanel.Push(DictStartupTimingText)

    DictBtnRestore := CreateFlatTextButton(DictGui, "x150 y468 w145 h34 Hidden", "Вернуть", (*) => RestoreHiddenWord(DictGui))
    DictBtnDelete  := CreateFlatTextButton(DictGui, "x306 y468 w110 h34 Hidden", "Удалить", (*) => DeleteWordFromDict(DictGui))
    DictBtnPruneWords := CreateFlatTextButton(DictGui, "x428 y468 w170 h34 Hidden", "Удалить ≤ рейтинг…", (*) => PruneLowRatedWordsFromGui())
    DictBtnEditPhrase := CreateFlatTextButton(DictGui, "x428 y468 w128 h34 Hidden", "Править", (*) => EditSelectedPhraseFromPanel(DictGui))
    DictBtnEditLink := CreateFlatTextButton(DictGui, "x428 y468 w128 h34 Hidden", "Править", (*) => EditSelectedLinkFromPanel(DictGui))
    DictBtnEditData := CreateFlatTextButton(DictGui, "x428 y468 w128 h34 Hidden", "Править", (*) => EditSelectedDataFromPanel(DictGui))
    DictBtnAddData := CreateFlatTextButton(DictGui, "x568 y468 w128 h34 Hidden", "Новая запись", (*) => OpenDataCardGui())
    DictBtnAddLink := CreateFlatTextButton(DictGui, "x568 y468 w128 h34 Hidden", "Новая ссылка", (*) => ShowLinkCaptureGui())
    DictBtnAssignPhraseHotkey := CreateFlatTextButton(DictGui, "x568 y468 w150 h34 Hidden", "Назначить хоткей", CreateHotInsertFromSelectedPhrase)
    DictBtnAddHotkey := CreateFlatTextButton(DictGui, "x428 y468 w128 h34 Hidden", "Новый хоткей", (*) => ShowHotInsertEditGui())
    DictBtnEditHotkey := CreateFlatTextButton(DictGui, "x568 y468 w128 h34 Hidden", "Править", (*) => EditSelectedHotInsertFromPanel(DictGui))
    ; Фильтр свалки: w146, чтобы не наезжать на кнопку "Удалить" (x306).
    ; Вся нижняя линейка выровнена по y468/h34, как остальные кнопки ряда.
    DictDataPileSelect := DictGui.Add("DropDownList", "x150 y472 w146 Background" ControlBg " c" TextCol " Hidden Choose" (DictDataPileMode = "NOPILE" ? 2 : (DictDataPileMode = "PILE" ? 3 : 1)), ["Все записи", "Без свалки", "Только свалка"])
    DictDataPileSelect.OnEvent("Change", HandleDataPileModeChanged)
    ApplyDarkControlTheme(DictDataPileSelect, "DarkMode_CFD")
    DictBtnClose := CreateFlatTextButton(DictGui, "x786 y468 w84 h34", "Закрыть", CloseDictionaryPanel)
    DictHintText := DictGui.Add("Text", "x150 y510 w720 h20 c8E8E8E", "")

    PopulateDictListView()
  UpdateDictionaryViewUi()
  ApplyDarkThemeToGui(DictGui)
  DictGui.Show("w900 h548")
  ; Прозрачности у панели НЕТ — осознанно. WinSetTransparent делает окно
  ; layered, а layered-стиль несовместим с WS_EX_COMPOSITED — единственным
  ; системным способом перерисовывать окно с контролами одним цельным кадром.
  ; Выбор: либо едва заметная прозрачность (247/255) + мерцание при
  ; переключении разделов, либо непрозрачное окно без мерцания. Выбрано второе.
    try DllCall("User32\SendMessageW", "Ptr", DictHelpEdit.Hwnd, "UInt", 0x00B1, "Ptr", 0, "Ptr", 0)
    ; v13.17: фокус — в поле поиска открытой вкладки.
    focusCtrl := (DictActiveView = "HOME") ? DictGlobalSearchEdit : DictSearchEdit
    try focusCtrl.Focus()
    ; v13.20: 40 мс и показ без паузы — плашка появляется сразу; тик почти
    ; бесплатный, пока курсор неподвижен или на той же строке (см.
    ; WatchDictionaryPanelPreview).
    SetTimer(WatchDictionaryPanelPreview, 40)
}



PanelTargetHasCaretNow() {
    ; CaretGetPos — не абсолютная гарантия для браузеров/IDE, но это лучший дешёвый guard
    ; от случайной вставки в окно, где явно нет текстовой каретки.
    try {
        if CaretGetPos(&cx, &cy)
            return true
    }
    return false
}

PanelTargetIsUsable() {
    global DictPanelTargetHwnd
    if !DictPanelTargetHwnd
        return false
    try return DllCall("User32\IsWindow", "Ptr", DictPanelTargetHwnd)
    return false
}

ActivatePanelTarget() {
    global DictPanelTargetHwnd
    if !PanelTargetIsUsable()
        return false
    try {
        WinActivate("ahk_id " DictPanelTargetHwnd)
        Sleep(120)
        return true
    }
    return false
}

InsertTextToPanelTarget(textToSend, closePanel := true, force := false, undoKind := "PANEL") {
    global DictPanelGui, DictPanelTargetHasCaret
    if (textToSend = "")
        return false
    ; Заявленное поведение (см. справку панели): Enter вставляет, только если при
    ; открытии панели найдена каретка; Ctrl+Enter (force) — принудительно.
    ; Раньше force и DictPanelTargetHasCaret просто игнорировались.
    if (!force && !DictPanelTargetHasCaret) {
        ToolTip("⚠️ Каретка в исходном окне не найдена. Ctrl+Enter — вставить принудительно")
        SetTimer(() => ToolTip(), -1800)
        return false
    }
    if !ActivatePanelTarget() {
        ToolTip("⚠️ Нет цели вставки: открой F9 из поля ввода")
        SetTimer(() => ToolTip(), -1800)
        return false
    }
    SafeSendPhrase(textToSend)
    StartPhraseUndo(textToSend, false, undoKind)
    if closePanel
        try CloseDictionaryPanel(DictPanelGui)
    return true
}

InsertDataToPanelTarget(dataId, closePanel := true, force := false) {
    global DataDB, DictPanelGui, DictPanelTargetHasCaret
    if !DataDB.Has(dataId) {
        ToolTip("⚠️ Карточка Данных не найдена: " dataId)
        SetTimer(() => ToolTip(), -1800)
        return false
    }

    data := DataDB[dataId]
    insertText := GetDataInsertText(data)
    if (insertText = "") {
        ToolTip("⚠️ В карточке нет текста для вставки")
        SetTimer(() => ToolTip(), -1600)
        return false
    }

    if (!force && !DictPanelTargetHasCaret) {
        ToolTip("⚠️ Каретка в исходном окне не найдена. Ctrl+Enter — вставить принудительно")
        SetTimer(() => ToolTip(), -1800)
        return false
    }

    if !ActivatePanelTarget() {
        ToolTip("⚠️ Нет цели вставки: открой F9 из поля ввода")
        SetTimer(() => ToolTip(), -2000)
        return false
    }

    ; ВАЖНО: логин/одиночный пароль вставляем через SendText, не через SafeSendPhrase,
    ; потому что SafeSendPhrase временно использует clipboard и может перетереть пароль.
    SafeSend(insertText, 0)
    StartWordInsertUndo(insertText, false, "DATA")

    copied := false
    if ShouldCopyDataPassword(data)
        copied := CopySecretToClipboard(data.Password)

    data.Count += 1
    QueueDataSave()
    if closePanel
        try CloseDictionaryPanel(DictPanelGui)

    if copied
        ToolTip("✅ Логин вставлен, пароль в буфере")
    else if (data.Password != "" && data.Login = "")
        ToolTip("🔐 Пароль вставлен")
    else
        ToolTip("✅ Вставлено")
    SetTimer(() => ToolTip(), -1600)
    return true
}
InsertSelectedFromDictionaryPanel(force := false, *) {
    global DictActiveView, LV_Phrases, LV_Prompts, LV_Links, LV_Data, LV_Hotkeys, LV_GlobalSearch, LV_Words, LV_Stems
    global DictPromptRowText, LinkDB, DataDB, HotInsertDB, PhraseDB, PromptDB, DictGlobalResultMap, WordDB

    if (DictActiveView = "PHRASES") {
        row := LV_Phrases.GetNext(0)
        if row
            return InsertTextToPanelTarget(LV_Phrases.GetText(row, 1), true, force, "PHRASE")
    } else if (DictActiveView = "PROMPTS") {
        row := LV_Prompts.GetNext(0)
        if row
            return InsertTextToPanelTarget(DictPromptRowText.Has(row) ? DictPromptRowText[row] : LV_Prompts.GetText(row, 1), true, force, "PROMPT")
    } else if (DictActiveView = "LINKS") {
        id := GetSelectedLinkIdFromPanel()
        if (id != "" && LinkDB.Has(id)) {
            LinkDB[id].Count += 1
            SaveLinksInternal()
            return InsertTextToPanelTarget(LinkDB[id].Url, true, force, "LINK")
        }
    } else if (DictActiveView = "DATA") {
        id := GetSelectedDataIdFromPanel()
        if (id != "")
            return InsertDataToPanelTarget(id, true, force)
    } else if (DictActiveView = "HOTKEYS") {
        id := GetSelectedHotInsertIdFromPanel()
        if (id != "" && HotInsertDB.Has(id))
            return InsertTextToPanelTarget(ResolveHotInsertText(HotInsertDB[id]), true, force, "HOTKEY")
    } else if (DictActiveView = "WORDS") {
        row := LV_Words.GetNext(0)
        if row
            return InsertTextToPanelTarget(LV_Words.GetText(row, 1) " ", true, force, "WORD")
    } else if (DictActiveView = "STEMS") {
        row := LV_Stems.GetNext(0)
        if row
            return InsertTextToPanelTarget(LV_Stems.GetText(row, 1), true, force, "STEM")
    } else if (DictActiveView = "HOME") {
        row := LV_GlobalSearch.GetNext(0)
        if row && DictGlobalResultMap.Has(row) {
            item := DictGlobalResultMap[row]
            if (item.Kind = "PHRASE" && PhraseDB.Has(StrLower(item.Key)))
                return InsertTextToPanelTarget(PhraseDB[StrLower(item.Key)].Text, true, force, "PHRASE")
            if (item.Kind = "PROMPT" && PromptDB.Has(StrLower(item.Key)))
                return InsertTextToPanelTarget(PromptDB[StrLower(item.Key)].Text, true, force, "PROMPT")
            if (item.Kind = "LINK" && LinkDB.Has(item.Key))
                return InsertTextToPanelTarget(LinkDB[item.Key].Url, true, force, "LINK")
            if (item.Kind = "DATA" && DataDB.Has(item.Key))
                return InsertDataToPanelTarget(item.Key, true, force)
            if (item.Kind = "HOTKEY" && HotInsertDB.Has(item.Key))
                return InsertTextToPanelTarget(ResolveHotInsertText(HotInsertDB[item.Key]), true, force, "HOTKEY")
            if ((item.Kind = "WORD" || item.Kind = "STEM") && WordDB.Has(item.Key))
                return InsertTextToPanelTarget(WordDB[item.Key].Display " ", true, force, "WORD")
        }
    }

    ToolTip("⚠️ Выбери строку для вставки")
    SetTimer(() => ToolTip(), -1200)
    return false
}

#HotIf WinActive("Панель Typer") && !TyperSuspended
Enter::InsertSelectedFromDictionaryPanel(false)
^Enter::InsertSelectedFromDictionaryPanel(true)
#HotIf

OnDictionaryPanelSize(guiObj, minMax, width, height) {
    ; MinMax = -1 означает, что панель свёрнута. Preview должен немедленно исчезать
    ; и больше не появляться, пока окно снова не активно.
    if (minMax = -1)
        HidePanelPreviewOsd()
}

CloseDictionaryPanel(guiObj := 0, *) {
    global DictPanelGui
    SavePanelColumnWidths()
    SetTimer(WatchDictionaryPanelPreview, 0)
    HidePanelPreviewOsd()
    DestroyPanelChildGuis()
    try guiObj.Destroy()
    try DictPanelGui.Destroy()
    DictPanelGui := 0
}

GetListViewColumnWidth(lv, col) {
    try return DllCall("User32\SendMessageW", "Ptr", lv.Hwnd, "UInt", 0x101D, "Ptr", col - 1, "Ptr", 0, "Ptr") ; LVM_GETCOLUMNWIDTH
    catch
        return 0
}

SaveListViewWidths(lv, key, colCount) {
    global DictPanelColumnWidths
    Loop colCount {
        w := GetListViewColumnWidth(lv, A_Index)
        if (w > 0)
            DictPanelColumnWidths[key "_" A_Index] := w
    }
}

SavePanelColumnWidths(*) {
    global LV_Words, LV_Stems, LV_Phrases, LV_Prompts, LV_Links, LV_Data, LV_Hidden, LV_Hotkeys, LV_GlobalSearch, DictPanelColumnWidths
    if IsSet(LV_Words)
        SaveListViewWidths(LV_Words, "words", 2)
    if IsSet(LV_Stems)
        SaveListViewWidths(LV_Stems, "stems", 2)
    if IsSet(LV_Phrases)
        SaveListViewWidths(LV_Phrases, "phrases", 2)
    ; v13.21: у «Промптов» ширины не сохраняются (см. StretchPromptListColumns);
    ; старые записи убираем, чтобы не висели в opt.bin.
    for _, oldKey in ["prompts_1", "prompts_2", "prompts_3"] {
        if DictPanelColumnWidths.Has(oldKey)
            DictPanelColumnWidths.Delete(oldKey)
    }
    if IsSet(LV_Links)
        SaveListViewWidths(LV_Links, "links", 4)
    if IsSet(LV_Data)
        SaveListViewWidths(LV_Data, "data", 5)
    if IsSet(LV_Hotkeys)
        SaveListViewWidths(LV_Hotkeys, "hotkeys", 3)
    if IsSet(LV_Hidden)
        SaveListViewWidths(LV_Hidden, "hidden", 2)
    if IsSet(LV_GlobalSearch)
        SaveListViewWidths(LV_GlobalSearch, "global", 3)
    SaveSettingsInternal()
}

ApplyListViewWidths(lv, key, defaults) {
    ; v13.21: сохранённая ширина — уже физические пиксели (её мерили
    ; LVM_GETCOLUMNWIDTH), ставим её как есть; значение по умолчанию — в единицах
    ; Gui через ModifyCol (он масштабирует под DPI). См. SetListViewColumnWidthPx.
    global DictPanelColumnWidths
    for i, defaultW in defaults {
        settingKey := key "_" i
        if DictPanelColumnWidths.Has(settingKey)
            SetListViewColumnWidthPx(lv, i, DictPanelColumnWidths[settingKey])
        else
            try lv.ModifyCol(i, defaultW)
    }
}

PanelDecryptWatch() {
    ; v13.17: пока базы расшифровываются — крутит индикатор; по готовности
    ; строит видимую вкладку (остальные — лениво, при первом открытии) и
    ; на пару секунд показывает «Базы готовы».
    global TyperStartupComplete
    if !IsDictionaryPanelReady() {
        SetTimer(PanelDecryptWatch, 0)
        return
    }
    if !TyperStartupComplete {
        UpdatePanelDecryptIndicator()
        return
    }
    SetTimer(PanelDecryptWatch, 0)
    ShowPanelDecryptDone()
    PopulateDictListView()
    UpdateDictionaryViewUi()
}

SetTyperStartupStage(step, stage) {
    ; v13.17: текущий этап стартовой загрузки — для индикатора в панели F9.
    ; Вызывается из автозапуска между этапами, поэтому индикатор обновляется
    ; сразу, даже если таймер панели не успел сработать.
    ; v13.18: заодно меряем длительность этапов (Настройки → «Справочно»).
    global TyperStartupStep, TyperStartupStage, TyperStartupComplete, TyperStartupTimings
    static lastTick := 0, lastStage := ""
    now := A_TickCount
    if (lastStage != "")
        TyperStartupTimings.Push({Stage: lastStage, Ms: now - lastTick})
    lastTick := now
    lastStage := (step > 0) ? stage : ""
    TyperStartupStep := step
    TyperStartupStage := stage
    if !TyperStartupComplete
        try UpdatePanelDecryptIndicator()
}

FormatSecondsShort(ms) {
    return Format("{:.1f}", Max(0, ms) / 1000) " с"
}

GetStartupTimingSummary() {
    ; v13.18: «Старт: 1.4 с — словарь 0.9 · фразы 0.2 …» — самые долгие этапы.
    global TyperStartupTimings
    if !TyperStartupTimings.Length
        return ""
    total := 0
    rows := []
    for _, t in TyperStartupTimings {
        total += t.Ms
        if (t.Ms >= 100)
            rows.Push(t)
    }
    ; несколько строк — простая сортировка вставками по убыванию
    i := 2
    while (i <= rows.Length) {
        cur := rows[i]
        j := i - 1
        while (j >= 1 && rows[j].Ms < cur.Ms) {
            rows[j + 1] := rows[j]
            j -= 1
        }
        rows[j + 1] := cur
        i += 1
    }
    parts := ""
    for idx, t in rows {
        if (idx > 4)
            break
        parts .= (parts != "" ? " · " : "") t.Stage " " FormatSecondsShort(t.Ms)
    }
    return "Последний старт после пароля: " FormatSecondsShort(total) (parts != "" ? " — " parts : "")
}

BuildSettingsInfoText() {
    ; v13.18: статичная справка + время последнего старта по этапам.
    info := "Пароль на диске не хранится. Автосохранение — при выходе и раз в 3 часа."
    timing := GetStartupTimingSummary()
    return (timing != "") ? info "`n" timing : info
}

UpdatePanelDecryptIndicator() {
    ; v13.17: «крутилка» + «Расшифровка N/M · этап» + полоса прогресса.
    ; Компактный вариант — внизу столбца разделов, крупный — на месте списков.
    static frames := ["●  ○  ○", "○  ●  ○", "○  ○  ●", "○  ●  ○"], frameIdx := 0
    global TyperStartupStep, TyperStartupSteps, TyperStartupStage, TyperStartupComplete
    global DictDecryptSpin, DictDecryptNote, DictDecryptBarFill, DictDecryptBarRest
    global DictLoadSpin, DictLoadStage, DictLoadBarFill, DictLoadBarRest
    if (TyperStartupComplete || !IsLiveGuiControl(DictDecryptSpin))
        return
    frameIdx := Mod(frameIdx, frames.Length) + 1
    frame := frames[frameIdx]
    total := Max(1, TyperStartupSteps)
    step := Max(1, Min(TyperStartupStep, total))
    stage := (TyperStartupStage != "") ? TyperStartupStage : "подготовка"
    ratio := (step - 1) / total
    try DictDecryptSpin.Text := frame
    try DictDecryptNote.Text := "Расшифровка " step "/" total "`n" stage
    SetPanelBarFill(DictDecryptBarFill, DictDecryptBarRest, 18, 496, 100, 3, ratio)
    if IsLiveGuiControl(DictLoadSpin) {
        try DictLoadSpin.Text := frame
        try DictLoadStage.Text := "Этап " step " из " total " · " stage
        SetPanelBarFill(DictLoadBarFill, DictLoadBarRest, 330, 278, 360, 3, ratio)
    }
}

SetPanelBarFill(fillCtrl, restCtrl, x, y, totalW, h, ratio) {
    ; Полоса прогресса из двух непересекающихся прямоугольников: заполненная
    ; часть (акцент) и остаток (тёмный). Нулевая ширина — просто не видна.
    fillW := Round(totalW * Max(0, Min(1, ratio)))
    try fillCtrl.Move(x, y, fillW, h)
    try restCtrl.Move(x + fillW, y, totalW - fillW, h)
}

ShowPanelDecryptDone() {
    global DictDecryptSpin, DictDecryptNote, DictDecryptBarFill, DictDecryptBarRest
    if !IsLiveGuiControl(DictDecryptNote)
        return
    try DictDecryptSpin.Text := "●"
    try DictDecryptNote.Text := "Базы готовы"
    try DictDecryptBarFill.Visible := false
    try DictDecryptBarRest.Visible := false
    SetTimer(HidePanelDecryptNote, -1800)
}

HidePanelDecryptNote() {
    global DictDecryptSpin, DictDecryptNote, DictDecryptBarFill, DictDecryptBarRest
    for ctrl in [DictDecryptSpin, DictDecryptNote, DictDecryptBarFill, DictDecryptBarRest]
        try ctrl.Visible := false
}

StretchLastListViewColumn(lv, lastCol) {
    ; Дотягивает последнюю колонку до правого края клиентской области, чтобы
    ; после неё не оставался пустой «фантомный столбец» (хвост шапки).
    ; GetClientRect уже не включает вертикальный скроллбар — запас не нужен.
    try {
        rc := Buffer(16, 0)
        if !DllCall("User32\GetClientRect", "Ptr", lv.Hwnd, "Ptr", rc.Ptr)
            return
        clientW := NumGet(rc, 8, "Int")
        if (clientW <= 0)
            return
        used := 0
        Loop lastCol - 1
            used += GetListViewColumnWidth(lv, A_Index)
        lastW := clientW - used
        ; v13.20: ширина та же — не трогаем (ModifyCol перерисовывает шапку и
        ; список; раньше это происходило после каждого обновления поиска).
        if (lastW >= 40 && lastW != GetListViewColumnWidth(lv, lastCol))
            SetListViewColumnWidthPx(lv, lastCol, lastW) ; v13.21: физические пиксели (было ModifyCol → ×DPI)
    }
}

ApplyPanelListViewWidths() {
    global LV_Words, LV_Stems, LV_Phrases, LV_Prompts, LV_Links, LV_Data, LV_Hidden, LV_Hotkeys, LV_GlobalSearch
    ApplyListViewWidths(LV_Words, "words", [560, 110])
    ApplyListViewWidths(LV_Stems, "stems", [560, 110])
    ApplyListViewWidths(LV_Phrases, "phrases", [610, 70])
    StretchPromptListColumns() ; v13.21: текст + «Кат.» + скрытый ref, ширины не сохраняются
    ApplyListViewWidths(LV_Links, "links", [180, 320, 150, 50])
    ApplyListViewWidths(LV_Data, "data", [230, 330, 90, 50, 0])
    ApplyListViewWidths(LV_Hotkeys, "hotkeys", [200, 140, 350])
    ApplyListViewWidths(LV_Hidden, "hidden", [560, 110, 0])
    ApplyGlobalSearchColumnMode()
    ; Убираем пустой хвост после последней колонки во всех разделах.
    StretchLastListViewColumn(LV_Words, 2)
    StretchLastListViewColumn(LV_Stems, 2)
    StretchLastListViewColumn(LV_Phrases, 2)
    StretchLastListViewColumn(LV_Links, 4)
    StretchLastListViewColumn(LV_Data, 4) ; 5-я колонка — скрытый ID (ширина 0)
    StretchLastListViewColumn(LV_Hotkeys, 3)
    StretchLastListViewColumn(LV_Hidden, 2)
}

ApplyGlobalSearchColumnMode() {
    ; v13.21: сохранённые ширины — физические пиксели (SetListViewColumnWidthPx),
    ; значения по умолчанию — через ModifyCol (единицы Gui, с DPI).
    global LV_GlobalSearch, DictShowFrequencyColumn, DictPanelColumnWidths
    if !IsSet(LV_GlobalSearch)
        return
    if DictPanelColumnWidths.Has("global_1")
        SetListViewColumnWidthPx(LV_GlobalSearch, 1, DictPanelColumnWidths["global_1"])
    else
        try LV_GlobalSearch.ModifyCol(1, 84)
    textW := DictPanelColumnWidths.Has("global_2") ? DictPanelColumnWidths["global_2"] : 0
    if (textW > 0 && (DictShowFrequencyColumn || textW >= Round(560 * A_ScreenDPI / 96)))
        SetListViewColumnWidthPx(LV_GlobalSearch, 2, textW)
    else
        try LV_GlobalSearch.ModifyCol(2, DictShowFrequencyColumn ? 500 : 625)
    freqW := DictPanelColumnWidths.Has("global_3") ? DictPanelColumnWidths["global_3"] : 0
    if !DictShowFrequencyColumn
        SetListViewColumnWidthPx(LV_GlobalSearch, 3, 0)
    else if (freqW >= 40)
        SetListViewColumnWidthPx(LV_GlobalSearch, 3, freqW)
    else
        try LV_GlobalSearch.ModifyCol(3, 105)
    SetListViewColumnWidthPx(LV_GlobalSearch, 4, 0) ; v13.17: скрытый ref
    ; Дотянуть до края: с частотой тянется 3-я колонка, без неё — 2-я.
    if DictShowFrequencyColumn
        StretchLastListViewColumn(LV_GlobalSearch, 3)
    else
        StretchLastListViewColumn(LV_GlobalSearch, 2)
}

ToggleGlobalSearchFrequencyColumn(ctrl, *) {
    global DictShowFrequencyColumn
    SetTimer(RunDictionarySearchRefreshDebounced, 0)
    DictShowFrequencyColumn := !!ctrl.Value
    ApplyGlobalSearchColumnMode()
    PopulateDictListView()
    SaveSettingsInternal()
}

ToggleGlobalSearchWordsColumn(ctrl, *) {
    global DictSearchIncludeWords
    SetTimer(RunDictionarySearchRefreshDebounced, 0)
    DictSearchIncludeWords := !!ctrl.Value
    PopulateDictListView()
    UpdateGlobalDeleteButtonState()
    SaveSettingsInternal()
}

BuildMainHelpText() {
    ; Моноширинная справка: блоки выровнены, чтобы при переносе в новый чат
    ; было ясно, какие клавиши являются глобальными, какие работают только в OSD,
    ; а какие относятся к панели/добавлению.
    line := "──────────────────────────────────────────────────────────────────────────────`r`n"
    out := "TYРER — ЛИЧНЫЙ ПОМОЩНИК НАБОРА`r`n"
    out .= "Фразы = любые текстовые фрагменты: куски, заготовки, короткие вставки.`r`n`r`n"

    out .= "ГЛОБАЛЬНО`r`n" line
    out .= PadHelpKey("Win+T")                  . "полностью остановить/включить Typer; остальные хоткеи во время паузы выключены.`r`n"
    out .= PadHelpKey("F9")                     . "главная панель Typer; открывается на «Промптах» (в Настройках можно на «Справке»).`r`n"
    out .= PadHelpKey("Win+F9")                 . "менеджер автозамен.`r`n"
    out .= PadHelpKey("Win+Q")                  . "временно разрешить/запретить Typer в текущем окне до перезапуска.`r`n"
    out .= PadHelpKey("Win+A")                  . "постоянно разрешить/запретить окно по exe+class; правило хранится в opt.bin.`r`n"
    out .= PadHelpKey("Win+Insert")             . "переключить захват Insert.`r`n"
    out .= PadHelpKey("Win+Shift+8 / Win+Num*") . "карточка Данные; выделение 'логин пароль' заполняет поля автоматически.`r`n"
    out .= PadHelpKey("Alt+N")                  . "случайное имя: Имя + Tab + Фамилия + Tab (раздельные поля Name/Surname).`r`n"
    out .= PadHelpKey("Alt+M")                  . "случайное имя одной строкой 'Имя Фамилия' + Tab (одно поле Full name).`r`n`r`n"

    out .= "РЕЖИМЫ ПОИСКА В OSD`r`n" line
    out .= PadHelpKey("буквы")                  . "слова и основы; OSD слов может скрываться по таймеру; режим словаря — в Настройках.`r`n"
    out .= PadHelpKey("1...")                   . "фразы/фрагменты по началу.`r`n"
    out .= PadHelpKey("11...")                  . "фразы/фрагменты по содержимому.`r`n"
    out .= PadHelpKey("2...")                   . "промпты по началу.`r`n"
    out .= PadHelpKey("22...")                  . "промпты по содержимому.`r`n"
    out .= PadHelpKey("3...")                   . "ссылки по названию, домену, тегам и токенам URL: 3ima, 3console.`r`n"
    out .= PadHelpKey("33...")                  . "ссылки по вхождению внутри URL/заметки/тегов.`r`n"
    out .= PadHelpKey("PgUp / PgDn")            . "молчаливая активация 1/11 и 2/22 без печати цифр; третий клик — выход (опция).`r`n"
    out .= PadHelpKey("*...")                   . "Данные: логины, пароли, карточки; авто-префикс может вставлять сразу.`r`n"
    out .= PadHelpKey("0... в поиске")           . "алиасные поля: ключи/префиксы Данных, названия/теги ссылок, метки хоткеев.`r`n`r`n"

    out .= "ВЫБОР И РЕДАКТИРОВАНИЕ OSD`r`n" line
    out .= PadHelpKey("1..0")                   . "выбрать вариант; F9 в OSD слов печатает цифры буквально до конца слова.`r`n"
    out .= PadHelpKey("LShift tap")             . "слова: первый вариант/основа; фразы/промпты/ссылки: вариант, выбранный «- / =».`r`n"
    out .= PadHelpKey("RShift tap в OSD фраз")  . "то же, что LShift: вставить выбранный вариант.`r`n" ; v13.20
    out .= PadHelpKey("- / =")                  . "листать варианты фраз/промптов/ссылок или основы; Shift — вставить выбранный.`r`n"
    out .= PadHelpKey("Delete")                 . "удалить текущую фразу/промпт/ссылку из OSD.`r`n"
    out .= PadHelpKey("\")                    . "открыть редактор текущей фразы/промпта/ссылки.`r`n"
    out .= PadHelpKey("Ctrl+1..8")              . "править фразу/промпт/ссылку из OSD.`r`n"
    out .= PadHelpKey("Ctrl+1..0 в *")          . "открыть карточку Данные.`r`n"
    out .= PadHelpKey("Alt+1..5")               . "скрыть вариант (фразы/промпты/ссылки — Alt+1..8).`r`n"
    out .= PadHelpKey("RAlt+1..5")              . "перенести слово в Данные.`r`n`r`n"

    out .= "ДОБАВЛЕНИЕ`r`n" line
    out .= PadHelpKey("Insert")                 . "новая фраза/фрагмент; Insert сохранить, Enter сохранить и вставить, Esc отменить.`r`n"
    out .= PadHelpKey("Alt+Insert")             . "новый промпт; категория — чипы / Ctrl+1…4; Alt+Insert сохранить, Enter сохранить и вставить, Esc отменить.`r`n"
    out .= PadHelpKey("Alt+F14")                . "добавить выделение как фразу/фрагмент.`r`n"
    out .= PadHelpKey("Shift+F14")              . "добавить выделение как промпт: у курсора — выбор категории (1–4 / I V L O / клик; Enter — подсвеченная; Esc — не сохранять; клик мимо — в подсвеченную).`r`n"
    out .= PadHelpKey("Numpad/")                . "добавить выделенный URL/домен как ссылку; без выделения — ручное окно.`r`n"
    out .= PadHelpKey("Alt+Numpad/")            . "ручное окно новой ссылки.`r`n`r`n"

    out .= "СИМВОЛЫ И ОТКАТ`r`n" line
    out .= PadHelpKey("\")                    . "после фрагмента слова — зафиксировать основу (сам \ не печатается); в OSD фраз — редактор; иначе обычный \.`r`n"
    out .= PadHelpKey("Alt+\")                . "напечатать обычный обратный слэш.`r`n"
    out .= PadHelpKey("Shift+\")              . "родная клавиша: в RU — «/», в EN — «|».`r`n"
    out .= PadHelpKey("Ctrl+\")               . "кавычки вокруг набираемого/только что вставленного слова или выделения (края сохраняются); повтор снимает кавычки, Alt+Z — вернуть как было.`r`n"
    out .= PadHelpKey("RShift tap")             . "запомнить текущее слово сразу с рейтингом " ManualWordScore " (наверху OSD); если выделен текст — добавить выделение в слова.`r`n"
    out .= PadHelpKey("AppsKey")                . "исключить выделение или текущий сырой фрагмент из выдачи словаря.`r`n"
    out .= PadHelpKey("Win+RShift tap")         . "запомнить текущее слово без пробела (тоже рейтинг " ManualWordScore ").`r`n"
    out .= PadHelpKey("LCtrl tap / RCtrl tap")  . "запятая / точка.`r`n"
    out .= PadHelpKey("Alt+Z")                  . "откат последней искусственной вставки.`r`n`r`n"

    out .= "ПАНЕЛЬ`r`n" line
    out .= PadHelpKey("Двойной клик / ПКМ")      . "правка фразы, промпта, ссылки, данных или горячей вставки (у промптов ПКМ — меню).`r`n"
    out .= PadHelpKey("Промпты: чипы, Ctrl+0…4") . "фильтр Все / Image / Video / LLM / Other; повторный выбор — снова «Все».`r`n"
    out .= PadHelpKey("Промпты: Alt+1…4")        . "перенести выбранный промпт в Image / Video / LLM / Other.`r`n"
    out .= PadHelpKey("ЛКМ по промпту")          . "копия промпта в буфер: вкладка «Промпты» и общий поиск (отключается в Настройках).`r`n"
    out .= PadHelpKey("Клик по заголовку")       . "сортировка колонки; повторный клик — обратный порядок.`r`n"
    out .= PadHelpKey("Enter / Ctrl+Enter")      . "вставить выбранное в прежнее окно; Ctrl+Enter — принудительно, если каретка не найдена.`r`n"
    out .= PadHelpKey("Delete")                 . "удалить выбранную строку панели/поиска (в поле поиска — обычное удаление символа).`r`n"
    out .= PadHelpKey("Исключённые")             . "записи целиком; Insert / «Вернуть» — снова в выдачу.`r`n"
    out .= PadHelpKey("Слова → Удалить ≤ рейтинг") . "массово почистить обычные слова с низким рейтингом; основы не трогает.`r`n"
    out .= PadHelpKey("Настройки → Словарь")    . "полный — учит все слова; ручной — новые только через RShift; выключен — не грузится (быстрый старт).`r`n"
    out .= PadHelpKey("Горячие")                . "свои вставки на хоткеи, например Win+Numpad9.`r`n"
    out .= PadHelpKey("Настройки → Сменить пароль") . "смена мастер-пароля шифрованных баз.`r`n"
    return out
}

PadHelpKey(key, width := 28) {
    key := StrReplace(key, "`t", " ")
    while (StrLen(key) < width)
        key .= " "
    return key . "— "
}


ClearDictionarySearch() {
    global DictSearchEdit
    SetTimer(RunDictionarySearchRefreshDebounced, 0)
    try DictSearchEdit.Value := ""
    PopulateDictListView()
    UpdateDictionaryViewUi()
}

ScheduleDictionarySearchRefresh(*) {
    global DictSearchDebounceMs
    HidePanelPreviewOsd()
    SetTimer(RunDictionarySearchRefreshDebounced, 0)
    SetTimer(RunDictionarySearchRefreshDebounced, -DictSearchDebounceMs)
}

RunDictionarySearchRefreshDebounced(*) {
    PopulateDictListView()
    UpdateDictionaryViewUi()
}

HandleGlobalSearchChanged(*) {
    ; v13.16: общий поиск на «Главной» меняет только свой список — не
    ; перезаполняем все 9 списков панели на каждую букву.
    global DictSearchDebounceMs
    HidePanelPreviewOsd()
    SetTimer(RunGlobalSearchRefreshDebounced, 0)
    SetTimer(RunGlobalSearchRefreshDebounced, -DictSearchDebounceMs)
}

RunGlobalSearchRefreshDebounced(*) {
    ; v13.16: общий поиск меняет только свой список.
    ; v13.17: пока базы не расшифрованы, искать не в чем — результат построит
    ; PanelDecryptWatch по готовности.
    global DictViewDirty, TyperStartupComplete
    if !IsDictionaryPanelReady()
        return
    if TyperStartupComplete {
        DictViewDirty["HOME"] := false
        RefreshGlobalSearchList()
    }
    UpdateDictionaryViewUi()
    try UpdateGlobalDeleteButtonState()
}

RefreshGlobalSearchList() {
    ; v13.20: заполнение — как у вкладок (BeginPanelListBulk): без перерисовки
    ; и без сабкласса тёмной шапки (раньше только -Redraw, и каждое сообщение
    ; заполнения шло через AHK-колбэк). Последняя колонка дотягивается уже после
    ; разморозки: появившийся скроллбар меняет ширину клиентской области.
    global LV_GlobalSearch, DictGlobalSearchEdit
    HidePanelPreviewOsd() ; содержимое строк меняется — плашка от старой строки не нужна
    detached := BeginPanelListBulk(LV_GlobalSearch)
    try {
        LV_GlobalSearch.Delete()
        globalSearchTerm := ""
        try globalSearchTerm := Trim(DictGlobalSearchEdit.Value)
        PopulateGlobalSearchResults(globalSearchTerm)
    } finally {
        EndPanelListBulk(LV_GlobalSearch, detached)
    }
    StretchGlobalSearchLastColumn()
}

StretchGlobalSearchLastColumn() {
    ; v13.20: после каждого поиска — только дотянуть последнюю колонку. Раньше
    ; здесь звался ApplyGlobalSearchColumnMode: он заново ставит сохранённые
    ; ширины всех колонок, и ширина, подогнанная мышью, сбрасывалась на каждую
    ; букву в поиске.
    global LV_GlobalSearch, DictShowFrequencyColumn
    try StretchLastListViewColumn(LV_GlobalSearch, DictShowFrequencyColumn ? 3 : 2)
}

ClearGlobalSearch() {
    global DictGlobalSearchEdit
    SetTimer(RunDictionarySearchRefreshDebounced, 0)
    SetTimer(RunGlobalSearchRefreshDebounced, 0)
    ToolTip()
    try DictGlobalSearchEdit.Value := ""
    RunGlobalSearchRefreshDebounced() ; v13.17: только свой список, без перестройки всех вкладок
}

PopulateGlobalSearchResults(queryText) {
    global WordDB, PhraseDB, PromptDB, LinkDB, DataDB, HotInsertDB, LV_GlobalSearch, DictGlobalResultMap, DictGlobalFullTextMap, DictGlobalRefs, DictShowFrequencyColumn, DictSearchIncludeWords

    DictGlobalResultMap := Map()
    DictGlobalFullTextMap := Map()
    DictGlobalRefs := Map() ; v13.17: ref → запись; переживает сортировку по заголовку
    queryText := StrLower(Trim(queryText))
    if (queryText = "")
        return

    aliasOnly := false
    if (SubStr(queryText, 1, 1) = "0") {
        aliasOnly := true
        queryText := Trim(SubStr(queryText, 2))
        if (queryText = "")
            return
    }

    added := 0
    maxResults := 220
    ; v13.20: см. PanelSearchMatch — запрос без пробелов ищется прямо по ключам.
    queryHasSpace := RegExMatch(queryText, "\s") ? true : false
    kindNames := ["Слово", "Слово скрыто", "Основа", "Основа скрыто"]
    kindHits := []
    for _, kindName in kindNames
        kindHits.Push(InStr(StrLower(kindName), queryText) ? true : false)

    AddGlobalRow(kind, title, countText, refKind := "", refKey := "", fullText := "") {
        global LV_GlobalSearch, DictGlobalResultMap, DictGlobalFullTextMap, DictGlobalRefs, DictShowFrequencyColumn
        titleFlat := RegExReplace(title, "\s+", " ")
        countFlat := RegExReplace(countText, "\s+", " ")
        if (fullText = "")
            fullText := title
        ; v13.17: 4-я скрытая колонка — ref. После сортировки по заголовку карты
        ; row → запись пересобираются по нему (раньше строки «съезжали»).
        ref := "g" (DictGlobalRefs.Count + 1)
        item := {Kind: refKind, Key: refKey}
        row := LV_GlobalSearch.Add(, kind, TruncatePhraseForOSD(titleFlat, 96), DictShowFrequencyColumn ? countFlat : "", ref)
        DictGlobalResultMap[row] := item
        DictGlobalFullTextMap[row] := fullText
        DictGlobalRefs[ref] := {Item: item, Full: fullText}
        return row
    }

    if !aliasOnly {
        if DictSearchIncludeWords {
            for key, data in WordDB {
                if (added >= maxResults)
                    break
                if data.HasOwnProp("DataOnly") && data.DataOnly
                    continue
                ; v13.20: раньше на КАЖДОЕ слово словаря (десятки тысяч) на каждую
                ; букву — склейка «слово + тип» и StrLower. Теперь ключ (он уже в
                ; нижнем регистре) и заранее посчитанное совпадение с типом.
                kindIdx := ((data.HasOwnProp("IsStem") && data.IsStem) ? 3 : 1) + ((data.HasOwnProp("Hidden") && data.Hidden) ? 1 : 0)
                kindHit := kindHits[kindIdx] || InStr(key, queryText)
                if (!kindHit && queryHasSpace)
                    kindHit := InStr(StrLower(data.Display " " kindNames[kindIdx]), queryText)
                if kindHit {
                    display := data.Display
                    kind := kindNames[kindIdx]
                    ; v13.17: исключённое показываем целиком, без масок.
                    AddGlobalRow(kind, display, "частота: " data.Count, (InStr(kind, "Основа") ? "STEM" : "WORD"), key, display)
                    added += 1
                }
            }
        }

        for key, data in PhraseDB {
            if (added >= maxResults)
                break
            ; v13.20: текст фразы и так однострочный (SanitizePhraseText), ключ —
            ; он же в нижнем регистре: без RegExReplace и StrLower на каждую фразу.
            if InStr(key, queryText) {
                kind := (data.HasOwnProp("Hidden") && data.Hidden) ? "Фраза скрыта" : "Фраза"
                AddGlobalRow(kind, data.Text, "использований: " data.Count, "PHRASE", data.Text, data.Text)
                added += 1
            }
        }

        for key, data in PromptDB {
            if (added >= maxResults)
                break
            if PanelSearchMatch(key, data.Text, queryText, queryHasSpace) { ; v13.20
                kind := (data.HasOwnProp("Hidden") && data.Hidden) ? "Промпт скрыт" : "Промпт"
                AddGlobalRow(kind, BuildPanelListPreview(data.Text), "использований: " data.Count, "PROMPT", data.Text, data.Text)
                added += 1
            }
        }
    }

    for id, data in LinkDB {
        if (added >= maxResults)
            break
        title := data.Title != "" ? data.Title : GuessLinkTitleFromUrl(data.Url)
        aliasBlob := StrLower(title " " data.Tags)
        fullBlob := GetLinkSearchBlob(data)
        if (aliasOnly ? InStr(aliasBlob, queryText) : InStr(fullBlob, queryText)) {
            kind := data.Hidden ? "Ссылка скрыта" : "Ссылка"
            note := BuildLinkListNote(data)
            full := title "`n" data.Url
            if (note != "")
                full .= "`n" note
            AddGlobalRow(kind, title " — " data.Url, "использований: " data.Count, "LINK", id, full)
            added += 1
        }
    }

    for id, data in DataDB {
        if (added >= maxResults)
            break
        title := data.Key != "" ? data.Key : (data.Login != "" ? data.Login : "[данные]")
        aliasBlob := StrLower(data.Key)
        fullBlob := StrLower(GetDataSearchBlob(data))
        if (aliasOnly ? InStr(aliasBlob, queryText) : InStr(fullBlob, queryText)) {
            details := (data.Login != "" ? "login: " data.Login : "")
            if (data.Note != "")
                details .= (details != "" ? "`n" : "") data.Note
            AddGlobalRow(data.IsPile ? "Данные свалка" : ((data.HasOwnProp("AutoInsert") && data.AutoInsert) ? "Данные авто" : "Данные"), title, "использований: " data.Count, "DATA", id, BuildDataPanelPreviewText(data))
            added += 1
        }
    }

    for id, data in HotInsertDB {
        if (added >= maxResults)
            break
        preview := RegExReplace(data.Text, "\s+", " ")
        aliasBlob := StrLower(data.Label)
        fullBlob := StrLower(data.Label " " data.Combo " " preview)
        if (aliasOnly ? InStr(aliasBlob, queryText) : InStr(fullBlob, queryText)) {
            AddGlobalRow("Горячее", data.Label " — " data.Combo " — " preview, "", "HOTKEY", id, data.Label "`n" data.Combo "`n" data.Text)
            added += 1
        }
    }

    if (added = 0)
        AddGlobalRow("—", aliasOnly ? "По алиасам ничего не найдено" : "Ничего не найдено", "", "", "", "Попробуй другое слово, домен, тег, алиас или часть текста.")

    ; v13.20: колонки здесь больше не переставляются (см. StretchGlobalSearchLastColumn).
    UpdateGlobalDeleteButtonState()
}

HidePanelPreviewOsd(*) {
    global DictPanelPreviewGui, DictPanelPreviewLastKey
    DictPanelPreviewLastKey := ""
    ; v13.20: Hide — только видимой плашке: наблюдатель вызывает это на каждом
    ; тике, пока курсор вне списков.
    if !IsObject(DictPanelPreviewGui)
        return
    try {
        if DllCall("User32\IsWindowVisible", "Ptr", DictPanelPreviewGui.Hwnd)
            DictPanelPreviewGui.Hide()
    }
}

CreatePanelPreviewOsd() {
    ; v13.19: плашка полного текста переделана.
    ; - Прозрачна для мыши (layered + WS_EX_TRANSPARENT) и не активируется:
    ;   раньше окно перехватывало курсор, если тот на него попадал, и плашка
    ;   мигала (под курсором оказывался не список → скрыть → снова показать).
    ; - Без полосы прокрутки: прокрутить её всё равно было нельзя.
    ; - Размер подстраивается под текст (см. ShowPanelPreviewOsd), координаты
    ;   в физических пикселях (-DPIScale) — раньше на 125–150 % окно было больше,
    ;   чем считала проверка края экрана, и вылезало за край.
    ; - Рамка своя, тонкая. v13.20: нейтрально-серая — акцентная (зелёная)
    ;   рамка из 13.19 спорила с выделением строки и была лишней.
    global DictPanelPreviewGui, DictPanelPreviewEdit, DictPanelPreviewFooter, DictPanelPreviewBorders
    global DictPanelPreviewMono
    if IsObject(DictPanelPreviewGui)
        return
    PreviewGui := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale +E0x80000 +E0x20 +E0x08000000", "TyperPanelPreview")
    PreviewGui.BackColor := "202020"
    PreviewGui.MarginX := 0, PreviewGui.MarginY := 0
    PreviewGui.SetFont("s10 cE6E6E6", "Segoe UI")
    DictPanelPreviewEdit := PreviewGui.Add("Edit", "x12 y10 w600 h20 +Multi ReadOnly -Tabstop -E0x200 -VScroll Background202020 cE6E6E6", "")
    DictPanelPreviewMono := 0
    PreviewGui.SetFont("s8 c8C8C8C", "Segoe UI")
    DictPanelPreviewFooter := PreviewGui.Add("Text", "x12 y40 w600 h16 Hidden Background202020", "")
    DictPanelPreviewBorders := []
    Loop 4
        DictPanelPreviewBorders.Push(PreviewGui.Add("Text", "x0 y0 w1 h1 Background3C3C3C", ""))
    ; Layered-окно невидимо, пока ему не задана прозрачность, — задаём сразу.
    try DllCall("User32\SetLayeredWindowAttributes", "Ptr", PreviewGui.Hwnd, "UInt", 0, "UChar", 242, "UInt", 2) ; LWA_ALPHA
    DictPanelPreviewGui := PreviewGui
}

SetPanelPreviewFont(mono) {
    ; Consolas — для Данных (логины/пароли: 0/O и l/1 различимы), остальное —
    ; Segoe UI: в нём длинный промпт читается заметно легче.
    global DictPanelPreviewEdit, DictPanelPreviewMono
    mono := mono ? 1 : 0
    if (DictPanelPreviewMono = mono)
        return
    try DictPanelPreviewEdit.SetFont("s10 cE6E6E6", mono ? "Consolas" : "Segoe UI")
    DictPanelPreviewMono := mono
}

GetPanelPreviewLineHeight(mono) {
    ; Высота строки Edit = tmHeight его шрифта (так считает сам Edit).
    global DictPanelPreviewEdit
    static cache := Map()
    k := mono ? 1 : 0
    if cache.Has(k)
        return cache[k]
    h := 0
    try {
        hwnd := DictPanelPreviewEdit.Hwnd
        hFont := DllCall("User32\SendMessageW", "Ptr", hwnd, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "Ptr") ; WM_GETFONT
        hdc := DllCall("User32\GetDC", "Ptr", hwnd, "Ptr")
        if hdc {
            old := hFont ? DllCall("Gdi32\SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr") : 0
            tm := Buffer(64, 0)
            if DllCall("Gdi32\GetTextMetricsW", "Ptr", hdc, "Ptr", tm)
                h := NumGet(tm, 0, "Int")
            if old
                DllCall("Gdi32\SelectObject", "Ptr", hdc, "Ptr", old, "Ptr")
            DllCall("User32\ReleaseDC", "Ptr", hwnd, "Ptr", hdc)
        }
    }
    if (h < 8)
        return Round(18 * A_ScreenDPI / 96) ; запасной вариант, не кэшируем
    cache[k] := h
    return h
}

GetWorkAreaAtPoint(x, y) {
    ; Рабочая область монитора под точкой (раньше всегда брался основной монитор,
    ; и на втором экране плашку «прижимало» не к тому краю).
    static mi := Buffer(40, 0)
    try {
        if (A_PtrSize = 8)
            hMon := DllCall("User32\MonitorFromPoint", "Int64", (y << 32) | (x & 0xFFFFFFFF), "UInt", 2, "Ptr")
        else
            hMon := DllCall("User32\MonitorFromPoint", "Int", x, "Int", y, "UInt", 2, "Ptr")
        if hMon {
            NumPut("UInt", 40, mi, 0)
            if DllCall("User32\GetMonitorInfoW", "Ptr", hMon, "Ptr", mi)
                return {L: NumGet(mi, 20, "Int"), T: NumGet(mi, 24, "Int"), R: NumGet(mi, 28, "Int"), B: NumGet(mi, 32, "Int")}
        }
    }
    try {
        MonitorGetWorkArea(MonitorGetPrimary(), &wl, &wt, &wr, &wb)
        return {L: wl, T: wt, R: wr, B: wb}
    }
    return {L: 0, T: 0, R: A_ScreenWidth, B: A_ScreenHeight}
}

GetListViewHoverInfo(lv) {
    ; Координаты берём напрямую из Windows, а не из MouseGetPos/CoordMode.
    ; Иначе при разных CoordMode мышь может давать координаты окна, а ScreenToClient
    ; получает их как экранные — из-за этого preview показывался на сотни пикселей ниже/правее.
    try {
        pt := Buffer(8, 0)
        if !DllCall("User32\GetCursorPos", "Ptr", pt.Ptr)
            return 0
        mx := NumGet(pt, 0, "Int")
        my := NumGet(pt, 4, "Int")

        rc := Buffer(16, 0)
        if !DllCall("User32\GetWindowRect", "Ptr", lv.Hwnd, "Ptr", rc.Ptr)
            return 0
        left := NumGet(rc, 0, "Int"), top := NumGet(rc, 4, "Int")
        right := NumGet(rc, 8, "Int"), bottom := NumGet(rc, 12, "Int")
        if (mx < left || mx >= right || my < top || my >= bottom)
            return 0

        ; Важно: координата может совпадать с прямоугольником скрытой/неактивной панели,
        ; но верхним окном под курсором уже будет браузер или другое приложение.
        ; Поэтому проверяем реальный HWND под курсором, а не только геометрию ListView.
        try {
            MouseGetPos(, , &underWin, &underCtrl, 2)
            if (underCtrl != lv.Hwnd && underWin != lv.Hwnd)
                return 0
        } catch {
            return 0
        }

        ptClient := Buffer(8, 0)
        NumPut("Int", mx, ptClient, 0)
        NumPut("Int", my, ptClient, 4)
        if !DllCall("User32\ScreenToClient", "Ptr", lv.Hwnd, "Ptr", ptClient.Ptr)
            return 0
        cx := NumGet(ptClient, 0, "Int")
        cy := NumGet(ptClient, 4, "Int")
        if (cx < 0 || cy < 0)
            return 0

        ht := Buffer(32, 0)
        NumPut("Int", cx, ht, 0)
        NumPut("Int", cy, ht, 4)
        ret := DllCall("User32\SendMessageW", "Ptr", lv.Hwnd, "UInt", 0x1039, "Ptr", 0, "Ptr", ht.Ptr, "Ptr") ; LVM_SUBITEMHITTEST
        rowIndex := Integer(ret) + 1
        if (rowIndex <= 0 || rowIndex > lv.GetCount())
            return 0
        return {Row: rowIndex, X: mx, Y: my}
    } catch {
        return 0
    }
}

GetVisiblePanelListViews() {
    ; Preview нужен только для длинных фраз/промптов/ссылок и для результатов общего поиска.
    ; Обычные слова и горячие вставки не показываем, чтобы не плодить шум.
    ; v13.17: + «Исключённые» — там длинные записи теперь видны целиком в превью.
    global LV_Phrases, LV_Prompts, LV_Links, LV_Data, LV_GlobalSearch, LV_Hidden
    views := []
    try views.Push({Name:"GLOBAL", LV:LV_GlobalSearch})
    try views.Push({Name:"PHRASES", LV:LV_Phrases})
    try views.Push({Name:"PROMPTS", LV:LV_Prompts})
    try views.Push({Name:"LINKS", LV:LV_Links})
    try views.Push({Name:"DATA", LV:LV_Data})
    try views.Push({Name:"HIDDEN", LV:LV_Hidden})
    return views
}

GetHoveredPanelListViewInfo(mx := "", my := "") {
    ; v13.20: сначала одно WindowFromPoint — какой контрол под курсором, и
    ; hit-test только того списка, что под ним. Раньше каждый тик опрашивал
    ; все 6 списков (Visible, GetWindowRect, MouseGetPos), даже когда курсор
    ; был над кнопками или полем поиска. Над шапкой колонок WindowFromPoint
    ; возвращает саму шапку (не список) — плашки там и не должно быть.
    if (mx = "" || my = "") {
        pt := Buffer(8, 0)
        if !DllCall("User32\GetCursorPos", "Ptr", pt.Ptr)
            return 0
        mx := NumGet(pt, 0, "Int"), my := NumGet(pt, 4, "Int")
    }
    underHwnd := 0
    try underHwnd := DllCall("User32\WindowFromPoint", "Int64", (my << 32) | (mx & 0xFFFFFFFF), "Ptr")
    if !underHwnd
        return 0
    for item in GetVisiblePanelListViews() {
        lvHwnd := 0
        try lvHwnd := item.LV.Hwnd
        if (!lvHwnd || lvHwnd != underHwnd)
            continue
        try {
            if !item.LV.Visible
                return 0
            info := GetListViewHoverInfo(item.LV)
            if IsObject(info)
                return {Name:item.Name, LV:item.LV, Row:info.Row, X:info.X, Y:info.Y}
        }
        return 0
    }
    return 0
}

GetPanelRowFullText(viewName, lv, row) {
    global DictGlobalFullTextMap, DictPromptRowText, DictDataRowIdMap, DataDB, DictHiddenRowRefs
    try {
        if (viewName = "GLOBAL") {
            return DictGlobalFullTextMap.Has(row) ? DictGlobalFullTextMap[row] : lv.GetText(row, 2)
        } else if (viewName = "PROMPTS") {
            return DictPromptRowText.Has(row) ? DictPromptRowText[row] : lv.GetText(row, 1)
        } else if (viewName = "PHRASES") {
            return lv.GetText(row, 1)
        } else if (viewName = "LINKS") {
            title := lv.GetText(row, 1)
            url := lv.GetText(row, 2)
            note := lv.GetText(row, 3)
            out := title
            if (url != "")
                out .= "`n" url
            if (note != "")
                out .= "`n" note
            return out
        } else if (viewName = "DATA") {
            ; Сначала скрытая колонка ID: она переезжает вместе со строкой при ручной
            ; сортировке по заголовку, поэтому наведение показывает актуальную карточку.
            ; а не то, что было в этой позиции до сортировки.
            rowId := ""
            try rowId := lv.GetText(row, 5)
            if (rowId != "" && DataDB.Has(rowId))
                return BuildDataPanelPreviewText(DataDB[rowId])
            if DictDataRowIdMap.Has(row) && DataDB.Has(DictDataRowIdMap[row])
                return BuildDataPanelPreviewText(DataDB[DictDataRowIdMap[row]])
            return lv.GetText(row, 1)
        } else if (viewName = "HIDDEN") {
            ; v13.17: полный текст исключённой записи (в списке — плоское превью).
            ref := ""
            try ref := lv.GetText(row, 3)
            if (ref != "" && DictHiddenRowRefs.Has(ref))
                return DictHiddenRowRefs[ref].Text
            return lv.GetText(row, 1)
        }
        return lv.GetText(row, 1)
    } catch {
        return ""
    }
}

ListViewColumnTextOverflows(lv, row, col) {
    try {
        text := lv.GetText(row, col)
        if (Trim(text) = "")
            return false
        colW := GetListViewColumnWidth(lv, col)
        if (colW <= 28)
            return false
        ; Быстрые пути без GDI-замера: очень длинный текст заведомо не влезает
        ; (минимум ~4px на символ), очень короткий — заведомо влезает (максимум
        ; ~14px). Точный замер остаётся только для пограничной серой зоны, и в
        ; него никогда не попадает целый промпт на тысячи символов.
        textLen := StrLen(text)
        if (textLen * 4 > colW)
            return true
        if (textLen * 14 <= colW - 24)
            return false
        flat := RegExReplace(text, "\s+", " ")
        return MeasureTextWidthPx(flat, "Segoe UI", 10) > (colW - 24) ; v13.20: шрифт списков панели — s10 (мерилось 9 → «влезает», хотя не влезало)
    } catch {
        return false
    }
}

AppendDataPreviewLine(&outRef, label, value) {
    value := SanitizeDataField(value, true)
    if (value = "")
        return
    while (StrLen(label) < 12)
        label .= " "
    outRef .= label value "`n"
}

BuildDataPanelPreviewText(data) {
    global DataPasswordsHidden
    out := ""

    AppendDataPreviewLine(&out, "Префикс", data.Key)
    AppendDataPreviewLine(&out, "Логин", data.Login)
    AppendDataPreviewLine(&out, "Пароль", (DataPasswordsHidden && data.Password != "") ? "••••••" : data.Password)
    AppendDataPreviewLine(&out, "Алиасы", data.Aliases)
    AppendDataPreviewLine(&out, "Описание", data.Note)

    mode := ""
    if (data.HasOwnProp("AutoInsert") && data.AutoInsert)
        mode := "автовставка по *" data.Key
    else if data.IsPile
        mode := "свалка / обычный выбор"
    else
        mode := "обычная карточка"
    AppendDataPreviewLine(&out, "Режим", mode)
    AppendDataPreviewLine(&out, "Исп.", data.Count)
    return RTrim(out, "`n")
}

PanelPreviewShouldShow(viewName, lv, row, fullText) {
    if (Trim(fullText) = "")
        return false

    if (viewName = "GLOBAL") {
        typeText := lv.GetText(row, 1)
        isPhrase := InStr(typeText, "Фраз")
        isPrompt := InStr(typeText, "Промпт")
        isLink := InStr(typeText, "Ссылка")
        isData := InStr(typeText, "Данные")
        if (!isPhrase && !isPrompt && !isLink && !isData)
            return false
        if InStr(fullText, "`n")
            return true
        if (fullText != lv.GetText(row, 2))
            return true
        return ListViewColumnTextOverflows(lv, row, 2)
    }

    if (viewName = "PHRASES")
        return InStr(fullText, "`n") || ListViewColumnTextOverflows(lv, row, 1)

    if (viewName = "PROMPTS")
        return InStr(fullText, "`n") || ListViewColumnTextOverflows(lv, row, 1)

    if (viewName = "LINKS") {
        ; Для ссылок показываем preview только если не влезло одно из видимых полей.
        overflow := ListViewColumnTextOverflows(lv, row, 1)
        if !overflow
            overflow := ListViewColumnTextOverflows(lv, row, 2)
        if !overflow
            overflow := ListViewColumnTextOverflows(lv, row, 3)
        return overflow
    }

    if (viewName = "DATA")
        return InStr(fullText, "`n")

    if (viewName = "HIDDEN") ; v13.17
        return InStr(fullText, "`n") || (fullText != lv.GetText(row, 1)) || ListViewColumnTextOverflows(lv, row, 1)

    return false
}

FormatPanelPreviewText(text, maxChars := 3000) {
    ; Не вставляем искусственные переносы каждые N символов: Edit-контрол сам
    ; переносит по ширине. Ручной разрез строки мог ломать слово посередине
    ; (например: "пр" / "едельно").
    text := Trim(text)
    if (StrLen(text) > maxChars)
        text := SubStr(text, 1, maxChars) "`n…"
    return text
}

ShowPanelPreviewOsd(text, x, y, mono := false) {
    ; v13.19: ширина — по самой длинной строке (короткий текст → узкая плашка),
    ; высота — по реальному числу строк после переноса (EM_GETLINECOUNT), но не
    ; больше ~55 % высоты экрана; если текст не влез — внизу «… ещё строк: N».
    ; Раньше было фиксированное окно 680×126 (≈7 строк) с бесполезным скроллом.
    global DictPanelPreviewGui, DictPanelPreviewEdit, DictPanelPreviewFooter, DictPanelPreviewBorders
    CreatePanelPreviewOsd()
    text := FormatPanelPreviewText(text)
    if (text = "") {
        HidePanelPreviewOsd()
        return
    }
    SetPanelPreviewFont(mono)
    s := A_ScreenDPI / 96
    padX := Round(12 * s), padY := Round(9 * s)
    previewFace := mono ? "Consolas" : "Segoe UI"
    wa := GetWorkAreaAtPoint(x, y)

    maxEditW := Max(Round(160 * s), Min(Round(640 * s), (wa.R - wa.L) - 2 * padX - Round(40 * s)))
    minEditW := Min(Round(200 * s), maxEditW)
    editW := maxEditW
    if (StrLen(text) <= 900) {
        widest := 0
        for _, ln in StrSplit(text, "`n", "`r") {
            if (ln = "")
                continue
            lw := MeasureTextWidthPx(StrReplace(ln, "`t", "        "), previewFace, 10)
            if (lw > widest)
                widest := lw
            if (widest >= maxEditW)
                break
        }
        editW := Max(minEditW, Min(maxEditW, widest + Round(10 * s)))
    }

    lineH := GetPanelPreviewLineHeight(mono)
    maxLines := Max(4, Min(28, Floor(((wa.B - wa.T) * 0.55) / lineH)))
    try {
        DictPanelPreviewEdit.Move(padX, padY, editW, lineH * maxLines + 2)
        DictPanelPreviewEdit.Value := text
    }
    total := 1
    try total := DllCall("User32\SendMessageW", "Ptr", DictPanelPreviewEdit.Hwnd, "UInt", 0xBA, "Ptr", 0, "Ptr", 0, "Ptr") ; EM_GETLINECOUNT
    total := Max(1, total)
    shown := Min(total, maxLines)
    editH := shown * lineH + 2
    try DictPanelPreviewEdit.Move(padX, padY, editW, editH)

    footerH := 0
    if (total > shown) {
        footerH := Round(18 * s)
        try {
            DictPanelPreviewFooter.Text := "… ещё строк: " (total - shown)
            DictPanelPreviewFooter.Move(padX, padY + editH + Round(3 * s), editW, footerH)
            DictPanelPreviewFooter.Visible := true
        }
        footerH += Round(3 * s)
    } else {
        try DictPanelPreviewFooter.Visible := false
    }

    w := editW + 2 * padX
    h := padY + editH + footerH + padY
    try {
        DictPanelPreviewBorders[1].Move(0, 0, w, 1)
        DictPanelPreviewBorders[2].Move(0, h - 1, w, 1)
        DictPanelPreviewBorders[3].Move(0, 0, 1, h)
        DictPanelPreviewBorders[4].Move(w - 1, 0, 1, h)
    }

    px := x + Round(16 * s)
    py := y + Round(20 * s)
    if (px + w > wa.R - 8)
        px := wa.R - w - 8
    if (py + h > wa.B - 8)
        py := y - h - Round(12 * s) ; снизу не влезает — над курсором
    if (px < wa.L + 8)
        px := wa.L + 8
    if (py < wa.T + 8)
        py := wa.T + 8

    ; Show с NA и для видимого окна: только сдвиг/размер, без активации и без
    ; скрытия — переход между строками не мигает.
    try DictPanelPreviewGui.Show("NA x" px " y" py " w" w " h" h)
}

WatchDictionaryPanelPreview() {
    ; Лёгкий наблюдатель наведения (таймер 40 мс). Принципы, чтобы никогда
    ; не подвешивать скрипт: (1) защита от повторного входа — если предыдущий
    ; тик ещё работает, новый молча выходит; (2) никакой тяжёлой работы, пока
    ; курсор стоит на той же строке (ключ не изменился); (3) всё в try.
    ; v13.20: плашка показывается сразу (пауза 320 мс из 13.19 убрана). Пока
    ; мышь неподвижна, тик заканчивается после одного GetCursorPos: плашка не
    ; всплывает сама по себе, когда список меняется под стоящим курсором (набор
    ; в поиске), а видимая раз в 250 мс сверяется со строкой под курсором
    ; (список могли прокрутить клавиатурой).
    static busy := false, lastX := -99999, lastY := -99999, lastFullTick := 0
    static cursorPt := Buffer(8, 0)
    global DictPanelGui, DictPanelPreviewGui, DictPanelPreviewLastKey, PanelWheelLastTick, DictGlobalResultMap
    if busy
        return
    ; Во время прокрутки колесом не трогаем список вообще: каждый SendMessage
    ; (hit-test, GetText) синхронно гонит сообщение через сабкласс-колбэк
    ; вложенно в поток таймера — в шторм сообщений скролла это лишний риск.
    if (A_TickCount - PanelWheelLastTick < 250) {
        HidePanelPreviewOsd()
        lastX := -99999 ; после прокрутки — полная проверка строки под курсором
        return
    }
    ; Зажата ЛКМ — пользователь тащит ползунок скролл-бара, ширину колонки
    ; или выделение. Перетаскивание ползунка вводит окно в модальный цикл
    ; отслеживания мыши, и синхронные SendMessage списку из таймера в этот
    ; момент — прямой путь к зависанию (воспроизводилось быстрым драгом
    ; скролл-бара в разделе Слова). Колёсная защита выше это не покрывает.
    if GetKeyState("LButton", "P") {
        HidePanelPreviewOsd()
        lastX := -99999
        return
    }
    busy := true
    try {
        panelHwnd := 0
        try panelHwnd := DictPanelGui.Hwnd
        if (!panelHwnd || !WinExist("ahk_id " panelHwnd)) {
            HidePanelPreviewOsd()
            return
        }
        try {
            if (WinGetMinMax("ahk_id " panelHwnd) = -1) {
                HidePanelPreviewOsd()
                return
            }
        }
        ; Preview показываем только когда сама панель активна. Иначе при
        ; совпадении координат плашка всплывала бы поверх других приложений.
        if !WinActive("ahk_id " panelHwnd) {
            HidePanelPreviewOsd()
            return
        }

        if !DllCall("User32\GetCursorPos", "Ptr", cursorPt.Ptr)
            return
        cx := NumGet(cursorPt, 0, "Int"), cy := NumGet(cursorPt, 4, "Int")
        if (cx = lastX && cy = lastY) {
            previewShown := false
            try previewShown := DllCall("User32\IsWindowVisible", "Ptr", DictPanelPreviewGui.Hwnd)
            if (!previewShown || A_TickCount - lastFullTick < 250)
                return
        }
        lastX := cx, lastY := cy
        lastFullTick := A_TickCount

        info := GetHoveredPanelListViewInfo(cx, cy)
        if !IsObject(info) {
            HidePanelPreviewOsd()
            return
        }

        ; Ключ строим ДО извлечения полного текста: пока курсор на той же
        ; строке — ни чтения текста, ни замеров, ни обновления Edit.
        key := info.Name ":" info.Row
        if (key = DictPanelPreviewLastKey)
            return

        fullText := GetPanelRowFullText(info.Name, info.LV, info.Row)
        if !PanelPreviewShouldShow(info.Name, info.LV, info.Row, fullText) {
            HidePanelPreviewOsd()
            DictPanelPreviewLastKey := key
            return
        }

        mono := (info.Name = "DATA")
        if (!mono && info.Name = "GLOBAL" && DictGlobalResultMap.Has(info.Row)) {
            gItem := DictGlobalResultMap[info.Row]
            mono := IsObject(gItem) && gItem.HasOwnProp("Kind") && (gItem.Kind = "DATA")
        }
        ShowPanelPreviewOsd(fullText, info.X, info.Y, mono)
        DictPanelPreviewLastKey := key
    } finally {
        busy := false
    }
}

RestoreListViewRow(lv, preferredRow) {
    try {
        count := lv.GetCount()
        if (count <= 0)
            return
        row := preferredRow
        if (row < 1)
            row := 1
        if (row > count)
            row := count
        lv.Modify(0, "-Select")
        ; Без Vis: при прямом удалении строки ListView сам сохраняет прокрутку,
        ; а принудительное EnsureVisible/Vis может раздражающе дёргать список.
        lv.Modify(row, "Select Focus")
    }
}

DeleteListViewRowPreservePlace(lv, row) {
    ; v13.17: другие вкладки строятся лениво — после удаления/возврата строки
    ; помечаем их устаревшими, чтобы при открытии они перечитали базы.
    global DictActiveView
    try MarkDictViewsDirty(DictActiveView)
    try {
        if (row < 1)
            return
        lv.Delete(row)
        RestoreListViewRow(lv, row)
    }
}

ShiftRowMapAfterDelete(rowMap, deletedRow) {
    newMap := Map()
    try {
        for row, value in rowMap {
            if (row < deletedRow)
                newMap[row] := value
            else if (row > deletedRow)
                newMap[row - 1] := value
        }
    }
    return newMap
}

UpdateGlobalDeleteButtonState(*) {
    global LV_GlobalSearch, DictGlobalDeleteBtn, DictGlobalResultMap, DictGlobalDeleteBtnState
    canDelete := false
    try {
        row := LV_GlobalSearch.GetNext(0)
        if (row && DictGlobalResultMap.Has(row)) {
            kind := DictGlobalResultMap[row].Kind
            canDelete := (kind = "PHRASE" || kind = "PROMPT" || kind = "LINK" || kind = "DATA" || kind = "HOTKEY" || kind = "WORD" || kind = "STEM")
        }
    }
    ; v13.20: перекраска — только при смене состояния. ItemSelect приходит на
    ; каждый клик дважды (снятие выделения + новое), и раньше кнопка каждый раз
    ; перекрашивалась (Opt с цветом = перерисовка), даже оставаясь такой же.
    wantState := canDelete ? 1 : 0
    if (wantState = DictGlobalDeleteBtnState)
        return
    try {
        if canDelete
            DictGlobalDeleteBtn.Opt("-Disabled cF0F0F0")
        else
            DictGlobalDeleteBtn.Opt("Disabled c808080")
        DictGlobalDeleteBtnState := wantState
    }
}

DeleteSelectedGlobalSearchResult(*) {
    global LV_GlobalSearch, DictGlobalResultMap, DictGlobalFullTextMap, WordDB, PhraseDB, PromptDB, LinkDB, DataDB, HotInsertDB, RegisteredHotInsertCombos, HotInsertCallbacks, DictGlobalSearchEdit
    row := 0
    try row := LV_GlobalSearch.GetNext(0)
    if !row || !DictGlobalResultMap.Has(row)
        return

    item := DictGlobalResultMap[row]
    deleted := false

    if (item.Kind = "PHRASE") {
        itemKey := StrLower(item.Key)
        if PhraseDB.Has(itemKey) {
            PhraseDB.Delete(itemKey)
            RemovePhraseFromIndexes(itemKey)
            SavePhrasesInternal()
            deleted := true
        }
    } else if (item.Kind = "PROMPT") {
        itemKey := StrLower(item.Key)
        if PromptDB.Has(itemKey) {
            PromptDB.Delete(itemKey)
            RemovePromptFromIndexes(itemKey)
            SavePromptsInternal()
            deleted := true
        }
    } else if (item.Kind = "LINK") {
        if LinkDB.Has(item.Key) {
            LinkDB.Delete(item.Key)
            RemoveLinkFromIndexes(item.Key)
            SaveLinksInternal()
            deleted := true
        }
    } else if (item.Kind = "DATA") {
        if DataDB.Has(item.Key) {
            DataDB.Delete(item.Key)
            RemoveDataFromIndexes(item.Key)
            QueueDataSave()
            deleted := true
        }
    } else if (item.Kind = "HOTKEY") {
        if HotInsertDB.Has(item.Key) {
            UnregisterHotInsertEntry(item.Key)
            HotInsertDB.Delete(item.Key)
            SaveHotInsertsInternal()
            deleted := true
        }
    } else if (item.Kind = "WORD" || item.Kind = "STEM") {
        if WordDB.Has(item.Key) {
            WordDB.Delete(item.Key)
            RemoveWordFromPrefixIndexes(item.Key)
            ; v13.20: словарь — самая большая база; полное перешифрование прямо в
            ; клике подвешивало панель. Отложенно и одним разом на серию удалений.
            SetTimer(SaveDictionary, -2000)
            deleted := true
        }
    }

    if !deleted {
        ToolTip("⚠️ Не удалось удалить: запись не найдена")
        SetTimer(() => ToolTip(), -1200)
        return
    }

    HidePanelPreviewOsd()
    DeleteListViewRowPreservePlace(LV_GlobalSearch, row)
    DictGlobalResultMap := ShiftRowMapAfterDelete(DictGlobalResultMap, row)
    DictGlobalFullTextMap := ShiftRowMapAfterDelete(DictGlobalFullTextMap, row)
    UpdateGlobalDeleteButtonState()
    ToolTip("🗑️ Удалено")
    SetTimer(() => ToolTip(), -900)
}

DeleteFromDictionaryPanelHotkey(*) {
    global DictActiveView, DictGlobalSearchEdit
    try {
        if (DictActiveView = "HOME" && Trim(DictGlobalSearchEdit.Value) != "") {
            DeleteSelectedGlobalSearchResult()
            return
        }
    }
    DeleteWordFromDict(0)
}

OpenSelectedGlobalSearchResult(guiObj, *) {
    global LV_GlobalSearch, DictGlobalResultMap, DictActiveView, DictSearchEdit

    row := LV_GlobalSearch.GetNext(0)
    if !row || !DictGlobalResultMap.Has(row)
        return

    item := DictGlobalResultMap[row]
    if (item.Kind = "PHRASE") {
        ShowPhraseEditGui(item.Key, Map("InsertAfterSave", false))
    } else if (item.Kind = "PROMPT") {
        ShowPromptEditGui(item.Key)
    } else if (item.Kind = "LINK") {
        ShowLinkCaptureGui("", item.Key)
    } else if (item.Kind = "DATA") {
        OpenDataCardGui(item.Key)
    } else if (item.Kind = "HOTKEY") {
        ShowHotInsertEditGui(item.Key)
    } else if (item.Kind = "WORD") {
        DictActiveView := "WORDS"
        try DictSearchEdit.Value := item.Key
        PopulateDictListView()
        UpdateDictionaryViewUi()
    } else if (item.Kind = "STEM") {
        DictActiveView := "STEMS"
        try DictSearchEdit.Value := item.Key
        PopulateDictListView()
        UpdateDictionaryViewUi()
    }
}

SwitchDictionaryView(viewName) {
    global DictActiveView
    DictActiveView := viewName
    UpdateDictionaryViewUi()
}

UpdateDictionaryViewUi() {
    global DictActiveView, DictPanelGui, LV_Words, LV_Stems, LV_Phrases, LV_Prompts, LV_Links, LV_Data, LV_Hidden, LV_Hotkeys, LV_GlobalSearch, DictHelpEdit, DictSettingsPanel, DictInfoTitle
    global DictTabHome, DictTabWords, DictTabStems, DictTabPhrases, DictTabPrompts, DictTabLinks, DictTabData, DictTabHotkeys, DictTabHidden, DictTabSettings
    global DictBtnRestore, DictHintText, DictBtnDelete, DictBtnPruneWords, DictBtnEditPhrase, DictBtnEditLink, DictBtnEditData, DictBtnAddData, DictBtnAddLink, DictBtnAssignPhraseHotkey, DictBtnAddHotkey, DictBtnEditHotkey, DictDataPileSelect
    global DictSearchLabel, DictSearchEdit, DictSearchClear, DictGlobalSearchLabel, DictGlobalSearchEdit, DictGlobalSearchClear, DictShowFrequencyCheck, DictIncludeWordsCheck, DictGlobalDeleteBtn, ColorHighlight
    global TyperStartupComplete, PanelPromptClickCopy
    global DictLoadSpin, DictLoadTitle, DictLoadStage, DictLoadBarFill, DictLoadBarRest, DictLoadHint
    global DictMode ; v13.18
    global DictViewUiSig, DictTabStyleState ; v13.20
    global DictPromptCatChips, DictPromptToolButtons, DictBtnClose ; v13.21

    ; v13.17: вкладка строится лениво — при первом показе или если устарела.
    EnsureDictViewPopulated(DictActiveView)

    showHome := (DictActiveView = "HOME")
    showWords := (DictActiveView = "WORDS")
    showStems := (DictActiveView = "STEMS")
    showPhrases := (DictActiveView = "PHRASES")
    showPrompts := (DictActiveView = "PROMPTS")
    showLinks := (DictActiveView = "LINKS")
    showData := (DictActiveView = "DATA")
    showHotkeys := (DictActiveView = "HOTKEYS")
    showHidden := (DictActiveView = "HIDDEN")
    showSettings := (DictActiveView = "SETTINGS")

    panelHwnd := 0
    try panelHwnd := DictPanelGui.Hwnd

    globalSearchText := ""
    try globalSearchText := Trim(DictGlobalSearchEdit.Value)
    showGlobalSearchResults := showHome && (globalSearchText != "")

    ; v13.17: пока базы расшифровываются, списки пустые — вместо них крупный
    ; индикатор расшифровки (справка и настройки доступны сразу).
    listsReady := TyperStartupComplete ? true : false

    ; v13.20: ГЛАВНАЯ ПРИЧИНА МЕРЦАНИЯ ПРИ ПОИСКЕ. Эта функция вызывается после
    ; КАЖДОГО обновления поиска (пауза в наборе), и раньше каждый раз заново
    ; раскладывала всё окно: ~80 переключений Visible, перекраска всех 10
    ; кнопок разделов, временный WS_EX_COMPOSITED и полная перерисовка окна с
    ; RDW_ERASE — то есть панель целиком перерисовывалась на каждое слово в
    ; поиске. Теперь раскладка зависит от «подписи» (раздел, видны ли
    ; результаты общего поиска, готовы ли базы, режим словаря, подсказка, цвет,
    ; само окно); если подпись не изменилась — меняется только список
    ; (его перестраивает вызывающий), а здесь — лишь значения настроек и
    ; кнопка «Удалить» общего поиска, и только если они отличаются.
    sig := panelHwnd . "|" . DictActiveView . "|" . (showGlobalSearchResults ? 1 : 0) . "|" . (listsReady ? 1 : 0)
        . "|" . DictMode . "|" . (PanelPromptClickCopy ? 1 : 0) . "|" . ColorHighlight
    if (panelHwnd && sig = DictViewUiSig) {
        SyncDictSettingsControls(showSettings)
        if (showGlobalSearchResults && listsReady)
            UpdateGlobalDeleteButtonState()
        return
    }

    ; Анти-моргание при переключении разделов: десятки Visible-переключений
    ; ниже перерисовывали окно после каждого. WM_SETREDRAW(0) замораживает
    ; отрисовку, а в конце окно инвалидируется целиком — один кадр вместо
    ; каскада промежуточных.
    if panelHwnd {
        ; WS_EX_COMPOSITED включается ТОЛЬКО на время перестройки: постоянный
        ; composited заставлял всё окно перерисовываться при каждом hot-track
        ; движении мыши над шапками колонок (моргали заголовки).
        DllCall("User32\SetWindowLongPtrW", "Ptr", panelHwnd, "Int", -20
            , "Ptr", DllCall("User32\GetWindowLongPtrW", "Ptr", panelHwnd, "Int", -20, "Ptr") | 0x02000000)
        DllCall("User32\SendMessageW", "Ptr", panelHwnd, "UInt", 0x0B, "Ptr", 0, "Ptr", 0) ; WM_SETREDRAW off
    }

    ; v13.20: try/finally — если что-то ниже бросит исключение, отрисовка окна
    ; всё равно размораживается (раньше панель оставалась «замёрзшей» до
    ; закрытия: WM_SETREDRAW(0) без парного включения).
    try {
        showLoadOverlay := !listsReady && (showGlobalSearchResults || showWords || showStems || showPhrases || showPrompts || showLinks || showData || showHotkeys || showHidden)
        DictHelpEdit.Visible := showHome && !showGlobalSearchResults
        LV_GlobalSearch.Visible := showGlobalSearchResults && listsReady
        if (showGlobalSearchResults && listsReady)
            ApplyGlobalSearchColumnMode()
        LV_Words.Visible := showWords && listsReady
        LV_Stems.Visible := showStems && listsReady
        LV_Phrases.Visible := showPhrases && listsReady
        LV_Prompts.Visible := showPrompts && listsReady
        ; v13.21: чипы категорий и компактные кнопки «Промптов»; «Закрыть» там не
        ; нужна (Esc / крестик) — на её месте список.
        for _, chipCtrl in DictPromptCatChips
            try chipCtrl.Visible := showPrompts && listsReady
        for _, toolCtrl in DictPromptToolButtons
            try toolCtrl.Visible := showPrompts && listsReady
        if (showPrompts && listsReady)
            PaintPromptFilterChips()
        try DictBtnClose.Visible := !showPrompts
        LV_Links.Visible := showLinks && listsReady
        LV_Data.Visible := showData && listsReady
        LV_Hotkeys.Visible := showHotkeys && listsReady
        LV_Hidden.Visible := showHidden && listsReady
        for ctrl in [DictLoadSpin, DictLoadTitle, DictLoadStage, DictLoadBarFill, DictLoadBarRest, DictLoadHint]
            try ctrl.Visible := showLoadOverlay
        DictInfoTitle.Visible := showSettings
        for ctrl in DictSettingsPanel
            ctrl.Visible := showSettings
        SyncDictSettingsControls(showSettings)

        ; Активный раздел выделяется без «●»: акцентный цвет текста + более тёмный
        ; фон кнопки (визуально «вдавленная»). Неактивные — обычный фон 2B2B2B.
        ; v13.20: перекрашиваются только кнопки, чьё состояние сменилось (обычно
        ; две: старый и новый раздел), а не все 10 при каждом вызове.
        for ctrl, state in Map(DictTabHome,showHome, DictTabWords,showWords, DictTabStems,showStems, DictTabPhrases,showPhrases, DictTabPrompts,showPrompts, DictTabLinks,showLinks, DictTabData,showData, DictTabHotkeys,showHotkeys, DictTabHidden,showHidden, DictTabSettings,showSettings) {
            tabStyle := state ? ColorHighlight : "0" ; "0" — обычная (так кнопка создаётся)
            tabHwnd := 0
            try tabHwnd := ctrl.Hwnd
            if (tabHwnd && (DictTabStyleState.Has(tabHwnd) ? DictTabStyleState[tabHwnd] : "0") = tabStyle)
                continue
            ctrl.Opt("c" (state ? ColorHighlight : "F0F0F0") " Background" (state ? "1A1A1A" : "2B2B2B"))
            ctrl.Redraw()
            if tabHwnd
                DictTabStyleState[tabHwnd] := tabStyle
        }

        DictBtnRestore.Visible := showHidden
        DictBtnDelete.Visible := (showWords || showStems || showPhrases || showLinks || showData || showHotkeys || showHidden) ; v13.21: у «Промптов» — своя кнопка
        DictBtnPruneWords.Visible := showWords && (DictMode != "off") ; v13.18
        DictBtnEditPhrase.Visible := showPhrases
        DictBtnEditLink.Visible := showLinks
        DictBtnEditData.Visible := showData
        DictBtnAddData.Visible := showData
        try DictDataPileSelect.Visible := showData
        DictBtnAddLink.Visible := showLinks
        DictBtnAssignPhraseHotkey.Visible := showPhrases
        DictBtnAddHotkey.Visible := showHotkeys
        DictBtnEditHotkey.Visible := showHotkeys
        DictSearchLabel.Visible := (showWords || showStems || showPhrases || showPrompts || showLinks || showData || showHotkeys || showHidden)
        DictSearchEdit.Visible := DictSearchLabel.Visible
        DictSearchClear.Visible := DictSearchLabel.Visible
        DictGlobalSearchLabel.Visible := showHome
        DictGlobalSearchEdit.Visible := showHome
        DictGlobalSearchClear.Visible := showHome
        DictShowFrequencyCheck.Visible := showGlobalSearchResults
        DictIncludeWordsCheck.Visible := showGlobalSearchResults
        DictGlobalDeleteBtn.Visible := showGlobalSearchResults
        if showGlobalSearchResults
            UpdateGlobalDeleteButtonState()

        if showHidden
            hintText := "Delete — удалить    Insert — вернуть скрытое"
        else if showLinks
            hintText := "3... — ссылки, 33... — поиск по URL/заметке    Numpad/ — добавить выделение    Alt+Numpad/ — ручное добавление"
        else if showData
            hintText := "Delete — удалить запись    Двойной клик / кнопка — правка"
        else if showHotkeys
            hintText := "Delete — удалить назначение    Двойной клик — правка"
        else if showPrompts
            hintText := PanelPromptClickCopy
                ? "ЛКМ — копировать    Двойной клик — правка    ПКМ — меню    Ctrl+0…4 — фильтр    Alt+1…4 — категория"
                : "Двойной клик — правка    ПКМ — меню    Delete — удалить    Ctrl+0…4 — фильтр    Alt+1…4 — категория"
        else if showPhrases
            hintText := "Delete — удалить фразу    Двойной клик — правка    Кнопка — назначить хоткей"
        else if showWords
            hintText := (DictMode = "off") ; v13.18
                ? "Словарь выключен — список пуст. Включить: Настройки → Словарь"
                : "Delete — удалить выбранное слово    Удалить ≤ рейтинг… — массовая чистка обычных слов"
        else if showStems
            hintText := (DictMode = "off")
                ? "Словарь выключен — список пуст. Включить: Настройки → Словарь"
                : "Delete — удалить выбранную основу"
        else if showSettings
            hintText := "Win+Q — разрешить Typer в окне до перезапуска. Win+A — постоянное правило (повторный Win+A удаляет)."
        else if showGlobalSearchResults
            hintText := PanelPromptClickCopy
                ? "Enter — вставить    Двойной клик — открыть    Delete — удалить    ЛКМ по промпту — в буфер"
                : "Enter — вставить    Двойной клик — открыть    Delete — удалить"
        else
            hintText := ""
        if (DictHintText.Text != hintText)
            DictHintText.Text := hintText

        DictViewUiSig := sig
    } finally {
        ; Разморозка отрисовки (парная к WM_SETREDRAW(0) в начале) + полная
        ; инвалидация: RDW_INVALIDATE|RDW_ERASE|RDW_ALLCHILDREN|RDW_UPDATENOW =
        ; 0x0185. RDW_ERASE ОБЯЗАТЕЛЕН: без него на месте скрытых контролов
        ; остаются старые пиксели («частичная отрисовка» разделов). Сам проход
        ; стирания невидим — WS_EX_COMPOSITED собирает стирание и отрисовку
        ; в offscreen-буфере и показывает только готовый кадр.
        if panelHwnd {
            DllCall("User32\SendMessageW", "Ptr", panelHwnd, "UInt", 0x0B, "Ptr", 1, "Ptr", 0)
            DllCall("User32\RedrawWindow", "Ptr", panelHwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0185)
            ; Снять временный WS_EX_COMPOSITED (кадр уже выведен RDW_UPDATENOW),
            ; чтобы в обычном режиме шапки колонок не провоцировали полную
            ; перерисовку окна на каждый hot-track.
            DllCall("User32\SetWindowLongPtrW", "Ptr", panelHwnd, "Int", -20
                , "Ptr", DllCall("User32\GetWindowLongPtrW", "Ptr", panelHwnd, "Int", -20, "Ptr") & ~0x02000000)
        }
    }
}

SyncDictSettingsControls(showSettings) {
    ; v13.20: значения контролов «Настроек» пишутся, только если отличаются.
    ; Раньше каждый вызов UpdateDictionaryViewUi (то есть каждая пауза в наборе
    ; поиска) переписывал поле секунд автоскрытия, а запись в однострочный Edit
    ; шлёт EN_CHANGE → UpdateWordOsdAutoHideSecondsFromGui → перепланирование
    ; автоскрытия и отложенное сохранение настроек.
    global DictInsertCheck, DictWordAutoHideCheck, DictWordAutoHideSecEdit, InsertCaptureEnabled, WordOsdAutoHideEnabled, WordOsdAutoHideMs
    global DictMode, DictModeSelect, DictStartupTimingText
    try {
        wantCheck := InsertCaptureEnabled ? 1 : 0
        if (DictInsertCheck.Value != wantCheck)
            DictInsertCheck.Value := wantCheck
    }
    try {
        wantCheck := WordOsdAutoHideEnabled ? 1 : 0
        if (DictWordAutoHideCheck.Value != wantCheck)
            DictWordAutoHideCheck.Value := wantCheck
    }
    try {
        secText := StrReplace(Trim(DictWordAutoHideSecEdit.Value), ",", ".")
        secSame := RegExMatch(secText, "^[0-9]+(\.[0-9]+)?$") && (Round(Number(secText) * 1000) = WordOsdAutoHideMs)
        if !secSame
            DictWordAutoHideSecEdit.Value := Format("{:.1f}", WordOsdAutoHideMs / 1000)
    }
    if showSettings {
        ; v13.18: режим словаря и время старта — актуальные при каждом показе.
        try {
            modeIdx := GetDictModeIndex(DictMode)
            if (DictModeSelect.Value != modeIdx)
                DictModeSelect.Choose(modeIdx)
        }
        try {
            settingsInfo := BuildSettingsInfoText()
            if (DictStartupTimingText.Text != settingsInfo)
                DictStartupTimingText.Text := settingsInfo
        }
    }
}

IsLiveWindowHandle(hwnd) {
    return hwnd && DllCall("IsWindow", "Ptr", hwnd, "Int")
}

IsLiveGuiControl(ctrl) {
    try hwnd := ctrl.Hwnd
    catch
        return false
    return IsLiveWindowHandle(hwnd)
}

IsDictionaryPanelReady() {
    global DictPanelGui, LV_Words, LV_Stems, LV_Phrases, LV_Prompts, LV_Links, LV_Data, LV_Hidden, LV_Hotkeys, LV_GlobalSearch
    if !(IsSet(DictPanelGui) && IsObject(DictPanelGui))
        return false
    try panelHwnd := DictPanelGui.Hwnd
    catch
        return false
    if !IsLiveWindowHandle(panelHwnd)
        return false
    if !(IsSet(LV_Words) && IsSet(LV_Stems) && IsSet(LV_Phrases) && IsSet(LV_Prompts) && IsSet(LV_Links) && IsSet(LV_Data) && IsSet(LV_Hotkeys) && IsSet(LV_Hidden) && IsSet(LV_GlobalSearch))
        return false
    for ctrl in [LV_Words, LV_Stems, LV_Phrases, LV_Prompts, LV_Links, LV_Data, LV_Hotkeys, LV_Hidden, LV_GlobalSearch] {
        if !IsLiveGuiControl(ctrl)
            return false
    }
    return true
}

; ---- v13.17: ленивое заполнение панели F9 -----------------------------------
; Раньше каждое открытие панели (и каждое изменение) перезаполняло все 9 списков,
; включая весь словарь, ещё до показа окна: задержка F9 росла вместе с базой.
; Теперь строится только видимая вкладка; остальные помечаются устаревшими
; (DictViewDirty) и строятся при первом открытии. Большие списки заполняются
; без перерисовки и без сабкласса тёмной шапки (см. BeginPanelListBulk).
GetDictListViewNames() {
    return ["HOME", "WORDS", "STEMS", "PHRASES", "PROMPTS", "LINKS", "DATA", "HOTKEYS", "HIDDEN"]
}

MarkDictViewsDirty(exceptView := "") {
    global DictViewDirty
    if !IsObject(DictViewDirty)
        DictViewDirty := Map()
    for _, view in GetDictListViewNames() {
        if (view != exceptView)
            DictViewDirty[view] := true
    }
}

EnsureDictViewPopulated(view) {
    global DictViewDirty, TyperStartupComplete
    if (view = "" || view = "SETTINGS")
        return
    ; Пока базы расшифровываются, они пустые: строить нечего. Вкладка остаётся
    ; «грязной», и PanelDecryptWatch построит её по готовности.
    if !TyperStartupComplete
        return
    if (DictViewDirty.Has(view) && !DictViewDirty[view])
        return
    if !IsDictionaryPanelReady()
        return
    DictViewDirty[view] := false
    try {
        PopulateDictView(view)
    } catch as err {
        DictViewDirty[view] := true
        throw err
    }
}

PopulateDictListView() {
    ; v13.17: «перестроить списки» = пометить все вкладки устаревшими и сразу
    ; построить только видимую.
    global DictActiveView
    if !IsDictionaryPanelReady()
        return
    MarkDictViewsDirty()
    EnsureDictViewPopulated(DictActiveView)
}

GetDictListViewForView(view) {
    global LV_Words, LV_Stems, LV_Phrases, LV_Prompts, LV_Links, LV_Data, LV_Hidden, LV_Hotkeys, LV_GlobalSearch
    switch view {
        case "HOME": return LV_GlobalSearch
        case "WORDS": return LV_Words
        case "STEMS": return LV_Stems
        case "PHRASES": return LV_Phrases
        case "PROMPTS": return LV_Prompts
        case "LINKS": return LV_Links
        case "DATA": return LV_Data
        case "HOTKEYS": return LV_Hotkeys
        case "HIDDEN": return LV_Hidden
    }
    return 0
}

PopulateDictView(view) {
    global WordDB, PhraseDB, PromptDB, LinkDB, DataDB, HotInsertDB, LV_Data, LV_Hidden, LV_Prompts
    global DictHelpEdit, DictSearchEdit, DictPromptRowText, DictPromptRefText, DictDataRowIdMap, DictDataPileMode, DictHiddenRowRefs, PanelPromptCatFilter, DictPromptCatCounts

    if (view = "HOME") {
        RefreshGlobalSearchList()
        try {
            helpText := BuildMainHelpText()
            if (DictHelpEdit.Value != helpText)
                DictHelpEdit.Value := helpText
            DllCall("User32\SendMessageW", "Ptr", DictHelpEdit.Hwnd, "UInt", 0x00B1, "Ptr", 0, "Ptr", 0)
        }
        return
    }

    lv := GetDictListViewForView(view)
    if !IsObject(lv)
        return
    HidePanelPreviewOsd() ; v13.20: содержимое строк меняется — плашка от старой строки не нужна

    searchTerm := ""
    try searchTerm := StrLower(Trim(DictSearchEdit.Value))
    termHasSpace := RegExMatch(searchTerm, "\s") ? true : false ; v13.20: см. PanelSearchMatch

    detached := BeginPanelListBulk(lv)
    try {
        lv.Delete()
        switch view {
            case "WORDS", "STEMS":
                wantStems := (view = "STEMS")
                for key, data in WordDB {
                    if (data.HasOwnProp("DataOnly") && data.DataOnly)
                        continue
                    if (data.HasOwnProp("Hidden") && data.Hidden)
                        continue
                    isStem := (data.HasOwnProp("IsStem") && data.IsStem) ? true : false
                    if (isStem != wantStems)
                        continue
                    if (searchTerm != "" && !InStr(key, searchTerm)) ; v13.20: ключ уже в нижнем регистре
                        continue
                    lv.Add(, data.Display, data.Count)
                }

            case "PHRASES":
                ; v13.20: текст фразы и так однострочный (SanitizePhraseText), ключ —
                ; он же в нижнем регистре: без RegExReplace и StrLower на каждую фразу.
                for key, data in PhraseDB {
                    if (data.HasOwnProp("Hidden") && data.Hidden)
                        continue
                    if (searchTerm != "" && !InStr(key, searchTerm))
                        continue
                    lv.Add(, data.Text, data.Count)
                }

            case "PROMPTS":
                ; 3-я колонка (ширина 0) — ref на полный текст: строка «уезжает» при
                ; сортировке по заголовку, а ref едет вместе с ней.
                ; v13.21: 2-я колонка — категория (вместо «Исп.»); фильтр —
                ; PanelPromptCatFilter. Порядок: категория (во «Всех»), затем
                ; частота, затем текст. Счётчики чипов — с учётом поиска.
                DictPromptRowText := Map()
                DictPromptRefText := Map()
                catCounts := Map("ALL", 0, "IMAGE", 0, "VIDEO", 0, "LLM", 0, "OTHER", 0)
                promptRows := []
                for key, data in PromptDB {
                    if (data.HasOwnProp("Hidden") && data.Hidden)
                        continue
                    if (searchTerm != "" && !PanelSearchMatch(key, data.Text, searchTerm, termHasSpace)) ; v13.20
                        continue
                    promptCat := GetPromptCat(data)
                    catCounts["ALL"] += 1
                    catCounts[promptCat] += 1
                    if (PanelPromptCatFilter != "ALL" && promptCat != PanelPromptCatFilter)
                        continue
                    promptRows.Push({Key: key, Text: data.Text, Cat: promptCat, Rank: GetPromptCatRank(promptCat), Count: data.Count})
                }
                if (promptRows.Length > 1)
                    SortRowsInPlace(promptRows, PanelPromptRowComparator)
                for _, pr in promptRows {
                    ref := "p" (DictPromptRefText.Count + 1)
                    DictPromptRefText[ref] := pr.Text
                    row := lv.Add(, BuildPanelListPreview(pr.Text), GetPromptCatName(pr.Cat), ref)
                    DictPromptRowText[row] := pr.Text
                }
                DictPromptCatCounts := catCounts

            case "LINKS":
                for id, data in LinkDB {
                    if data.Hidden
                        continue
                    if (searchTerm != "" && !InStr(GetLinkSearchBlob(data), searchTerm))
                        continue
                    lv.Add(, data.Title != "" ? data.Title : GuessLinkTitleFromUrl(data.Url), data.Url, BuildLinkListNote(data), data.Count)
                }

            case "DATA":
                DictDataRowIdMap := Map()
                dataRows := []
                for id, data in DataDB {
                    if (DictDataPileMode = "NOPILE" && data.IsPile)
                        continue
                    if (DictDataPileMode = "PILE" && !data.IsPile)
                        continue
                    if (searchTerm != "" && !InStr(StrLower(GetDataSearchBlob(data)), searchTerm))
                        continue
                    title := data.Key != "" ? data.Key : (data.Login != "" ? data.Login : "[данные]")
                    dataRows.Push({Id: id, Title: title, Data: data})
                }
                ; Вкладка Данные всегда открывается отсортированной по ключу/названию.
                if (dataRows.Length > 1)
                    SortRowsInPlace(dataRows, DataTitleAscComparator)
                for _, r in dataRows {
                    state := r.Data.IsPile ? "Свалка" : "Карточка"
                    row := lv.Add(, r.Title, r.Data.Note, state, r.Data.Count, r.Id)
                    DictDataRowIdMap[row] := r.Id
                }

            case "HOTKEYS":
                for id, data in HotInsertDB {
                    preview := RegExReplace(data.Text, "\s+", " ")
                    if (searchTerm != "" && !InStr(StrLower(data.Label " " data.Combo " " preview), searchTerm))
                        continue
                    lv.Add(, data.Label, data.Combo, TruncatePhraseForOSD(preview, 68))
                }

            case "HIDDEN":
                ; v13.17: исключённое показываем целиком, без масок: доступ к панели
                ; уже означает доступ ко всем базам. Полный текст — в превью.
                DictHiddenRowRefs := Map()
                for key, data in WordDB {
                    if !(data.HasOwnProp("Hidden") && data.Hidden)
                        continue
                    if (data.HasOwnProp("DataOnly") && data.DataOnly)
                        continue
                    if (searchTerm != "" && !InStr(StrLower(data.Display), searchTerm))
                        continue
                    isStem := (data.HasOwnProp("IsStem") && data.IsStem) ? true : false
                    AddHiddenPanelRow(data.Display, isStem ? "Основа" : "Слово", key, data.Display)
                }
                for key, data in PhraseDB {
                    if !(data.HasOwnProp("Hidden") && data.Hidden)
                        continue
                    if (searchTerm != "" && !InStr(key, searchTerm)) ; v13.20
                        continue
                    AddHiddenPanelRow(data.Text, "Фраза", key, data.Text)
                }
                for key, data in PromptDB {
                    if !(data.HasOwnProp("Hidden") && data.Hidden)
                        continue
                    if (searchTerm != "" && !PanelSearchMatch(key, data.Text, searchTerm, termHasSpace)) ; v13.20
                        continue
                    AddHiddenPanelRow(BuildPanelListPreview(data.Text), "Промпт", key, data.Text)
                }
                for id, data in LinkDB {
                    if !data.Hidden
                        continue
                    if (searchTerm != "" && !InStr(GetLinkSearchBlob(data), searchTerm))
                        continue
                    AddHiddenPanelRow(BuildLinkDisplay(data), "Ссылка", id, BuildLinkDisplay(data))
                }
        }
    } finally {
        EndPanelListBulk(lv, detached)
    }

    ; Скрытые служебные колонки — ширина 0 (после EndPanelListBulk: правка
    ; колонок перерисовывает шапку, а она должна рисоваться уже с сабклассом).
    hiddenCol := (view = "DATA") ? 5 : (view = "HIDDEN") ? 3 : (view = "PROMPTS") ? 3 : 0
    if (hiddenCol > 0 && GetListViewColumnWidth(lv, hiddenCol) != 0) ; v13.20: без лишней перерисовки шапки
        try lv.ModifyCol(hiddenCol, 0)
    RestretchDictListView(view)
    if (view = "PROMPTS")
        PaintPromptFilterChips() ; v13.21
}

RestretchDictListView(view) {
    ; После заполнения у списка мог появиться вертикальный скроллбар —
    ; дотягиваем последнюю колонку заново, чтобы не вылезал горизонтальный.
    global LV_Words, LV_Stems, LV_Phrases, LV_Prompts, LV_Links, LV_Data, LV_Hidden, LV_Hotkeys
    switch view {
        case "WORDS": StretchLastListViewColumn(LV_Words, 2)
        case "STEMS": StretchLastListViewColumn(LV_Stems, 2)
        case "PHRASES": StretchLastListViewColumn(LV_Phrases, 2)
        case "PROMPTS": StretchPromptListColumns() ; v13.21
        case "LINKS": StretchLastListViewColumn(LV_Links, 4)
        case "DATA": StretchLastListViewColumn(LV_Data, 4)
        case "HOTKEYS": StretchLastListViewColumn(LV_Hotkeys, 3)
        case "HIDDEN": StretchLastListViewColumn(LV_Hidden, 2)
    }
}

; --- v13.21: вкладка «Промпты» — категории ------------------------------------
SetListViewColumnWidthPx(lv, col, widthPx) {
    ; v13.21: ширина колонки в ФИЗИЧЕСКИХ пикселях (LVM_SETCOLUMNWIDTH). ModifyCol
    ; принимает ширину в единицах Gui и масштабирует её под DPI, а всё, что мы
    ; меряем (LVM_GETCOLUMNWIDTH, GetClientRect), — уже физические пиксели. На
    ; 125–150 % дотянутая последняя колонка выходила шире списка (горизонтальный
    ; скроллбар), а сохранённые ширины росли при каждом открытии панели.
    try return DllCall("User32\SendMessageW", "Ptr", lv.Hwnd, "UInt", 0x101E, "Ptr", col - 1, "Ptr", widthPx, "Ptr")
    return 0
}

StretchPromptListColumns() {
    ; 1-я колонка (текст) — на всю ширину, 2-я — категория (только в фильтре
    ; «Все»), 3-я — скрытый ref. Ширины не сохраняются: их целиком задают окно и
    ; фильтр (раньше сохранённая ширина текста + «Исп.» давали горизонтальный скролл).
    global LV_Prompts, PanelPromptCatFilter
    if (!IsSet(LV_Prompts) || !IsObject(LV_Prompts))
        return
    try {
        catW := (PanelPromptCatFilter = "ALL") ? Round(72 * A_ScreenDPI / 96) : 0
        if (GetListViewColumnWidth(LV_Prompts, 2) != catW)
            SetListViewColumnWidthPx(LV_Prompts, 2, catW)
        if (GetListViewColumnWidth(LV_Prompts, 3) != 0)
            SetListViewColumnWidthPx(LV_Prompts, 3, 0)
        rc := Buffer(16, 0)
        if !DllCall("User32\GetClientRect", "Ptr", LV_Prompts.Hwnd, "Ptr", rc.Ptr)
            return
        textW := NumGet(rc, 8, "Int") - catW
        if (textW >= 80 && textW != GetListViewColumnWidth(LV_Prompts, 1))
            SetListViewColumnWidthPx(LV_Prompts, 1, textW)
    }
}

PanelPromptRowComparator(left, right) {
    ; true — right идёт раньше left (см. SortRowsInPlace). Во «Всех» — группы по
    ; категориям, внутри — самые используемые сверху, затем по алфавиту.
    if (left.Rank != right.Rank)
        return left.Rank > right.Rank
    if (left.Count != right.Count)
        return left.Count < right.Count
    return StrCompare(left.Key, right.Key) > 0
}

SetPanelPromptCatFilter(cat, *) {
    ; Чип / Ctrl+0…4. Повторный выбор той же категории — снова «Все».
    global PanelPromptCatFilter, DictActiveView, DictViewDirty
    cat := (cat = "ALL") ? "ALL" : NormalizePromptCat(cat)
    if (cat != "ALL" && cat = PanelPromptCatFilter)
        cat := "ALL"
    if (cat = PanelPromptCatFilter)
        return
    PanelPromptCatFilter := cat
    if !IsDictionaryPanelReady()
        return
    HidePanelPreviewOsd()
    if !IsObject(DictViewDirty)
        DictViewDirty := Map()
    DictViewDirty["PROMPTS"] := true
    if (DictActiveView = "PROMPTS")
        EnsureDictViewPopulated("PROMPTS")
}

PaintPromptFilterChips() {
    ; Текст чипа — «Категория · N» (N — с учётом поиска). Активный — как активный
    ; раздел панели; пустые неактивные — приглушённые. Перекраска только при
    ; смене текста/цвета (DictPromptChipState), как у кнопок разделов.
    global DictPromptCatChips, DictPromptChipState, DictPromptCatCounts, PanelPromptCatFilter, ColorHighlight
    if (!IsObject(DictPromptCatChips) || DictPromptCatChips.Count = 0)
        return
    if !IsObject(DictPromptChipState)
        DictPromptChipState := Map()
    for chipCat, ctrl in DictPromptCatChips {
        chipCount := (IsObject(DictPromptCatCounts) && DictPromptCatCounts.Has(chipCat)) ? DictPromptCatCounts[chipCat] : ""
        label := ((chipCat = "ALL") ? "Все" : GetPromptCatName(chipCat)) . ((chipCount != "") ? " · " chipCount : "")
        isOn := (chipCat = PanelPromptCatFilter)
        chipColor := isOn ? ColorHighlight : ((chipCount = 0) ? "7A7A7A" : "F0F0F0")
        chipBg := isOn ? "1A1A1A" : "2B2B2B"
        stateKey := label "|" chipColor "|" chipBg
        chipHwnd := 0
        try chipHwnd := ctrl.Hwnd
        if (chipHwnd && DictPromptChipState.Has(chipHwnd) && DictPromptChipState[chipHwnd] == stateKey)
            continue
        try {
            if (ctrl.Text != label)
                ctrl.Text := label
            ctrl.Opt("c" chipColor " Background" chipBg)
            ctrl.Redraw()
        }
        if chipHwnd
            DictPromptChipState[chipHwnd] := stateKey
    }
}

RecountPanelPromptCats() {
    ; Счётчики чипов после удаления / смены категории без перестройки списка.
    global PromptDB, DictSearchEdit, DictPromptCatCounts
    searchTerm := ""
    try searchTerm := StrLower(Trim(DictSearchEdit.Value))
    termHasSpace := RegExMatch(searchTerm, "\s") ? true : false
    counts := Map("ALL", 0, "IMAGE", 0, "VIDEO", 0, "LLM", 0, "OTHER", 0)
    for key, data in PromptDB {
        if (data.HasOwnProp("Hidden") && data.Hidden)
            continue
        if (searchTerm != "" && !PanelSearchMatch(key, data.Text, searchTerm, termHasSpace))
            continue
        counts["ALL"] += 1
        counts[GetPromptCat(data)] += 1
    }
    DictPromptCatCounts := counts
    PaintPromptFilterChips()
}

GetSelectedPanelPromptKey(&rowOut := 0) {
    global DictActiveView, LV_Prompts, PromptDB
    rowOut := 0
    if (DictActiveView != "PROMPTS")
        return ""
    row := 0
    try row := LV_Prompts.GetNext(0)
    if !row
        return ""
    key := StrLower(GetPanelRowFullText("PROMPTS", LV_Prompts, row))
    if !PromptDB.Has(key)
        return ""
    rowOut := row
    return key
}

SetSelectedPromptCategoryFromPanel(cat, *) {
    ; Alt+1…4 / меню ПКМ: перенести выбранный промпт в категорию. Во «Всех»
    ; строка остаётся (меняется ячейка «Кат.»), в фильтре другой категории —
    ; уходит из списка, выделение переходит на соседнюю.
    global LV_Prompts, DictPromptRowText, PanelPromptCatFilter
    row := 0
    key := GetSelectedPanelPromptKey(&row)
    if (key = "")
        return
    cat := NormalizePromptCat(cat)
    if !SetPromptCategory(key, cat) {
        ToolTip("Уже в " GetPromptCatName(cat))
        SetTimer(() => ToolTip(), -800)
        return
    }
    HidePanelPreviewOsd()
    try MarkDictViewsDirty("PROMPTS")
    if (PanelPromptCatFilter = "ALL" || PanelPromptCatFilter = cat) {
        try LV_Prompts.Modify(row, "Col2", GetPromptCatName(cat))
    } else {
        DictPromptRowText := ShiftRowMapAfterDelete(DictPromptRowText, row)
        try LV_Prompts.Delete(row)
        RestoreListViewRow(LV_Prompts, row)
    }
    RecountPanelPromptCats()
    ToolTip("🏷 " GetPromptCatName(cat))
    SetTimer(() => ToolTip(), -700)
}

CopySelectedPromptFromPanel(*) {
    global LV_Prompts, PromptDB
    row := 0
    key := GetSelectedPanelPromptKey(&row)
    if (key = "")
        return
    if CopyPanelPromptToClipboard(PromptDB[key].Text)
        FlashPanelListRow(LV_Prompts, row)
}

ShowPromptPanelContextMenu(row := 0) {
    ; v13.21: ПКМ по промпту — меню вместо прямой правки: правка, копия,
    ; категория (текущая отмечена), хоткей, удаление. По пустому месту — новый.
    global PromptDB
    HidePanelPreviewOsd()
    m := Menu()
    key := ""
    if (row >= 1)
        key := GetSelectedPanelPromptKey()
    if (key = "") {
        m.Add("Новый промпт…", (*) => ShowPromptEditGui(""))
        m.Show()
        return
    }
    curCat := GetPromptCat(PromptDB[key])
    editItem := "Править`tДвойной клик"
    m.Add(editItem, (*) => EditSelectedPromptFromPanel(0))
    m.Add("Копировать в буфер", CopySelectedPromptFromPanel)
    m.Add()
    for i, cat in GetPromptCatOrder() {
        itemName := GetPromptCatName(cat) "`tAlt+" i
        m.Add(itemName, SetSelectedPromptCategoryFromPanel.Bind(cat))
        if (cat = curCat)
            m.Check(itemName)
    }
    m.Add()
    m.Add("Назначить хоткей…", CreateHotInsertFromSelectedPrompt)
    m.Add("Новый промпт…", (*) => ShowPromptEditGui(""))
    m.Add("Удалить`tDelete", (*) => DeleteWordFromDict(0))
    try m.Default := editItem
    m.Show()
}

PanelSearchMatch(key, text, term, termHasSpace) {
    ; v13.20: поиск панели без StrLower/RegExReplace каждого текста. Ключ записи
    ; (StrLower(Text)) уже лежит в базе. Запрос без пробелов не может пересечь
    ; пробельный промежуток, поэтому InStr по ключу даёт тот же результат, что и
    ; старое «сплющить пробелы → StrLower → InStr», но без копии каждого промпта
    ; на каждую букву. Запрос с пробелом — по-старому.
    if !termHasSpace
        return InStr(key, term) ? true : false
    return InStr(StrLower(RegExReplace(text, "\s+", " ")), term) ? true : false
}

BuildPanelListPreview(text, maxChars := 600) {
    ; v13.20: строка списка панели для длинного текста (промпты). ListView всё
    ; равно рисует только начало ячейки (~260 символов), а раньше в каждую
    ; строку клался весь промпт, сплющенный RegExReplace, — тысячи символов на
    ; строку при каждом заполнении. Полный текст — в картах строк (превью,
    ; вставка, правка, копирование), не в ячейке.
    if (StrLen(text) > maxChars)
        text := SubStr(text, 1, maxChars)
    return RegExReplace(text, "\s+", " ")
}

BeginPanelListBulk(lv) {
    ; Массовое заполнение: -Redraw — без перерисовки на каждую строку. Сабкласс
    ; тёмной шапки на это время снимаем: иначе КАЖДОЕ сообщение списку
    ; (LVM_INSERTITEM/LVM_SETITEM на каждую строку и колонку) проходило бы через
    ; AHK-колбэк DarkHeaderDrawProc — на тысячах слов это заметные доли секунды.
    ; Возвращает true, если сабкласс был и снят (тогда EndPanelListBulk вернёт его).
    global DarkHeaderDrawCb
    try lv.Opt("-Redraw")
    detached := false
    if DarkHeaderDrawCb
        try detached := DllCall("comctl32\RemoveWindowSubclass", "Ptr", lv.Hwnd, "Ptr", DarkHeaderDrawCb, "Ptr", lv.Hwnd, "Int") ? true : false
    return detached
}

EndPanelListBulk(lv, detached := false) {
    ; Сабкласс возвращаем только тому списку, с которого его сняли: свежие списки
    ; новой панели получают его позже, в ApplyDarkThemeToGui → AttachDarkHeader.
    global DarkHeaderDrawCb
    if (detached && DarkHeaderDrawCb) {
        try {
            headerHwnd := DllCall("User32\SendMessageW", "Ptr", lv.Hwnd, "UInt", 0x101F, "Ptr", 0, "Ptr", 0, "Ptr") ; LVM_GETHEADER
            if headerHwnd {
                DllCall("comctl32\SetWindowSubclass", "Ptr", lv.Hwnd, "Ptr", DarkHeaderDrawCb, "Ptr", lv.Hwnd, "Ptr", headerHwnd)
                ; Шапку перерисовать уже с сабклассом (светлый текст на тёмном).
                DllCall("User32\InvalidateRect", "Ptr", headerHwnd, "Ptr", 0, "Int", 1)
            }
        }
    }
    try lv.Opt("+Redraw")
}


PanelContextEdit(viewName, ctrl := 0, row := 0, *) {
    ; ПКМ в главной панели — только локальное GUI-событие, не глобальный перехват мыши.
    ; Если ListView передал номер строки, сначала выделяем именно её.
    try {
        if (row > 0)
            ctrl.Modify(row, "Select Focus Vis")
    }
    if (viewName = "GLOBAL")
        OpenSelectedGlobalSearchResult(0)
    else if (viewName = "PHRASES")
        EditSelectedPhraseFromPanel(0)
    else if (viewName = "PROMPTS")
        ShowPromptPanelContextMenu(row) ; v13.21: меню вместо прямой правки
    else if (viewName = "LINKS")
        EditSelectedLinkFromPanel(0)
    else if (viewName = "DATA")
        EditSelectedDataFromPanel(0)
    else if (viewName = "HOTKEYS")
        EditSelectedHotInsertFromPanel(0)
}

IsFrequencyColumnForListView(lv, col) {
    global LV_Words, LV_Stems, LV_Phrases, LV_Prompts, LV_Links, LV_Data, LV_GlobalSearch, DictShowFrequencyColumn
    try {
        hwnd := lv.Hwnd
        ; v13.21: у «Промптов» 2-я колонка — категория (текст), не частота.
        if (hwnd = LV_Words.Hwnd || hwnd = LV_Stems.Hwnd || hwnd = LV_Phrases.Hwnd)
            return (col = 2)
        if (hwnd = LV_Links.Hwnd || hwnd = LV_Data.Hwnd)
            return (col = 4)
        if (hwnd = LV_GlobalSearch.Hwnd)
            return (DictShowFrequencyColumn && col = 3)
    }
    return false
}

HandlePanelListViewColClick(lv, col, *) {
    global DictPanelSortState
    sorted := 0
    if IsFrequencyColumnForListView(lv, col) {
        key := lv.Hwnd ":" col
        descending := !(DictPanelSortState.Has(key) && DictPanelSortState[key] = "DESC")
        DictPanelSortState[key] := descending ? "DESC" : "ASC"
        try lv.ModifyCol(col, "Integer " (descending ? "SortDesc" : "Sort"))
        sorted := 1
    }
    ; v13.17: после ЛЮБОЙ сортировки (встроенной по тексту или числовой выше)
    ; номера строк сменились — пересобираем карты row → запись по скрытым ref.
    ; Раньше «Промпты» и общий поиск после клика по заголовку открывали,
    ; вставляли и показывали в превью не ту запись.
    try RemapPanelRowMapsAfterSort(lv)
    try HidePanelPreviewOsd()
    return sorted
}

RemapPanelRowMapsAfterSort(lv) {
    global LV_Prompts, LV_GlobalSearch, DictPromptRowText, DictPromptRefText
    global DictGlobalResultMap, DictGlobalFullTextMap, DictGlobalRefs, DictPanelPreviewLastKey
    DictPanelPreviewLastKey := ""
    if (lv.Hwnd = LV_Prompts.Hwnd) {
        newMap := Map()
        Loop lv.GetCount() {
            ref := lv.GetText(A_Index, 3)
            if DictPromptRefText.Has(ref)
                newMap[A_Index] := DictPromptRefText[ref]
        }
        DictPromptRowText := newMap
    } else if (lv.Hwnd = LV_GlobalSearch.Hwnd) {
        newItems := Map()
        newFull := Map()
        Loop lv.GetCount() {
            ref := lv.GetText(A_Index, 4)
            if DictGlobalRefs.Has(ref) {
                newItems[A_Index] := DictGlobalRefs[ref].Item
                newFull[A_Index] := DictGlobalRefs[ref].Full
            }
        }
        DictGlobalResultMap := newItems
        DictGlobalFullTextMap := newFull
    }
    ; «Данные» и «Исключённые» уже берут запись из своих скрытых колонок.
}

; v13.17: ЛКМ по промпту — копия полного текста в буфер обмена. Работает на
; вкладке «Промпты» и в результатах общего поиска; отключается в Настройках
; («ЛКМ по промпту — копировать в буфер»).
HandlePromptListClick(lv, row, *) {
    global PanelPromptClickCopy, DictPromptRowText, DictPromptRefText
    if (!PanelPromptClickCopy || row < 1)
        return
    text := ""
    ref := ""
    try ref := lv.GetText(row, 3)
    if (ref != "" && DictPromptRefText.Has(ref))
        text := DictPromptRefText[ref]
    else if DictPromptRowText.Has(row)
        text := DictPromptRowText[row]
    if CopyPanelPromptToClipboard(text)
        FlashPanelListRow(lv, row) ; v13.19
}

HandleGlobalSearchClick(lv, row, *) {
    global PanelPromptClickCopy, DictGlobalRefs, DictGlobalResultMap, PromptDB
    if (!PanelPromptClickCopy || row < 1)
        return
    item := 0
    ref := ""
    try ref := lv.GetText(row, 4)
    if (ref != "" && DictGlobalRefs.Has(ref))
        item := DictGlobalRefs[ref].Item
    else if DictGlobalResultMap.Has(row)
        item := DictGlobalResultMap[row]
    if (!IsObject(item) || item.Kind != "PROMPT")
        return
    key := StrLower(item.Key)
    if CopyPanelPromptToClipboard(PromptDB.Has(key) ? PromptDB[key].Text : item.Key)
        FlashPanelListRow(lv, row) ; v13.19
}

CopyPanelPromptToClipboard(text) {
    ; v13.19: без подсказки «скопировано» — подтверждение даёт вспышка строки.
    ; Подсказка осталась только для ошибки (буфер занят другим приложением).
    if (text = "")
        return false
    try {
        A_Clipboard := text
        return true
    } catch {
        ToolTip("⚠️ Буфер обмена занят — попробуй ещё раз")
        SetTimer(() => ToolTip(), -1100)
        return false
    }
}

IsPanelTextFieldFocused() {
    ; v13.17: в поле поиска панели Delete/Insert — обычное редактирование текста,
    ; а не удаление/возврат выбранной строки списка.
    try {
        focused := ControlGetFocus("A")
        return focused ? (WinGetClass("ahk_id " focused) = "Edit") : false
    }
    return false
}

GetCurrentDictionaryListView() {
    global DictActiveView, LV_Words, LV_Stems, LV_Phrases, LV_Prompts, LV_Links, LV_Data, LV_Hidden, LV_Hotkeys
    return (DictActiveView = "WORDS") ? LV_Words
        : (DictActiveView = "STEMS") ? LV_Stems
        : (DictActiveView = "PHRASES") ? LV_Phrases
        : (DictActiveView = "PROMPTS") ? LV_Prompts
        : (DictActiveView = "LINKS") ? LV_Links
        : (DictActiveView = "DATA") ? LV_Data
        : (DictActiveView = "HOTKEYS") ? LV_Hotkeys
        : LV_Hidden
}

DeleteWordFromDict(guiObj, *) {
    global WordDB, PhraseDB, PromptDB, LinkDB, DataDB, HotInsertDB, DictActiveView, RegisteredHotInsertCombos, HotInsertCallbacks, DictPromptRowText
    if !(DictActiveView = "WORDS" || DictActiveView = "STEMS" || DictActiveView = "PHRASES" || DictActiveView = "PROMPTS" || DictActiveView = "LINKS" || DictActiveView = "DATA" || DictActiveView = "HOTKEYS" || DictActiveView = "HIDDEN")
        return

    CurrentLV := GetCurrentDictionaryListView()
    selectedRow := 0
    try selectedRow := CurrentLV.GetNext(0)

    if (DictActiveView = "LINKS") {
        linkId := GetSelectedLinkIdFromPanel()
        if (linkId != "" && LinkDB.Has(linkId)) {
            LinkDB.Delete(linkId)
            RemoveLinkFromIndexes(linkId)
            SaveLinksInternal()
            HidePanelPreviewOsd()
            DeleteListViewRowPreservePlace(CurrentLV, selectedRow)
        }
        return
    }

    if (DictActiveView = "DATA") {
        dataId := GetSelectedDataIdFromPanel()
        if (dataId != "" && DataDB.Has(dataId)) {
            DataDB.Delete(dataId)
            RemoveDataFromIndexes(dataId)
            QueueDataSave()
            HidePanelPreviewOsd()
            DeleteListViewRowPreservePlace(CurrentLV, selectedRow)
        }
        return
    }

    if (DictActiveView = "HOTKEYS") {
        hotId := GetSelectedHotInsertIdFromPanel()
        if (hotId != "" && HotInsertDB.Has(hotId)) {
            UnregisterHotInsertEntry(hotId)
            HotInsertDB.Delete(hotId)
            SaveHotInsertsInternal()
            HidePanelPreviewOsd()
            DeleteListViewRowPreservePlace(CurrentLV, selectedRow)
        }
        return
    }

    RowNumber := selectedRow
    if !RowNumber
        return

    itemText := CurrentLV.GetText(RowNumber, 1)
    itemType := (DictActiveView = "HIDDEN") ? CurrentLV.GetText(RowNumber, 2) : DictActiveView
    if (DictActiveView = "PROMPTS")
        itemText := DictPromptRowText.Has(RowNumber) ? DictPromptRowText[RowNumber] : CurrentLV.GetText(RowNumber, 1)
    itemKey := StrLower(itemText)
    ; v13.16: во «Исключённых» видимый текст может быть маской — берём настоящий ключ.
    if (DictActiveView = "HIDDEN") {
        hiddenRef := GetHiddenPanelRowRef(RowNumber)
        if IsObject(hiddenRef) {
            itemType := hiddenRef.Type
            itemText := hiddenRef.Text
            itemKey := hiddenRef.Key
        }
    }

    if (itemType = "WORDS" || itemType = "Слово") {
        if WordDB.Has(itemKey) {
            WordDB.Delete(itemKey)
            RemoveWordFromPrefixIndexes(itemKey)
        }
        SetNoSpaceWord(itemKey, false)
    } else if (itemType = "STEMS" || itemType = "Основа") {
        if WordDB.Has(itemKey) {
            WordDB.Delete(itemKey)
            RemoveWordFromPrefixIndexes(itemKey)
        }
    } else if (itemType = "PHRASES" || itemType = "Фраза") {
        if PhraseDB.Has(itemKey) {
            PhraseDB.Delete(itemKey)
            RemovePhraseFromIndexes(itemKey)
        }
    } else if (itemType = "Ссылка") {
        for id, data in LinkDB {
            if (BuildLinkDisplay(data) = itemText) {
                LinkDB.Delete(id)
                RemoveLinkFromIndexes(id)
                break
            }
        }
    } else if (itemType = "PROMPTS" || itemType = "Промпт") {
        if PromptDB.Has(itemKey) {
            PromptDB.Delete(itemKey)
            RemovePromptFromIndexes(itemKey)
            QueuePromptSave() ; v13.21: раньше — только при выходе / автосохранении
        }
    }

    HidePanelPreviewOsd()
    if (DictActiveView = "PROMPTS")
        DictPromptRowText := ShiftRowMapAfterDelete(DictPromptRowText, RowNumber)
    DeleteListViewRowPreservePlace(CurrentLV, RowNumber)
    if (DictActiveView = "PROMPTS")
        RecountPanelPromptCats() ; v13.21: счётчики чипов
}


PruneLowRatedWordsFromGui(*) {
    ; v13.17: раньше слова удалялись по одному. Map в AHK — отсортированный
    ; массив, и каждое WordDB.Delete сдвигает его хвост (O(n)), плюс правка
    ; префиксных индексов на каждое слово: на большом словаре это O(k·n) и
    ; долгий подвис. Поток при этом прерывался набором в других окнах, и OSD
    ; строился по полуразобранной базе (кривые «двойные» окна). Теперь —
    ; один проход с новым Map из оставшихся слов и одна перестройка индексов,
    ; всё под Critical: ввод ждёт доли секунды и видит уже готовую базу.
    ; v13.18: основное время «зависания» съедало не удаление, а сохранение:
    ; base64 каждого слова через Crypt32 с LoadLibrary/FreeLibrary на вызов
    ; (см. #DllLoad в начале файла). Теперь показываем и время обоих шагов.
    global WordDB, NoSpaceWords

    if !GuardTyperStartup()
        return
    if !IsDictionaryActive() {
        MsgBox("Словарь выключен — чистить нечего.`n`nВключить: F9 → Настройки → Словарь.", "Чистка слов", 0x40)
        return
    }
    if !WordDB.Count {
        MsgBox("Словарь пуст.", "Чистка слов", 0x40)
        return
    }

    ib := InputBox("Удалить обычные слова с рейтингом меньше или равным указанному числу.`n`nОсновы, записи Данных и служебные data-only слова не трогаются.", "Удалить слова по рейтингу", "w460 h170", "10")
    if (ib.Result != "OK")
        return

    raw := Trim(ib.Value)
    if !RegExMatch(raw, "^[0-9]+$") {
        MsgBox("Введите целое число: 0, 1, 2 ...", "Некорректный рейтинг", 0x30)
        return
    }

    threshold := Integer(raw)
    deleteCount := 0
    hiddenCount := 0
    for key, data in WordDB {
        if !IsPrunableWordEntry(data, threshold)
            continue
        deleteCount += 1
        if (data.HasOwnProp("Hidden") && data.Hidden)
            hiddenCount += 1
    }

    if (deleteCount = 0) {
        MsgBox("Обычных слов с рейтингом ≤ " threshold " не найдено.", "Чистка слов", 0x40)
        return
    }

    confirmText := "Будет удалено обычных слов: " deleteCount " из " WordDB.Count "`n"
        . "Порог: рейтинг ≤ " threshold "`n"
        . "Основы и записи Данных не будут затронуты."
    if (hiddenCount > 0)
        confirmText .= "`nВ том числе исключённых слов: " hiddenCount
    confirmText .= "`n`nПродолжить?"

    if (MsgBox(confirmText, "Подтверждение чистки слов", 0x34) != "Yes")
        return

    HideSuggestions()
    HidePanelPreviewOsd()
    ToolTip("🧹 Чистка словаря…")

    removed := 0
    tStart := A_TickCount
    prevCritical := Critical("On")
    try {
        kept := Map()
        try kept.Capacity := Max(16, WordDB.Count - deleteCount + 16)
        noSpaceDrop := []
        for key, data in WordDB {
            if IsPrunableWordEntry(data, threshold) {
                removed += 1
                nsKey := StrLower(key)
                if NoSpaceWords.Has(nsKey)
                    noSpaceDrop.Push(nsKey)
            } else {
                kept[key] := data
            }
        }
        for _, nsKey in noSpaceDrop
            NoSpaceWords.Delete(nsKey)
        WordDB := kept
        RebuildPrefixIndexes()
    } finally {
        Critical(prevCritical)
    }
    pruneMs := A_TickCount - tStart

    ToolTip("💾 Сохраняю словарь…")
    tSave := A_TickCount
    saved := SaveDictionary()
    SaveMetaInternal()
    saveMs := A_TickCount - tSave
    ToolTip()
    PopulateDictListView()
    UpdateDictionaryViewUi()
    resultText := "Удалено слов: " removed "`nОсталось: " WordDB.Count "`n`n"
        . "Чистка: " FormatSecondsShort(pruneMs) " · сохранение: " FormatSecondsShort(saveMs)
    if !saved
        resultText .= "`n`n⚠️ Словарь не удалось сохранить — изменения пока только в памяти."
    MsgBox(resultText, "Чистка слов", saved ? 0x40 : 0x30)
}

IsPrunableWordEntry(data, threshold) {
    ; Обычное слово с рейтингом ≤ порога. Основы и data-only записи не трогаем.
    if (data.HasOwnProp("IsStem") && data.IsStem)
        return false
    if (data.HasOwnProp("DataOnly") && data.DataOnly)
        return false
    count := data.HasOwnProp("Count") ? data.Count : 0
    return (count <= threshold)
}

; v13.16: строки вкладки «Исключённые» несут в скрытой 3-й колонке ref на
; настоящий ключ записи. Видимый текст — плоское превью (v13.17: без масок), а ref
; переживает и удаление строк, и сортировку по клику на заголовок.
AddHiddenPanelRow(shownText, kind, refKey, fullText) {
    global LV_Hidden, DictHiddenRowRefs
    ref := "h" (DictHiddenRowRefs.Count + 1)
    DictHiddenRowRefs[ref] := {Type: kind, Key: refKey, Text: fullText}
    return LV_Hidden.Add(, shownText, kind, ref)
}

GetHiddenPanelRowRef(row) {
    global LV_Hidden, DictHiddenRowRefs
    ref := ""
    try ref := LV_Hidden.GetText(row, 3)
    if (ref != "" && DictHiddenRowRefs.Has(ref))
        return DictHiddenRowRefs[ref]
    return 0
}

RestoreHiddenWord(guiObj, *) {
    global WordDB, PhraseDB, PromptDB, LinkDB, DictActiveView, LV_Hidden

    if (DictActiveView != "HIDDEN")
        return

    RowNumber := LV_Hidden.GetNext(0)
    if !RowNumber
        return

    itemText := StrLower(LV_Hidden.GetText(RowNumber, 1))
    itemType := LV_Hidden.GetText(RowNumber, 2)
    ; v13.16: настоящий ключ — из скрытой колонки (видимый текст может быть маской).
    hiddenRef := GetHiddenPanelRowRef(RowNumber)
    if IsObject(hiddenRef) {
        itemText := hiddenRef.Key
        itemType := hiddenRef.Type
    }
    if (itemType = "Фраза") {
        if PhraseDB.Has(itemText)
            PhraseDB[itemText].Hidden := 0
    } else if (itemType = "Промпт") {
        if PromptDB.Has(itemText)
            PromptDB[itemText].Hidden := 0
    } else if (itemType = "Ссылка") {
        if (IsObject(hiddenRef) && LinkDB.Has(hiddenRef.Key)) {
            LinkDB[hiddenRef.Key].Hidden := 0
        } else {
            for id, data in LinkDB {
                if (BuildLinkDisplay(data) = LV_Hidden.GetText(RowNumber, 1)) {
                    LinkDB[id].Hidden := 0
                    break
                }
            }
        }
    } else {
        if WordDB.Has(itemText)
            WordDB[itemText].Hidden := 0
    }

    HidePanelPreviewOsd()
    DeleteListViewRowPreservePlace(LV_Hidden, RowNumber)
}

; v13.16: пока базы расшифровываются, в памяти они пустые. Окна и кнопки,
; которые пишут в базы, в это время не срабатывают (панель F9 открывается раньше).
GuardTyperStartup() {
    global TyperStartupComplete
    if TyperStartupComplete
        return true
    ToolTip("⏳ Typer ещё расшифровывает базы — секунду…")
    SetTimer(() => ToolTip(), -1500)
    return false
}

SaveAllDataFromGui(*) {
    if !GuardTyperStartup()
        return
    SaveAllData()
    ToolTip("Сохранено")
    SetTimer(() => ToolTip(), -900)
}

EditSelectedPhraseFromPanel(guiObj, *) {
    global DictActiveView, LV_Phrases
    if (DictActiveView != "PHRASES")
        return

    row := LV_Phrases.GetNext(0)
    if !row
        return

    phraseText := LV_Phrases.GetText(row, 1)
    ShowPhraseEditGui(phraseText, Map("InsertAfterSave", false))
}

EditSelectedPromptFromPanel(guiObj, *) {
    global DictActiveView, LV_Prompts, DictPromptRowText
    if (DictActiveView != "PROMPTS")
        return
    row := LV_Prompts.GetNext(0)
    if !row
        return
    promptText := DictPromptRowText.Has(row) ? DictPromptRowText[row] : LV_Prompts.GetText(row, 1)
    ShowPromptEditGui(promptText)
}

GetSelectedDataIdFromPanel() {
    global DictActiveView, LV_Data, DataDB, DictDataRowIdMap
    if (DictActiveView != "DATA")
        return ""

    row := LV_Data.GetNext(0)
    if !row {
        ; Если пользователь отфильтровал список до одной карточки, Enter должен работать без лишнего клика по строке.
        try {
            if (LV_Data.GetCount() = 1)
                row := 1
        }
        if !row
            return ""
    }

    ; Самый надёжный путь: скрытая колонка ID. Она переживает сортировку ListView,
    ; потому что едет вместе со строкой, в отличие от внешней row->id карты.
    rowId := ""
    try rowId := LV_Data.GetText(row, 5)
    if (rowId != "" && DataDB.Has(rowId))
        return rowId

    ; Fallback для старого состояния/если скрытая колонка не создана.
    rowTitle := LV_Data.GetText(row, 1)
    rowNote := LV_Data.GetText(row, 2)
    rowState := LV_Data.GetText(row, 3)

    for id, data in DataDB {
        candidateTitle := data.Key != "" ? data.Key : (data.Login != "" ? data.Login : "[данные]")
        candidateState := data.IsPile ? "Свалка" : "Карточка"
        if (candidateTitle = rowTitle && data.Note = rowNote && candidateState = rowState)
            return id
    }

    if DictDataRowIdMap.Has(row)
        return DictDataRowIdMap[row]

    return ""
}
GetSelectedLinkIdFromPanel() {
    global DictActiveView, LV_Links, LinkDB
    if (DictActiveView != "LINKS")
        return ""
    row := LV_Links.GetNext(0)
    if !row
        return ""
    rowTitle := LV_Links.GetText(row, 1)
    rowUrl := LV_Links.GetText(row, 2)
    for id, data in LinkDB {
        title := data.Title != "" ? data.Title : GuessLinkTitleFromUrl(data.Url)
        if (title = rowTitle && data.Url = rowUrl)
            return id
    }
    return ""
}

EditSelectedLinkFromPanel(guiObj, *) {
    linkId := GetSelectedLinkIdFromPanel()
    if (linkId = "")
        return
    ShowLinkCaptureGui("", linkId)
}

EditSelectedDataFromPanel(guiObj, *) {
    dataId := GetSelectedDataIdFromPanel()
    if (dataId = "")
        return
    OpenDataCardGui(dataId)
}

ShowPhraseEditGui(sourcePhrase, options := 0) {
    global PhraseDB
    oldKey := StrLower(sourcePhrase)
    if !PhraseDB.Has(oldKey)
        return

    insertAfterSave := false
    targetHwnd := 0
    backspaces := 0
    if IsObject(options) {
        try insertAfterSave := options.Has("InsertAfterSave") ? options["InsertAfterSave"] : false
        try targetHwnd := options.Has("TargetHwnd") ? options["TargetHwnd"] : 0
        try backspaces := options.Has("Backspaces") ? options["Backspaces"] : 0
    }

    data := PhraseDB[oldKey]
    EditGui := CreateTyperDialog("+AlwaysOnTop +ToolWindow -MinimizeBox", "Правка фразы")
    EditGui.BackColor := "171717"
    EditGui.SetFont("s10 cF0F0F0", "Segoe UI")
    EditGui.MarginX := 12
    EditGui.MarginY := 10

    EditGui.Add("Text", "w620 h20", "Текст фразы:")
    PhraseEdit := EditGui.Add("Edit", "w620 h160 +Multi +VScroll -WantReturn Background2D2D2D cF0F0F0")
    ApplyDarkControlTheme(PhraseEdit)
    PhraseEdit.Value := data.Text
    BtnSave := CreateFlatTextButton(EditGui, "xm y+12 w170 h34", "Сохранить", SavePhraseEdit)
    BtnCancel := CreateFlatTextButton(EditGui, "x+m yp w120 h34", "Отмена", (*) => ClosePhraseEditGui(EditGui))
    HiddenDefaultBtn := EditGui.Add("Button", "x0 y0 w0 h0 Hidden Default", "OK")
    HiddenDefaultBtn.OnEvent("Click", SavePhraseEdit)
    EditGui.OnEvent("Escape", (*) => ClosePhraseEditGui(EditGui))
    EditGui.Show("AutoSize Center")
    SetEditCaretEnd(PhraseEdit)

    SavePhraseEdit(*) {
        global PhraseDB, CurrentInput
        newText := SanitizePhraseText(PhraseEdit.Value)
        if (newText = "") {
            ToolTip("⚠️ Пустая фраза")
            SetTimer(() => ToolTip(), -1000)
            return
        }

        newKey := StrLower(newText)
        if (newKey != oldKey && PhraseDB.Has(newKey)) {
            ToolTip("⚠️ Такая фраза уже есть")
            SetTimer(() => ToolTip(), -1200)
            return
        }

        oldData := PhraseDB[oldKey]
        if (newKey != oldKey) {
            PhraseDB.Delete(oldKey)
            RemovePhraseFromIndexes(oldKey)
            PhraseDB[newKey] := {Text: newText, Count: oldData.Count, Hidden: oldData.Hidden}
            AddPhraseToIndexes(newKey)
        } else {
            PhraseDB[oldKey].Text := newText
        }

        SavePhrasesInternal()
        PopulateDictListView()
        if (CurrentInput != "")
            ShowSuggestions()
        ClosePhraseEditGui(EditGui)

        if insertAfterSave && targetHwnd && backspaces > 0 {
            try {
                if WinExist("ahk_id " targetHwnd) {
                    WinActivate("ahk_id " targetHwnd)
                    WinWaitActive("ahk_id " targetHwnd, , 0.7)
                    HideSuggestions()
                    SafeSendPhrase(newText . " ", backspaces)
                    RememberInsertedText(newText, true, "PHRASE")
                    StartPhraseUndo(newText, true, "PHRASE")
                    LearnPhrase(newText, 1)
                    FinalizeTypingState(false, true)
                }
            }
        }
    }
}


ShowPromptEditGui(sourcePrompt, newCat := "") {
    ; v13.21: + категория (чипы, Ctrl+1…4). Пустой sourcePrompt — новый промпт
    ; (кнопка «+ Новый» / меню ПКМ на вкладке «Промпты»); категория нового —
    ; из фильтра вкладки, если он не «Все», иначе последняя выбранная.
    global PromptDB, PanelPromptCatFilter, PromptLastCaptureCat
    isNew := (sourcePrompt = "")
    oldKey := StrLower(sourcePrompt)
    if (!isNew && !PromptDB.Has(oldKey))
        return

    if isNew
        startCat := (newCat != "") ? newCat : ((PanelPromptCatFilter != "ALL") ? PanelPromptCatFilter : PromptLastCaptureCat)
    else
        startCat := GetPromptCat(PromptDB[oldKey])
    EditGui := CreateTyperDialog("+AlwaysOnTop +ToolWindow -MinimizeBox", isNew ? "Новый промпт" : "Правка промпта")
    EditGui.BackColor := "171717"
    EditGui.SetFont("s10 cF0F0F0", "Segoe UI")
    EditGui.MarginX := 12
    EditGui.MarginY := 10

    EditGui.Add("Text", "xm w86 h26 +0x200 cB8B8B8", "Категория:")
    catRow := CreatePromptCatChipRow(EditGui, "x+6 yp", startCat, 92, 26)
    EditGui.Add("Text", "x+10 yp w80 h26 +0x200 c6E6E6E", "Ctrl+1…4")
    RegisterPromptCatRow(EditGui, catRow)
    EditGui.Add("Text", "xm y+10 w620 h20", "Текст промпта:")
    PromptEdit := EditGui.Add("Edit", "xm w620 h220 +Multi +VScroll Background2D2D2D cF0F0F0")
    ApplyDarkControlTheme(PromptEdit)
    if !isNew
        PromptEdit.Value := PromptDB[oldKey].Text
    BtnSave := CreateFlatTextButton(EditGui, "xm y+12 w170 h34", "Сохранить", SavePromptEdit)
    BtnCancel := CreateFlatTextButton(EditGui, "x+m yp w120 h34", "Отмена", ClosePromptEdit)
    EditGui.OnEvent("Escape", ClosePromptEdit)
    EditGui.OnEvent("Close", ClosePromptEdit)
    EditGui.Show("AutoSize Center")
    SetEditCaretEnd(PromptEdit)

    ClosePromptEdit(*) {
        UnregisterPromptCatRow(EditGui)
        try EditGui.Destroy()
    }

    SavePromptEdit(*) {
        global PromptDB, CurrentInput
        newText := SanitizePromptText(PromptEdit.Value)
        if (newText = "") {
            ToolTip("⚠️ Пустой промпт")
            SetTimer(() => ToolTip(), -1000)
            return
        }
        newKey := StrLower(newText)
        promptCat := NormalizePromptCat(catRow.Cat)
        if isNew {
            if PromptDB.Has(newKey) {
                ToolTip("⚠️ Такой промпт уже есть")
                SetTimer(() => ToolTip(), -1200)
                return
            }
            PromptDB[newKey] := {Text: newText, Count: 1, Hidden: 0, Cat: promptCat}
            AddPromptToIndexes(newKey)
            RememberPromptCaptureCat(promptCat)
        } else {
            if (newKey != oldKey && PromptDB.Has(newKey)) {
                ToolTip("⚠️ Такой промпт уже есть")
                SetTimer(() => ToolTip(), -1200)
                return
            }
            if !PromptDB.Has(oldKey) {
                ; Пока окно было открыто, промпт удалили (панель / OSD).
                ToolTip("⚠️ Промпт уже удалён")
                SetTimer(() => ToolTip(), -1200)
                ClosePromptEdit()
                return
            }
            oldData := PromptDB[oldKey]
            if (newKey != oldKey) {
                PromptDB.Delete(oldKey)
                RemovePromptFromIndexes(oldKey)
                PromptDB[newKey] := {Text: newText, Count: oldData.Count, Hidden: oldData.Hidden, Cat: promptCat}
                AddPromptToIndexes(newKey)
            } else {
                PromptDB[oldKey].Text := newText
                PromptDB[oldKey].Cat := promptCat
            }
        }
        SavePromptsInternal()
        PopulateDictListView()
        if (CurrentInput != "")
            ShowSuggestions()
        ClosePromptEdit()
    }
}

ClosePhraseEditGui(editGui) {
    try editGui.Destroy()
}

ToggleLCtrlCommaFromGui(ctrl, *) {
    global EnableLCtrlComma
    EnableLCtrlComma := !!ctrl.Value
    SaveSettingsInternal()
}

ToggleRCtrlPeriodFromGui(ctrl, *) {
    global EnableRCtrlPeriod
    EnableRCtrlPeriod := !!ctrl.Value
    SaveSettingsInternal()
}

TogglePgKeysModeFromGui(ctrl, *) {
    global PgKeysModeEnabled
    PgKeysModeEnabled := !!ctrl.Value
    SaveSettingsInternal()
    ToolTip(PgKeysModeEnabled ? "PgUp/PgDn — режимы 1/11 и 2/22" : "PgUp/PgDn — обычная прокрутка")
    SetTimer(() => ToolTip(), -1400)
}

TogglePanelOpenPromptsFromGui(ctrl, *) {
    ; v13.17: стартовая вкладка F9 — «Промпты» (вкл.) или «Справка» (выкл.).
    global PanelOpenPromptsByDefault
    PanelOpenPromptsByDefault := !!ctrl.Value
    SaveSettingsInternal()
    ToolTip(PanelOpenPromptsByDefault ? "F9 откроется на вкладке «Промпты»" : "F9 откроется на «Справке»")
    SetTimer(() => ToolTip(), -1400)
}

TogglePanelPromptClickCopyFromGui(ctrl, *) {
    ; v13.17: ЛКМ по промпту (вкладка «Промпты» и общий поиск) — копия в буфер.
    global PanelPromptClickCopy
    PanelPromptClickCopy := !!ctrl.Value
    SaveSettingsInternal()
}

ToggleDataPasswordsHiddenFromGui(ctrl, *) {
    ; v13.22: OSD Данных, превью панели и карточка — без символов пароля.
    global DataPasswordsHidden
    DataPasswordsHidden := !!ctrl.Value
    SaveSettingsInternal()
    HidePanelPreviewOsd()
    ToolTip(DataPasswordsHidden ? "🔒 Пароли Данных скрыты" : "Пароли Данных — с коротким намёком")
    SetTimer(() => ToolTip(), -1400)
}

HandleDataPileModeChanged(ctrl, *) {
    global DictDataPileMode
    DictDataPileMode := (ctrl.Value = 2) ? "NOPILE" : ((ctrl.Value = 3) ? "PILE" : "ALL")
    HidePanelPreviewOsd()
    PopulateDictListView()
}

ToggleInsertCaptureFromGui(ctrl, *) {
    global InsertCaptureEnabled
    InsertCaptureEnabled := !!ctrl.Value
    SaveSettingsInternal()
    ToolTip(InsertCaptureEnabled ? "Insert захватывается Typer" : "Insert временно родной")
    SetTimer(() => ToolTip(), -1200)
    try UpdateDictionaryViewUi()
}
; #EndRegion

; #Region 🔑 СМЕНА ПАРОЛЯ


BuildCurrentStoreSpecs() {
    global DictFile, HotstringsFile, LockFile, MetaFile, SettingsFile, PhraseFile, PromptFile, DataFile, LinkFile, HotInsertFile, InsertCaptureEnabled
    if HasCorruptStores()
        throw Error("Cannot rekey/save specs while some containers are corrupt/unloaded")
    specs := []
    specs.Push({Name: "settings", Path: SettingsFile, Plain: BuildSettingsPlainText(), Optional: false})
    specs.Push({Name: "dictionary", Path: DictFile, Plain: GetDictionaryPlainForSpecs(), Optional: true}) ; v13.18
    specs.Push({Name: "hotstrings", Path: HotstringsFile, Plain: LoadHotstringsPlainText(), Optional: true})
    specs.Push({Name: "phrases", Path: PhraseFile, Plain: LoadPhrasesPlainText(), Optional: true})
    specs.Push({Name: "prompts", Path: PromptFile, Plain: LoadPromptsPlainText(), Optional: true})
    specs.Push({Name: "data", Path: DataFile, Plain: LoadDataPlainText(), Optional: true})
    specs.Push({Name: "links", Path: LinkFile, Plain: LoadLinksPlainText(), Optional: true})
    specs.Push({Name: "hotinserts", Path: HotInsertFile, Plain: LoadHotInsertsPlainText(), Optional: true})
    specs.Push({Name: "meta", Path: MetaFile, Plain: LoadMetaPlainText(), Optional: true})
    ; v13.16: lock — последним. Если смена пароля оборвётся посередине, lock ещё под
    ; старым паролем, а уже переписанные базы откроются старым паролем из .bak.
    specs.Push({Name: "lock", Path: LockFile, Plain: "VERIFIED_OK", Optional: false})
    return specs
}

CaptureCurrentEncryptedStoreState(specs) {
    for spec in specs {
        spec.PreviousEnc := ""
        if FileExist(spec.Path) || FileExist(spec.Path ".bak")
            spec.PreviousEnc := ReadTextFileWithBak(spec.Path)
    }
    return specs
}

RestoreEncryptedStoreState(specs) {
    restored := true
    for spec in specs {
        try {
            if (spec.PreviousEnc = "") {
                if FileExist(spec.Path)
                    FileDelete(spec.Path)
                if FileExist(spec.Path ".bak")
                    FileDelete(spec.Path ".bak")
                if FileExist(spec.Path ".tmp")
                    FileDelete(spec.Path ".tmp")
                continue
            }

            if !WriteTextFileAtomic(spec.Path, spec.PreviousEnc)
                restored := false
        } catch {
            restored := false
        }
    }
    CleanupTransientFiles()
    return restored
}

PrepareEncryptedStoreSpecs(specs, password) {
    for spec in specs {
        if (spec.Optional && spec.Plain = "") {
            spec.Enc := ""
            continue
        }
        spec.Enc := Crypto.Encrypt(spec.Plain, password)
        if (spec.Enc = "")
            return false
        if (Crypto.Decrypt(spec.Enc, password) !== spec.Plain)
            return false
    }
    return true
}

RestoreTargetsFromBak(targets) {
    for filePath in targets {
        try {
            if FileExist(filePath ".bak") {
                if FileExist(filePath)
                    FileDelete(filePath)
                FileMove(filePath ".bak", filePath, 1)
            }
        }
    }
}

DeleteStoreBackupArtifacts(specs) {
    ; После успешного rekey старые .bak могут быть зашифрованы прежним паролем.
    ; Удаляем их только когда новые контейнеры уже записаны и проверены.
    for spec in specs {
        try {
            if FileExist(spec.Path ".bak")
                FileDelete(spec.Path ".bak")
            if FileExist(spec.Path ".tmp")
                FileDelete(spec.Path ".tmp")
            if FileExist(spec.Path ".rekey")
                FileDelete(spec.Path ".rekey")
        }
    }
}

CommitEncryptedStoreSpecs(specs) {
    touched := []
    for spec in specs {
        if (spec.Optional && spec.Enc = "")
            continue
        if !WriteTextFileAtomic(spec.Path, spec.Enc) {
            RestoreTargetsFromBak(touched)
            return false
        }
        touched.Push(spec.Path)
    }

    for spec in specs {
        if (spec.Optional && spec.Enc = "") {
            try {
                if FileExist(spec.Path)
                    FileDelete(spec.Path)
                if FileExist(spec.Path ".bak")
                    FileDelete(spec.Path ".bak")
                if FileExist(spec.Path ".tmp")
                    FileDelete(spec.Path ".tmp")
            }
        }
    }
    return true
}

VerifyCurrentStoresWithPassword(password) {
    if HasCorruptStores()
        return false
    try {
        specs := BuildCurrentStoreSpecs()
    } catch {
        return false
    }
    for spec in specs {
        if (spec.Optional && spec.Plain = "")
            continue
        dec := ReadDecryptedTextWithBak(spec.Path, password)
        if (dec !== spec.Plain)
            return false
    }
    return true
}

LoadDictionaryPlainText() {
    global WordDB
    out := ""
    VarSetStrCapacity(&out, WordDB.Count * 48 + 64) ; v13.18: без десятков переаллокаций
    for key, data in WordDB {
        hidden := data.HasOwnProp("Hidden") ? data.Hidden : 0
        isStem := data.HasOwnProp("IsStem") ? data.IsStem : 0
        dataOnly := data.HasOwnProp("DataOnly") ? data.DataOnly : 0
        ; D2-формат: display хранится кодированным, чтобы пароли/логины с =, |, \ и прочими
        ; символами не ломали парсер словаря. Старый формат word=count=... читается ниже
        ; через legacy-parser для совместимости и восстановления уже сохранённых строк.
        out .= "D2|" EncodePhraseText(data.Display) "|" data.Count "|" hidden "|" isStem "|" dataOnly "`n"
    }
    return out
}

LoadHotstringsPlainText() {
    global MyHotstrings
    out := ""
    for abbr, data in MyHotstrings {
        opts := ":" . (data.Immediate ? "*" : "") . (data.AddSpace ? "S" : "") . ":"
        out .= opts "|" abbr "|" StrReplace(data.Repl, "`n", "``n") "`n"
    }
    return out
}

LoadMetaPlainText() {
    global NoSpaceWords
    out := ""
    for key in NoSpaceWords
        out .= key "`n"
    return out
}

ChangePasswordGUI() {
    global MasterPassword
    if !GuardTyperStartup()
        return
    CpGui := CreateTyperDialog("-MinimizeBox +AlwaysOnTop +ToolWindow", "Смена системного ключа")
    CpGui.BackColor := "111111"
    CpGui.SetFont("s10 cWhite", "Segoe UI")
    CpGui.MarginX := 14
    CpGui.MarginY := 12

    CpGui.Add("Text", "w290 Center Background111111", "Новый пароль:")
    PassEdit1 := CpGui.Add("Edit", "w290 h26 Password Center Background333333 -E0x200")
    CpGui.Add("Text", "xm w290 Center Background111111 y+10", "Повторите пароль:")
    PassEdit2 := CpGui.Add("Edit", "w290 h26 Password Center Background333333 -E0x200")
    CpGui.Add("Text", "xm w290 Center cAAAAAA Background111111 y+10", "Рекомендуется длинная уникальная фраза")

    BtnSave := CpGui.Add("Button", "xm w140 h34 Default y+12", "Сохранить")
    BtnCancel := CpGui.Add("Button", "x+m w140 h34", "Отмена")

    BtnCancel.OnEvent("Click", (*) => CpGui.Destroy())
    BtnSave.OnEvent("Click", SaveNewPassword)
    CpGui.OnEvent("Escape", (*) => CpGui.Destroy())
    CpGui.Show("AutoSize Center")
    SetEditCaretEnd(PassEdit1)

    SaveNewPassword(*) {
        global DevAllowShortMasterPassword, TyperStartupComplete
        ; v13.16: смену ключа не прерывают автосохранения и хоткеи — иначе
        ; отложенная запись базы могла вклиниться между шагами.
        Critical
        oldPassword := MasterPassword
        P1 := PassEdit1.Value, P2 := PassEdit2.Value

        if (P1 == "" || P2 == "") {
            ToolTip("⚠️ Пароль не может быть пустым!"), SetTimer(() => ToolTip(), -2000)
            return
        }
        if (P1 !== P2) { ; v13.16: с учётом регистра (раньше MyPass и mypass считались одинаковыми)
            ToolTip("⚠️ Пароли не совпадают!"), SetTimer(() => ToolTip(), -2000)
            return
        }
        if (StrLen(P1) < MinMasterPasswordLen) {
            if !DevAllowShortMasterPassword {
                ToolTip("⚠️ Лучше использовать пароль от " MinMasterPasswordLen " символов"), SetTimer(() => ToolTip(), -2200)
                return
            }
            ToolTip("⚠️ Короткий пароль разрешён только для dev-режима"), SetTimer(() => ToolTip(), -2200)
        }

        if !TyperStartupComplete {
            ToolTip("⏳ Базы ещё загружаются — смена пароля чуть позже"), SetTimer(() => ToolTip(), -2200)
            return
        }
        if HasCorruptStores() {
            WarnIfStoresCorrupt()
            ToolTip("⚠️ Смена пароля заблокирована: не все базы загружены")
            SetTimer(() => ToolTip(), -2800)
            return
        }

        ; v13.18: выключенный словарь читается из файла — тот может не открыться.
        try {
            specs := BuildCurrentStoreSpecs()
        } catch as specErr {
            ToolTip("⚠️ Смена пароля отменена: " specErr.Message), SetTimer(() => ToolTip(), -3200)
            return
        }
        CaptureCurrentEncryptedStoreState(specs)

        ; v13.16: новый пароль — новая соль сессии (при откате вернём прежнюю).
        prevSalt := Crypto.SessionSalt
        newSalt := Crypto.RandomBytes(Crypto.SaltSize)
        if IsObject(newSalt)
            Crypto.SessionSalt := newSalt

        ForgetStoreFingerprints() ; v13.19: после смены пароля всё пишется заново
        if !PrepareEncryptedStoreSpecs(specs, P1) {
            Crypto.SessionSalt := prevSalt
            ToolTip("⚠️ Не удалось подготовить новые контейнеры"), SetTimer(() => ToolTip(), -2500)
            return
        }
        if !CommitEncryptedStoreSpecs(specs) {
            Crypto.SessionSalt := prevSalt
            ToolTip("⚠️ Не удалось записать новые контейнеры"), SetTimer(() => ToolTip(), -2500)
            return
        }

        MasterPassword := P1
        CleanupTransientFiles()
        ok := VerifyCurrentStoresWithPassword(MasterPassword)

        if !ok {
            rollbackOk := RestoreEncryptedStoreState(specs)
            MasterPassword := oldPassword
            Crypto.SessionSalt := prevSalt
            oldStateOk := rollbackOk && VerifyCurrentStoresWithPassword(oldPassword)

            if !oldStateOk {
                ToolTip("⚠️ Смена пароля сорвалась, откат нужно проверить вручную"), SetTimer(() => ToolTip(), -3200)
                return
            }

            ToolTip("⚠️ Не удалось безопасно сменить пароль, выполнен откат"), SetTimer(() => ToolTip(), -2800)
            return
        }

        DeleteStoreBackupArtifacts(specs)
        ; v13.16: ключи старого пароля больше не нужны — убираем из кэша.
        Crypto.ForgetPassword(oldPassword)
        CpGui.Destroy()
        ToolTip("✅ Пароль изменен")
        SetTimer(() => ToolTip(), -2200)
    }
}
; #EndRegion

; #Region 📂 РАБОТА С ФАЙЛАМИ (СЛОВАРЬ)
LoadDictionary() {
    global WordDB, DictFile
    WordDB := Map()
    LoadEncryptedContainer(DictFile, "dictionary", ParseDictionaryLine)
}

TryParseLegacyDictionaryLine(line, &display, &count, &hidden, &isStem, &dataOnly) {
    display := "", count := 0, hidden := 0, isStem := 0, dataOnly := 0
    parts := StrSplit(line, "=")
    if (parts.Length < 2)
        return false

    maxTail := Min(4, parts.Length - 1)
    tailLen := 0
    displayPartsCount := 0

    ; Берём числовые поля справа. Это чинит старый формат display=count=hidden=isStem=dataOnly,
    ; даже если сам display содержит символ =, например сырой пароль или уже повреждённая строка.
    Loop maxTail {
        candidate := maxTail - A_Index + 1
        startIdx := parts.Length - candidate + 1
        ok := true
        Loop candidate {
            idx := startIdx + A_Index - 1
            if !RegExMatch(parts[idx], "^-?\d+$") {
                ok := false
                break
            }
        }
        if ok {
            tailLen := candidate
            displayPartsCount := parts.Length - tailLen
            break
        }
    }

    if (tailLen = 0 || displayPartsCount < 1)
        return false

    Loop displayPartsCount
        display .= (A_Index > 1 ? "=" : "") parts[A_Index]

    if (display = "")
        return false

    baseIdx := displayPartsCount + 1
    count := Integer(parts[baseIdx])
    hidden := (tailLen >= 2) ? Integer(parts[baseIdx + 1]) : 0
    isStem := (tailLen >= 3) ? Integer(parts[baseIdx + 2]) : 0
    dataOnly := (tailLen >= 4) ? Integer(parts[baseIdx + 3]) : 0
    return true
}

ParseDictionaryLine(line) {
    global WordDB
    display := "", count := 0, hidden := 0, isStem := 0, dataOnly := 0

    ; Новый безопасный формат словаря. Нужен потому что в Исключённые теперь можно
    ; заносить сырой пароль/логин, а там запросто бывают =, | и прочие разделители.
    if (SubStr(line, 1, 3) = "D2|") {
        parts := StrSplit(line, "|",, 6)
        if (parts.Length < 6)
            return
        display := DecodePhraseText(parts[2])
        count := Integer(parts[3])
        hidden := Integer(parts[4])
        isStem := Integer(parts[5])
        dataOnly := Integer(parts[6])

        ; Ремонт последствий step5al: если старая строка вида word=32=0=0 была ошибочно
        ; сохранена как D2-display целиком, в GUI получалось word=32=0=0 с рейтингом 0.
        ; При count=0 пробуем распознать такой display как legacy-строку и восстановить поля.
        if (count = 0 && InStr(display, "=")) {
            repairedDisplay := "", repairedCount := 0, repairedHidden := 0, repairedStem := 0, repairedDataOnly := 0
            if TryParseLegacyDictionaryLine(display, &repairedDisplay, &repairedCount, &repairedHidden, &repairedStem, &repairedDataOnly) {
                display := repairedDisplay
                count := repairedCount
                hidden := repairedHidden
                isStem := repairedStem
                dataOnly := repairedDataOnly
            }
        }
    } else {
        if !TryParseLegacyDictionaryLine(line, &display, &count, &hidden, &isStem, &dataOnly)
            return
    }

    if (display = "")
        return

    ; Старый формат хранил основу как count + 1_000_000. Совместимость со старыми .bin.
    if (count >= 1000000) {
        isStem := 1
        count -= 1000000
        if (count < 0)
            count := 0
    }

    WordDB[StrLower(display)] := {Display: display, Count: count, Hidden: hidden, IsStem: isStem, DataOnly: dataOnly}
}

SaveDictionary() {
    global DictFile
    return SaveEncryptedContainer(DictFile, LoadDictionaryPlainText(), "dictionary")
}

; ---- v13.18: режим словаря ----------------------------------------------------
; full   — как раньше: каждое набранное слово запоминается;
; manual — новые слова только вручную (RShift, выделение + RShift, «\» — основа);
;          у уже известных слов рейтинг растёт при наборе и выборе из OSD;
; off    — словарь не расшифровывается при старте и не пишется на диск (файл
;          остаётся как есть), OSD слов нет. Фразы, промпты, ссылки, Данные,
;          горячие вставки и автозамены работают как обычно.
NormalizeDictMode(mode) {
    mode := StrLower(Trim(mode))
    return (mode = "manual" || mode = "off") ? mode : "full"
}

GetDictModeChoices() {
    return ["Полный — запоминать все набранные слова", "Ручной — новые слова только через RShift", "Выключен — не загружать словарь (быстрый старт)"]
}

GetDictModeIndex(mode) {
    return (mode = "manual") ? 2 : (mode = "off") ? 3 : 1
}

GetDictModeName(mode) {
    return (mode = "manual") ? "ручной" : (mode = "off") ? "выключен" : "полный"
}

IsDictionaryActive() {
    ; Словарь включён и уже прочитан с диска.
    global DictMode
    return (DictMode != "off") && IsStoreLoaded("dictionary")
}

ShowDictionaryOffTip() {
    ToolTip("📕 Словарь выключен (F9 → Настройки → Словарь)")
    SetTimer(() => ToolTip(), -1600)
}

UnloadDictionaryFromMemory() {
    ; Пустой WordDB + снятая отметка «прочитан»: SaveEncryptedContainer после
    ; этого файл словаря не трогает (см. IsStoreLoaded).
    global WordDB, PrefixIndex1, PrefixIndex2, WordIndexVersion
    WordDB := Map()
    PrefixIndex1 := Map()
    PrefixIndex2 := Map()
    WordIndexVersion += 1 ; v13.19
    MarkStoreUnloaded("dictionary")
}

LoadDictionaryNow() {
    ; Подгрузка словаря на лету (режим включили из Настроек). Под Critical —
    ; чтобы набор в другом окне не видел полупрочитанную базу.
    prevCritical := Critical("On")
    try {
        LoadDictionary()
        RebuildPrefixIndexes()
    } finally {
        Critical(prevCritical)
    }
    return IsStoreLoaded("dictionary")
}

SetDictionaryMode(newMode) {
    global DictMode, TyperStartupComplete
    newMode := NormalizeDictMode(newMode)
    if (newMode = DictMode)
        return true
    if !TyperStartupComplete {
        ToolTip("⏳ Дождись окончания загрузки баз — потом меняй режим словаря")
        SetTimer(() => ToolTip(), -1800)
        return false
    }

    if (newMode = "off") {
        if IsStoreLoaded("dictionary") {
            answer := MsgBox("Выключить словарь?`n`n"
                . "Слова останутся в зашифрованном файле и вернутся, когда словарь снова включишь. "
                . "Пока он выключен, он не расшифровывается при запуске, не подсказывает и не запоминает слова.`n`n"
                . "Фразы, промпты, ссылки, Данные, горячие вставки и автозамены работают как обычно.",
                "Словарь", 0x24)
            if (answer != "Yes")
                return false
            ToolTip("💾 Сохраняю словарь…")
            saved := SaveDictionary()
            ToolTip()
            if (!saved && !IsStoreCorrupt("dictionary")) {
                MsgBox("Не удалось сохранить словарь — режим не изменён.", "Словарь", 0x30)
                return false
            }
        }
        HideSuggestions()
        DictMode := "off"
        UnloadDictionaryFromMemory()
    } else {
        wasOff := (DictMode = "off")
        DictMode := newMode
        if (wasOff && !IsStoreLoaded("dictionary") && !IsStoreCorrupt("dictionary")) {
            ToolTip("⏳ Загружаю словарь…")
            ok := LoadDictionaryNow()
            ToolTip()
            if !ok
                WarnIfStoresCorrupt()
        }
    }

    SaveSettingsInternal()
    MarkDictViewsDirty()
    try UpdateDictionaryViewUi()
    ToolTip("📗 Словарь: " GetDictModeName(DictMode))
    SetTimer(() => ToolTip(), -1400)
    return true
}

ApplyDictModeFromGui(ctrl, *) {
    global DictMode
    modes := ["full", "manual", "off"]
    idx := 0
    try idx := ctrl.Value
    if (idx < 1 || idx > modes.Length)
        return
    if !SetDictionaryMode(modes[idx])
        try ctrl.Choose(GetDictModeIndex(DictMode))
}

GetDictionaryPlainForSpecs() {
    ; v13.18: для смены пароля. Словарь в памяти — как раньше. Выключенный
    ; словарь в памяти пуст: берём содержимое файла как есть, иначе смена
    ; пароля записала бы пустую базу (а CommitEncryptedStoreSpecs удалил бы файл).
    global DictFile, MasterPassword
    if IsStoreLoaded("dictionary")
        return LoadDictionaryPlainText()
    if !FileExist(DictFile) && !FileExist(DictFile ".bak")
        return ""
    plain := ReadDecryptedTextWithBak(DictFile, MasterPassword)
    if (plain = "")
        throw Error("файл словаря не расшифровался")
    return plain
}

SaveAllData(*) {
    ; Сбрасываем все отложенные дебаунсы, чтобы Save* отработали один раз и не
    ; повторялись через несколько сотен мс уже после флушa.
    SetTimer(SaveDataInternal, 0)
    SetTimer(SaveQueuedPhrases, 0)
    SetTimer(SavePromptsInternal, 0) ; v13.21: QueuePromptSave
    SetTimer(SaveLinksInternal, 0)
    SetTimer(SaveSettingsInternal, 0) ; v13.19

    SaveDictionary()
    SavePhrasesInternal()
    SavePromptsInternal()
    SaveLinksInternal()
    SaveDataInternal()
    SaveHotInsertsInternal()
    SaveMetaInternal()
    SaveHotstringsToFile()
    SaveSettingsInternal()
}

ExitFunc(ExitReason, ExitCode) {
    global LastDataClipboardExpected, LastDataClipboardStamp
    RestoreSecretClipboardIfStillCurrent(LastDataClipboardExpected, LastDataClipboardStamp, "exit")
    SaveAllData()
    CleanupTransientFiles()
    ReleaseTyperInstanceLock()
}
; #EndRegion

; #Region ⌨️ ГОРЯЧИЕ КЛАВИШИ ПОДСКАЗОК И ЗНАКОВ ПРЕПИНАНИЯ
; v13.19: в условиях #HotIf дешёвые проверки (SuggestionVisible, режим OSD)
; стоят ПЕРВЫМИ. Условие вычисляется на каждое нажатие клавиши-хоткея (цифры,
; стрелки, LShift, «-»/«=», Delete…), и раньше каждое такое нажатие при
; закрытом OSD сначала гоняло IsTyperInputContext (WinActive по группе окон +
; поиск по спискам разрешённых окон). && останавливается на первом false.
#HotIf SuggestionVisible && IsTyperInputContext() && !IsDetachedSnippetEditorActive()

~Up::HandlePointerAction()
~Down::HandlePointerAction()
~Left::HandlePointerAction()
~Right::HandlePointerAction()
~Home::HandlePointerAction()
~End::HandlePointerAction()

#HotIf SuggestionVisible && !PgKeysModeEnabled && IsTyperInputContext() && !IsDetachedSnippetEditorActive()
~PgUp::HandlePointerAction()
~PgDn::HandlePointerAction()
#HotIf SuggestionVisible && IsTyperInputContext() && !IsDetachedSnippetEditorActive()

; v13.16: CapsLock при открытом OSD больше не перехватывается: он листал регистр
; подсказок и мешал основному скрипту со сменой языка на CapsLock.

~LShift:: {
    global ShiftPressTime := A_TickCount
}
~LShift Up:: {
    global ShiftPressTime, TapThreshold
    if (A_PriorKey = "LShift" && (A_TickCount - ShiftPressTime < TapThreshold))
        ConfirmAction("STEM", 0)
}

1::SelectWordOrSendDigit(1)
2::SelectWordOrSendDigit(2)
3::SelectWordOrSendDigit(3)
4::SelectWordOrSendDigit(4)
5::SelectWordOrSendDigit(5)
6::SelectWordOrSendDigit(6)
7::SelectWordOrSendDigit(7)
8::SelectWordOrSendDigit(8)
9::SelectWordOrSendDigit(9)
0::SelectWordOrSendDigit(10)

#HotIf SuggestionVisible && IsSnippetSuggestionMode(CurrentSuggestionMode) && IsTyperInputContext() && !IsDetachedSnippetEditorActive()
-::CyclePhraseSelection(-1)
=::CyclePhraseSelection(1)
Delete::DeleteSuggestedPhraseByIndex(SelectedPhraseIndex)
; v13.20: RShift tap в OSD фраз/промптов/ссылок — как LShift: вставить вариант,
; выбранный «-»/«=». Раньше при открытом OSD RShift ничего не делал (его
; «запомнить слово» работает только при закрытом OSD — блок ниже).
~RShift:: {
    global RShiftPressTime := A_TickCount
}
~RShift Up:: {
    global RShiftPressTime, TapThreshold
    if (A_PriorKey = "RShift" && (A_TickCount - RShiftPressTime < TapThreshold))
        ConfirmAction("STEM", 0)
}
#HotIf SuggestionVisible && IsSnippetSuggestionMode(CurrentSuggestionMode) && !GetKeyState("Shift", "P") && IsTyperInputContext() && !IsDetachedSnippetEditorActive()
sc02B::OpenDetachedSnippetEditor(CurrentSuggestionMode, SelectedPhraseIndex)
vkDC::OpenDetachedSnippetEditor(CurrentSuggestionMode, SelectedPhraseIndex)

; v13.16: «\» — фиксация основы. Перехватывается только там, где работает Typer
; (его приложения, не пауза Win+T, не поле пароля, не отдельный редактор).
; В остальных местах это обычный «\». Shift+\ не трогаем: в RU — «/», в EN — «|».
; Вариант для OSD фраз выше объявлен раньше и поэтому проверяется первым.
; v13.17: ПОЧЕМУ «\» НЕ РАБОТАЛ. Хоткеи ^sc02B/!sc02B (Ctrl+\ и Alt+\) заданы
; скан-кодом, а такой хоткей включает для всего скан-кода 0x2B поиск по таблице
; скан-кодов (sc_takes_precedence в hook.cpp). Хоткей «\::» записан по VK и
; поэтому для этой клавиши не находился никогда — «\» просто печатался. Теперь
; хоткей задан и скан-кодом (sc02B — обычная клавиша), и по VK (vkDC — если
; «\» приходит с другим скан-кодом, например на клавиатурах ISO/102).
#HotIf IsTyperInputContext() && !IsDetachedSnippetEditorActive() && !IsPasswordFieldActive()
sc02B::HandleTyperBackslashKey()
vkDC::HandleTyperBackslashKey()

#HotIf SuggestionVisible && CurrentStems.Length > 1 && !IsSnippetSuggestionMode(CurrentSuggestionMode) && IsTyperInputContext()
-::CycleStemSelection(-1)
=::CycleStemSelection(1)

#HotIf SuggestionVisible && !IsSnippetSuggestionMode(CurrentSuggestionMode) && IsTyperInputContext()
~Delete::HandlePointerAction()

#HotIf IsDetachedSnippetEditorActive()
Enter::ConfirmDetachedSnippetEditorAndInsert()
Escape::CancelDetachedSnippetEditor()
#HotIf

#HotIf SuggestionVisible && IsSnippetSuggestionMode(CurrentSuggestionMode) && IsTyperInputContext()
^1::EditSuggestedPhraseByIndex(1)
^2::EditSuggestedPhraseByIndex(2)
^3::EditSuggestedPhraseByIndex(3)
^4::EditSuggestedPhraseByIndex(4)
^5::EditSuggestedPhraseByIndex(5)
^6::EditSuggestedPhraseByIndex(6) ; v13.19: фраз и промптов в OSD до 8
^7::EditSuggestedPhraseByIndex(7)
^8::EditSuggestedPhraseByIndex(8)
!6::HideSuggestedWordByIndex(6)
!7::HideSuggestedWordByIndex(7)
!8::HideSuggestedWordByIndex(8)

#HotIf SuggestionVisible && (CurrentSuggestionMode = "DATA") && IsTyperInputContext()
^1::OpenSelectedDataFromOsd(1)
^2::OpenSelectedDataFromOsd(2)
^3::OpenSelectedDataFromOsd(3)
^4::OpenSelectedDataFromOsd(4)
^5::OpenSelectedDataFromOsd(5)
^6::OpenSelectedDataFromOsd(6)
^7::OpenSelectedDataFromOsd(7)
^8::OpenSelectedDataFromOsd(8)
^9::OpenSelectedDataFromOsd(9)
^0::OpenSelectedDataFromOsd(10)

#HotIf
; Глобальная сводка слотов Ctrl+1…9. Контекстные ^0 выше (режим DATA в OSD)
; имеют приоритет, когда их #HotIf активен — конфликтов нет.
^0::ShowCtrlSlotsSummary()

#HotIf SuggestionVisible && (CurrentSuggestionMode = "WORDS") && IsTyperInputContext()
>!1::RedirectSuggestedWordToDataByIndex(1)
>!2::RedirectSuggestedWordToDataByIndex(2)
>!3::RedirectSuggestedWordToDataByIndex(3)
>!4::RedirectSuggestedWordToDataByIndex(4)
>!5::RedirectSuggestedWordToDataByIndex(5)
<^>!1::RedirectSuggestedWordToDataByIndex(1)
<^>!2::RedirectSuggestedWordToDataByIndex(2)
<^>!3::RedirectSuggestedWordToDataByIndex(3)
<^>!4::RedirectSuggestedWordToDataByIndex(4)
<^>!5::RedirectSuggestedWordToDataByIndex(5)

#HotIf SuggestionVisible && IsTyperInputContext()

!1::HideSuggestedWordByIndex(1)
!2::HideSuggestedWordByIndex(2)
!3::HideSuggestedWordByIndex(3)
!4::HideSuggestedWordByIndex(4)
!5::HideSuggestedWordByIndex(5)

!Numpad1::HideSuggestedStemByIndex(1)
!NumpadEnd::HideSuggestedStemByIndex(1)
!Numpad2::HideSuggestedStemByIndex(2)
!NumpadDown::HideSuggestedStemByIndex(2)
!Numpad3::HideSuggestedStemByIndex(3)
!NumpadPgDn::HideSuggestedStemByIndex(3)
!Numpad4::HideSuggestedStemByIndex(4)
!NumpadLeft::HideSuggestedStemByIndex(4)
!Numpad5::HideSuggestedStemByIndex(5)
!NumpadClear::HideSuggestedStemByIndex(5)

#HotIf

; ---- PgUp/PgDn как префиксы режимов (тестовая опция в Настройках) ----------
; МОЛЧАЛИВАЯ активация: цифры режима НЕ печатаются в поле, а живут только во
; внутреннем хвосте (см. PhantomInputLen). Один клик PgUp включает режим фраз ("1"),
; второй клик — поиск по содержимому ("11"), третий — молчаливый выход из режима.
; PgDn — аналогично "2"/"22" для промптов.
; Когда набор уже идёт другим текстом, клавиша работает как обычный PgUp/PgDn.
HandlePgModeKey(digit, nativeKey) {
    global CurrentInput, JustInsertedWord, NextCharUpper, PgKeysModeEnabled, PhantomInputLen
    if (!PgKeysModeEnabled || IsPasswordFieldActive()) {
        SendLevel 1
        Send("{Blind}{" nativeKey "}")
        return
    }
    if (CurrentInput = "") {
        CurrentInput := digit
        PhantomInputLen := 1
        JustInsertedWord := false
        NextCharUpper := false
        ; ВАЖНО: фиксируем контекст набора. Иначе PrepareTypingContextForChar()
        ; при первом же символе после PgUp/PgDn увидит "смену контрола" (актуально
        ; для классических Win32-редакторов вроде Notepad++/Scintilla) и сбросит
        ; фантомный режим через ResetInput().
        UpdateTypingContextStamp()
        ShowSuggestions()
        return
    }
    if (CurrentInput = digit) {
        CurrentInput := digit digit
        PhantomInputLen := 2
        JustInsertedWord := false
        NextCharUpper := false
        UpdateTypingContextStamp()
        ShowSuggestions()
        return
    }
    if (CurrentInput = digit digit) {
        ; Третий клик той же клавишей — молчаливый выход из режима.
        ResetInput()
        return
    }
    HandlePointerAction()
    SendLevel 1
    Send("{Blind}{" nativeKey "}")
}

#HotIf PgKeysModeEnabled && IsTyperInputContext() && !IsDetachedSnippetEditorActive()
$PgUp::HandlePgModeKey("1", "PgUp")
$PgDn::HandlePgModeKey("2", "PgDn")
#HotIf

#HotIf IsTyperInputContext()
#RShift:: {
    global CurrentInput, MinWordLen, MinUsageThreshold

    if IsPasswordFieldActive()
        return
    if !IsDictionaryActive() { ; v13.18
        if (CurrentInput != "")
            ShowDictionaryOffTip()
        return
    }

    if (CurrentInput != "") {
        if (IsDataTriggerInput(CurrentInput) || IsSnippetTriggerInput(CurrentInput)) {
            ToolTip("⚠️ Этот режим не запоминается как обычное слово")
            SetTimer(() => ToolTip(), -1400)
            ResetInput()
            return
        }
        if (StrLen(CurrentInput) < MinWordLen) {
            ToolTip("⚠️ Слово слишком короткое (< " MinWordLen " симв.)")
            SetTimer(() => ToolTip(), -1500)
        } else {
            LearnWordExact(CurrentInput, GetManualLearnScore(CurrentInput), true) ; v13.19
            SetNoSpaceWord(CurrentInput, true)
            SaveMetaInternal()
            ToolTip("🔒 Добавлено без пробела")
            SetTimer(() => ToolTip(), -1000)
        }
        ResetInput()
    }
}

#HotIf !SuggestionVisible && IsTyperInputContext()

~RShift:: {
    global RShiftPressTime := A_TickCount
}
~RShift Up:: {
    global CurrentInput, RShiftPressTime, MinWordLen, MaxLearnedWordLen, MinUsageThreshold, TapThreshold

    if IsPasswordFieldActive()
        return

    if (A_PriorKey = "RShift" && (A_TickCount - RShiftPressTime < TapThreshold)) {
        if !IsDictionaryActive() { ; v13.18: и выделение не копируем — словаря нет
            if (CurrentInput != "")
                ShowDictionaryOffTip()
            return
        }
        if (CurrentInput = "" && LearnSelectedTextAsWords())
            return
        if (CurrentInput != "") {
            if (IsDataTriggerInput(CurrentInput) || IsSnippetTriggerInput(CurrentInput)) {
                ToolTip("⚠️ Этот режим не запоминается как обычное слово")
                SetTimer(() => ToolTip(), -1400)
                ResetInput()
                return
            }
            if (StrLen(CurrentInput) < MinWordLen) {
                ToolTip("⚠️ Слово слишком короткое (< " MinWordLen " симв.)")
                SetTimer(() => ToolTip(), -1500)
            } else if (StrLen(CurrentInput) > MaxLearnedWordLen) {
                ToolTip("⚠️ Слишком длинно для словаря (> " MaxLearnedWordLen " симв.), лучше Фразы")
                SetTimer(() => ToolTip(), -1700)
            } else {
                LearnWordExact(CurrentInput, GetManualLearnScore(CurrentInput), true) ; v13.19
                ToolTip("✅ Добавлено")
                SetTimer(() => ToolTip(), -1000)
            }
            ResetInput()
        }
    }
}

#HotIf IsTyperInputContext()

~LCtrl:: {
    global CtrlPressTime := A_TickCount
}
~LCtrl Up:: {
    global CtrlPressTime, TapThreshold, EnableLCtrlComma
    if !EnableLCtrlComma
        return
    if (A_PriorKey = "LControl" && (A_TickCount - CtrlPressTime < TapThreshold))
        HandleLeftCtrlTap()
}

~RControl:: {
    global RCtrlPressTime := A_TickCount
}
~RControl Up:: {
    global JustInsertedWord, LastSpaceTime, CurrentInput, CurrentRawInput, NextCharUpper, RCtrlPressTime, TapThreshold, EnableRCtrlPeriod, PhantomInputLen
    if !EnableRCtrlPeriod
        return
    if (A_PriorKey = "RControl" && (A_TickCount - RCtrlPressTime < TapThreshold)) {
        InvalidateHotstringUndo()
        if (CurrentInput != "") {
            if !IsDataTriggerInput(CurrentInput) && !IsSnippetTriggerInput(CurrentInput)
                LearnWord(CurrentInput, 1, false)
            CurrentInput := ""
            CurrentRawInput := ""
            PhantomInputLen := 0
            HideSuggestions()
        }
        if (JustInsertedWord && (A_TickCount - LastSpaceTime < 3000)) {
            SendInput("{Backspace}. ")
            JustInsertedWord := false
            NextCharUpper := true
        } else {
            SendInput(". ")
            JustInsertedWord := false
            NextCharUpper := true
        }
    }
}

; AppsKey: исключить выделение или текущий сырой фрагмент из выдачи словаря.
; Это единый режим "Исключённые": не показывать в OSD и не обучать заново.
AppsKey::ExcludeCurrentOrSelectedFromSuggestions()

; Клик мыши перемещает каретку в новое место (адресная строка, другое поле, страница),
; поэтому старый внутренний хвост дальше недействителен. Без этого сброса после клика
; в пустую адресную строку набор "1abc"/"3xyz" склеивался с прежним хвостом и режимы
; 1/2/3/* не распознавались, пока пользователь не ставил пробел.
; v13.17: «*» — и с модификаторами: Shift+клик расширяет выделение, Ctrl+клик
; ставит курсор — хвост тоже недействителен (иначе Ctrl+\ стирал Backspace'ами
; текст перед выделением). Ctrl+A выделяет всё — по той же причине сбрасываем.
~*LButton::HandlePointerAction()
~*MButton::HandlePointerAction()
~^vk41::HandlePointerAction()
#HotIf

; #EndRegion
