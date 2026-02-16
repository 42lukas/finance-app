# Finance

Private iOS-App zum Verwalten von Schulden und Forderungen im Freundes- und Familienkreis.

Die App fokussiert sich auf:
- schnelle Erfassung von Einträgen
- saubere Verwaltung von Teilzahlungen
- aussagekräftige Statistiken
- Siri-Shortcuts zum sprachgesteuerten Anlegen von Einträgen

## Funktionen

### 1) Schulden- und Forderungsverwaltung
- Einträge für `schulde ich` und `bekomme ich`
- Betragserfassung über Schrittweiten (`0,01`, `0,10`, `1,00`, `10,00` EUR)
- manueller Betrag per Long-Press auf den Betragswert
- moderner Eintrag-Dialog mit klarer Kartenstruktur
- Namens-Autocompletion im Personenfeld basierend auf bestehenden Einträgen (Prefix-Matching, z. B. `Er` -> `Eric`)
- Beschreibung/Grund pro Eintrag

### 2) Listen-Interaktion
- Swipe nach rechts: Betrag bearbeiten
- Swipe nach links: Eintrag archivieren (Soft Delete)
- archivierte Einträge verschwinden aus der Schuldenliste, bleiben aber für Statistiken erhalten

### 3) Teilzahlungen
- pro Eintrag beliebig viele Teilzahlungen
- Übersicht direkt im Listenelement:
  - Gesamt
  - bereits bezahlt
  - offen
- Teilzahlungen nur über den Button `Teilzahlung hinzufügen`
- Teilzahlungshistorie mit Datum/Uhrzeit pro Zahlung
- Ausklappen der Historie nur über Chevron-Button
- visuelles „Komplett bezahlt“-Banner, wenn offen = 0

### 4) Statistik-Tab
- Zeitraum-Umschaltung: `Monat`, `Jahr`, `All Time`
- Kennzahlen:
  - Anzahl Einträge
  - Gesamtvolumen
  - Ich schulde
  - Ich bekomme
  - Durchschnitt
  - Anzahl Personen
- Cluster/Insights:
  - häufigste Person
  - größte Volumen-Person
  - Konzentrationsindex (Top-3)
  - vollständig bezahlte Einträge
- Charts:
  - Zeitverlauf (Ich schulde vs. Ich bekomme)
  - Top-Personen
  - Wochentagsmuster

### 5) Statistik-Datenbereinigung (Hard Delete)
- eigener Bereich im Statistik-Tab: `Statistik-Daten bereinigen`
- einzelnes endgültiges Löschen von Einträgen
- optional: alle archivierten Einträge endgültig löschen
- endgültig gelöschte Einträge werden auch aus Statistiken entfernt

### 6) Siri / App Intents
- AppIntents für schnelles Anlegen per Siri/Shortcuts:
  - `Schuldeneintrag (Ich schulde)`
  - `Schuldeneintrag (Ich bekomme)`
- Beispiel-Phrasen:
  - „Ich schulde in Finance"
  - „Ich bekomme in Finance"

### 7) Erinnerungen
- Benachrichtigungsberechtigung beim App-Start
- wiederkehrende Erinnerung um 20:00 Uhr (falls erlaubt)

## Tech Stack
- Swift 5
- SwiftUI
- Core Data
- Charts
- AppIntents (Siri/Shortcuts)
- UserNotifications

## Voraussetzungen
- Xcode 16+
- iOS Deployment Target: `17.6`
- Bundle Identifier: `com.example.finance`

## Projekt lokal starten

1. Repository öffnen:
   - `Finance.xcodeproj`
2. In Xcode ein iPhone-Simulator oder Gerät wählen
3. Build & Run (`Cmd + R`)

## Nutzung

### Eintrag erstellen
1. Im Tab `Schulden` auf `+` tippen
2. Betrag wählen (Buttons oder Long-Press + manuelle Eingabe)
3. Person und Beschreibung eingeben
4. Kategorie wählen (`schulde ich` / `bekomme ich`)
5. `Eintrag speichern`

### Teilzahlung erfassen
1. Eintrag in der Liste öffnen
2. `Teilzahlung hinzufügen` tippen
3. Betrag eingeben und speichern

### Eintrag bearbeiten/archivieren
- Bearbeiten: Swipe nach rechts
- Archivieren: Swipe nach links

### Statistik ansehen
1. In `Statistiken` wechseln
2. Zeitraum auswählen
3. Kennzahlen und Charts analysieren

### Daten endgültig löschen
1. In `Statistiken` auf `Statistik-Daten bereinigen`
2. Einträge einzeln oder archivierte gesammelt endgültig löschen

## Datenmodell (Core Data)
Entity: `Item`
- `timestamp: Date`
- `amount: Double`
- `category: String`
- `person: String`
- `descriptionText: String`
- `isArchived: Bool`
- `paidAmount: Double`
- `partialPaymentsData: Binary` (JSON-codierte Teilzahlungen)

## Projektstruktur

```text
Finance/
├── AppIntents/
│   ├── AddDebtEntryIntents.swift
│   └── FinanceAppShortcuts.swift
├── Features/
│   ├── Debts/
│   │   └── Services/
│   │       └── DebtEntryCreationService.swift
│   └── Statistics/
│       ├── Models/
│       │   └── StatisticsModels.swift
│       ├── Services/
│       │   └── StatisticsCalculator.swift
│       └── Views/
│           ├── Components/
│           │   └── StatisticsCards.swift
│           ├── StatisticsDataManagementView.swift
│           └── StatisticsView.swift
├── Views/
│   ├── DebtsView.swift
│   └── SheetView.swift
├── ContentView.swift
├── FinanceApp.swift
├── Persistence.swift
└── Finance.xcdatamodeld/
```

## Datenschutz
- Alle Daten werden lokal in Core Data gespeichert.
- Keine Cloud-Synchronisation und kein externer Serverzugriff durch die App-Logik.

## Troubleshooting

### Siri sagt „App unterstützt diesen Vorgang nicht"
- Sicherstellen, dass die aktuelle Build-Version mit aktivierten AppIntents installiert ist
- App mindestens einmal manuell öffnen
- In der Kurzbefehle-App prüfen, ob `Finance`-Shortcuts verfügbar sind
- Siri in iOS aktiviert lassen und Gerät neu starten, falls Shortcuts nicht sofort erscheinen

## Roadmap-Ideen
- Export/Backup (z. B. JSON/CSV)
- Filter und Suche in der Schuldenliste
- FaceID/Passcode-Schutz
- Wiederkehrende Einträge

---

built by Lukas
~ new repo to remove privacy Date
