# Moonkeep

Ein gemeinsamer Familienkalender für Android und iOS.

## Produktziel

Eine Familie, ein Kalender: Termine gemeinsam planen, bearbeiten und auf allen
Geräten sehen. Die erste Produktversion umfasst Anmeldung, Familie erstellen,
Mitglieder einladen, Monatsansicht und synchronisierte Termine.

## Entwicklungsstand

Ein lokaler Flutter-Prototyp mit Monatsansicht, Tagesagenda und Terminverwaltung
ist umgesetzt. Termine werden als JSON mit `SharedPreferencesAsync` gespeichert.
Unter **Mein Konto** ist die Firebase-Anmeldung vorbereitet (E-Mail/Passwort,
Registrierung, Bestätigungsmail und Passwort-Reset). Ohne Firebase-Konfiguration
zeigt die App einen Einrichtungshinweis. Der Android-Testbuild ist für das
Firebase-Projekt des Nutzers konfiguriert; echte Kontoabläufe sind noch zu prüfen.
Version 0.4 enthält zusätzlich Familie erstellen/beitreten, eine Rollen- und
Mitgliederansicht, einmalige Einladungscodes und einen getrennten gemeinsamen
Firestore-Kalender mit Konflikterkennung. Wichtigkeitsstufen, farbige
Terminpunkte, lokale Android-Erinnerungen und Live-Hinweise bei
Erstellen/Löschen sind integriert. Die Zugriffsregeln sind lokal im Emulator getestet; die
Live-Datenbank in Berlin und Regel-Deployment sind eingerichtet. Der erste
Zwei-Konten-/Zwei-Geräte-Test bestätigte die direkte Synchronisierung eines neu
angelegten Termins, sofortiges Löschen sowie den Erhalt der Anmeldung nach einem
vollständigen App-Neustart. Bis die restlichen Fehlerfälle geprüft sind, nur Testdaten verwenden.

Details: [MVP](docs/MVP.md) und [Projektstand](PROJECT_STATUS.md).

## Technische Richtung

- Flutter für Android und iOS; Web zusätzlich als Entwicklungsvorschau.
- Firebase Authentication ist integriert; Android-Projektkonfiguration liegt
  lokal vor. Cloud Firestore und der gemeinsame Kalender sind implementiert.
- Kleine, nach Funktionen gegliederte Struktur; Datenzugriff getrennt von der UI.
- Deutsche Oberfläche, Montag als Wochenbeginn, 24-Stunden-Zeiten.

## Entwicklung

Das lokale SDK liegt in `.tools/flutter` und wird nicht eingecheckt. Es verändert
keine globale Flutter-Installation. Auf anderen Rechnern Flutter gemäß der
[offiziellen Anleitung](https://docs.flutter.dev/install/manual) installieren.

Verifiziert mit **Flutter 3.47.2 / Dart 3.13.2**, SDK-Revision `d3b14c8769`.
Die App-Abhängigkeiten sind über `pubspec.lock` festgehalten.

```powershell
.\.tools\flutter\bin\flutter.bat pub get
.\.tools\flutter\bin\flutter.bat analyze
.\.tools\flutter\bin\flutter.bat test
.\.tools\flutter\bin\flutter.bat run -d chrome
```

Für eine Vorschau ohne Chrome-Installation:

```powershell
.\.tools\flutter\bin\flutter.bat run -d web-server --web-hostname 127.0.0.1 --web-port 8080
```

Die angezeigte lokale Adresse im Browser öffnen. Daten gehören zum jeweiligen
Browserprofil und Ursprung (Host und Port); eine andere Adresse zeigt einen
separaten Kalender. Das Löschen der Browserdaten entfernt auch die Termine.

Shared Preferences ist ein einfacher Prototyp-Speicher ohne garantierte
Ausfallsicherheit oder Backup; bitte vorerst ausschließlich Testdaten verwenden.
Siehe [Paketdokumentation](https://pub.dev/packages/shared_preferences).

Android benötigt zusätzlich das Android-SDK; iOS-Builds benötigen macOS und Xcode.
Firebase-Konfigurationsdateien und Signierschlüssel werden nicht eingecheckt.
`dev.moonkeep.moonkeep` ist vorläufig; App-Kennung, Icons und Signierung sind vor
einer Store-Veröffentlichung zu ersetzen bzw. festzulegen.

### Android-Testversion

Das Projekt verwendet derzeit Android SDK Platform 36, Build-Tools 36.0.0 und
NDK 28.2.13676358. Android Studio und die Command-line Tools sind lokal installiert.

```powershell
.\.tools\flutter\bin\flutter.bat build apk --debug
```

Nach erfolgreichem Build liegt die Test-APK unter
`build/app/outputs/flutter-apk/app-debug.apk`. Sie verwendet einen lokalen
Debug-Schlüssel und ist nicht für eine Store-Veröffentlichung vorgesehen.

Für den Start auf einem angeschlossenen Android-Handy USB-Debugging aktivieren,
die Verbindung auf dem Handy bestätigen und anschließend ausführen:

```powershell
.\.tools\flutter\bin\flutter.bat devices
.\.tools\flutter\bin\flutter.bat run -d <Android-Geräte-ID>
```

Die Command-line Tools 23 verwenden die neue Android CLI. Ihre Ausgabe zu
`--licenses` wird von Flutter 3.47.2 noch als unbekannter Lizenzstatus eingeordnet.
Die automatische NDK-Installation scheiterte hier zusätzlich an der Übergabe des
Paketnamens. Die benötigten Versionen wurden deshalb direkt mit der Android CLI
installiert; SDK-Dateien oder Lizenzprüfungen wurden nicht manipuliert.

## Nächste Meilensteine

1. Erreicht: lokaler Kalender einschließlich Nutzertest auf dem Android-Handy.
2. Erreicht: echte Registrierung und Anmeldung im konfigurierten Android-Build.
3. Erreicht: Familien, einmalige Einladungen, synchronisierte Termine,
   Live-Datenbank und Zwei-Nutzer-Test.
4. Implementiert: Mitgliederrollen, Wichtigkeitsstufen, Monatsmarkierungen,
   Android-Erinnerungen und sichere Terminaktivität mit 15 Regeltests.
5. Kontolöschung, Push bei geschlossener App, weitere Gerätetests, App Check und
   Veröffentlichungsvorbereitung.

Einrichtung und Grenzen der Kontofunktion: [Firebase-Anleitung](docs/FIREBASE_SETUP.md).
Familienmodell und Sicherheitsgrenzen: [Firestore-Anleitung](docs/FIRESTORE_SETUP.md).
Eine Anmeldung schützt oder synchronisiert den weiterhin getrennten lokalen Kalender nicht.
