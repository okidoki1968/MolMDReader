# MolMDReader Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Een alleen-lezen markdown-lezer voor Windows in Lazarus: favorieten en mappenboom links, opgemaakte markdown rechts, zoeken, onthoudt de laatste map.

**Architecture:** Pure Pascal-units zonder UI (instellingen, bestandsboom, geschiedenis, markdown-voorbewerking, zoeken) die met fpcunit worden getest, plus één VCL-achtige LCL-form die ze aan elkaar knoopt. Markdown wordt naar HTML omgezet en getoond in WebView2 met een eigen licht/donker-stylesheet. Taak 1 is een proef die de WebView2-binding en de markdown-parser vastlegt; de rest van het plan hangt daaraan.

**Tech Stack:** Lazarus 4.8 / FPC 3.2.2 (`C:\lazarus`, `lazbuild`), fpcunit, fpjson (instellingen), WebView2 Evergreen runtime (aanwezig op deze pc), een Pascal-WebView2-binding en markdown-parser te kiezen in Taak 1.

**Spec:** `docs/superpowers/specs/2026-10-16-molmdreader-design.md`

## Global Constraints

- Alleen Windows (Windows 11 is het doel); Lazarus-project met de naam `MolMDReader`.
- Het programma schrijft **nooit** naar bestanden van de gebruiker; alleen naar `%APPDATA%\MolMDReader` (instellingen en WebView2-gegevensmap).
- Alleen `.md`-bestanden en de mappen die daar naartoe leiden staan in de boom.
- Scripts in markdown worden niet uitgevoerd; ruwe HTML wordt niet uitgevoerd; `http(s)`-links openen in de standaardbrowser; lokale afbeeldingen worden getoond; andere bestandstypen openen niet vanuit een link.
- Markdown-dialect: GFM (tabellen, takenlijsten, doorhalen, codeblokken) plus frontmatter (verborgen) en `[[wikilinks]]`.
- Zoeken: huidige map inclusief submappen als standaard, optie "alles onder de hoofdmap"; zoekt in bestandsnamen én inhoud; live op de achtergrond, geen index.
- Een favoriet openen maakt die map de nieuwe hoofdmap. Terug/vooruit werkt per bestand.
- Bij elke wijziging opslaan: hoofdmap, huidige map, geopend bestand. Bij opstarten herstellen.
- Thema: licht en donker, volgt standaard Windows, knop om te wisselen; Segoe UI, vlak ontwerp.
- Mocht WebView2 in Taak 1 niet werken: terugvallen op een ingebouwde HTML-viewer en dat in de spec noteren.

## Review Focus

- Opgeslagen hoofdmap of bestand bestaat niet meer bij het opstarten: tonen een lege staat of de map-kies-knop, geen crash (Taak 2 en 8).
- WebView2-runtime ontbreekt: duidelijke melding met downloadlink, programma sluit netjes (Taak 10).
- Bestand met UTF-8 BOM, ongeldige UTF-8 of heel groot (>5 MB): wordt getoond of netjes overgeslagen, zoeken loopt er niet op vast (Taak 5 en 6).
- Links met spaces, hoofdletters, unicode of `#anker`, en wikilinks naar een bestaand of niet-bestaand bestand (Taak 5).
- Map met onleesbare submap of symbolische-lus, of het geopende bestand wordt verwijderd terwijl het open staat (Taak 3 en 8).

---

### Task 1: Project, testproject en proef (spike)

**Files:**
- Create: `MolMDReader.lpi`, `MolMDReader.lpr`, `src/fMain.pas`, `src/fMain.lfm` (lege form), `tests/MolMDReaderTests.lpi`, `tests/MolMDReaderTests.lpr`, `.gitignore`, `docs/superpowers/spikes/webview2-markdown.md`

**Interfaces:**
- Produces: bouwbaar project (`lazbuild MolMDReader.lpi`) en testrunner (`lazbuild tests/MolMDReaderTests.lpi`, dan `tests\MolMDReaderTests.exe --all --format=plain`); in het spike-document de gekozen WebView2-binding (naam, bron, hoe te installeren) en de gekozen markdown-parser, met als vorm `function MarkdownToHtml(const Markdown: string): string` die uit die parser volgt.

