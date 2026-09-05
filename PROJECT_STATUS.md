# Projektstand

Stand: 5. September 2026
Version: `0.4.1+8`

## Aktueller Produktstand

Moonkeep ist ein Spark-first Online-Kalender für kleine private Gruppen. Nach
Anmeldung und E-Mail-Bestätigung kann ein Nutzer einen Kalender erstellen oder
per Einladungscode beitreten. Bestehende Mitglieder öffnen direkt ihren
gemeinsamen Kalender.

Gemeinsame Daten liegen in Cloud Firestore und werden bei laufender App live
synchronisiert. Angezeigt wird nur bestätigter Serverstand; der lokale
Firestore-Cache ist deaktiviert. Die feste Kalenderzeitzone ist
`Europe/Berlin`. Cloud Functions, Blaze und Push-Benachrichtigungen werden nicht
verwendet.

## Umgesetzt und integriert

- Registrierung, Login, E-Mail-Verifikation, Passwort-Reset, Logout und
  Sitzungswiederherstellung
- Kalender erstellen, per einmaligem 128-Bit-Code beitreten, Einladungen
  widerrufen, Mitgliedschaft verlassen und Besitz atomar übertragen
- Spark-kompatible fachliche Kalenderauflösung; aufgelöste Kalender sind für
  bisherige Mitglieder nicht mehr nutzbar
- gemeinsame Termine erstellen, bearbeiten und löschen, mit Revisionsschutz
  und Live-Synchronisierung
- normale, ganztägige und inklusive Mehrtagestermine
- tägliche, wöchentliche, zweiwöchentliche, monatliche und jährliche Serien mit
  optionalem Enddatum; Monate ohne den ursprünglichen Kalendertag werden
  übersprungen
- Serien bleiben jeweils ein Firestore-Dokument; Bearbeiten und Löschen
  betreffen derzeit die gesamte Serie
- drei Wichtigkeitsstufen, optionale Mitgliederzuordnung, stabile
  Mitgliederfarben, Anzeigenamen und Filter nach Mitglied
- fokussierte Monatsansicht, kompakte Wochenansicht und Tagesdetail
- Reminder V2: keine Erinnerung, zur Startzeit, 15/30 Minuten, eine Stunde oder
  einen Tag vorher; vorhandene alte 10-Minuten-Werte bleiben lesbar
- lokale Busy-Zustände sowie kurze, nichttechnische Erfolgs- und Fehlermeldungen
  für die wichtigen Nutzeraktionen

Alte Firestore-Termine ohne Ganztägig-, Wiederholungs-, Mehrtag-, Reminder- oder
Zuordnungsfelder bleiben kompatibel.

## Architektur und Sicherheit

- Gemeinsame Daten benötigen ein angemeldetes Konto mit bestätigter
  E-Mail-Adresse; ein Nutzer gehört höchstens einem aktiven Kalender an.
- Firestore verwendet intern weiterhin `families`; Regeln und Datenmodell
  behandeln Familien ohne Statusfeld rückwärtskompatibel als aktiv.
- Kalenderanlage, Mitgliedschaft, Einladung, Beitritt, Austritt,
  Besitzerwechsel und Auflösung sind in den kritischen Übergängen atomar.
- Fremde Kalender, Mitgliederdaten und Einladungslisten sind gesperrt. Events,
  Activity, Einladungen und Mitglieder eines aufgelösten Kalenders können nicht
  normal weiterverwendet werden.
- Event-Felder, Reminder-Werte, Datumsgrenzen und Revisionen werden durch
  `firestore.rules` validiert; unbekannte Pfade sind standardmäßig verweigert.
- Die Rules erlauben in `assignedMemberIds` derzeit nur eine begrenzte Liste,
  prüfen aber nicht Typ, Leerwerte oder tatsächliche Kalenderzugehörigkeit jedes
  Eintrags. Der Client prüft strenger; diese Abweichung sollte vor einer breiten
  Beta geschlossen werden.
- Firebase-Konfiguration wird beim Build aus einer ignorierten lokalen Datei
  geladen. Produktionsregeln liegen in `firestore.rules`.

## Verifikation

Am 5. September 2026 erfolgreich:

