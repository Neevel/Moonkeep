# Moonkeep Arbeitsregeln

## Produkt

- Moonkeep ist ein gemeinsamer Online-Kalender für kleine private Gruppen.
- Es gibt keinen lokalen Kalender in der Nutzerführung.
- Nach Anmeldung und E-Mail-Bestätigung: Kalender erstellen oder per Code beitreten.
- Bestehende Mitglieder öffnen direkt ihren gemeinsamen Kalender.
- Die Firestore-Struktur heißt intern weiterhin `families`; UI-Texte sprechen allgemein von Kalendern und Mitgliedern.

## Verbindlicher Stand

- Vor Arbeiten zuerst `PROJECT_STATUS.md` gezielt auf den aktuellen Task prüfen.
- Bei einem fortgesetzten Task zuerst `CURRENT_WORK.md` lesen; sie ist der
  kurze operative Wiedereinstieg und ersetzt keine Produktdokumentation.
- Bereits dokumentierte Architektur oder Entscheidungen nicht erneut aus dem Code rekonstruieren, sofern kein konkreter Widerspruch besteht.
- `PROJECT_STATUS.md` nach abgeschlossenen größeren Änderungen knapp aktualisieren.
- Firebase-Konfiguration kommt aus `config/firebase.android.json`; Geheimnisse niemals ausgeben oder einchecken.
- Produktionsregeln liegen in `firestore.rules`.
- Regeländerungen zuerst gegen den Emulator testen und erst danach veröffentlichen.
- Keine bestehenden Kalender-, Konto- oder Firestore-Daten löschen, sofern der Nutzer das nicht ausdrücklich verlangt.
- Ohne ausdrücklichen Wunsch keinen Commit oder Push erstellen.

## Kontext- und Token-effizient arbeiten

- Kontextgröße als begrenzte Ressource behandeln.
- Nur Dateien lesen, die für den aktuellen Task wahrscheinlich relevant sind.
- Mit `rg` gezielt nach Klassen, Methoden, Widgets oder Fehlertexten suchen.
- Keine vollständigen großen Dateien lesen, wenn ein relevanter Ausschnitt genügt.
- Bereits gelesene und unveränderte Dateien nicht unnötig erneut vollständig einlesen.
- Keine komplette Projektanalyse durchführen, wenn der Task lokal eingegrenzt werden kann.
- Tool-Ausgaben klein halten und auf relevante Zeilen begrenzen.
- Keine vollständigen Logs oder `logcat`-Ausgaben laden.
- Bei Fehlern zuerst nach Exception, Stacktrace oder betroffener Komponente filtern.
- Lange Build-, Firebase- oder Testausgaben nur bei einem konkreten Fehler näher untersuchen.

## Tests

- Während eines Tasks nur gezielte, betroffene Tests ausführen.
- Bevorzugt einzelne Testdateien oder gezielte Testnamen ausführen.
- Bestehende Flutter-Tests und Fixtures erweitern, statt parallele Testdateien anzulegen.
- Keine komplette Flutter-Test-Suite nach jeder Feature-Änderung ausführen.
- `flutter analyze --no-pub` nur einmal am Ende eines größeren Tasks oder wenn
  statische Fehler vermutet werden.
- `flutter test --no-pub` vollständig nur ausführen:
  - vor Release- oder Distributionsständen,
  - bei breit wirkenden Änderungen,
  - wenn der Nutzer es ausdrücklich anfordert,
  - oder wenn gezielte Tests Hinweise auf Seiteneffekte geben.
- `pnpm test:rules` nur ausführen, wenn `firestore.rules` geändert wurde oder ein
  Rules-Release vorbereitet wird.
- Bei erfolgreichen Testläufen keine langen Ausgaben weiter analysieren oder
  wiederholen.
- Bei Fehlern nur die relevante Fehlermeldung oder den betroffenen Test weiter
  untersuchen.
- Tests nicht erneut starten, wenn derselbe unveränderte Stand bereits
  erfolgreich geprüft wurde.
- Wenn eine manuelle Prüfung durch den Nutzer ausreicht, diese statt zusätzlicher
  visueller oder redundanter Testläufe verwenden.
- Vor Task-Abschluss kurz dokumentieren, welche gezielten Tests tatsächlich
  ausgeführt wurden.
- Vollständige Abschluss-Suites sind nicht pauschal Pflicht.

## Flutter-Entwicklung

- Für Emulator-Entwicklung Hot Reload/Hot Restart verwenden.
- Nicht für jede Änderung eine neue APK bauen.
- Eine neue APK oder App-Distribution-Version erst für einen echten Test- oder Release-Stand erstellen.

## Task-Arbeitsweise

- Einen Task möglichst fachlich klar eingrenzen.
- Keine benachbarten Refactorings durchführen, sofern sie für den Task nicht notwendig sind.
- Bestehende Architektur respektieren.
- Vor größeren Architekturänderungen erst analysieren und die Änderung begründen.
- Nach Abschluss kurz festhalten:
  - was geändert wurde,
  - welche Tests erfolgreich waren,
  - ob noch etwas offen ist.
- `PROJECT_STATUS.md` nur mit Informationen aktualisieren, die für einen zukünftigen Task weiterhin relevant sind.
- `CURRENT_WORK.md` nur mit Task, sicherem Zwischenstand und nächstem Schritt
  aktuell halten; nach Abschluss wieder auf „kein laufender Task“ setzen.
