local _, ns = ...

-- Keys are the English text; on esES/esMX clients they are replaced by the Spanish one (a test checks every key
-- used has one).
local es = {
    -- startup, commands
    ["no goals yet: /enfocao new"] = "aún no tienes objetivos: /enfocao new",
    ["1 goal on: /enfocao"] = "1 objetivo en marcha: /enfocao",
    ["%d goals on: /enfocao"] = "%d objetivos en marcha: /enfocao",
    ["Usage: /enfocao | new | goals | suggestions | achieved | style | hud | prefs | minimap | about | version"] =
        "Uso: /enfocao | new | goals | suggestions | achieved | style | hud | prefs | minimap | about | version",
    ["%d suggestions: /enfocao suggestions"] = "%d sugerencias: /enfocao suggestions",

    -- suggestions: the advisors' reasons
    ["Level %d brings %s. You are %d levels away."] = "El nivel %d trae %s. Te faltan %d niveles.",
    ["talents, and your class's quests"] = "talentos y las misiones de tu clase",
    ["new spells and the dungeons of the middle levels"] = "hechizos nuevos y las mazmorras de nivel medio",
    ["more talents, and five levels from thinking of your mount"] = "más talentos, y quedarte a cinco niveles de la montura",
    ["your mount, and better armor for many classes"] = "tu montura, y mejor armadura para muchas clases",
    ["the dungeons of Blackrock and the last zones"] = "las mazmorras de Roca Negra y las últimas zonas",
    ["the top level: raids, attunements and the end game"] = "el nivel máximo: bandas, accesos y el final del juego",
    ["You have %d%% of a level in rested experience: every kill is worth double. A good time to level."] =
        "Tienes un %d%% de nivel en experiencia de descanso: cada muerte vale doble. Buen momento para subir.",
    ["At level 40 you can ride: the mount and the riding skill cost about 100 gold. You have %d."] =
        "A nivel 40 podrás montar: la montura y la equitación cuestan unos 100 de oro. Tienes %d.",
    ["Your %s is at the top of its rank (%d/%d): learn %s from your trainer and take it to %d."] =
        "Tu %s está en el tope de su rango (%d/%d): aprende %s en tu instructor y súbela a %d.",
    ["Journeyman"] = "Oficial",
    ["Expert"] = "Experto",
    ["Artisan"] = "Artesano",
    ["Your %s is at %d: at your level it could be at %d."] = "Tu %s está en %d: a tu nivel podría estar en %d.",
    ["Learn First Aid"] = "Aprender Primeros auxilios",
    ["First Aid costs almost nothing and heals you between fights: every class wants it."] =
        "Primeros auxilios casi no cuesta nada y te cura entre combates: le viene bien a cualquier clase.",
    ["You are %d%% of the way to %s with %s."] = "Llevas un %d%% del camino hasta %s con %s.",
    ["At level %d you can start it: one step closer to the end game."] = "Desde el nivel %d puedes empezarlo: un paso más hacia el final del juego.",
    ["Shadowforge Key (Blackrock Depths)"] = "Llave de Forjatiniebla (Profundidades de Roca Negra)",
    ["Molten Core attunement"] = "Acceso al Núcleo de Magma",
    ["Skeleton Key (Scholomance)"] = "Llave esqueleto (Scholomance)",
    ["Onyxia's Lair attunement"] = "Acceso a la Guarida de Onyxia",
    ["Seal of Ascension (Upper Blackrock Spire)"] = "Sello de Ascensión (Cumbre de Roca Negra superior)",
    ["Blackwing Lair attunement"] = "Acceso a la Guarida Alanegra",
    ["Better %s"] = "Mejorar: %s",
    ["Your %s is item level %d; the rest of your gear is around %d."] =
        "Tu pieza de %s es de nivel de objeto %d; el resto de tu equipo ronda el %d.",
    ["head"] = "cabeza",
    ["shoulders"] = "hombros",
    ["chest"] = "pecho",
    ["waist"] = "cintura",
    ["legs"] = "piernas",
    ["feet"] = "pies",
    ["wrists"] = "muñecas",
    ["hands"] = "manos",
    ["back"] = "espalda",
    ["main hand weapon"] = "arma principal",

    -- the Suggestions view
    ["Suggestions"] = "Sugerencias",
    ["What I'd advise you to spend your time on, from what I know of this character and your style."] =
        "En qué te aconsejaría invertir tu tiempo, según lo que sé de este personaje y de tu estilo.",
    ["Accept"] = "Aceptar",
    ["Later"] = "Ahora no",
    ["Dismiss: don't suggest it again"] = "Descartar: no volver a sugerirlo",
    ["New goal: %s"] = "Nuevo objetivo: %s",
    ["Scroll for %d more"] = "Rueda del ratón para %d más",
    ["Nothing to suggest right now: you're on track."] = "Nada que sugerir ahora mismo: vas bien encaminado.",
    ["No goals: I have %d suggestions for you (click)."] = "Sin objetivos: tengo %d sugerencias para ti (clic).",

    -- your style
    ["Your style"] = "Tu estilo",
    ["Your style: %s"] = "Tu estilo: %s",
    ["not set yet"] = "sin definir",
    ["Tell me how you like to play and I'll tune my suggestions. You can change it whenever you want."] =
        "Cuéntame cómo te gusta jugar y ajustaré mis sugerencias. Puedes cambiarlo cuando quieras.",
    ["How do you play?"] = "¿Cómo juegas?",
    ["What do you enjoy? (any)"] = "¿Qué te gusta? (las que quieras)",
    ["How long do you usually play?"] = "¿Cuánto sueles jugar?",
    ["Your time per session will shape the daily plan, coming in a next version."] =
        "Tu tiempo por sesión dará forma al plan del día, que llegará en una próxima versión.",
    ["Save"] = "Guardar",
    ["Chill"] = "Tranquilo",
    ["I play to have a good time, no rush"] = "Juego para pasarlo bien, sin prisas",
    ["Balanced"] = "Equilibrado",
    ["A bit of everything, at my own pace"] = "Un poco de todo, a mi ritmo",
    ["Min-maxer"] = "Min-maxer",
    ["I want to be as efficient as possible"] = "Quiero ser lo más eficiente posible",
    ["Questing and leveling"] = "Misiones y subir de nivel",
    ["Dungeons"] = "Mazmorras",
    ["Raids"] = "Bandas",
    ["PvP"] = "JcJ",
    ["Professions"] = "Profesiones",
    ["Making gold"] = "Hacer oro",
    ["Reputations"] = "Reputaciones",
    ["Playing alts"] = "Jugar con alters",
    ["Collecting"] = "Coleccionar",
    ["Short sessions (under an hour)"] = "Ratos cortos (menos de una hora)",
    ["About an hour"] = "Más o menos una hora",
    ["Long sessions"] = "Sesiones largas",

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
