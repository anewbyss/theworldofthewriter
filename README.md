# WOW Brainstorm

A writer's room for building a huge story world across books, comics, film, games and audio. It helps you **write, track, research and keep continuity** across all of them.

There are two apps that share one data format:

| | Where | What it's best for |
|---|---|---|
| **Web app** | `web/` — runs in any browser, works offline | Desk work, big screens, quick access anywhere |
| **iPad app** | `ios/WowBrainstorm.swiftpm` — Swift Playgrounds | Apple Pencil handwriting, on-the-go drafting |

Backups made in either app open in the other.

## The no-AI promise

WOW Brainstorm contains **no generative AI** — no AI writing, no AI images, no AI music.

- **Character images** are simple portraits you build yourself from shapes (build, hair or head covering, skin tone, aura, emblem). They're placeholders. Sketch your real designs on an Ink page.
- **The originality checker** is a word-overlap formula you can read in `web/js/originality.js`. It compares your text with a hand-curated list of about 80 well-known tropes and with your own entries, then shows exactly which words matched.
- **Handwriting-to-text** uses Apple's on-device Vision text recognition on iPad. In the browser it uses the built-in Handwriting Recognition API. Both are character recognition, like scanning a page. Nothing is written for you.
- **Spark dice** are old-fashioned random tables, like a tabletop game's. They give you prompts, never prose.

## What's inside

- **Characters**: role, continuity status, cultural roots, origin, abilities, media appearances, personality, desire, wound, contradiction, arc, lineage and community, appearance, voice and inspiration. Each one gets a printable **character breakdown** and a portrait builder.
- **Abilities**: category, source, what it does, limits, cost, sensory signature and growth.
- **Abilities, classified and traceable**: each ability can have a power system and rank, a type (active, passive, ritual, triggered…), a reach (self to cosmic, across time or realms), a school, the lineage it passes through, prerequisites, counters, the faith that grants it, and its real-world roots. A **trace** view shows the system chain, the prerequisite tree, what it unlocks and counters, and *how each holder got it* (lineage, inherited from an ancestor, taught by a teacher, acquired in a timeline event, or from their origin).
- **Power systems**: magic, cultivation, divine grants, spirit pacts, ancestral power, bloodlines, craft, word and song, divination, technology. Each has a source, access rules, a rank ladder, laws, costs, counters, social role, and branches or schools. They can start from 20 real-world power concepts (àṣẹ, nyama, mana, baraka, tapas, siddhis, hamingja, kotodama, cultivation, ancestral intercession…), each with care notes.
- **Lineages & families**: families, clans, dynasties, bloodlines, teaching and initiation lines, reincarnation and spirit-chosen lines, each with an inheritance rule. Characters gain parents, teachers and lineages, which give you **family trees**, siblings, students, and inherited powers (awakened or not).
- **Peoples & Cultures, Faiths, Languages**: build your own and tie each back to the real sources it draws on.
  - A people can draw on real peoples from the index, plus regions, homelands, languages, faiths, kinship, customs and naming.
  - A faith can be a real faith as portrayed, a real branch, inspired by real faiths, fictional or syncretic. It has deities, cosmology, rites, texts, clergy, calendar, ethics, holy places and linked power systems.
  - A language can draw on real languages, features and writing systems, and has a parent language (for family trees), phonology, grammar, a lexicon and name patterns.
- **Origins**: reusable origin stories (born, gifted, bargained, initiated, exiled…) and the debts they create.
- **Books & Media**: every work, in any medium, with release order, status, logline and synopsis. Book ideas live here too.
- **Places**: realms, cities, sacred sites, otherworld locations and buildings. Each has a layer of reality (mortal world, spirit world, underworld, sky, dream…), a parent place, an existence window on the in-world timeline, history, myth and lore, and sensory detail.
- **Map designer**: draw maps at any size, from **cosmos and world** down to **city, site and building interior**. Place stamps (cities, temples, sacred trees, volcanoes, portals, camps, ships…), draw routes and regions, and add labels. Works with Apple Pencil, touch or mouse.
  - **Visual styles** draw on non-European mapmaking traditions, each with a care note: al-Idrisi's south-up atlas, Mesoamerican codex maps with footprint roads (east-up), Marshall Islands swell and stick charts, mandala cosmos, ink-and-mist painting, star-road night maps, Bamana mud cloth, spirit realm, a modern atlas and the WOW house style.
  - **Zoom between sizes**: any marker can open a detail map, so a world map can open a city map, which can open a building. A map that depicts a place is linked automatically.
  - **Time travel**: a slider shows the map at any moment of in-world time. Features appear and vanish according to when their places exist. Event badges show what has happened where, including events at sub-places.
  - **Journeys**: trace any character's route (homeland, then each place they appear on the timeline) across a map.
  - **Everything connects**: events, characters (homeland), origins, works (settings) and storylines all point at places. Place pages show their maps, sub-places, events and people. Continuity flags events at places that don't exist yet or anymore, characters in two places at once, places nested inside themselves, and maps showing places outside their era.
  - Export any map as SVG or PNG. Maps also appear in the series bible.
