# Spike: WebView2 en markdown (Taak 1)

## Uitkomst

- **Weergave:** WebView2 via [WebView4Delphi](https://github.com/salvadordf/WebView4Delphi) (MIT, commit `48c37fe`, ondersteunt Lazarus). Werkt op deze pc (Lazarus 4.8, FPC 3.2.2, 32-bit doel `i386-win32`).
- **Markdown-parser:** er is geen bruikbare Pascal-parser met GFM. Gekozen: `marked` 12.0.2 (MIT) en `DOMPurify` 3.1.6 (Apache-2.0/MPL-2.0), gebundeld in `assets/`, uitgevoerd in de pagina. Daardoor vervalt `MarkdownToHtml` in Pascal; Taak 7 wordt het opbouwen van het renderbericht (zie ledger).
- **Pagina laden:** een vaste pagina `assets/index.html` via de virtuele hostnaam `https://app.molmd/` (map `assets`); notities via `https://notes.molmd/` (hoofdmap) zodat lokale afbeeldingen werken. `NavigateToString` is niet gebruikt: de bibliotheken bevatten `</script>`-tekst en er geldt een limiet van 2 MB.
- **Communicatie:** Pascal stuurt `{"type":"render","markdown":...,"baseUrl":...,"dark":...}` met `PostWebMessageAsString`; de pagina stuurt `ready`, `rendered` en `link` terug. Klikken op links worden in de pagina onderschept.
- **Veiligheid (bewezen in de proef):** `<script>` en `onerror` in markdown worden door DOMPurify verwijderd; CSP van de pagina staat alleen scripts van `app.molmd` toe; navigatie naar andere pagina's wordt geannuleerd (`OnNavigationStarting`) en nieuwe vensters worden onderdrukt (`OnNewWindowRequested`).

## Installatie

WebView4Delphi is meegeleverd in `third_party/WebView4Delphi` (alleen `source/` en `packages/`, plus de MIT-licentie). Registreer het pakket eenmalig en bouw:

```
lazbuild --add-package-link third_party\WebView4Delphi\packages\webview4delphi.lpk
lazbuild MolMDReader.lpi
```

`WebView2Loader.dll` (uit `bin32` van WebView4Delphi) staat naast `MolMDReader.exe`.

## Wat niet werkte

- Bibliotheken inlinen in een string met `NavigateToString`: brak op `</script>`.
- Bash-heredoc met losse aanhalingstekens in dit schrijfproces; bestanden zijn met de editor geschreven.
