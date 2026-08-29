# Moonkeep – MVP 0.1

## Ziel und Grenzen

Eine Familie verwaltet einen gemeinsamen Kalender. Erwachsene Familienmitglieder
können Termine sehen, erstellen, bearbeiten und löschen. Für den MVP gehört ein
Nutzer zu genau einer Familie. Das ist eine Arbeitsannahme, keine endgültige
Produktentscheidung.

Enthalten: Registrierung/Anmeldung, Familie erstellen, Mitglied einladen,
Monatsansicht mit Tagesagenda, Terminverwaltung und Synchronisierung.

Später: Push-Nachrichten, Google-/Apple-Kalendersynchronisierung, Serientermine,
Aufgaben, Einkaufslisten, mehrere Familien pro Nutzer und separate Kinderkonten.

## Erster Entwicklungsschritt: lokaler Kalender

- Eine deutsche Monatsansicht mit Tagesauswahl und Heute-Schaltfläche.
- Ein Termin hat Titel, Datum, Beginn, Ende und optionale Notizen.
- Beginn und Ende liegen zunächst am selben Tag; Ende muss nach Beginn liegen.
- Termine werden nach Beginn sortiert und lokal auf dem Gerät gespeichert.
- Änderungen und Löschungen bleiben nach einem Neustart erhalten.
- Löschen benötigt eine Bestätigung; Abbrechen verändert keine Daten.
- Lade- und Speicherfehler werden sichtbar, fehlerhafte Daten nicht still ersetzt.
- Keine Anmeldung und keine Synchronisierung; diese Grenze steht auch in der UI.

Lokale Zeit ohne Zeitzonenwechsel ist eine bewusste Grenze dieses Prototyps.
Vor Synchronisierung wird ein Zeitzonenmodell festgelegt. Ganztägige und
mehrtägige Termine werden gesondert modelliert, nicht aus Zeitstempeln geraten.

## Vorgesehene Architektur

`lib/features/calendar/` enthält Terminmodell, lokalen Datenspeicher und UI.
Die UI kommuniziert mit dem Datenspeicher, nicht direkt mit Firebase. Für die
Synchronisierung wird diese Grenze bei Bedarf zu einer Repository-Schnittstelle
erweitert; vorab wird kein allgemeines Framework aufgebaut.

Firebase Authentication und die Firestore-Datenschicht sind implementiert.
Lokale Emulator-Tests prüfen die Regeln; die Live-Datenbank und der Zwei-Nutzer-Test
bleiben vor einer Nutzung mit privaten Daten erforderlich.

## Anforderungen vor gemeinsamer Nutzung

- Authentifizierte Nutzer dürfen ausschließlich auf ihre Familie zugreifen.
- Einladungen sind zeitlich begrenzt, einmalig und serverseitig geprüft.
- Familienzugehörigkeit darf nicht durch einen beliebigen Client änderbar sein.
- Firestore-Regeln und Einladungslogik werden mit Emulatoren getestet.
- Zeitzonen, parallele Änderungen, Offline-Verhalten und Kontolöschung sind geklärt.
- Ein Zwei-Nutzer-Test belegt Synchronisierung und Trennung verschiedener Familien.

Offene Entscheidungen: Firebase-Projekt/Region, Anmeldemethoden, Familienrollen,
App-Kennung für die Stores, Umgang mit Konflikten und Zeitzonen.