- **Storylines**: pick a narrative style and its beats appear as writing prompts. Map emotional flavours with the nine rasas.
- **Narrative styles**: 18 traditions from around the world, plus 2 Euro-American forms for comparison only. Each has beats, guidance and sources:
  - East Asia: Kishōtenketsu, Jo-ha-kyū, Zhanghui chapter novel, Pansori, Rakugo, Jianghu ensemble
  - South Asia, Persia and the Arab world: Rasa arc, Nested frame tale, Maqāma, Naqqālī
  - Africa and the diaspora: Griot epic, Anansesem trickster tale, Ifá precedent verse, Ntsomi image weaving
  - Southeast Asia: Wayang kulit night cycle
  - Americas: Popol Vuh cycles of making, Spiral / returning story
  - Pacific: Whakapapa layering
- **Culture atlas**: 19 regional information pools (now including Europe's minority and Indigenous peoples, the Caucasus, the Himalaya, Madagascar and the Indian Ocean, and diasporas), with an index of 637 named peoples. That's a starting point, not a census: thousands of peoples exist, so add your own. Each lists storytelling forms, cosmology, power concepts, mythic and historical figures, crafts, further reading and a **cultural-care note**. One tap sends any item to your Research Pool.
- **Faiths library**: 84 real religions and philosophies, 120 prominent branches (Sunni schools and Sufi orders, Theravada, Mahayana and Vajrayana schools, Orthodox and Oriental churches, Candomblé nations, Vodou rites and more), across Abrahamic, Dharmic, East Asian, Iranian, African and diaspora, Indigenous, historical and modern families. Each has key ideas, where it lives, sources and care notes.
- **Languages library**: 323 real languages in 33 families (including sign languages, creoles, isolates and real constructed or ritual languages), 60 writing systems, and 24 language features to design with (tone, clicks, evidentiality, noun classes, honorifics, whistled and drummed speech…).
- **World coverage & gaps**: which regions, faith families, language families and power concepts your world draws on. It also spots **natural gaps** along 24 real contact zones (Silk Roads, Indian Ocean monsoon world, Trans-Saharan routes, the Atlantic world, Austronesian voyaging, Manila galleons, indenture, diasporas and more), each with a story hook.
- **Research Pool**: books, conversations, archives, music and places, with a field for permissions and cultural care.
- **Ink Pages**: handwrite with Apple Pencil, a stylus, a finger or a mouse, then convert to text.
- **Timeline & continuity**: one in-world timeline across every work. The checker flags problems like a character appearing after their death with no return event, a birth after earlier appearances, or a work missing from a character's appearances. It also flags duplicate names and abilities nobody holds.
- **Connection web**: a graph of the relationships you define, plus the links implied by references.
- **Originality checker**: check one entry or scan your whole library. It includes a **representation check** that flags harmful patterns such as the "magical" minority helper, the outsider saviour, the exotic mystic East and demonised African religions.
- **Series bible**: everything in one printable document (PDF from the web, Markdown from the iPad).

## Using the web app

Open `web/index.html` in a browser. That's all — no install, no build step.

To use it on an iPad or phone like an app, host the `web/` folder somewhere. GitHub Pages works: repo **Settings → Pages**, deploy from a branch, folder `/web`. Then open the page in Safari and choose **Share → Add to Home Screen**. Once hosted, it works offline.

With Apple Pencil in Safari, **Scribble** lets you handwrite straight into any text box in the app.

## Using the iPad app (Swift Playgrounds)

1. Get the `ios/WowBrainstorm.swiftpm` folder onto your iPad: iCloud Drive, AirDrop, or download the repo as a zip and unzip it in Files.
2. Open it in **Swift Playgrounds** (version 4.4 or later, iPadOS 16+).
3. Tap **Run**. You can also install it to your Home Screen from Playgrounds.

It also opens in Xcode on a Mac. The app keeps its library in its own Documents folder, with automatic snapshots.

## Backups and the data format

- **Export** a full backup (`.json`) from *Backups & Data* in either app. **Import** by merging (the newest version of each entry wins) or by replacing everything.
- **Snapshots** are taken automatically: every 10 minutes of work, at start-up, and before every import, restore and delete. The last 20 are kept.
- **CSV** exports open in Numbers, Excel or Google Sheets.
- The format is plain JSON: `{ "format": "wow-brainstorm", "formatVersion": 1, "data": { "characters": [...], ... } }`. Every field is defined in `shared/schemas.json`, so your work is always readable without these apps.

## Extending the reference library

All the built-in material lives in `shared/`:

- `schemas.json`: collections and fields (both apps build their forms from it)
- `narrative-styles.json`: story structures
- `culture-pools.json`: the culture atlas and peoples index
- `religions.json`: the faiths library
- `languages.json`: language families, writing systems and language features
- `connections.json`: contact zones and real-world power concepts
- `tropes.json`: the trope list the originality checker uses
- `library.json`: rasas, spark dice tables, twist prompts, stop-words, portrait shapes, and map styles, stamps and canvas sizes

After editing any of them, run:

```sh
node tools/build-data.mjs
```

That regenerates `web/js/reference-data.js` and `ios/WowBrainstorm.swiftpm/ReferenceData.swift`.

## A note on care

The atlas and styles are **starting points, not authorities**. Many stories, designs and ceremonies belong to specific communities and aren't public domain. The care notes say where. Read work by people from those cultures, credit your sources in the Research Pool, and ask permission when in doubt.