- `flutter test --no-pub`: 75 Tests
- `flutter analyze --no-pub`: keine Befunde
- offizieller Firestore-Emulatorlauf: 29 Rules-Tests
- Android Debug APK mit der vorhandenen Firebase-Konfiguration gebaut

Automatisiert abgedeckt sind Auth- und Account-UI, Familien- und
Einladungsabläufe, Besitzwechsel und Auflösung, CalendarEvent-Modell und
Firestore-Mapping, Kalender-Store und -Screen, Editor, Wiederholungen,
Ganztägig-/Mehrtagestermine, Filter/Farben/Anzeigenamen, Reminder und Firestore
Rules.

Auf zwei echten Android-Geräten manuell bestätigt sind die zentralen
Registrierungs-, Kalender-, Einladungs-, Termin-, Serien-, Ganztägig-,
Mehrtag-, Filter-, Besitzerwechsel-, Austritts-, Auflösungs- und
Live-Synchronisierungsabläufe. Eine Erinnerung zur Startzeit wurde bestätigt;
die übrigen Reminder-Abstände sind rechnerisch getestet, aber noch nicht alle
praktisch auf einem Gerät abgewartet.

## Beta-Readiness und bekannte Grenzen

Moonkeep ist für eine kleine, eng begleitete private Android-Beta geeignet. Vor
einer Store- oder breiteren Beta sind insbesondere folgende Punkte offen:

1. Kontolöschung und der Umgang mit einem löschwilligen Owner fehlen.
2. Android Release-Signierung verwendet noch den Debug-Schlüssel; außerdem muss
   vor der nächsten verteilten Version die Versionsnummer erhöht werden.
3. `assignedMemberIds` muss in den Rules auf gültige Stringwerte und nach
   Möglichkeit auf aktuelle Mitglieder begrenzt werden.
4. Wiederkehrende Reminder planen aktuell nur den ursprünglichen Serienstart,
   nicht jedes berechnete Vorkommen.
5. Lokale Reminder anderer Geräte werden nur synchronisiert, wenn die App dort
   läuft und den aktuellen Serverstand empfängt. Bei geschlossener App gibt es
   weder Push noch serverseitige Planung.
6. Aufgelöste Kalender und historische Events werden fachlich gesperrt, aber
   nicht physisch gelöscht. E-Mail-Adressen verbleiben in Memberdokumenten;
   akzeptierte und abgelaufene Einladungsdokumente werden nicht automatisch
   bereinigt.
7. Firebase App Check sowie Crash-/Diagnose-Telemetrie sind nicht eingerichtet.
8. Die Live-Abfrage lädt derzeit alle Event-Dokumente eines kleinen Kalenders;
   für größere oder lang laufende Kalender fehlt eine Bereichspaginierung.

Kurze Netzunterbrechungen führen bewusst zu einem verständlichen
Verbindungszustand statt zur Bearbeitung möglicherweise veralteter Cache-Daten.
Nach Wiederverbindung synchronisiert die laufende App erneut. Bei vollständig
geschlossener App findet keine Datensynchronisierung statt.

## iOS-Stand

Die iOS-Projektstruktur und Bundle-ID `dev.moonkeep.moonkeep` sind vorhanden,
wurden auf Windows aber nicht gebaut. Vor einer iOS-Beta fehlen eine eigene
iOS-Firebase-App-Konfiguration und ein Build-/Gerätetest auf macOS/Xcode. Die
Benachrichtigungsberechtigung wird im Dart-Code angefragt, die geplante
Notification enthält derzeit jedoch nur Android-spezifische Details; lokale
iOS-Reminder sind deshalb noch ein Blocker. App-Icons und weiterer iOS-Polish
können anschließend geprüft werden.

## Nächster Fokus

1. Kontolöschungs- und Owner-Lifecycle fachlich entscheiden und implementieren.
2. Android Release-Signierung, Versionierung und Rules-Validierung für
   Mitgliederzuordnungen abschließen.
3. Wiederkehrende Reminder fachlich eindeutig begrenzen oder vollständig
   planen.
4. Erst danach iOS-Firebase-/Notification-Konfiguration und iOS-Gerätetest.

## Arbeitszustand

Der Review ist abgeschlossen. Feature-Commits und dieser Dokumentationsstand
sind lokal; ein Push erfolgt nur nach ausdrücklicher Freigabe.
