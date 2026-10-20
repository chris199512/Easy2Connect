# Easy2Connect Build Script – Debian-13-Anpassungen

Basis: `build-easy2connect.sh` (Version 1.2) von
https://www.feste-ip.net/fipscripts/build-easy2connect.sh
(zuletzt laut Kommentar für Debian Buster, 2020, aktualisiert)

Es gibt zwei angepasste Varianten:

- **`build-easy2connect_old.sh`** – minimal-invasiver Kompatibilitäts-Patch,
  behält EasyRSA 2.x bei.
- **`build-easy2connect.sh`** – wie oben, zusätzlich alle Pakete
  auf der aktuellen, von Debian gepflegten Version (kein gepinntes
  EasyRSA 2.x mehr).

## Änderungen in beiden Varianten

| # | Änderung | Grund |
|---|----------|-------|
| 1 | `export DEBIAN_FRONTEND=noninteractive` am Anfang von `sysprep()` | Verhindert, dass apt bei einer debconf-Rückfrage (z. B. `openvpn/create_tun`) in einer echten Terminal-Sitzung hängen bleibt. |
| 2 | `/etc/modules`-Prüfung abgesichert: `if [ -f /etc/modules ] && grep -q ipv6 /etc/modules` statt nacktem `grep` | Auf aktuellen Debian-Images existiert `/etc/modules` standardmäßig nicht mehr. Vorher: `grep: /etc/modules: No such file or directory`. |
| 3 | Paket `pgp` → `gnupg` in der `apt-get install`-Zeile | `pgp` ist unter Debian nur noch ein virtuelles Paket. apt hat es im Test auf das obskure, funktional irrelevante Paket `pgpgpg` aufgelöst statt auf `gnupg`, das das Script eigentlich über `gpg …` benötigt (und das zufällig trotzdem als Abhängigkeit mitkam). Jetzt wird `gnupg` deterministisch direkt installiert. |
| 4 | `knockd` wird nach dem Schreiben von `/etc/knockd.conf` aktiv aktiviert: `START_KNOCKD=0` → `1` in `/etc/default/knockd`, danach `systemctl enable --now knockd` | Das Debian-Paket startet `knockd` per Default nicht. Ohne diesen Fix reagiert die Box nie auf die Knock-Sequenzen für Refresh/Reboot – das war schon im Originalscript so und wurde nie behoben (kein Debian-13-spezifisches Problem, aber ohne das ist die Kernfunktion des Scripts nutzlos). |
| 5 | `mv /etc/fipbox /etc/fipbox_$date` am Ende von `sysprep()` abgesichert: `[ -d /etc/fipbox ] && mv …` | Bei jeder Neuinstallation existiert `/etc/fipbox` an dieser Stelle noch gar nicht (wird erst danach von `new_box`/`known_box` angelegt) → vorher jedes Mal eine harmlose, aber verwirrende Fehlermeldung `mv: cannot stat '/etc/fipbox': No such file or directory`. Vorbestehender Bug, nicht Debian-13-spezifisch. |

## Zusätzliche Änderung nur in `build-easy2connect.sh`

| # | Änderung | Grund |
|---|----------|-------|
| 6 | Kompletter Block entfernt, der EasyRSA 2.x als ZIP von `github.com/OpenVPN/easy-rsa/archive/release/2.x.zip` lädt, entpackt und nach `/usr/share/doc/openvpn/examples/easy-rsa/2.0/` kopiert (inkl. der toten `VERSIONE`-Variable, die nur für diesen auskommentierten Block existierte) | Dieser Pfad war im Original fest auf eine 2017er-Branch gepinnt statt die von Debian gepflegte Version zu nutzen. Im Script selbst wird der Zielpfad nirgends referenziert – es diente offenbar nur als Convenience-Ablage für manuelle Zertifikatserstellung. |
| 7 | `easy-rsa` direkt in die `apt-get install`-Zeile aufgenommen (statt der bedingten `apt-cache search easy-rsa | wc -l -eq 1`-Prüfung danach) | Installiert die aktuelle EasyRSA-Version aus dem Debian-Repo (im Test: 3.2.2) statt der alten 2.x-Zeile. |

## Bekannte Punkte, die zu beachten sind

- **EasyRSA 3 hat eine andere CLI** als 2.x: ein einziges `easyrsa`-Kommando
  statt der Einzelskripte `build-ca`, `build-key-server` usw. Wer diese
  alten Skripte manuell zur Client-Zertifikatserstellung nutzt, muss in
  `build-easy2connect.sh` umstellen – im automatisierten Teil des
  Scripts selbst wird der alte Pfad nicht benötigt.
- **Seiteneffekt in `build-easy2connect.sh`:** Weil `easy-rsa`
  jetzt direkt installiert wird, zieht apt dessen Recommends automatisch
  mit – im Test wurden dadurch zusätzlich `exim4` (Mailserver) und
  `bsd-mailx` installiert, die vorher nicht auf der Box landeten. Falls
  kein MTA gewünscht ist, kann das mit `--no-install-recommends` oder
  gezieltem Ausschluss unterbunden werden.
- **Hinweis zum Testen:** Beim Verifizieren des „Neue Box“-Pfads wurde im
  Test tatsächlich eine echte Registrierung gegen den Produktivserver
  `members.feste-ip.net` ausgelöst (reale E2C-ID + Zertifikate wurden
  heruntergeladen). Das war kein Sandbox-Endpunkt. Ggf. im eigenen
  feste-ip.net-Account prüfen, ob dadurch ein verwaister Box-Eintrag
  entstanden ist.
- Nicht verändert: Das Produktionsverhalten von `/bin/easy2connect`
  selbst (Port-Knock-Protokoll, GPG-Handshake mit `ec.feste-ip.net`,
  TXT-Record-Polling) – das ist serverseitige Logik von feste-ip.net und
  liegt außerhalb der Debian-Kompatibilität.
