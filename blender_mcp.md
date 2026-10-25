# Blender mit opencode steuern (MCP)

Kurzanleitung für die `werkstatt-workstation`. Die Einrichtung ist in
`hosts/werkstatt-workstation/blender.nix` beschrieben.

## Was ist MCP?

**MCP (Model Context Protocol)** ist ein Standard, über den ein KI-Assistent
Werkzeuge benutzen kann. Ein *MCP-Server* ist ein kleines Programm, das solche
Werkzeuge anbietet, z. B. „Szene auslesen“ oder „Python-Code in Blender ausführen“.
Das Sprachmodell entscheidet, wann es welches Werkzeug aufruft. opencode führt den
Aufruf aus und gibt dem Modell das Ergebnis zurück.

Bei uns hängen vier Teile hintereinander:

```
 Du ──► opencode ──► mcp-for-blender ──TCP-Port 9876──► Blender-Addon ──► Blender
        (Terminal)    (MCP-Server,                      („MCP for Blender“,
           │           startet opencode selbst)          läuft in Blender)
           ▼
        Ollama (Sprachmodell, lokal auf der GPU)
```

- **opencode** startet `mcp-for-blender` automatisch, das steht in
  `/etc/opencode/opencode.json`.
- **mcp-for-blender** verbindet sich bei jedem Werkzeug-Aufruf mit `localhost:9876`.
- Das **Blender-Addon** lauscht auf Port 9876 und führt die Befehle in Blender aus.

> **Wichtig:** Zeigt opencode `blender connected`, heißt das nur, dass
> `mcp-for-blender` läuft. Ob Blender selbst erreichbar ist, sieht man daran nicht.
> Das steht auch da, wenn Blender gar nicht offen ist.

## Voraussetzungen

| # | Voraussetzung | Wie prüfen |
|---|---------------|------------|
| 1 | **Blender ist geöffnet**, und zwar vom selben Benutzer, der opencode benutzt. | Blender-Fenster ist offen. |
| 2 | **Addon ist aktiv und der Server läuft.** Das passiert automatisch beim Start von Blender. | In Blender im 3D-Viewport `N` drücken, Reiter **„MCP for Blender“**: Dort muss **„Connected on port 9876“** stehen. Sonst auf **„Connect to MCP server“** klicken. |
| 3 | **Nur ein Blender offen.** Ein zweites Blender bekommt den Port nicht. | Im Reiter steht beim zweiten „Not connected“. |
| 4 | **Ein Modell, das Werkzeuge kann.** Alle vier eingetragenen Modelle können das. Kleine Modelle verhaspeln sich aber leichter. | In opencode `/models`. Empfehlung siehe unten. |
| 5 | **opencode sieht die richtige Config.** | Im Terminal `opencode mcp list` muss `blender` zeigen. |

Die Reihenfolge, in der du Blender und opencode startest, ist egal.

### Welches Modell?

| Modell | Größe | Eignung für Blender |
|--------|-------|---------------------|
| `gemma4:12b` | 8 GB | Gut, kann außerdem Bilder ansehen (Viewport-Screenshots). |
| `qwen3.5:9b` | 6,5 GB | Standard, solider Allrounder, kann auch Bilder. |
| `qwen3.5:4b` | 3,3 GB | Schnell, aber bei mehreren Schritten unzuverlässig. |
| `qwen2.5-coder:14b` | 9 GB | **Nicht für Blender/MCP geeignet.** Schreibt Werkzeug-Aufrufe nur als JSON-Text, statt sie auszuführen (getestet). Außerdem passt es mit 32k Kontext nicht ganz in die GPU und ist dadurch langsam. Gut für reine Code-Fragen ohne Werkzeuge. |

Lokale Modelle sind deutlich schwächer als große Online-Modelle. Kleine, klare
Aufträge funktionieren besser als „bau mir eine Stadt“.

## Schritt für Schritt

1. **Blender starten.** Im 3D-Viewport `N` drücken, Reiter „MCP for Blender“:
   „Connected on port 9876“ abwarten.
