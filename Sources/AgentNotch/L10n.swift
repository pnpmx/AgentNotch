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

        // Agents, limits, session and dictation options
        "%@ finished": ["es": "%@ ha terminado", "it": "%@ ha finito", "fr": "%@ a terminé", "de": "%@ ist fertig", "pt": "%@ terminou"],
        "%@ needs your approval": ["es": "%@ necesita tu aprobación", "it": "%@ ha bisogno della tua approvazione", "fr": "%@ attend votre autorisation", "de": "%@ braucht deine Freigabe", "pt": "%@ precisa da sua aprovação"],
        "%@ is waiting for you": ["es": "%@ te está esperando", "it": "%@ ti sta aspettando", "fr": "%@ vous attend", "de": "%@ wartet auf dich", "pt": "%@ está esperando você"],
        "Couldn't read the agent's settings file.": ["es": "No se pudo leer el archivo de ajustes del agente.", "it": "Impossibile leggere il file di impostazioni dell’agente.", "fr": "Impossible de lire le fichier de réglages de l’agent.", "de": "Die Einstellungsdatei des Agenten konnte nicht gelesen werden.", "pt": "Não foi possível ler o arquivo de ajustes do agente."],
        "Codex already runs another notify program; it was not replaced.": ["es": "Codex ya usa otro programa de notificación; no se ha reemplazado.", "it": "Codex usa già un altro programma di notifica; non è stato sostituito.", "fr": "Codex utilise déjà un autre programme de notification ; il n’a pas été remplacé.", "de": "Codex nutzt bereits ein anderes Benachrichtigungsprogramm; es wurde nicht ersetzt.", "pt": "O Codex já usa outro programa de notificação; ele não foi substituído."],
        "That value isn't supported.": ["es": "Ese valor no es compatible.", "it": "Valore non supportato.", "fr": "Cette valeur n’est pas prise en charge.", "de": "Dieser Wert wird nicht unterstützt.", "pt": "Esse valor não é compatível."],
        "%@ %@ limit at %d%%": ["es": "Límite de %2$@ de %1$@ al %3$d%%", "it": "Limite %2$@ di %1$@ al %3$d%%", "fr": "Limite %2$@ de %1$@ à %3$d %%", "de": "%1$@-Limit %2$@ bei %3$d %%", "pt": "Limite de %2$@ do %1$@ em %3$d%%"],
        "%@ %@ limit has reset": ["es": "El límite de %2$@ de %1$@ se ha reiniciado", "it": "Il limite %2$@ di %1$@ è stato azzerato", "fr": "La limite %2$@ de %1$@ est réinitialisée", "de": "%1$@-Limit %2$@ wurde zurückgesetzt", "pt": "O limite de %2$@ do %1$@ foi reiniciado"],
        "context %d%%": ["es": "contexto %d%%", "it": "contesto %d%%", "fr": "contexte %d %%", "de": "Kontext %d %%", "pt": "contexto %d%%"],
        "None": ["es": "Ninguno", "it": "Nessuno", "fr": "Aucun", "de": "Keiner", "pt": "Nenhum"],
        "Minimal": ["es": "Mínimo", "it": "Minimo", "fr": "Minimal", "de": "Minimal", "pt": "Mínimo"],
        "Low": ["es": "Bajo", "it": "Basso", "fr": "Faible", "de": "Niedrig", "pt": "Baixo"],
        "Medium": ["es": "Medio", "it": "Medio", "fr": "Moyen", "de": "Mittel", "pt": "Médio"],
        "High": ["es": "Alto", "it": "Alto", "fr": "Élevé", "de": "Hoch", "pt": "Alto"],
        "Extra high": ["es": "Muy alto", "it": "Molto alto", "fr": "Très élevé", "de": "Sehr hoch", "pt": "Muito alto"],
        "Max": ["es": "Máximo", "it": "Massimo", "fr": "Maximum", "de": "Maximal", "pt": "Máximo"],
        "Agent alerts are on. New Claude Code and Codex sessions will report here.": ["es": "Avisos activados. Las nuevas sesiones de Claude Code y Codex avisarán aquí.", "it": "Avvisi attivi. Le nuove sessioni di Claude Code e Codex avviseranno qui.", "fr": "Alertes activées. Les nouvelles sessions Claude Code et Codex s’afficheront ici.", "de": "Hinweise aktiv. Neue Claude-Code- und Codex-Sitzungen melden sich hier.", "pt": "Avisos ativados. Novas sessões do Claude Code e do Codex avisarão aqui."],
        "Recent dictations": ["es": "Dictados recientes", "it": "Dettature recenti", "fr": "Dictées récentes", "de": "Letzte Diktate", "pt": "Ditados recentes"],
        "Enable agent alerts": ["es": "Activar avisos de agentes", "it": "Attiva avvisi degli agenti", "fr": "Activer les alertes d’agents", "de": "Agenten-Hinweise aktivieren", "pt": "Ativar avisos dos agentes"],
        "Settings": ["es": "Ajustes", "it": "Impostazioni", "fr": "Réglages", "de": "Einstellungen", "pt": "Ajustes"],
        "at this pace: 100%% at %@": ["es": "a este ritmo: 100%% a las %@", "it": "a questo ritmo: 100%% alle %@", "fr": "à ce rythme : 100 %% à %@", "de": "bei diesem Tempo: 100 %% um %@", "pt": "neste ritmo: 100%% às %@"],
        "Agents": ["es": "Agentes", "it": "Agenti", "fr": "Agents", "de": "Agenten", "pt": "Agentes"],
        "Dismiss": ["es": "Descartar", "it": "Ignora", "fr": "Ignorer", "de": "Ausblenden", "pt": "Dispensar"],
        "Default model for new sessions": ["es": "Modelo por defecto para sesiones nuevas", "it": "Modello predefinito per le nuove sessioni", "fr": "Modèle par défaut des nouvelles sessions", "de": "Standardmodell für neue Sitzungen", "pt": "Modelo padrão para novas sessões"],
        "Open sessions keep their model; use /model there.": ["es": "Las sesiones abiertas mantienen su modelo; usa /model en ellas.", "it": "Le sessioni aperte mantengono il loro modello; usa /model lì.", "fr": "Les sessions ouvertes gardent leur modèle ; utilisez /model.", "de": "Offene Sitzungen behalten ihr Modell; dort /model nutzen.", "pt": "Sessões abertas mantêm o modelo; use /model nelas."],
        "Alerts": ["es": "Avisos", "it": "Avvisi", "fr": "Alertes", "de": "Hinweise", "pt": "Avisos"],
        "Limit alerts (80%, 95%, reset)": ["es": "Avisos de límite (80%, 95%, reinicio)", "it": "Avvisi dei limiti (80%, 95%, azzeramento)", "fr": "Alertes de limite (80 %, 95 %, réinit.)", "de": "Limit-Hinweise (80 %, 95 %, Reset)", "pt": "Avisos de limite (80%, 95%, reinício)"],
        "Agent finished / needs approval": ["es": "Agente terminado / necesita aprobación", "it": "Agente finito / serve approvazione", "fr": "Agent terminé / autorisation requise", "de": "Agent fertig / Freigabe nötig", "pt": "Agente terminou / precisa de aprovação"],
        "Dictation": ["es": "Dictado", "it": "Dettatura", "fr": "Dictée", "de": "Diktat", "pt": "Ditado"],
        "Names and terms to recognise, separated by commas": ["es": "Nombres y términos a reconocer, separados por comas", "it": "Nomi e termini da riconoscere, separati da virgole", "fr": "Noms et termes à reconnaître, séparés par des virgules", "de": "Namen und Begriffe, durch Kommas getrennt", "pt": "Nomes e termos a reconhecer, separados por vírgulas"],
        "Press Enter after pasting": ["es": "Pulsar Enter después de pegar", "it": "Premi Invio dopo aver incollato", "fr": "Appuyer sur Entrée après le collage", "de": "Nach dem Einfügen Enter drücken", "pt": "Pressionar Enter após colar"],
        "Remove filler words (um, eh…)": ["es": "Quitar muletillas (eh, este…)", "it": "Rimuovi intercalari (ehm…)", "fr": "Supprimer les hésitations (euh…)", "de": "Füllwörter entfernen (äh…)", "pt": "Remover vícios de linguagem (hum…)"],
        "Default": ["es": "Por defecto", "it": "Predefinito", "fr": "Par défaut", "de": "Standard", "pt": "Padrão"],
        "Effort": ["es": "Esfuerzo", "it": "Impegno", "fr": "Effort", "de": "Aufwand", "pt": "Esforço"],

        // Sessions, drop, handoff and Wrapped
        "thinking…": ["es": "pensando…", "it": "sta pensando…", "fr": "réfléchit…", "de": "denkt nach…", "pt": "pensando…"],
        "editing %@": ["es": "editando %@", "it": "modifica %@", "fr": "modifie %@", "de": "bearbeitet %@", "pt": "editando %@"],
        "running %@": ["es": "ejecutando %@", "it": "esegue %@", "fr": "exécute %@", "de": "führt %@ aus", "pt": "executando %@"],
        "reading %@": ["es": "leyendo %@", "it": "legge %@", "fr": "lit %@", "de": "liest %@", "pt": "lendo %@"],
        "searching %@": ["es": "buscando %@", "it": "cerca %@", "fr": "cherche %@", "de": "sucht %@", "pt": "buscando %@"],
        "browsing %@": ["es": "navegando %@", "it": "consulta %@", "fr": "consulte %@", "de": "ruft %@ auf", "pt": "navegando %@"],
        "delegating: %@": ["es": "delegando: %@", "it": "delega: %@", "fr": "délègue : %@", "de": "delegiert: %@", "pt": "delegando: %@"],
        "using %@": ["es": "usando %@", "it": "usa %@", "fr": "utilise %@", "de": "nutzt %@", "pt": "usando %@"],
        "%d s": ["es": "%d s", "it": "%d s", "fr": "%d s", "de": "%d s", "pt": "%d s"],
        "%d min": ["es": "%d min", "it": "%d min", "fr": "%d min", "de": "%d Min.", "pt": "%d min"],
        "working": ["es": "trabajando", "it": "al lavoro", "fr": "en cours", "de": "arbeitet", "pt": "trabalhando"],
        "waiting for you": ["es": "te espera", "it": "ti aspetta", "fr": "vous attend", "de": "wartet auf dich", "pt": "esperando você"],
        "done": ["es": "terminado", "it": "finito", "fr": "terminé", "de": "fertig", "pt": "concluído"],
        "idle": ["es": "inactiva", "it": "inattiva", "fr": "inactive", "de": "inaktiv", "pt": "inativa"],
        "Continue this task in the project “%@” (%@).\n\nWhat I asked:\n%@\n\nWhere it got to:\n%@\n\nCheck the current state of the files, then carry on.": ["es": "Continúa esta tarea en el proyecto «%@» (%@).\n\nLo que pedí:\n%@\n\nHasta dónde llegó:\n%@\n\nRevisa el estado actual de los archivos y sigue.", "it": "Continua questa attività nel progetto «%@» (%@).\n\nCosa ho chiesto:\n%@\n\nA che punto è arrivato:\n%@\n\nControlla lo stato attuale dei file e prosegui.", "fr": "Poursuis cette tâche dans le projet « %@ » (%@).\n\nCe que j’ai demandé :\n%@\n\nOù en était le travail :\n%@\n\nVérifie l’état actuel des fichiers, puis continue.", "de": "Setze diese Aufgabe im Projekt „%@“ (%@) fort.\n\nMeine Anfrage:\n%@\n\nStand der Arbeit:\n%@\n\nPrüfe den aktuellen Stand der Dateien und mach weiter.", "pt": "Continue esta tarefa no projeto “%@” (%@).\n\nO que pedi:\n%@\n\nAté onde chegou:\n%@\n\nVerifique o estado atual dos arquivos e continue."],
        "%@ has been waiting for you in %@": ["es": "%1$@ lleva un rato esperándote en %2$@", "it": "%1$@ ti aspetta da un po’ in %2$@", "fr": "%1$@ vous attend depuis un moment dans %2$@", "de": "%1$@ wartet in %2$@ schon eine Weile auf dich", "pt": "%1$@ está esperando você em %2$@"],
        "Handoff prompt copied. Paste it in %@.": ["es": "Prompt de traspaso copiado. Pégalo en %@.", "it": "Prompt di passaggio copiato. Incollalo in %@.", "fr": "Prompt de relais copié. Collez-le dans %@.", "de": "Übergabe-Prompt kopiert. In %@ einfügen.", "pt": "Prompt de transferência copiado. Cole no %@."],
        "Path pasted where you were typing.": ["es": "Ruta pegada donde estabas escribiendo.", "it": "Percorso incollato dove stavi scrivendo.", "fr": "Chemin collé là où vous écriviez.", "de": "Pfad dort eingefügt, wo du geschrieben hast.", "pt": "Caminho colado onde você estava digitando."],
        "Drop to paste the path": ["es": "Suelta para pegar la ruta", "it": "Rilascia per incollare il percorso", "fr": "Déposez pour coller le chemin", "de": "Loslassen, um den Pfad einzufügen", "pt": "Solte para colar o caminho"],
        "Your week": ["es": "Tu semana", "it": "La tua settimana", "fr": "Votre semaine", "de": "Deine Woche", "pt": "Sua semana"],
        "back in %@": ["es": "vuelve en %@", "it": "torna tra %@", "fr": "de retour dans %@", "de": "wieder in %@", "pt": "volta em %@"],
        "Sessions": ["es": "Sesiones", "it": "Sessioni", "fr": "Sessions", "de": "Sitzungen", "pt": "Sessões"],
        "Last response": ["es": "Última respuesta", "it": "Ultima risposta", "fr": "Dernière réponse", "de": "Letzte Antwort", "pt": "Última resposta"],
        "Copy response": ["es": "Copiar respuesta", "it": "Copia risposta", "fr": "Copier la réponse", "de": "Antwort kopieren", "pt": "Copiar resposta"],
        "Continue in Claude": ["es": "Continuar en Claude", "it": "Continua in Claude", "fr": "Continuer dans Claude", "de": "In Claude fortsetzen", "pt": "Continuar no Claude"],
        "Continue in Codex": ["es": "Continuar en Codex", "it": "Continua in Codex", "fr": "Continuer dans Codex", "de": "In Codex fortsetzen", "pt": "Continuar no Codex"],
        "My week with AI agents": ["es": "Mi semana con agentes de IA", "it": "La mia settimana con gli agenti IA", "fr": "Ma semaine avec des agents IA", "de": "Meine Woche mit KI-Agenten", "pt": "Minha semana com agentes de IA"],
        "tasks finished": ["es": "tareas terminadas", "it": "attività completate", "fr": "tâches terminées", "de": "erledigte Aufgaben", "pt": "tarefas concluídas"],
        "lines written": ["es": "líneas escritas", "it": "righe scritte", "fr": "lignes écrites", "de": "geschriebene Zeilen", "pt": "linhas escritas"],
        "on Claude": ["es": "en Claude", "it": "su Claude", "fr": "sur Claude", "de": "für Claude", "pt": "no Claude"],
        "hours of agent work": ["es": "horas de trabajo de agentes", "it": "ore di lavoro degli agenti", "fr": "heures de travail des agents", "de": "Stunden Agentenarbeit", "pt": "horas de trabalho dos agentes"],
        "favourite model": ["es": "modelo favorito", "it": "modello preferito", "fr": "modèle préféré", "de": "Lieblingsmodell", "pt": "modelo favorito"],
        "top project": ["es": "proyecto principal", "it": "progetto principale", "fr": "projet principal", "de": "Top-Projekt", "pt": "projeto principal"],
        "busiest day": ["es": "día más productivo", "it": "giorno più produttivo", "fr": "jour le plus productif", "de": "produktivster Tag", "pt": "dia mais produtivo"],
        "Made with AgentNotch · open source": ["es": "Hecho con AgentNotch · código abierto", "it": "Creato con AgentNotch · open source", "fr": "Créé avec AgentNotch · open source", "de": "Erstellt mit AgentNotch · Open Source", "pt": "Feito com AgentNotch · código aberto"],
        "No finished tasks yet this week. Enable agent alerts to start counting.": ["es": "Aún no hay tareas terminadas esta semana. Activa los avisos de agentes para empezar a contar.", "it": "Nessuna attività completata questa settimana. Attiva gli avvisi degli agenti per iniziare a contare.", "fr": "Aucune tâche terminée cette semaine. Activez les alertes d’agents pour commencer.", "de": "Diese Woche noch keine erledigten Aufgaben. Aktiviere Agenten-Hinweise zum Zählen.", "pt": "Nenhuma tarefa concluída nesta semana. Ative os avisos dos agentes para começar a contar."],
        "Save image": ["es": "Guardar imagen", "it": "Salva immagine", "fr": "Enregistrer l’image", "de": "Bild speichern", "pt": "Salvar imagem"],
        "Image saved.": ["es": "Imagen guardada.", "it": "Immagine salvata.", "fr": "Image enregistrée.", "de": "Bild gespeichert.", "pt": "Imagem salva."],
        "Couldn't save the image.": ["es": "No se pudo guardar la imagen.", "it": "Impossibile salvare l’immagine.", "fr": "Impossible d’enregistrer l’image.", "de": "Bild konnte nicht gespeichert werden.", "pt": "Não foi possível salvar a imagem."],
        "%@ %@ limit is available again": ["es": "El límite de %2$@ de %1$@ vuelve a estar disponible", "it": "Il limite %2$@ di %1$@ è di nuovo disponibile", "fr": "La limite %2$@ de %1$@ est de nouveau disponible", "de": "%1$@-Limit %2$@ ist wieder verfügbar", "pt": "O limite de %2$@ do %1$@ está disponível de novo"],
        "Path copied. Paste it with Cmd+V.": ["es": "Ruta copiada. Pégala con Cmd+V.", "it": "Percorso copiato. Incollalo con Cmd+V.", "fr": "Chemin copié. Collez-le avec Cmd+V.", "de": "Pfad kopiert. Mit Cmd+V einfügen.", "pt": "Caminho copiado. Cole com Cmd+V."],
        "Show in Finder": ["es": "Mostrar en Finder", "it": "Mostra nel Finder", "fr": "Afficher dans le Finder", "de": "Im Finder zeigen", "pt": "Mostrar no Finder"],
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