- [ ] **Step 1: `git init`, maak project en testproject aan** met `lazbuild`-bouwbare lege projecten; `.gitignore` bevat `lib/`, `*.exe`, `*.compiled`, `backup/`, `.superpowers/`.
- [ ] **Step 2: Proef WebView2.** Installeer een Lazarus-compatibele WebView2-binding (zoek naar WebView4Delphi/Lazarus-ondersteuning of een andere binding); toon in de lege form een webview met `<h1>test</h1>`, met gegevensmap in `%APPDATA%\MolMDReader\webview`. Verwacht: venster toont de kop. Lukt het niet binnen redelijke moeite, noteer waarom en kies de ingebouwde viewer (`THtmlViewer`/`Ipro`) als terugval.
- [ ] **Step 3: Proef markdown-parser.** Kies een Pascal-parser met FPC-ondersteuning die GFM-tabellen, takenlijsten en doorhalen aankan (bijvoorbeeld delphi-markdown van Grahame Grieve); render er een voorbeeld mee in de webview. Lukt dat niet, gebruik een gebundelde `marked.min.js` binnen de pagina en pas `MarkdownToHtml` in Taak 7 aan naar "pagina met script dat markdown rendert" met ruwe-HTML sanitizing.
- [ ] **Step 4: Leg de uitkomst vast** in `docs/superpowers/spikes/webview2-markdown.md` (keuze, installatiestappen, versies, wat niet werkte).
- [ ] **Step 5: Verifieer.** Run `lazbuild MolMDReader.lpi` en de testrunner. Verwacht: beide bouwen, testrunner meldt 0 tests, 0 fouten.
- [ ] **Step 6: Commit** `chore: project skeleton and WebView2/markdown spike`.

### Task 2: Instellingen

**Files:**
- Create: `src/uSettings.pas`
- Test: `tests/uTestSettings.pas`

**Interfaces:**
- Produces: `TAppSettings = class` met `RootDir`, `CurrentDir`, `CurrentFile: string`; `Theme: TThemeMode (tmSystem, tmLight, tmDark)`; `Favorites: TStringList`; `SearchAll: Boolean`; `constructor Create(const FilePath: string)`; `procedure Load`; `procedure Save`; `function DefaultSettingsPath: string` (geeft `%APPDATA%\MolMDReader\settings.json` en maakt de map aan); `procedure AddFavorite(const Dir: string)` (geen dubbelen, hoofdletterongevoelig); `procedure RemoveFavorite(const Dir: string)`; `procedure ValidatePaths` (zet `RootDir/CurrentDir/CurrentFile` op leeg als ze niet meer bestaan; `CurrentFile` ook leeg als `CurrentDir` leeg is).

- [ ] **Step 1: Schrijf tests** `TestRoundTrip` (alle velden na Save+Load gelijk), `TestLoadMissingFileGivesDefaults` (geen uitzondering; `Theme = tmSystem`), `TestLoadCorruptJsonGivesDefaults`, `TestAddFavoriteIgnoresDuplicates` (`C:\A` en `c:\a`), `TestValidatePathsClearsMissing`.
- [ ] **Step 2: Run tests, verwacht FAIL** (unit bestaat niet).
- [ ] **Step 3: Implementeer `TAppSettings`** met `fpjson`/`jsonparser`; schrijf atomisch (naar `.tmp` en dan hernoemen).
- [ ] **Step 4: Run tests, verwacht PASS.**
- [ ] **Step 5: Commit** `feat: settings with favorites and path validation`.

### Task 3: Bestandsboom

**Files:**
- Create: `src/uFileTree.pas`
- Test: `tests/uTestFileTree.pas`

