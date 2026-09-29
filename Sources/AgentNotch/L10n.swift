import Foundation

/// Interface language, independent of the dictation locale.
/// Strings live in code rather than a String Catalog so the SwiftPM-built
/// bundle needs no compiled resources and the language can change at runtime.
enum UILanguage: String, CaseIterable, Identifiable {
    case system, en, es, it, fr, de, pt

    var id: String { rawValue }

    /// Native names, so a user can always find their own language.
    var nativeName: String {
        switch self {
        case .system: return tr("System default")
        case .en: return "English"
        case .es: return "Español"
        case .it: return "Italiano"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .pt: return "Português"
        }
    }

    static let defaultsKey = "uiLanguage"

    static var stored: UILanguage {
        UserDefaults.standard.string(forKey: defaultsKey).flatMap(UILanguage.init(rawValue:)) ?? .system
    }

    /// The concrete language used to render strings.
    var resolved: UILanguage {
        guard self == .system else { return self }
        for identifier in Locale.preferredLanguages {
            let code = String(identifier.prefix(2)).lowercased()
            if let language = UILanguage(rawValue: code), language != .system { return language }
        }
        return .en
    }
}

enum L10n {
    /// Set by the app model; tests may override it.
    static var current: UILanguage = UILanguage.stored.resolved

