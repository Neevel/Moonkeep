# Projektstand

Stand: 30. August 2026  
Version: `0.4.1+8`

## Aktueller Produktstand

Moonkeep ist ein gemeinsamer Online-Kalender für kleine private Gruppen.

Nach Anmeldung und E-Mail-Bestätigung kann ein Nutzer:

- einen Kalender als Familie, Partnerschaft, Freunde oder WG erstellen,
- unter „Sonstiges“ einen eigenen Kalendernamen vergeben,
- per Einladungscode einem Kalender beitreten.

Bestehende Mitglieder öffnen nach der Anmeldung direkt ihren gemeinsamen Kalender.

Der frühere lokale Kalender ist nicht mehr Teil der Nutzerführung. Vorhandene lokale Daten werden nicht ungefragt gelöscht oder hochgeladen.

Gemeinsame Kalenderdaten liegen in Cloud Firestore. Angezeigt wird nur bestätigter Serverstand. Die feste Zeitzone ist `Europe/Berlin`.

## Umgesetzt

- Firebase E-Mail-Konten und Sitzungswiederherstellung
- E-Mail-Verifikation einschließlich erneuertem Firebase-ID-Token
- Kalender erstellen und per Einladungscode beitreten
- Mitgliederliste mit Besitzer-/Mitglied-Rollen
- sichere Einladungscodes mit Ablauf, Widerruf und atomarem Einmalverbrauch
- gemeinsame Terminverwaltung
- Live-Synchronisierung zwischen Mitgliedern/Geräten
- Revisionsschutz gegen veraltete Änderungen
- drei Wichtigkeitsstufen für Termine
- optionale Android-Erinnerungen
- farbige Terminmarkierungen in der Monatsansicht
- Aktivitätseinträge bei Erstellen und Löschen
- Live-Hinweise für andere Mitglieder bei geöffnetem Kalender
- normale Mitglieder können einen Kalender nach Bestätigung sicher verlassen
- Besitzer können den Besitz atomar an ein bestehendes Mitglied übertragen;
  der bisherige Besitzer wird dabei normales Mitglied
- Kalenderverwaltung und Konto sind aus dem Kalenderkopf erreichbar

Besitzer können den Kalender weiterhin nicht verlassen oder auflösen.

## Architektur und Sicherheit

- Gemeinsame Daten benötigen Anmeldung und bestätigte E-Mail-Adresse.
- Ein Nutzer gehört im MVP höchstens einem gemeinsamen Kalender an.
- Firestore verwendet intern weiterhin die Collection-Struktur `families`.
- Kalenderanlage, Mitgliedschaft, Einladung, Beitritt und Austritt erfolgen atomar.
- Zugriffe auf fremde Kalender, Mitglieder und Einladungen sind gesperrt.
- Terminwerte und Revisionen werden serverseitig durch Firestore-Regeln validiert.
- Unbekannte Firestore-Pfade sind standardmäßig verweigert.
- Gemeinsame Daten verwenden keinen lokalen Firestore-Cache.
- Offline wird ein Verbindungsfehler statt möglicherweise veralteter Daten angezeigt.
- Produktionsregeln liegen in `firestore.rules`.
- Firebase-Konfiguration für Android kommt aus `config/firebase.android.json`.
- Produktionsdatenbank: `(default)`, Region `europe-west10`.

## Aktueller Teststand

Zuletzt vollständig erfolgreich:

- `flutter analyze --no-pub`
- `flutter test --no-pub`: 38 Tests
- Firestore Emulator: 20 Regel-/Synchronisierungstests
- Android Debug Build mit Firebase-Konfiguration

Auf echten Android-Geräten bestätigt:

- Registrierung und Anmeldung
- Sitzung bleibt nach App-Neustart erhalten
- zwei Konten auf zwei Geräten
- gemeinsames Erstellen, Anzeigen und Löschen von Terminen
- Live-Synchronisierung ohne manuelles Neuladen

Im virtuellen Android-Gerät bestätigt:

- atomare Übertragung des Kalenderbesitzes an ein bestehendes Mitglied

Virtuelles Testgerät:

- Pixel 8
- Android 16 / API 36
- AVD `Moonkeep_Pixel_8`

## Deployment

Aktuelle Android-Version:

`0.4.1+8`

APK:

`build/app/outputs/flutter-apk/app-debug.apk`

Die korrigierte Version `0.4.1+8` wurde über Firebase App Distribution verteilt.

Die korrigierte `firestore.rules`-Version ist veröffentlicht und der
Besitzerwechsel damit manuell bestätigt.

Firebase CLI ist lokal nicht angemeldet.

## Nächste Tasks

Priorität:

1. Kalenderauflösung
2. Kontolöschung

Danach geräteübergreifend prüfen:

- Mitgliederliste
- Live-Hinweise
- Wichtigkeitsfarben
- kurzfristige Android-Erinnerung

Später:

- Firebase App Check
- weitere Android-Gerätetests
- iOS-Firebase-Konfiguration und iOS-Tests
- Store-Vorbereitung

Push-Benachrichtigungen bei vollständig geschlossener App sind noch nicht umgesetzt. Dafür wären Firebase Cloud Messaging und ein vertrauenswürdiger Server-Auslöser erforderlich.

## Arbeitszustand

Alle aktuellen Änderungen sind lokal.

Ohne ausdrücklichen Nutzerwunsch keinen Commit oder Push erstellen.