**Interfaces:**
- Produces: `TTreeNode = record Name, FullPath: string; IsDir: Boolean; Children: array of ...` (gebruik een class `TMdNode` met `Children: TObjectList`); `function ScanMdTree(const Root: string): TMdNode` (alleen `.md` en mappen met minstens één `.md` eronder; mappen vóór bestanden, alfabetisch hoofdletterongevoelig; onleesbare mappen worden overgeslagen; symbolische mappen/junctions worden niet gevolgd); `function CountMdFiles(Node: TMdNode): Integer`.

- [ ] **Step 1: Schrijf tests** met een tijdelijke mapstructuur: `TestOnlyMdFilesAndNeededFolders` (lege map en map met alleen `.txt` ontbreken), `TestSortOrderFoldersFirst`, `TestSkipsUnreadableFolder` (maak map zonder toegang of simuleer met een niet-bestaand pad), `TestDoesNotFollowSymlinkLoop`, `TestCountMdFiles`.
- [ ] **Step 2: Run, verwacht FAIL.**
- [ ] **Step 3: Implementeer** met `FindFirst/FindNext`; sla `faSymLink` en reparse points over.
- [ ] **Step 4: Run, verwacht PASS.**
- [ ] **Step 5: Commit** `feat: markdown file tree scan`.

### Task 4: Terug/vooruit-geschiedenis

**Files:**
- Create: `src/uNavHistory.pas`
- Test: `tests/uTestNavHistory.pas`

**Interfaces:**
- Produces: `TNavHistory = class` met `procedure Visit(const FilePath: string)` (wist de vooruit-lijst; negeert hetzelfde bestand twee keer achter elkaar), `function CanBack, CanForward: Boolean`, `function Back: string`, `function Forward: string`, `function Current: string`.

- [ ] **Step 1: Schrijf tests** `TestBackForward`, `TestVisitClearsForward`, `TestSameFileTwiceIgnored`, `TestEmptyHistory` (`CanBack = False`, `Current = ''`).
- [ ] **Step 2: Run, verwacht FAIL.**
- [ ] **Step 3: Implementeer** met een `TStringList` en een index.
- [ ] **Step 4: Run, verwacht PASS.**
- [ ] **Step 5: Commit** `feat: navigation history`.

### Task 5: Markdown-voorbewerking en linkherleiding

**Files:**
- Create: `src/uMdPrepare.pas`
- Test: `tests/uTestMdPrepare.pas`

**Interfaces:**
- Produces: `function ReadMdFile(const Path: string): string` (UTF-8 met of zonder BOM; ongeldige bytes worden vervangen, geen uitzondering; bij bestanden >5 MB de eerste 5 MB plus de regel `*(bestand ingekort)*`); `function StripFrontmatter(const Text: string): string` (alleen als de tekst met `---` begint en er een afsluitende `---` volgt); `function ConvertWikiLinks(const Text, BaseDir, RootDir: string): string` (`[[Naam]]` en `[[Naam|Tekst]]` worden `[Tekst](pad)` naar het eerste bestaande `Naam.md` onder `BaseDir`, dan `RootDir`; geen treffer wordt `[Tekst](#niet-gevonden)`); `type TLinkKind = (lkExternal, lkMarkdown, lkAnchor, lkBlocked)`; `function ClassifyLink(const Href, BaseDir: string; out ResolvedPath: string): TLinkKind` (`http(s)` is extern, `.md` met `%20`/unicode/`#anker` wordt opgelost tegen `BaseDir` en moet bestaan, `#...` is anker, al het andere is geblokkeerd).

- [ ] **Step 1: Schrijf tests:** `TestReadBomAndInvalidUtf8` (geen uitzondering), `TestReadLargeFileTruncates`, `TestStripFrontmatter` (met, zonder, niet afgesloten), `TestWikiLinkPlainAndAlias`, `TestWikiLinkMissingTarget`, `TestClassifyExternal`, `TestClassifyMdWithSpacesAndAnchor` (`Mijn%20Notitie.md#kop`), `TestClassifyUnknownExtensionBlocked`, `TestClassifyMissingMdBlocked`.
- [ ] **Step 2: Run, verwacht FAIL.**
- [ ] **Step 3: Implementeer** de vier functies; `ClassifyLink` decodeert met `HTTPDecode` en normaliseert paden.
- [ ] **Step 4: Run, verwacht PASS.**
- [ ] **Step 5: Commit** `feat: markdown preparation and link classification`.