    /// Keys are the English text. Every entry must provide es, it, fr, de and pt;
    /// the regression suite enforces this and matching format specifiers.
    static let table: [String: [String: String]] = [
        // Menu bar
        "Show / hide notch": ["es": "Mostrar / ocultar notch", "it": "Mostra / nascondi notch", "fr": "Afficher / masquer l’encoche", "de": "Notch ein-/ausblenden", "pt": "Mostrar / ocultar notch"],
        "Refresh limits": ["es": "Actualizar límites", "it": "Aggiorna limiti", "fr": "Actualiser les limites", "de": "Limits aktualisieren", "pt": "Atualizar limites"],
        "Connect Claude Code": ["es": "Conectar Claude Code", "it": "Collega Claude Code", "fr": "Connecter Claude Code", "de": "Claude Code verbinden", "pt": "Conectar Claude Code"],
        "Copy diagnostics": ["es": "Copiar diagnóstico", "it": "Copia diagnostica", "fr": "Copier le diagnostic", "de": "Diagnose kopieren", "pt": "Copiar diagnóstico"],
        "Enable Space to Speak": ["es": "Activar Space to Speak", "it": "Attiva Space to Speak", "fr": "Activer Space to Speak", "de": "Space to Speak aktivieren", "pt": "Ativar Space to Speak"],
        "Space to Speak active": ["es": "Space to Speak activo", "it": "Space to Speak attivo", "fr": "Space to Speak actif", "de": "Space to Speak aktiv", "pt": "Space to Speak ativo"],
        "Open at login": ["es": "Abrir al iniciar sesión", "it": "Apri al login", "fr": "Ouvrir à l’ouverture de session", "de": "Beim Anmelden öffnen", "pt": "Abrir ao iniciar sessão"],
        "Interface language": ["es": "Idioma de la interfaz", "it": "Lingua dell’interfaccia", "fr": "Langue de l’interface", "de": "Sprache der Oberfläche", "pt": "Idioma da interface"],
        "Dictation language": ["es": "Idioma del dictado", "it": "Lingua della dettatura", "fr": "Langue de la dictée", "de": "Diktiersprache", "pt": "Idioma do ditado"],
        "System default": ["es": "Idioma del sistema", "it": "Lingua di sistema", "fr": "Langue du système", "de": "Systemsprache", "pt": "Idioma do sistema"],
        "Quit": ["es": "Salir", "it": "Esci", "fr": "Quitter", "de": "Beenden", "pt": "Sair"],
        "Launch at login: %@": ["es": "Inicio automático: %@", "it": "Avvio automatico: %@", "fr": "Lancement automatique : %@", "de": "Autostart: %@", "pt": "Início automático: %@"],
        "Enable Agent Notch in Login Items.": ["es": "Activa Agent Notch en Ítems de inicio.", "it": "Attiva Agent Notch in Elementi login.", "fr": "Activez Agent Notch dans Ouverture.", "de": "Aktiviere Agent Notch unter Anmeldeobjekte.", "pt": "Ative o Agent Notch em Itens de início."],
        "macOS needs approval in System Settings.": ["es": "macOS necesita aprobación en Ajustes del Sistema.", "it": "macOS richiede l’approvazione in Impostazioni di Sistema.", "fr": "macOS demande une autorisation dans Réglages Système.", "de": "macOS benötigt eine Freigabe in den Systemeinstellungen.", "pt": "O macOS precisa de aprovação nos Ajustes do Sistema."],
        "Couldn't register launch at login.": ["es": "No se pudo registrar el inicio automático.", "it": "Impossibile registrare l’avvio automatico.", "fr": "Impossible d’activer le lancement automatique.", "de": "Autostart konnte nicht registriert werden.", "pt": "Não foi possível registrar o início automático."],

        // Panel
        "Close": ["es": "Cerrar", "it": "Chiudi", "fr": "Fermer", "de": "Schließen", "pt": "Fechar"],
        "Enable Space": ["es": "Activar Space", "it": "Attiva Space", "fr": "Activer Space", "de": "Space aktivieren", "pt": "Ativar Space"],
        "Retry": ["es": "Reintentar", "it": "Riprova", "fr": "Réessayer", "de": "Erneut versuchen", "pt": "Tentar novamente"],
        "Copy": ["es": "Copiar", "it": "Copia", "fr": "Copier", "de": "Kopieren", "pt": "Copiar"],
        "Connect Claude": ["es": "Conectar Claude", "it": "Collega Claude", "fr": "Connecter Claude", "de": "Claude verbinden", "pt": "Conectar Claude"],
        "Grant voice permissions": ["es": "Conceder permisos de voz", "it": "Concedi permessi vocali", "fr": "Accorder les autorisations vocales", "de": "Sprachberechtigungen erteilen", "pt": "Conceder permissões de voz"],
        "Loading…": ["es": "Cargando…", "it": "Caricamento…", "fr": "Chargement…", "de": "Wird geladen…", "pt": "Carregando…"],
        "stale": ["es": "antiguo", "it": "vecchio", "fr": "ancien", "de": "veraltet", "pt": "antigo"],
        "%d min ago": ["es": "hace %d min", "it": "%d min fa", "fr": "il y a %d min", "de": "vor %d Min.", "pt": "há %d min"],
        "outdated": ["es": "desactualizado", "it": "non aggiornato", "fr": "obsolète", "de": "nicht aktuell", "pt": "desatualizado"],

        // Usage windows and resets
        "5 hours": ["es": "5 horas", "it": "5 ore", "fr": "5 heures", "de": "5 Stunden", "pt": "5 horas"],
        "7 days": ["es": "7 días", "it": "7 giorni", "fr": "7 jours", "de": "7 Tage", "pt": "7 dias"],
        "Spend": ["es": "Gasto", "it": "Spesa", "fr": "Dépenses", "de": "Ausgaben", "pt": "Gasto"],
        "%@ weekly": ["es": "%@ semanal", "it": "%@ settimanale", "fr": "%@ hebdo", "de": "%@ wöchentlich", "pt": "%@ semanal"],
        "reset unknown": ["es": "reset desconocido", "it": "reset sconosciuto", "fr": "réinit. inconnue", "de": "Reset unbekannt", "pt": "reinício desconhecido"],
        "reset overdue · refresh": ["es": "reset vencido · actualizar", "it": "reset scaduto · aggiorna", "fr": "réinit. dépassée · actualiser", "de": "Reset fällig · aktualisieren", "pt": "reinício vencido · atualizar"],
        "reset <1 min": ["es": "reset <1 min", "it": "reset <1 min", "fr": "réinit. <1 min", "de": "Reset <1 Min.", "pt": "reinício <1 min"],
        "reset %d min": ["es": "reset %d min", "it": "reset %d min", "fr": "réinit. %d min", "de": "Reset %d Min.", "pt": "reinício %d min"],
        "reset %d h": ["es": "reset %d h", "it": "reset %d h", "fr": "réinit. %d h", "de": "Reset %d Std.", "pt": "reinício %d h"],
        "reset %d h %d min": ["es": "reset %d h %d min", "it": "reset %d h %d min", "fr": "réinit. %d h %d min", "de": "Reset %d Std. %d Min.", "pt": "reinício %d h %d min"],
        "reset %d d %d h": ["es": "reset %d d %d h", "it": "reset %d g %d h", "fr": "réinit. %d j %d h", "de": "Reset %d T. %d Std.", "pt": "reinício %d d %d h"],

        // Speech states
        "Hold Space": ["es": "Mantén Space", "it": "Tieni premuto Space", "fr": "Maintenez Space", "de": "Space gedrückt halten", "pt": "Segure Space"],
        "Preparing…": ["es": "Preparando…", "it": "Preparazione…", "fr": "Préparation…", "de": "Wird vorbereitet…", "pt": "Preparando…"],
        "Listening…": ["es": "Escuchando…", "it": "In ascolto…", "fr": "Écoute…", "de": "Hört zu…", "pt": "Ouvindo…"],
        "Transcribing…": ["es": "Transcribiendo…", "it": "Trascrizione…", "fr": "Transcription…", "de": "Wird transkribiert…", "pt": "Transcrevendo…"],
        "Voice error": ["es": "Error de voz", "it": "Errore vocale", "fr": "Erreur vocale", "de": "Sprachfehler", "pt": "Erro de voz"],

        // Notices
        "Checking keyboard…": ["es": "Comprobando teclado…", "it": "Verifica tastiera…", "fr": "Vérification du clavier…", "de": "Tastatur wird geprüft…", "pt": "Verificando teclado…"],
        "Open Claude Code and send a message to get its limits.": ["es": "Abre Claude Code y envía un mensaje para obtener sus límites.", "it": "Apri Claude Code e invia un messaggio per ottenere i limiti.", "fr": "Ouvrez Claude Code et envoyez un message pour obtenir ses limites.", "de": "Öffne Claude Code und sende eine Nachricht, um die Limits abzurufen.", "pt": "Abra o Claude Code e envie uma mensagem para obter os limites."],
        "Connect Claude's status line.": ["es": "Conecta el status line de Claude.", "it": "Collega la status line di Claude.", "fr": "Connectez la status line de Claude.", "de": "Verbinde die Statuszeile von Claude.", "pt": "Conecte a status line do Claude."],
        "Send a message in Claude Code to load the first reading.": ["es": "Envía un mensaje en Claude Code para cargar el primer dato.", "it": "Invia un messaggio in Claude Code per caricare il primo dato.", "fr": "Envoyez un message dans Claude Code pour charger la première valeur.", "de": "Sende eine Nachricht in Claude Code, um den ersten Wert zu laden.", "pt": "Envie uma mensagem no Claude Code para carregar o primeiro dado."],
        "Claude Code connected.": ["es": "Claude Code conectado.", "it": "Claude Code collegato.", "fr": "Claude Code connecté.", "de": "Claude Code verbunden.", "pt": "Claude Code conectado."],
        "Enable Agent Notch under Microphone and try again.": ["es": "Activa Agent Notch en Micrófono y vuelve a intentarlo.", "it": "Attiva Agent Notch in Microfono e riprova.", "fr": "Activez Agent Notch dans Microphone et réessayez.", "de": "Aktiviere Agent Notch unter Mikrofon und versuche es erneut.", "pt": "Ative o Agent Notch em Microfone e tente novamente."],
        "Voice permissions granted.": ["es": "Permisos de voz concedidos.", "it": "Permessi vocali concessi.", "fr": "Autorisations vocales accordées.", "de": "Sprachberechtigungen erteilt.", "pt": "Permissões de voz concedidas."],
        "Enable Agent Notch under Speech Recognition.": ["es": "Activa Agent Notch en Reconocimiento de voz.", "it": "Attiva Agent Notch in Riconoscimento vocale.", "fr": "Activez Agent Notch dans Reconnaissance vocale.", "de": "Aktiviere Agent Notch unter Spracherkennung.", "pt": "Ative o Agent Notch em Reconhecimento de fala."],
        "Preparing voice; the first time may download the language. Release Space to cancel.": ["es": "Preparando voz; la primera vez puede descargar el idioma. Suelta Space para cancelar.", "it": "Preparazione voce; la prima volta potrebbe scaricare la lingua. Rilascia Space per annullare.", "fr": "Préparation de la voix ; la première fois, la langue peut être téléchargée. Relâchez Space pour annuler.", "de": "Sprache wird vorbereitet; beim ersten Mal wird sie eventuell geladen. Space loslassen zum Abbrechen.", "pt": "Preparando voz; na primeira vez o idioma pode ser baixado. Solte Space para cancelar."],
        "Listening; release Space to finish.": ["es": "Escuchando; suelta Space para terminar.", "it": "In ascolto; rilascia Space per terminare.", "fr": "Écoute ; relâchez Space pour terminer.", "de": "Hört zu; Space loslassen zum Beenden.", "pt": "Ouvindo; solte Space para terminar."],
        "Paste requested. If text is missing, use Copy.": ["es": "Pegado solicitado. Si falta texto, usa Copiar.", "it": "Incolla richiesto. Se manca testo, usa Copia.", "fr": "Collage demandé. S’il manque du texte, utilisez Copier.", "de": "Einfügen angefordert. Falls Text fehlt, nutze Kopieren.", "pt": "Colagem solicitada. Se faltar texto, use Copiar."],
        "The app changed. Text kept; use Copy.": ["es": "Cambió la aplicación. Texto conservado; usa Copiar.", "it": "L’app è cambiata. Testo conservato; usa Copia.", "fr": "L’app a changé. Texte conservé ; utilisez Copier.", "de": "Die App hat gewechselt. Text behalten; nutze Kopieren.", "pt": "O app mudou. Texto mantido; use Copiar."],
        "Couldn't paste. Text kept; use Copy.": ["es": "No se pudo pegar. Texto conservado; usa Copiar.", "it": "Impossibile incollare. Testo conservato; usa Copia.", "fr": "Collage impossible. Texte conservé ; utilisez Copier.", "de": "Einfügen fehlgeschlagen. Text behalten; nutze Kopieren.", "pt": "Não foi possível colar. Texto mantido; use Copiar."],
        "No text detected. Hold Space to retry.": ["es": "No se detectó texto. Mantén Space para reintentar.", "it": "Nessun testo rilevato. Tieni premuto Space per riprovare.", "fr": "Aucun texte détecté. Maintenez Space pour réessayer.", "de": "Kein Text erkannt. Halte Space, um es erneut zu versuchen.", "pt": "Nenhum texto detectado. Segure Space para tentar novamente."],
        "Dictation cancelled.": ["es": "Dictado cancelado.", "it": "Dettatura annullata.", "fr": "Dictée annulée.", "de": "Diktat abgebrochen.", "pt": "Ditado cancelado."],
        "Hold Space to retry.": ["es": "Mantén Space para reintentar.", "it": "Tieni premuto Space per riprovare.", "fr": "Maintenez Space pour réessayer.", "de": "Halte Space, um es erneut zu versuchen.", "pt": "Segure Space para tentar novamente."],
        "Text copied.": ["es": "Texto copiado.", "it": "Testo copiato.", "fr": "Texte copié.", "de": "Text kopiert.", "pt": "Texto copiado."],
        "Space ready": ["es": "Space listo", "it": "Space pronto", "fr": "Space prêt", "de": "Space bereit", "pt": "Space pronto"],
        "Accessibility granted; keyboard capture unavailable. Retrying…": ["es": "Accesibilidad concedida; captura de teclado no disponible. Reintentando…", "it": "Accessibilità concessa; cattura tastiera non disponibile. Nuovo tentativo…", "fr": "Accessibilité accordée ; capture du clavier indisponible. Nouvelle tentative…", "de": "Bedienungshilfen erlaubt; Tastaturerfassung nicht verfügbar. Neuer Versuch…", "pt": "Acessibilidade concedida; captura de teclado indisponível. Tentando novamente…"],
        "Enable Agent Notch in Settings → Privacy & Security → Accessibility.": ["es": "Activa Agent Notch en Ajustes → Privacidad y seguridad → Accesibilidad.", "it": "Attiva Agent Notch in Impostazioni → Privacy e sicurezza → Accessibilità.", "fr": "Activez Agent Notch dans Réglages → Confidentialité et sécurité → Accessibilité.", "de": "Aktiviere Agent Notch in Einstellungen → Datenschutz & Sicherheit → Bedienungshilfen.", "pt": "Ative o Agent Notch em Ajustes → Privacidade e Segurança → Acessibilidade."],

        // Errors
        "The response contains no valid JSON.": ["es": "La respuesta no contiene JSON válido.", "it": "La risposta non contiene JSON valido.", "fr": "La réponse ne contient pas de JSON valide.", "de": "Die Antwort enthält kein gültiges JSON.", "pt": "A resposta não contém JSON válido."],
        "The response includes no usage limits.": ["es": "La respuesta no incluye límites de uso.", "it": "La risposta non include limiti di utilizzo.", "fr": "La réponse n’inclut aucune limite d’utilisation.", "de": "Die Antwort enthält keine Nutzungslimits.", "pt": "A resposta não inclui limites de uso."],
        "Enable the microphone for Agent Notch in Privacy & Security.": ["es": "Activa el micrófono para Agent Notch en Privacidad y seguridad.", "it": "Attiva il microfono per Agent Notch in Privacy e sicurezza.", "fr": "Activez le micro pour Agent Notch dans Confidentialité et sécurité.", "de": "Aktiviere das Mikrofon für Agent Notch unter Datenschutz & Sicherheit.", "pt": "Ative o microfone para o Agent Notch em Privacidade e Segurança."],
        "Enable Speech Recognition for Agent Notch.": ["es": "Activa Reconocimiento de voz para Agent Notch.", "it": "Attiva Riconoscimento vocale per Agent Notch.", "fr": "Activez la reconnaissance vocale pour Agent Notch.", "de": "Aktiviere die Spracherkennung für Agent Notch.", "pt": "Ative o Reconhecimento de fala para o Agent Notch."],
        "SpeechAnalyzer doesn't support %@ yet.": ["es": "SpeechAnalyzer no soporta todavía %@.", "it": "SpeechAnalyzer non supporta ancora %@.", "fr": "SpeechAnalyzer ne prend pas encore en charge %@.", "de": "SpeechAnalyzer unterstützt %@ noch nicht.", "pt": "O SpeechAnalyzer ainda não suporta %@."],
        "SpeechAnalyzer isn't available on this Mac.": ["es": "SpeechAnalyzer no está disponible en este Mac.", "it": "SpeechAnalyzer non è disponibile su questo Mac.", "fr": "SpeechAnalyzer n’est pas disponible sur ce Mac.", "de": "SpeechAnalyzer ist auf diesem Mac nicht verfügbar.", "pt": "O SpeechAnalyzer não está disponível neste Mac."],
        "Couldn't prepare the microphone format.": ["es": "No se pudo preparar el formato del micrófono.", "it": "Impossibile preparare il formato del microfono.", "fr": "Impossible de préparer le format du micro.", "de": "Mikrofonformat konnte nicht vorbereitet werden.", "pt": "Não foi possível preparar o formato do microfone."],
        "A transcription is already running.": ["es": "Ya hay una transcripción activa.", "it": "C’è già una trascrizione attiva.", "fr": "Une transcription est déjà en cours.", "de": "Es läuft bereits eine Transkription.", "pt": "Já há uma transcrição ativa."],
        "Can't find the Codex executable.": ["es": "No encuentro el ejecutable de Codex.", "it": "Eseguibile di Codex non trovato.", "fr": "Exécutable Codex introuvable.", "de": "Codex-Programm nicht gefunden.", "pt": "Executável do Codex não encontrado."],
        "Couldn't start Codex: %@": ["es": "No se pudo iniciar Codex: %@", "it": "Impossibile avviare Codex: %@", "fr": "Impossible de lancer Codex : %@", "de": "Codex konnte nicht gestartet werden: %@", "pt": "Não foi possível iniciar o Codex: %@"],
        "Codex took too long to respond.": ["es": "Codex tardó demasiado en responder.", "it": "Codex ha impiegato troppo a rispondere.", "fr": "Codex a mis trop de temps à répondre.", "de": "Codex hat zu lange nicht geantwortet.", "pt": "O Codex demorou demais para responder."],
        "Codex closed the connection.": ["es": "Codex cerró la conexión.", "it": "Codex ha chiuso la connessione.", "fr": "Codex a fermé la connexion.", "de": "Codex hat die Verbindung geschlossen.", "pt": "O Codex fechou a conexão."],
        "Codex response too large.": ["es": "Respuesta de Codex demasiado grande.", "it": "Risposta di Codex troppo grande.", "fr": "Réponse de Codex trop volumineuse.", "de": "Antwort von Codex zu groß.", "pt": "Resposta do Codex grande demais."],
        "Codex rejected initialization.": ["es": "Codex rechazó la inicialización.", "it": "Codex ha rifiutato l’inizializzazione.", "fr": "Codex a refusé l’initialisation.", "de": "Codex hat die Initialisierung abgelehnt.", "pt": "O Codex recusou a inicialização."],
        "Codex returned an error.": ["es": "Codex devolvió un error.", "it": "Codex ha restituito un errore.", "fr": "Codex a renvoyé une erreur.", "de": "Codex hat einen Fehler gemeldet.", "pt": "O Codex retornou um erro."],
        "Can't find the installed Agent Notch executable.": ["es": "No encuentro el ejecutable instalado de Agent Notch.", "it": "Eseguibile installato di Agent Notch non trovato.", "fr": "Exécutable Agent Notch installé introuvable.", "de": "Installiertes Agent-Notch-Programm nicht gefunden.", "pt": "Executável instalado do Agent Notch não encontrado."],
        "Claude already has a status line. I didn't overwrite it.": ["es": "Claude ya tiene un status line. No lo he sobrescrito.", "it": "Claude ha già una status line. Non l’ho sovrascritta.", "fr": "Claude a déjà une status line. Je ne l’ai pas remplacée.", "de": "Claude hat bereits eine Statuszeile. Sie wurde nicht überschrieben.", "pt": "O Claude já tem uma status line. Não a sobrescrevi."],
        "Claude's settings file doesn't contain valid JSON.": ["es": "El archivo de ajustes de Claude no contiene JSON válido.", "it": "Il file delle impostazioni di Claude non contiene JSON valido.", "fr": "Le fichier de réglages de Claude ne contient pas de JSON valide.", "de": "Die Einstellungsdatei von Claude enthält kein gültiges JSON.", "pt": "O arquivo de ajustes do Claude não contém JSON válido."],
        "Claude: limits available after the first reply": ["es": "Claude: límites disponibles después de la primera respuesta", "it": "Claude: limiti disponibili dopo la prima risposta", "fr": "Claude : limites disponibles après la première réponse", "de": "Claude: Limits nach der ersten Antwort verfügbar", "pt": "Claude: limites disponíveis após a primeira resposta"],
    ]

    static func string(_ key: String, language: UILanguage = L10n.current) -> String {
        let language = language.resolved
        guard language != .en else { return key }
        return table[key]?[language.rawValue] ?? key
    }
}

/// Translate an English source string into the current interface language.
func tr(_ key: String, _ arguments: CVarArg...) -> String {
    let format = L10n.string(key)
    return arguments.isEmpty ? format : String(format: format, arguments: arguments)
}

extension UsageWindow {
    /// Labels are derived from stable ids so cached snapshots written in an
    /// older language still render in the current one.
    var displayLabel: String {
        let key = id.split(separator: "-").last.map(String.init) ?? ""
        switch key {
        case "five_hour", "fh": return tr("5 hours")
        case "seven_day", "sd": return tr("7 days")
        case "so": return "Opus · " + tr("7 days")
        case "sn": return "Sonnet · " + tr("7 days")
        case "spend_limit": return tr("Spend")
        default: break
        }
        switch durationMinutes {
        case 300: return tr("5 hours")
        case 10_080: return tr("7 days")
        default: break
        }
        if id.hasPrefix("codex-"), id.hasSuffix("-secondary") {
            return tr("%@ weekly", String(id.dropFirst("codex-".count).dropLast("-secondary".count)))
        }
        return label
    }
}
