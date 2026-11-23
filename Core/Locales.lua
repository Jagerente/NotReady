local _, ns = ...

local L = {}
ns.L = L

local STRINGS = {}

STRINGS.enUS = {
    NAV_HINTS = "Hints",
    NAV_ABOUT = "About",

    READY = "Ready",
    NOT_ENOUGH = "Not enough",
    SAMPLE_REASON = "Out of range",
    POWER_MANA = "mana",
    POWER_RAGE = "rage",
    POWER_ENERGY = "energy",
    POWER_FOCUS = "focus",

    SECTION_PLACE = "Where to show",
    PLACE_cursor = "At cursor",
    PLACE_nameplate = "At nameplate",
    PLACE_spot = "My spot",
    OFFSET_X = "Shift right",
    OFFSET_Y = "Shift up",
    SPOT_CHOOSE = "Choose a spot on screen",
    SPOT_CHOOSE_PLATE = "Spot without nameplate",
    RESET_POSITION = "Reset position",
    MOVE_HINT = "Drag the hints where you want them",
    MOVE_DONE = "Done",
    MOVE_CANCEL = "Cancel",

    SECTION_LOOK = "Look",
    SIZE = "Size",
    SHOW_READY = "Ready signal",
    SHOW_READY_DESC = "When a skill you pressed becomes available, shows Ready in the same place.",
    SHOW_OTHER = "Other reasons",
    SHOW_OTHER_DESC = "Shows the game's reason when it isn't cooldown or resources: out of range, no target, wrong stance.",

    SECTION_OTHER = "Other",
    MINIMAP_BUTTON = "Minimap button",
    MINIMAP_LEFT_CLICK = "Click: settings",
    MINIMAP_DRAG = "Drag: move around the minimap",
    LANGUAGE = "Language",
    LANGUAGE_auto = "Game",
    LANGUAGE_enUS = "English",
    LANGUAGE_ruRU = "Русский",
    RESET = "Reset all settings",
    RESET_CONFIRM = "Click again to reset everything",

    SETTINGS_DESC = "Shows why a skill didn't go off: seconds of cooldown left or how much rage, mana or energy you're missing.",
    SETTINGS_OPEN = "Open settings",

    ABOUT_AUTHOR = "Author",
    ABOUT_SHAPESHIFT = "Click to shapeshift",
    ABOUT_WEBSITE = "Website",
    ABOUT_COPY = "Copy",
    ABOUT_COPY_HINT = "Press Ctrl+C",
    ABOUT_COMMAND = "Chat commands",
    ABOUT_COMMAND_OPTIONS = "Opens this window",
    ABOUT_FONT_CREDIT = "Fira Sans font, SIL Open Font License 1.1.",
}

STRINGS.ruRU = {
    NAV_HINTS = "Подсказки",
    NAV_ABOUT = "Об аддоне",

    READY = "Готово",
    NOT_ENOUGH = "Не хватает",
    SAMPLE_REASON = "Слишком далеко",
    POWER_MANA = "маны",
    POWER_RAGE = "ярости",
    POWER_ENERGY = "энергии",
    POWER_FOCUS = "фокуса",

    SECTION_PLACE = "Где показывать",
    PLACE_cursor = "У курсора",
    PLACE_nameplate = "У неймплейта",
    PLACE_spot = "Своё место",
    OFFSET_X = "Сдвиг вправо",
    OFFSET_Y = "Сдвиг вверх",
    SPOT_CHOOSE = "Выбрать место на экране",
    SPOT_CHOOSE_PLATE = "Место без неймплейта",
    RESET_POSITION = "Сбросить позицию",
    MOVE_HINT = "Перетащите подсказки туда, где хотите их видеть",
    MOVE_DONE = "Готово",
    MOVE_CANCEL = "Отмена",

    SECTION_LOOK = "Вид",
    SIZE = "Размер",
    SHOW_READY = "Сигнал «Готово»",
    SHOW_READY_DESC = "Когда нажатый скилл становится доступен, на том же месте загорается «Готово».",
    SHOW_OTHER = "Другие причины",
    SHOW_OTHER_DESC = "Показывает причину из игры, если дело не в кулдауне и не в ресурсе: далеко, нет цели, не та стойка.",

    SECTION_OTHER = "Прочее",
    MINIMAP_BUTTON = "Кнопка у миникарты",
    MINIMAP_LEFT_CLICK = "ЛКМ: настройки",
    MINIMAP_DRAG = "Перетащите, чтобы передвинуть",
    LANGUAGE = "Язык",
    LANGUAGE_auto = "Как в игре",
    LANGUAGE_enUS = "English",
    LANGUAGE_ruRU = "Русский",
    RESET = "Сбросить все настройки",
    RESET_CONFIRM = "Нажмите ещё раз, чтобы сбросить всё",

    SETTINGS_DESC = "Показывает, почему скилл не нажался: сколько секунд кулдауна осталось или сколько не хватает ярости, маны или энергии.",
    SETTINGS_OPEN = "Открыть настройки",

    ABOUT_AUTHOR = "Автор",
    ABOUT_SHAPESHIFT = "Нажмите, чтобы сменить облик",
    ABOUT_WEBSITE = "Сайт",
    ABOUT_COPY = "Копировать",
    ABOUT_COPY_HINT = "Нажмите Ctrl+C",
    ABOUT_COMMAND = "Команды в чате",
    ABOUT_COMMAND_OPTIONS = "Открывает это окно",
    ABOUT_FONT_CREDIT = "Шрифт Fira Sans, лицензия SIL Open Font License 1.1.",
}

ns.LANGUAGES = { "auto", "enUS", "ruRU" }

local function Resolve(choice)
    if choice and STRINGS[choice] then return choice end
    local gameLocale = GetLocale()
    return STRINGS[gameLocale] and gameLocale or "enUS"
end

function ns.ApplyLanguage(choice)
    local code = Resolve(choice)
    wipe(L)
    for key, text in pairs(STRINGS.enUS) do
        L[key] = text
    end
    if code ~= "enUS" then
        for key, text in pairs(STRINGS[code]) do
            L[key] = text
        end
    end
    ns.Fire("LOCALE_CHANGED")
end

ns.ApplyLanguage("auto")

ns.Listen("DB_READY", function()
    ns.ApplyLanguage(ns.db.locale)
end)

ns.Listen("SETTING_CHANGED", function(key)
    if key == "locale" or key == nil then
        ns.ApplyLanguage(ns.db.locale)
    end
end)