### Task 6: Zoeken

**Files:**
- Create: `src/uSearch.pas`
- Test: `tests/uTestSearch.pas`

**Interfaces:**
- Consumes: `ReadMdFile` uit Taak 5.
- Produces: `TSearchHit = record FilePath: string; Line: Integer; Snippet: string; NameMatch: Boolean end`; `function SearchFolder(const Dir, Query: string; Cancel: PBoolean): TArray<TSearchHit>` (hoofdletterongevoelig; bestandsnaam- en inhoudstreffers, maximaal één treffer per regel, maximaal 500 totaal; leeg zoekwoord geeft niets); `TSearchThread = class(TThread)` met `constructor Create(const Dir, Query: string; OnDone: TSearchDoneEvent)` en `procedure Cancel`, die `OnDone(Hits)` in de hoofdthread aanroept en nooit een uitzondering doorlaat.

- [ ] **Step 1: Schrijf tests:** `TestNameMatch`, `TestContentMatchHasLineAndSnippet`, `TestCaseInsensitive`, `TestSubfoldersIncluded`, `TestEmptyQueryNoHits`, `TestCancelStopsEarly`, `TestUnreadableFileSkipped`.
- [ ] **Step 2: Run, verwacht FAIL.**
- [ ] **Step 3: Implementeer** met `ScanMdTree`-achtige enumeratie (hergebruik de map-regels uit Taak 3 voor symlinks).
- [ ] **Step 4: Run, verwacht PASS.**
- [ ] **Step 5: Commit** `feat: background search`.

### Task 7: HTML-pagina en thema's

**Files:**
- Create: `src/uMdRender.pas`, `assets/light.css`, `assets/dark.css`, `assets/base.css` (als resources in het programma)
- Test: `tests/uTestMdRender.pas`

**Interfaces:**
- Consumes: parser uit Taak 1, `StripFrontmatter` en `ConvertWikiLinks` uit Taak 5, `TThemeMode` uit Taak 2.
- Produces: `function MarkdownToHtml(const Markdown: string): string` (alleen de body; ruwe HTML en `<script>` worden geëscaped of verwijderd); `function BuildPage(const Body: string; Dark: Boolean): string` (volledige pagina met CSS ingebed, Segoe UI, een `Content-Security-Policy` die scripts blokkeert); `function ResolveDark(Mode: TThemeMode): Boolean` (voor `tmSystem` de Windows-instelling uit het register `AppsUseLightTheme`).

- [ ] **Step 1: Schrijf tests:** `TestTableTaskListStrikethrough` (output bevat `<table`, checkbox, `<del`), `TestRawScriptNotExecutable` (invoer `<script>alert(1)</script>` geeft uitvoer zonder werkend `<script`), `TestPageContainsCspAndCss`, `TestDarkPageUsesDarkCss`.
- [ ] **Step 2: Run, verwacht FAIL.**
- [ ] **Step 3: Implementeer** en schrijf de drie CSS-bestanden (vlak, ruime witruimte, nette koppen, tabellen, codeblokken; kleuren via CSS-variabelen).
- [ ] **Step 4: Run, verwacht PASS.**
- [ ] **Step 5: Commit** `feat: html rendering with light/dark themes`.

### Task 8: Hoofdscherm en navigatie

**Files:**
- Modify: `src/fMain.pas`, `src/fMain.lfm`

**Interfaces:**
- Consumes: alle units uit Taak 2 t/m 7 en de WebView2-binding uit Taak 1.
- Produces: `TMainForm` met bovenbalk (map openen, zoekbalk, ◀ ▶), links een favorietenpaneel (boven) en een mappenboom (onder), rechts de webview, onderaan een statusbalk (bestandsnaam, wijzigingsdatum, aantal bestanden); `procedure OpenFile(const Path: string; AddToHistory: Boolean)`; `procedure OpenRoot(const Dir: string)`.

