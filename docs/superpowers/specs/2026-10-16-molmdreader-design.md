# MolMDReader – ontwerp

## Intentie en waarom

Frank wil een eenvoudige, snelle lezer voor markdown-notities op Windows, in de geest van Obsidian maar zonder alle extra's. Links de mappenstructuur, rechts de opgemaakte markdown. Het is **uitsluitend een lezer**: bestanden worden nooit aangepast. Het programma wordt gebouwd in **Lazarus (Free Pascal)** en heet **MolMDReader**.

## Doelen

- Een map kiezen en daarin door de mappen- en bestandsstructuur bladeren (alleen `.md`-bestanden en de mappen die daar naartoe leiden).
- Een gekozen `.md`-bestand tonen als opgemaakte tekst, met een modern uiterlijk.
- Zoeken: standaard in de **huidige map** (inclusief submappen), met een optie om te kiezen voor **alles onder de hoofdmap**. Zoekt in bestandsnamen én inhoud; treffers worden als lijst getoond, klikken opent het bestand.
- Een **favorietenpaneel** (linksboven, boven de mappenboom): huidige map toevoegen met een ＋-knop, klikken op een favoriet opent die map, verwijderen via rechtsklik.
- Bij elke wijziging de **huidige map en het geopende bestand opslaan**; bij het opstarten weer op die map en dat bestand staan.
- Navigeren via links: klikken op een link naar een ander `.md`-bestand opent dat bestand; knoppen ◀ ▶ voor terug en vooruit.
- Automatisch verversen als het getoonde bestand op schijf verandert.
- Modern uiterlijk: licht en donker thema (standaard licht, want donker was slecht leesbaar; keuze Systeem/Licht/Donker via een knop), vlak ontwerp, ruime witruimte, Segoe UI, kleine pictogrammen in de boom.

## Niet-doelen

- Bestanden bewerken, aanmaken, hernoemen of verwijderen.
- Ondersteuning voor andere besturingssystemen dan Windows (Windows 11 is het doel).
- Obsidian-specifieke functies zoals graph view, plugins of sync.

## Anti-doelen (zou een mislukking zijn, ook als het technisch werkt)

- Het programma wijzigt, per ongeluk of automatisch, een bestand van de gebruiker.
- Het ziet er uit als een verouderd Windows-programma.
- Opstarten of zoeken voelt traag bij een map met honderden notities.

## Vastgelegde beslissingen (door Frank)

- Project heet MolMDReader, gebouwd in Lazarus.
- Layout: favorieten en mappenboom links, opgemaakte markdown rechts, zoekbalk bovenin, statusbalk onderin (zie mockup).
- Niet aanpasbaar: alleen lezen.
- Zoeken: huidige map standaard, alles als keuze.
- Favorietenpaneel en onthouden van de huidige map bij opstarten.
- Modern uiterlijk.

## Mijn keuzes (Claude; niet expliciet door Frank bevestigd)

- Markdown wordt naar HTML omgezet en getoond met de Edge-engine (WebView2) voor moderne CSS-opmaak. Alternatief was een ingebouwde Lazarus-HTML-viewer; die ziet er ouder uit.
- Favorieten en laatst geopende map/bestand staan in een kleine instellingenfile (bijvoorbeeld INI of JSON) in `%APPDATA%\MolMDReader`, niet naast het programma (werkt ook vanuit Program Files). De WebView2-gegevensmap staat daar ook.
- Frank liet twee vragen onbeantwoord ("go"); mijn keuzes: (1) markdown-dialect is GFM (tabellen, takenlijsten, doorhalen, codeblokken) plus lichte Obsidian-ondersteuning: frontmatter wordt verborgen of compact getoond en `[[wikilinks]]` werken als links; callouts en embeds zijn niet nodig. (2) WebView2 is de weergave-engine, met als eerste stap een korte proef; faalt die, dan valt het terug op een ingebouwde HTML-viewer. Bij opstarten zonder runtime een duidelijke melding met downloadlink.
- Verwijderen van een favoriet via rechtsklik.
- Veiligheid van de weergave: scripts geblokkeerd, ruwe HTML in markdown wordt niet uitgevoerd, `http(s)`-links openen in de standaardbrowser, lokale afbeeldingen worden getoond, andere bestandstypen worden niet geopend vanuit een link.
- Opening van een favoriet maakt die map de nieuwe hoofdmap; "alles zoeken" zoekt onder de huidige hoofdmap.
- Zoeken scant live op de achtergrond (geen index), uitgaande van honderden tot enkele duizenden notities.
- Terug/vooruit geldt voor bestanden; opgeslagen wordt hoofdmap, huidige map en geopend bestand.
- Opties voor later: recent geopende bestanden, inhoudsopgave per document, afbeeldingen tonen, Ctrl+P om snel een bestand te openen.

## Overgelaten aan de bouwer

- Keuze van de markdown-bibliotheek of -parser voor Pascal.
- Opbouw van de code, bestandsformaat van de instellingen, en details van de zoekfunctie (bijvoorbeeld op de achtergrond zoeken).
- Exacte kleuren en pictogrammen, binnen de beschreven stijl.
- Wat te doen als de opgeslagen map of het bestand niet meer bestaat bij het opstarten.

## Latere aanvullingen (2026-10-18)

- Een `.md`-bestand kan als opdrachtregelargument worden geopend; de map van dat bestand wordt de hoofdmap, tenzij het bestand al onder de huidige hoofdmap valt.
- `MolMDReader.exe --register` koppelt `.md` aan het programma voor de huidige gebruiker (alleen HKCU, geen beheerdersrechten); `--unregister` maakt dat ongedaan.
- Standaardthema is licht.
