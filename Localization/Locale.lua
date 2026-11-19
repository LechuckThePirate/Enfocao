local _, ns = ...

-- Keys are the English text; on esES/esMX clients they are replaced by the Spanish one (a test checks every key
-- used has one).
local es = {
    -- startup, commands
    ["no goals yet: /enfocao new"] = "aún no tienes objetivos: /enfocao new",
    ["1 goal on: /enfocao"] = "1 objetivo en marcha: /enfocao",
    ["%d goals on: /enfocao"] = "%d objetivos en marcha: /enfocao",
    ["Usage: /enfocao | new | goals | achieved | hud | prefs | minimap | about | version"] =
        "Uso: /enfocao | new | goals | achieved | hud | prefs | minimap | about | version",

    -- time
    ["now"] = "ahora",
    ["%s ago"] = "hace %s",

    -- kinds of goal
    ["Reach a level"] = "Llegar a un nivel",
    ["Level %d"] = "Nivel %d",
    ["level %d (%d%%)"] = "nivel %d (%d%%)",
    ["Raise a profession"] = "Subir una profesión",
    ["%s to %d"] = "%s a %d",
    ["not learned"] = "no aprendida",
    ["Reputation with a faction"] = "Reputación con una facción",
    ["%s with %s"] = "%s con %s",
    ["Save gold"] = "Ahorrar oro",
    ["%dg on the whole account"] = "%d de oro en toda la cuenta",
    ["Save %dg"] = "Ahorrar %d de oro",
    ["Gather items"] = "Reunir objetos",
    ["%d x %s"] = "%d x %s",
    ["Complete a quest"] = "Completar una misión",
    ["Quest: %s"] = "Misión: %s",
    ["completed"] = "completada",
    ["not yet"] = "todavía no",
    ["Something else (I tick it)"] = "Otra cosa (la marco yo)",
    ["every day"] = "cada día",
    ["every week"] = "cada semana",
    ["done"] = "hecho",
    ["to do"] = "por hacer",
    ["Hated"] = "Odiado",
    ["Hostile"] = "Hostil",
    ["Unfriendly"] = "Adverso",
    ["Neutral"] = "Neutral",
    ["Friendly"] = "Amistoso",
    ["Honored"] = "Honorable",
    ["Revered"] = "Venerado",
    ["Exalted"] = "Exaltado",

    -- goals
    ["Unknown character."] = "Personaje desconocido.",
    ["Check the values: that goal can't be set."] = "Revisa los valores: ese objetivo no se puede poner.",
    ["Goal reached: %s"] = "¡Objetivo conseguido! %s",

    -- the window and its views
    ["Preferences"] = "Preferencias",
    ["Goals"] = "Objetivos",
    ["What this character is going for, and how far it is. They update by themselves."] =
        "A qué va este personaje y cuánto le falta. Se actualizan solos.",
    ["Achieved"] = "Conseguidos",
    ["Every goal reached, and how long it took."] = "Todos los objetivos conseguidos, y cuánto costaron.",
    ["Goal"] = "Objetivo",
    ["Progress"] = "Progreso",
    ["Set"] = "Puesto",
    ["It took"] = "Ha costado",
    ["Untick"] = "Desmarcar",
    ["Tick as done"] = "Marcar como hecho",
    ["Back to the active goals"] = "Volver a los objetivos activos",
    ["Remove this goal"] = "Quitar este objetivo",
    ["Unknown until this character logs in (with BakalaoStudios DataStore)."] =
        "Se sabrá cuando este personaje entre al juego (con BakalaoStudios DataStore).",
    ["Click: tick it. Right-click: menu."] = "Clic: marcarlo. Clic derecho: menú.",
    ["Right-click: menu."] = "Clic derecho: menú.",
    ["+ New goal"] = "+ Nuevo objetivo",
    ["No goals yet. Set one with \"+ New goal\": a level, a profession, a reputation, gold, items..."] =
        "Aún no hay objetivos. Ponte uno con «+ Nuevo objetivo»: un nivel, una profesión, una reputación, oro, objetos...",
    ["1 active goal"] = "1 objetivo activo",
    ["%d active goals"] = "%d objetivos activos",
    ["Nothing achieved yet: it'll come."] = "Todavía nada conseguido: ya llegará.",

    -- the new goal form
    ["New goal"] = "Nuevo objetivo",
    ["For: %s"] = "Para: %s",
    ["Kind"] = "Tipo",
    ["Level to reach"] = "Nivel a alcanzar",
    ["Profession"] = "Profesión",
    ["Skill to reach"] = "Habilidad a alcanzar",
    ["Faction"] = "Facción",
    ["Standing to reach"] = "Nivel a alcanzar",
    ["Gold to have"] = "Oro a tener",
    ["How many"] = "Cuántos",
    ["Item"] = "Objeto",
    ["Shift-click an item, or type its name or id."] = "Mayús+clic en un objeto, o escribe su nombre o id.",
    ["Quest"] = "Misión",
    ["Shift-click a quest in your quest log, or type its id."] = "Mayús+clic en una misión de tu registro, o escribe su id.",
    ["What"] = "Qué",
    ["Repeats"] = "Se repite",
    ["Once"] = "Una vez",
    ["Every day"] = "Cada día",
    ["Every week"] = "Cada semana",
    ["Count the whole account"] = "Contar toda la cuenta",
    ["Set goal"] = "Poner objetivo",

    -- the "Today" window
    ["Today"] = "Hoy",
    ["Open Enfocao!!"] = "Abrir Enfocao!!",
    ["Unlock position"] = "Desbloquear posición",
    ["Lock position"] = "Bloquear posición",
    ["Hide this window"] = "Ocultar esta ventana",
    ["No goals: right-click to set one."] = "Sin objetivos: clic derecho para ponerte uno.",
    ["(+%d more)"] = "(+%d más)",

    -- preferences
    ["Enfocao!! preferences"] = "Preferencias de Enfocao!!",
    ["The \"Today\" window"] = "La ventana «Hoy»",
    ["Show the playing character's goals on screen"] = "Mostrar en pantalla los objetivos del personaje con el que juegas",
    ["Lock its position"] = "Bloquear su posición",
    ["Goals it lists: %d"] = "Objetivos que muestra: %d",
    ["When a goal is reached"] = "Al conseguir un objetivo",
    ["Play a sound"] = "Reproducir un sonido",
    ["Show a message in the middle of the screen"] = "Mostrar un mensaje en el centro de la pantalla",
    ["Other"] = "Otros",
    ["No chat message at startup"] = "Sin mensaje en el chat al iniciar",
    ["Minimap button"] = "Botón del minimapa",
    ["Window size: %d%%"] = "Tamaño de la ventana: %d%%",
    ["Background picture: %d%%"] = "Imagen de fondo: %d%%",
    ["Reset preferences"] = "Restablecer preferencias",
    ["About"] = "Acerca de",

    -- minimap button
    ["Hide the \"Today\" window"] = "Ocultar la ventana «Hoy»",
    ["Show the \"Today\" window"] = "Mostrar la ventana «Hoy»",
    ["About Enfocao!!"] = "Acerca de Enfocao!!",
    ["Hide the minimap button"] = "Ocultar el botón del minimapa",
    ["No goals yet."] = "Aún no hay objetivos.",
    ["Left-click: open the window"] = "Clic izquierdo: abrir la ventana",
    ["Right-click: menu"] = "Clic derecho: menú",
    ["Drag: move"] = "Arrastrar: mover",
    ["Minimap button shown."] = "Botón del minimapa mostrado.",
    ["Minimap button hidden. Show it again with /enfocao minimap."] =
        "Botón del minimapa oculto. Vuelve a mostrarlo con /enfocao minimap.",

    -- about
    ["Version %s"] = "Versión %s",
    ["by LechuckThePirate"] = "por LechuckThePirate",
    ["Stop planning. Start playing. Set your goals and Enfocao!! follows them for you: level, professions, reputations, gold, items, quests."] =
        "Deja de planificar. Ponte a jugar. Ponte objetivos y Enfocao!! los sigue por ti: nivel, profesiones, reputaciones, oro, objetos, misiones.",
    ["Commands: /enfocao (window), /enfocao new, hud, prefs, minimap, about, version."] =
        "Comandos: /enfocao (ventana), /enfocao new, hud, prefs, minimap, about, version.",
    ["Found a bug or have an idea? Please report it on GitHub (click to select, then Ctrl+C):"] =
        "¿Has encontrado un fallo o tienes una idea? Cuéntalo en GitHub (clic para seleccionar y luego Ctrl+C):",
}

local locale = GetLocale and GetLocale() or "enUS"
local active = (locale == "esES" or locale == "esMX") and es or {}

-- English text is the key: a missing translation shows the English one.
ns.L = setmetatable({}, { __index = function(_, key) return active[key] or key end })
ns.L_ES = es -- for the tests (every key used has a translation)
