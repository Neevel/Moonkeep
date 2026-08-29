# Familien und gemeinsamer Kalender

## Modell

Moonkeep trennt den lokalen Kalender bewusst vom Familienkalender. Lokale Termine
werden nicht automatisch hochgeladen. Der Familienkalender liegt in Cloud
Firestore und wird in Version 0.2 nur mit bestätigter Serververbindung angezeigt;
der SDK-Cache ist dafür deaktiviert. Uhrzeiten sind zivile Uhrzeiten der Familie
in `Europe/Berlin`, keine umgerechneten UTC-Zeitpunkte.

Ein bestätigter Nutzer gehört im MVP zu höchstens einer Familie. Das Erstellen
einer Familie legt Familie und Mitgliedschaft atomar an. Einladungen verwenden
zufällige 128-Bit-Codes, laufen nach spätestens sieben Tagen ab und werden beim
Beitritt atomar genau einmal verbraucht. Nur der Besitzer kann Codes erzeugen und
widerrufen. Alle Familienmitglieder dürfen gemeinsame Termine bearbeiten.

Termine haben eine fortlaufende Revision. Die App schreibt oder löscht nur die
Revision, die der Nutzer geöffnet hat. Bei einer parallelen Änderung erscheint
ein Konflikt statt eines stillen Überschreibens.

## Sicherheit

`firestore.rules` prüft bestätigte Anmeldung, Familienmitgliedschaft,
unveränderliche Mitgliedschaften, Besitz von Einladungen, Ablauf und einmaligen
Codeverbrauch, Feldtypen, Längen, echte Kalendertage und Revisionsschritte.
Unbekannte Pfade werden verweigert. Regeln und App bleiben zwei getrennte
Schutzschichten: Die Regeln schützen auch gegen manipulierte Clients, die App
ergänzt eine verständliche Konfliktbehandlung.

Die automatischen Tests verwenden ausschließlich die feste Demo-Projekt-ID
`demo-moonkeep`. Der Emulator blockiert Zugriffe auf nicht emulierte Dienste bei
Demo-Projekten. Mit lokalem Java und Node:

```powershell
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
pnpm install
pnpm test:rules
```

Abgedeckt sind unter anderem anonyme und unbestätigte Nutzer, Familienisolation,
gefälschte Mitgliedschaften, nicht aufzählbare Einladungen, Ablauf, Widerruf,
gleichzeitiger Codeverbrauch, ungültige Termine, Live-Synchronisierung und
veraltete Revisionen.

## Live-Einrichtung

Vor einem echten Zwei-Nutzer-Test werden im Firebase-Projekt benötigt:

1. Cloud Firestore Standard Edition im Native Mode und eine einmalig gewählte Region.
2. Deployment von `firestore.rules` und `firestore.indexes.json`.
3. Zwei bestätigte Testkonten auf getrennten Geräten oder App-Installationen.

Keine Test- oder offenen Produktionsregeln verwenden. Bis Regeln erfolgreich
bereitgestellt sind, darf keine Familie mit echten privaten Daten angelegt werden.
Live-Stand am 29. August 2026: Die Standarddatenbank wurde als Standard Edition
im Produktionsmodus und Spark-Tarif in `europe-west10` (Berlin) angelegt. Die
lokal getestete Datei `firestore.rules` wurde anschließend veröffentlicht. Die
Firebase Console zeigte danach die Live-Version 10:24 Uhr ohne unveröffentlichte
Änderungen. Das Regel-Deployment erfolgte über die Konsole, weil die lokale
Firebase CLI nicht angemeldet ist.

Offizielle Grundlagen: [Regelbedingungen](https://firebase.google.com/docs/firestore/security/rules-conditions),
[atomare Transaktionen](https://firebase.google.com/docs/firestore/manage-data/transactions),
[Regeltests](https://firebase.google.com/docs/rules/unit-tests) und
[Firestore-Standorte](https://firebase.google.com/docs/firestore/locations).
