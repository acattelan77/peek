# PEEK-111 — Prompt: export headless del calendario per Northwind Notes

## Mandato

Implementa PEEK-111: una modalità CLI headless in Peek che legge il calendario
locale tramite EventKit e produce JSON versionato su `stdout`.

L'obiettivo è alimentare una cache locale di Northwind Notes, così gli agenti senza
accesso a Google Calendar possono leggere l'agenda dal vault. Google Calendar
rimane la fonte autorevole. Peek non deve conoscere, né leggere o scrivere,
la cartella Northwind Notes.

## Prima di modificare

- Repository: `~/Dev/peek`
- Versione di partenza: 1.4.1 (build 28)
- Segui `AGENTS.md` integralmente: leggi `docs/HANDOFF.md`,
  `docs/ROADMAP.md`, `docs/ARCHITECTURE.md`, `docs/VERSIONING.md` e tutti i
  workstream attivi; controlla `git status` e non sovrascrivere lavoro altrui.
- Crea un workstream PEEK-111 e aggiungi PEEK-111 alla roadmap prima di
  iniziare l'implementazione.

## Confini di prodotto

Peek implementa soltanto l'export. Un renderer esterno, fuori dal repository,
consuma il JSON e genera nel vault:

- `_calendar.md`: agenda compatta da leggere normalmente;
- `_calendar-events.json`: dettaglio da interrogare soltanto quando serve.

Il renderer deve scrivere i file atomicamente e lasciare intatto l'ultimo
export valido se Peek o il rendering falliscono. Un job `launchd` esterno
eseguirà questo comando ogni giorno alle 06:45 e alle 13:00, più `RunAtLoad`
al login:

```zsh
/Applications/Peek.app/Contents/MacOS/Peek \
  --export --from -3 --to 14 --json \
  | <notes vault path removed>
```

Non implementare il renderer, `launchd`, né alcuna scrittura nel vault.

## CLI richiesta

Il binario dell'app deve supportare:

```text
Peek --export --from -3 --to 14 --json
```

Semantica:

1. `--export` attiva un percorso headless: nessuna menu bar, popover,
   onboarding, HUD, notifica o finestra.
2. `--json` è obbligatorio nella prima versione.
3. `--from` e `--to` sono interi firmati, in giorni locali rispetto alla
   data di esecuzione.
4. `--from -3 --to 14` copre da mezzanotte locale del giorno corrente meno
   tre giorni fino a mezzanotte locale del giorno corrente più quindici
   giorni, fine esclusiva.
5. Includi ogni evento che interseca l'intervallo, inclusi all-day ed eventi
   a cui l'utente ha risposto `declined`. Questa è una cache del calendario,
   non la lista filtrata della UI.
6. Rispetta i calendari selezionati e persistiti in Peek. Se non esiste una
   selezione esplicita, usa tutti i calendari disponibili, come il primo
   avvio corrente dell'app.
7. In assenza di autorizzazione EventKit completa, non avviare una richiesta
   di permesso: scrivi un errore comprensibile su `stderr`, non scrivere JSON
   parziale e termina con codice non-zero.
8. `--help` documenta la sintassi e termina con codice 0. Argomenti assenti o
   non validi terminano non-zero con un errore utile.
9. `stdout` contiene esclusivamente JSON; log e diagnostica vanno su `stderr`.

## Contratto JSON v1

