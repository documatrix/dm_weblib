
Die DmWebLib bietet die Funktion eines Web-Servers der sich gut einbinden lässt um einerseits
Ressourcen-Anfragen aus einem File oder einem Directory zu handeln, andererseits bietet sie aber
auch die Möglichkeit über eine Callback-Funktion eigenen Code für HTTP-Requests ausführen zu lassen.

Folgendes ist durchzuführen um die DmWebLib verwenden zu können:
Code
====
using DmWebLib;

Kompilieren
===========
Mit Vala: valac ... -X -ldmweblib --pkg gio-2.0 --pkg libsoup-2.4 --pkg dmweblib ...

Mit gcc: gcc ... -ldmweblib ...

