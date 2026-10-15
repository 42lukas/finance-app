# Even

Even ist eine private iOS-App zum Verwalten von Schulden und Forderungen im Freundes- und Familienkreis. Alle Daten bleiben lokal auf dem Gerät. Ein Home-Screen-Widget greift über eine gemeinsame App Group auf denselben Core-Data-Speicher zu.

## Funktionen

### Schulden und Forderungen

- Einträge für `schulde ich` und `bekomme ich`
- Person, Grund, Betrag und Erstellungszeitpunkt
- optionales Fälligkeitsdatum
- Swipe nach rechts zum Bearbeiten
- Swipe nach links zum Archivieren
- aktuelle Summen für offene Schulden und Forderungen

### Teilzahlungen

- beliebig viele Teilzahlungen pro Eintrag
- optionale Notiz und Zeitstempel pro Zahlung
- Bearbeiten und Löschen bestehender Teilzahlungen
- Fortschrittsanzeige für bezahlt und offen
- vollständig bezahlte Einträge bleiben nachvollziehbar

### Archiv

- archivierte Einträge werden aus der aktiven Übersicht ausgeblendet
- Wiederherstellung aus dem Archiv
- Rückgängig-Aktion direkt nach dem Archivieren
- bei einer Widget-Erledigung kann auch die automatisch erzeugte Abschlusszahlung zurückgenommen werden
- endgültiges Löschen über die Datenverwaltung

### Fälligkeitserinnerungen

- Erinnerungen basieren auf dem Fälligkeitsdatum
- wählbar sind eine, drei oder fünf Erinnerungen
- frei wählbare Uhrzeit, standardmäßig 18:00 Uhr
- mehrere Einträge mit demselben Fälligkeitsdatum werden gebündelt
- erledigte oder archivierte Einträge werden nicht weiter erinnert
- bei deaktivierten Mitteilungsvorschauen zeigt der Sperrbildschirm nur einen neutralen Hinweis

Für geschützte Vorschauen auf dem iPhone:

`Einstellungen → Mitteilungen → Even → Vorschauen zeigen → Wenn entsperrt`

### Statistiken

Die Statistiken beziehen archivierte Einträge in historische Gesamtwerte ein und zeigen:

- Gesamtbilanz aus Forderungen minus Schulden
- aktuell offenen Gesamtwert
- kumulative Bilanz über die Zeit
- am häufigsten auftretende Personen
- älteste und größte offene Schuld
- bezahlten Anteil am Gesamtvolumen mit Fortschritt und Prozentwert

### Widget

Even stellt kleine und mittlere Home-Screen-Widgets bereit:

- aktueller Saldo
- Gesamtsummen für Schulden und Forderungen
- Eintrag mit der nächsten Fälligkeit
- offener Betrag und Fälligkeitsstatus
- direktes Erledigen und automatisches Archivieren eines Eintrags

### Backup und Darstellung

- JSON-Export aller aktiven und archivierten Einträge
- System-, Hell- und Dunkelmodus
- keine Cloud-Synchronisation und kein externer Serverzugriff

Der aktuelle Backup-Stand unterstützt den Export. Eine Wiederherstellung aus einer JSON-Datei ist noch nicht implementiert.

## Technischer Aufbau

- Swift 5
- SwiftUI
- Core Data
- WidgetKit und App Intents
- Charts
- UserNotifications
- Deployment Target: iOS 17.6
- sichtbarer App-Name und Version: Even 2.0
- Release Bundle Identifier: `com.lukas42.finance`

Die internen Namen `Finance`, `Finance.sqlite` und `group.com.lukas42.finance` bleiben aus Kompatibilitätsgründen bestehen. Sie sichern Updates und den Zugriff auf vorhandene TestFlight-Daten.

## Projektstruktur

```text
Finance/
├── App/
│   ├── ContentView.swift
│   └── FinanceApp.swift
├── Features/
│   ├── Archive/
│   │   ├── Models/
│   │   ├── Services/
│   │   └── Views/
│   ├── Backup/
│   │   ├── Models/
│   │   └── Services/
│   ├── Debts/
│   │   ├── Models/
│   │   └── Views/
│   │       └── Components/
│   ├── Reminders/
│   │   ├── Models/
│   │   ├── Services/
│   │   └── Views/
│   ├── Settings/
│   │   └── Views/
│   └── Statistics/
│       ├── Models/
│       ├── Services/
│       └── Views/
├── Infrastructure/
│   ├── EvenSharedStore.swift
│   └── PersistenceController.swift
├── Theme/
│   ├── AppTheme.swift
│   └── Components/
├── Assets.xcassets/
├── Finance.entitlements
└── Finance.xcdatamodeld/

EvenWidget/
├── EvenOverviewWidget.swift
├── EvenWidgetBundle.swift
└── EvenWidget.entitlements
```

### Widget Shared Dependencies

Diese Gruppe im Xcode-Navigator ist ein virtueller Satz von Dateiverweisen und kein zusätzlicher Ordner. Die Dateien liegen weiterhin unter `Finance/`, werden aber auch in die separate Widget Extension kompiliert. Dazu gehören der gemeinsame Store-Zugriff, Zahlungsmodell und -berechnung, Archivservice sowie das Core-Data-Modell.

Die Einträge sind keine Dateikopien und dürfen nicht ohne Ersatz aus dem Widget-Target entfernt werden.

### Core-Data-Versionen

`Finance.xcdatamodeld` enthält die Modellstände `Finance` bis `Finance 4`. Dabei handelt es sich nicht um vier Nutzerdatenbanken, sondern um Schema-Versionen für automatische Migrationen:

- `Finance`: ursprüngliches Modell
- `Finance 2`: Fälligkeitsdatum
- `Finance 3`: stabile Eintrags-ID
- `Finance 4`: Archivmetadaten und Widget-Wiederherstellung

`Finance 4` ist das aktuelle Modell. Die älteren Versionen bleiben enthalten, damit Installationen früherer App-Versionen ihre bestehenden Daten weiterhin öffnen und migrieren können.

## Projekt starten

1. `Finance.xcodeproj` in Xcode öffnen.
2. Ein iPhone, iPad oder einen Simulator auswählen.
3. Das Scheme `Finance` starten (`Cmd + R`).

Für das Widget müssen App und Widget Extension dieselbe App Group verwenden. Auf einem neuen Gerät sollte Even mindestens einmal geöffnet werden, bevor das Widget Daten anzeigt.

## Datenschutz

- Einträge werden lokal in Core Data gespeichert.
- App und Widget teilen den Store ausschließlich über die konfigurierte App Group.
- Es gibt keine Netzwerk- oder Cloud-Synchronisation in der App-Logik.
- JSON-Backups werden nur auf ausdrückliche Nutzeraktion über die Dateienauswahl exportiert.
