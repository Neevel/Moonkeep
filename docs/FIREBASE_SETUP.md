# Firebase-Anmeldung vorbereiten

## Aktueller Stand

Die App besitzt unter **Mein Konto** einen optionalen Ablauf für E-Mail-Anmeldung,
Registrierung, Passwort-Zurücksetzen, Bestätigungsmail, Statusaktualisierung und
Abmeldung. Ohne Konfiguration bleibt der Kalender lokal nutzbar; die Kontoseite
zeigt einen Einrichtungshinweis und keine Eingabefelder für Zugangsdaten.

Der Nutzer hat das Projekt `moonkeep-e1aef` erstellt. Seine Android-Konfiguration
wurde nach Prüfung des Paketnamens in `config/firebase.android.json` übernommen.
Der konfigurierte Android-Build ist auf dem Samsung als Update installiert.
Web und iOS sind noch nicht konfiguriert. UI-Tests verwenden ein Test-Repository;
echte Registrierung und An-/Abmeldung wurden vom Nutzer bestätigt. Die dabei
gemeldete verzögerte Kontoansicht wurde in Version 0.1.0+3 korrigiert; erneuter
Gerätetest sowie Mailzustellung und Sitzungspersistenz sind noch zu prüfen.

## Vor dem Verbinden entscheiden

- Welches Firebase-Projekt wird für die Entwicklung verwendet?
- Ist `dev.moonkeep.moonkeep` als Entwicklungs-App-Kennung passend?
- E-Mail/Passwort ist zunächst die implementierte Anmeldemethode.
- Ein Entwicklungsprojekt mit Testkonten verwenden, nicht das spätere Produktivprojekt.
- Firestore-Region und Datenmodell werden erst vor der Synchronisierung festgelegt.

## Einrichtung

1. Mit dem Projektinhaber das Firebase-Projekt auswählen oder anlegen.
2. Android-/Web-/iOS-Apps im Projekt passend zu den lokalen App-Kennungen registrieren.
3. In Firebase Authentication die Anmeldemethode **E-Mail/Passwort** aktivieren.
4. Plattformwerte aus der Firebase-Konfiguration übernehmen. Der offizielle
   FlutterFire-Workflow kann diese als `firebase_options.dart` generieren.
   Diese App nimmt dieselben Build-Parameter entgegen, damit Builds ohne
   Firebase-Konfigurationsdatei weiterhin möglich sind.
5. `config/firebase.example.json` beispielsweise nach `config/firebase.android.json`
   kopieren und für Android ausfüllen. Für Web eine separate Datei verwenden;
   die `appId` ist plattformspezifisch. `authDomain` wird für Web übernommen,
   `iosBundleId` für iOS. Die vier anderen Werte sind Pflichtfelder.

Keine Service-Account-Schlüssel, privaten Schlüssel oder Benutzerpasswörter in
die Konfiguration eintragen. Die genannten Firebase-Clientwerte sind keine
Geheimnisse, werden hier aber als umgebungsspezifische Dateien ignoriert.

```powershell
.\.tools\flutter\bin\flutter.bat run -d <Android-Geräte-ID> --dart-define-from-file=config/firebase.android.json
.\.tools\flutter\bin\flutter.bat build apk --debug --dart-define-from-file=config/firebase.android.json
```

Für die Web-Vorschau entsprechend `config/firebase.web.json` verwenden.
Konfigurationsänderungen benötigen einen Neustart bzw. Neubau, keinen Hot Reload.

## Sicherheits- und Testgrenzen

- Zugangsdaten werden ausschließlich an Firebase Authentication übergeben,
  nicht im Kalender-Speicher abgelegt oder protokolliert.
- Die Firebase-SDKs verwalten die Anmeldesitzung. Persistenz und Abmeldung sind
  mit einem echten Testkonto noch auf jedem Zielsystem zu prüfen.
- Auch angemeldet ist der Kalender gerätebezogen, nicht kontobezogen. Ein
  Kontowechsel lädt keine anderen Termine. Der lokale Kalender ist nicht durch
  Login geschützt und steht jedem Nutzer des entsperrten Geräts zur Verfügung.
- Es gibt keinen automatischen Upload und keine Migration vorhandener Termine.
- E-Mail-Bestätigung wird erst durch die erneute serverseitige Statusabfrage
  sichtbar. Familienfreigaben dürfen später nur serverseitig autorisiert werden.
- Keine Firestore-Datenbank und keine offenen Datenbankregeln wurden angelegt.
- Vor einer öffentlichen Nutzung fehlen unter anderem Kontolöschung,
  Datenschutzinformationen und der vollständige Test gegen Firebase.

## Nach Verbindung prüfen

Registrierung, falsches Passwort, Anmeldung, Abmeldung und Sitzung nach Neustart;
Bestätigungsmail und Statusaktualisierung; Passwort-Reset; Netzwerkausfall;
Kontowechsel ohne Änderung der lokalen Testtermine. Nur eigene Testadressen verwenden.

Offizielle Quellen: [Flutter-Einrichtung](https://firebase.google.com/docs/flutter/setup),
[E-Mail/Passwort](https://firebase.google.com/docs/auth/flutter/password-auth),
[Authentifizierungsstatus](https://firebase.google.com/docs/auth/flutter/start).