- [ ] **Step 1: Bouw de layout** zoals de mockup (`.superpowers/brainstorm/.../layout-v2.html`), met splitter tussen links en rechts.
- [ ] **Step 2: Wire instellingen:** laad bij start, `ValidatePaths`, herstel root, map en bestand; zijn die leeg, toon een lege staat met de knop "Map openen…". Sla bij elke wijziging op.
- [ ] **Step 3: Boom en favorieten:** vul de boom met `ScanMdTree`, klik opent bestand; ＋ voegt de huidige map toe, klik op een favoriet roept `OpenRoot` aan, rechtsklik "Verwijderen".
- [ ] **Step 4: Weergave:** `OpenFile` leest met `ReadMdFile`, bouwt de pagina en toont die in de webview. Navigatie in de webview wordt onderschept en via `ClassifyLink` afgehandeld: extern opent in de browser, markdown opent in de lezer, anker scrollt, geblokkeerd doet niets.
- [ ] **Step 5: ◀ ▶** via `TNavHistory`, knoppen uitgeschakeld waar niet mogelijk.
- [ ] **Step 6: Verversen:** `TTimer` (1 s) vergelijkt wijzigingsdatum van het open bestand; herlaad bij verschil; is het bestand weg, toon "Bestand niet meer beschikbaar" en ververs de boom.
- [ ] **Step 7: Verifieer handmatig:** start het programma met een testmap met submappen, wikilink, tabel, frontmatter, link met spaties; sluit, start opnieuw en controleer dat map en bestand terugkomen; hernoem de map buiten het programma en start opnieuw (verwacht lege staat zonder crash). Run `lazbuild MolMDReader.lpi` en de testrunner; verwacht 0 fouten.
- [ ] **Step 8: Commit** `feat: main window, navigation, restore on startup`.

### Task 9: Zoek-UI

**Files:**
- Modify: `src/fMain.pas`, `src/fMain.lfm`

**Interfaces:**
- Consumes: `TSearchThread` uit Taak 6, `TAppSettings.SearchAll` uit Taak 2.

- [ ] **Step 1: Zoekbalk met schakelaar** "Huidige map | Alles" (waarde wordt opgeslagen in `SearchAll`); Ctrl+F zet de focus in de zoekbalk.
- [ ] **Step 2: Resultatenlijst** vervangt tijdelijk de boom: bestandsnaam, regelnummer en snippet; klik opent het bestand; Esc of leegmaken toont de boom weer. Een nieuwe zoekopdracht annuleert de lopende; start na 300 ms typpauze.
- [ ] **Step 3: Verifieer handmatig** in een map met een paar honderd notities: zoeken blijft vloeiend, annuleren werkt, schakelaar wisselt bereik. Run de testrunner; verwacht 0 fouten.
- [ ] **Step 4: Commit** `feat: search UI with scope toggle`.

### Task 10: Afwerking

**Files:**
- Modify: `src/fMain.pas`, `MolMDReader.lpr`

- [ ] **Step 1: Themaknop** (Systeem/Licht/Donker) die `Theme` opslaat en de pagina en de vensterkleuren direct bijwerkt; vorm het VCL-gedeelte (boom, panelen, balken) mee in donker.
- [ ] **Step 2: Ontbrekende WebView2-runtime:** bij het opstarten een melding "WebView2-runtime ontbreekt" met de downloadlink, daarna netjes afsluiten.
- [ ] **Step 3: Sneltoetsen:** Ctrl+F (zoeken), Alt+Links/Rechts (terug/vooruit), F5 (verversen).
- [ ] **Step 4: Verifieer handmatig:** wissel thema's, controleer dat het programma tijdens het hele gebruik niets in de testmap wijzigt (vergelijk bestandsdatums voor en na). Run `lazbuild MolMDReader.lpi` en de testrunner; verwacht 0 fouten.
- [ ] **Step 5: Commit** `feat: theme toggle, runtime check, shortcuts`.