2. **Terminal öffnen**, in einen Arbeitsordner wechseln und `opencode` starten.
3. Optional mit `/models` ein Modell wählen.
4. **Erst die Verbindung testen**, z. B.:
   > Rufe get_addon_status auf und sag mir, ob Blender erreichbar ist.
5. **Dann kleine Aufträge geben**, z. B.:
   > Beschreibe die aktuelle Blender-Szene.

   > Lösche den Standardwürfel und erstelle eine UV-Kugel mit Radius 2 bei (0, 0, 1).

   > Gib der Kugel ein rotes, glänzendes Material.

   > Füge eine Kamera hinzu, die von schräg oben auf die Kugel schaut, und setze sie als aktive Kamera.

   > Mach einen Screenshot vom Viewport und sag mir, was du siehst.

Die Änderungen erscheinen sofort im Blender-Fenster. Mit `Strg+Z` in Blender kann man
sie wie gewohnt rückgängig machen.

## Welche Werkzeuge gibt es?

Das Modell sucht sich die Werkzeuge selbst aus. Es hilft aber, sie zu kennen:

| Werkzeug | Was es tut |
|----------|-----------|
| `get_addon_status` | Prüft, ob Blender erreichbar ist. |
| `get_scene_info` | Liest Objekte, Materialien, Kameras usw. aus der Szene. |
| `execute_blender_code` | Führt beliebigen Python-Code (`bpy`) in Blender aus. Fast alles läuft hierüber. |
| `look`, `viewport_capture` | Screenshot vom Viewport, damit das Modell „sehen“ kann (nur Modelle mit Vision). |
| `search_assets`, `import_asset` | Fertige Modelle/Texturen von Poly Haven, Sketchfab usw. (siehe unten). |
| `generate_3d` | 3D-Modelle per KI erzeugen (Hyper3D, kostenpflichtig, nicht eingerichtet). |

## Gut zu wissen

- **Vorher speichern.** `execute_blender_code` kann alles, was Python in Blender kann,
  auch Objekte löschen oder Dateien überschreiben. opencode fragt vor
  Werkzeug-Aufrufen nicht unbedingt nach.
- **Asset-Bibliotheken sind aus.** Im Reiter „MCP for Blender“ kann man unter
  „Asset Libraries“ Poly Haven (kostenlos) oder Sketchfab (API-Key nötig) einschalten.
  Die brauchen Internet, die Daten laufen dann über diese Dienste.
- **Telemetrie:** Im Addon ist „Allow Telemetry“ standardmäßig aus
  (Edit → Preferences → Add-ons → MCP for Blender). Soll das Programm sicher nichts
  senden, kann man in der opencode-Config für den MCP-Server
  `DISABLE_TELEMETRY=true` setzen. Das ist noch nicht eingerichtet.
- **Andere Benutzer:** Das Addon wird beim Anmelden für jeden Benutzer automatisch
  eingerichtet. Es funktioniert also auch mit anderen Konten, nicht nur mit `erfindergeist`.

## Wenn es nicht klappt

| Problem | Lösung |
|---------|--------|
| Modell sagt „Could not connect to Blender“ | Blender offen? Im Reiter „MCP for Blender“ auf „Connect to MCP server“ klicken. |
| Reiter „MCP for Blender“ fehlt | Edit → Preferences → Add-ons, nach „MCP for Blender“ suchen und Haken setzen. |
| Als Antwort kommt JSON wie `{"name": "blender_execute_blender_code", "arguments": …}`, aber in Blender passiert nichts | Das Modell hat den Aufruf nur als Text geschrieben. Passiert mit `qwen2.5-coder:14b`. Mit `/models` auf `qwen3.5:9b` oder `gemma4:12b` wechseln. |
| Modell ruft keine Werkzeuge auf, sondern erklärt nur, wie man's machen würde | Größeres Modell wählen (`gemma4:12b`) und ausdrücklich sagen: „Benutze das Blender-Werkzeug“. |
| `blender` fehlt in `opencode mcp list` | `echo $OPENCODE_CONFIG` muss `/etc/opencode/opencode.json` zeigen, sonst neu anmelden bzw. neu starten. |
| Lauscht Blender überhaupt? | Im Terminal: `ss -ltn \| grep 9876`. Steht da eine Zeile, lauscht das Addon. |