L'output è un singolo oggetto JSON UTF-8, serializzato in ordine stabile per
`startAt`, `endAt`, `title`, `id`.

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-08-13T06:45:00+02:00",
  "timeZone": "Europe/Rome",
  "window": {
    "from": "2026-08-10T00:00:00+02:00",
    "toExclusive": "2026-08-28T00:00:00+02:00"
  },
  "events": [
    {
      "id": "opaque-stable-occurrence-id",
      "title": "Titolo evento",
      "startAt": "2026-08-13T09:30:00+02:00",
      "endAt": "2026-08-13T10:00:00+02:00",
      "allDay": false,
      "calendar": {
        "id": "eventkit-calendar-id",
        "title": "Nome calendario"
      },
      "location": "string oppure null",
      "organizer": { "name": "string oppure null" },
      "attendees": [
        {
          "name": "string",
          "response": "accepted|declined|tentative|pending|unknown",
          "isOrganizer": false
        }
      ],
      "notes": "string troncata a 500 caratteri Unicode oppure null",
      "links": [
        { "kind": "join|document|other", "url": "https://..." }
      ],
      "currentUserResponse": "accepted|declined|tentative|pending|unknown"
    }
  ]
}
```

## Requisiti di implementazione

- Gli identificatori sono opachi e il più possibile stabili per la stessa
  occorrenza. Non usare il titolo come identificatore.
- Normalizza le stringhe vuote a `null`. Non emettere campi superflui.
- Pulisci `notes` e troncale a 500 caratteri Unicode senza spezzare un
  carattere.
- Riusa `EventDetailBuilder` dove sensato per note, partecipanti, organizer e
  mapping degli stati; non duplicare logica già testata.
- Un link `join` può contenere soltanto un URL HTTPS che passa
  `MeetingURLDetector.isURLSafe`.
- Se estrai URL aggiuntivi da `notes`, `location` o `event.url`, classifica i
  meeting URL trusted come `join`; gli altri URL HTTP(S) come `document` o
  `other`. Documenta il criterio, deduplica gli URL e mantieni il primo
  incontro.
- Gli URL non-join sono metadati di export, non devono diventare azioni nella
  UI di Peek.
- Non includere allegati: EventKit su macOS non li espone.
- Non far dipendere il percorso CLI da `CalendarManager` come oggetto
  osservabile della UI. Estrai componenti testabili per parsing argomenti,
  calcolo della finestra, mapping dell'evento e serializzazione.
- Mantieni EventKit dietro `CalendarEventStoring` o una nuova boundary stretta
  e testabile; aggiorna fake e test se estendi il protocollo.
- Usa tipi valore `Codable` per il payload ed ISO 8601 con offset esplicito.
- Aggiungi una decision record per il nuovo contratto CLI e aggiorna il README
  con una sezione breve che avverta che l'output può contenere dati personali
  e non va committato, loggato o condiviso.

## Test obbligatori

Aggiungi test unitari per:

1. parsing valido e non valido degli argomenti CLI;
2. calcolo della finestra a cambio mese, anno e ora legale;
3. ordinamento deterministico;
4. serializzazione JSON conforme allo schema;
5. note vuote, whitespace e troncamento Unicode sicuro;
6. mapping degli attendee e stato dell'utente;
7. deduplica e classificazione dei link, incluso rifiuto di join URL non
   trusted;
8. selezione calendari: preferenza esplicita, nessuna preferenza esplicita e
   selezione esplicita vuota;
9. assenza di JSON parziale in caso di autorizzazione mancante o errore
   EventKit.

## Fuori scope

- Scrittura nella cartella 42 o conoscenza dei suoi file.
- Renderer Markdown/JSON del vault.
- Job `launchd` e automazioni di sistema.
- Preferenze UI dedicate all'export.
- Modifiche al comportamento della menu bar.
- Sincronizzazione bidirezionale o modifica di Google Calendar.

## Consegna

- Aggiorna workstream, roadmap, handoff, changelog e README secondo
  `AGENTS.md`.
- È una nuova capacità user-visible: applica un solo version bump appropriato.
- Esegui e riporta:
  - `bash scripts/check-version.sh`
  - `git diff --check`
  - build Debug unsigned
  - test macOS unsigned
- Includi un esempio di output JSON fittizio e il comando esatto per invocare
  l'export dalla build installata.
- Non dichiarare verificato l'accesso a un calendario reale senza prova
  manuale su una build firmata che abbia già ottenuto il permesso.
