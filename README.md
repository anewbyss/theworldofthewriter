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

- **Opening screen**: both apps open on a welcome screen with today's inspiration (a mythic being, a place where myth meets history, a story shape, and a war or rivalry, changing daily), a story spark to write from, and ways to begin: meet a character, draw a world, start from a myth or from history, choose a story shape, wander the atlas. If you've already started, it offers to pick up where you left off. You can turn it off, and reopen it from Home.
- **Home**: no wall of zeroes. A new world shows doors to begin; once you've made things, Home shows only what you have.
- **Bestiary**: 217 real animals (big cats to beetles, domestic to extinct), each with the lore people tell about it, and 259 mythic and fictional beings grouped by region, plus public-domain literary creatures and kinds of being to invent from. Start a species or companion from any of them; it stays linked.
- **History & myth**: 112 wars (sacred and mythic wars beside real wars from every continent, including African diaspora freedom wars), 47 rivalries (mythic, historical, artistic and scholarly), and 44 places and people where history and legend meet. Start a war, rivalry or timeline event from any of them. Gold edges mark what your world already draws on, and they count toward World Coverage.
- **Characters**: role, continuity status, cultural roots, origin, abilities, media appearances, personality, desire, wound, contradiction, arc, lineage and community, appearance, voice and inspiration. Each one gets a printable **character breakdown** and a portrait builder.
- **Abilities**: category, source, what it does, limits, cost, sensory signature and growth.
- **Abilities, classified and traceable**: each ability can have a power system and rank, a type (active, passive, ritual, triggered…), a reach (self to cosmic, across time or realms), a school, the lineage it passes through, prerequisites, counters, the faith that grants it, and its real-world roots. A **trace** view shows the system chain, the prerequisite tree, what it unlocks and counters, and *how each holder got it* (lineage, inherited from an ancestor, taught by a teacher, acquired in a timeline event, or from their origin).
- **Power systems**: magic, cultivation, divine grants, spirit pacts, ancestral power, bloodlines, craft, word and song, divination, technology. Each has a source, access rules, a rank ladder, laws, costs, counters, social role, and branches or schools. They can start from 23 real-world power concepts (àṣẹ, nyama, mana, baraka, tapas, siddhis, hamingja, kotodama, cultivation, ancestral intercession, conjure and rootwork, the flight home, coded song…), each with care notes.
- **Lineages & families**: families, clans, dynasties, bloodlines, teaching and initiation lines, reincarnation and spirit-chosen lines, each with an inheritance rule. Characters gain parents, teachers and lineages, which give you **family trees**, siblings, students, and inherited powers (awakened or not).
- **Peoples & Cultures, Faiths, Languages**: build your own and tie each back to the real sources it draws on.
  - A people can draw on real peoples from the index, plus regions, homelands, languages, faiths, kinship, customs and naming.
  - A faith can be a real faith as portrayed, a real branch, inspired by real faiths, fictional or syncretic. It has deities, cosmology, rites, texts, clergy, calendar, ethics, holy places and linked power systems.
  - A language can draw on real languages, features and writing systems, and has a parent language (for family trees), phonology, grammar, a lexicon and name patterns.
- **Gear & artifacts, curses and blessings**: each has its own section, and you manage them from character and place pages ("Give gear", "Lay a curse", "Bestow a blessing", "Store gear here", "Bless this place").
  - Curses and blessings can rest on characters, whole lineages (they pass down), places (and everything inside them) or gear (affecting whoever holds it).
  - Gear tracks maker, holder, location, granted abilities and a **chain of custody** from "gains item" / "loses item" timeline events.
- **Family & bonds beyond blood**: adoptive, foster and step-parents, guardians, spiritual parents, godparents and sponsors, mentors, teachers, masters and apprentices, initiators, chosen elders, found family, sworn siblings, milk kin, age-set mates, co-parents, partners and more.
  - Each bond can follow a real cultural tradition: 26 included, such as hānai, whāngai, compadrazgo, Gaelic fosterage, milk kinship, jiébài, anda, age-sets, guru–shishya, iemoto, senpai–kōhai, Orisha godparents, the Sufi silsila, dharma transmission, kafala, clan adoption, ballroom houses, shipmate kinship (malungo, sippi, mati), fictive kin and chosen family.
  - A bond can also follow the customs of one of your own peoples.
  - Bonds appear in family trees (adopted children marked), in power tracing ("taught by your mentor"), and in lineage checks.
- **Heirlooms**: any gear can be an heirloom of a lineage, with a succession rule (eldest or youngest child, designated heir, next in the lineage, worthiest, the item's own choice, returns to a shrine…), past holders and a suggested next heir. Adopted children count. Lineage and character pages show heirlooms held and due, and continuity flags heirlooms held outside the family or heirs who have died.
- **Labels & tags**: every dropdown has "＋ Add option…", so you can extend any kind, role or status menu. A Labels & Tags page renames, merges, colours, describes and deletes tags everywhere. Each tag has its own page, and you can type `#tag` in search to jump to one.
- **Heredity traits & offspring calculator**: define heritable traits as dominant, recessive, codominant (blend), X-linked, polygenic numbers, one-parent lines, or spirit-chosen chance, with a "manifests in X%" setting for powers that may not awaken. Set each character's genome, then pick two parents to see Punnett-style odds, XX and XY breakdowns, expected ranges, which lineages the child may join, generational curses and blessings, and cultural inheritance. Roll children and create them with parents, genome, lineages and a blended portrait filled in. The rules are simplified and fictional, not real human genetics.
- **Paradox-safe continuity**: loops (bootstrap ancestry, prerequisite cycles, places inside themselves) never break the app.
  - Events can sit on an alternate **timeline or branch**, and "time travel" events count as returns.
  - Any paradox-type note can be marked as an **intentional paradox** (time loop, bootstrap, bilocation, resurrection, self-fulfilling prophecy…). It then leaves the warnings list and appears with the paradox it belongs to.
- **Species**: every kind of being (humans, humanoids, spirits, deities, animals, beasts, plant-beings, constructs, ancestors, elementals, shapeshifters, hybrids, star-born), with sapience, subspecies and variants, lifespan and maturity, size, senses, innate abilities, weaknesses, habitat, diet, society, peoples, languages, how new ones come to be, and **which species can have children together**.
  - Characters can belong to several species (mixed heritage), and their page offers to add innate abilities they're missing.
  - Start from 16 folklore templates, each with care notes: fox-spirits, nāga, jinn, aziza, mmoatia, trickster animal people, tengu, dokkaebi, encantados, duende, water people, migoi, garuda-kin, golems, aswang and humans.
- **Pets & companions**: pets, familiars, mounts, guardian beasts, working animals, messengers, sacred charges and wild allies.
  - Each has a species and breed, the characters they're bonded to and how, a home, abilities, personality and how they met.
  - Companions have parents and heritable traits, and the offspring calculator breeds them (and warns when species rules say two beings can't have children).
  - Heredity traits can be limited to specific species.
  - Continuity flags incompatible parents, children who share no species with their parents, and companions whose keepers have all died.
- **Factions & orders**: empires, city-states, houses and clans, warrior orders, guilds, sects, secret societies, rebel movements, alliances, trading houses, raiders, councils and spirit courts. Each has leaders, members, seat and territory, ruling lineages, allies and enemies (one-sided alliances are flagged), founding and dissolution dates, goals, symbols and history.
- **Rivalries**: personal, nemesis, sibling, mentor against student, romantic, family and blood feuds, schools, doctrines, politics, trade, art or sport.
  - Sides can mix characters, factions, peoples, lineages, faiths, places and power systems.
  - Each has an intensity, an origin event and escalation events, the wars it fed, and lineages that inherit it.
- **Wars & conflicts, present and past**: war, civil war, rebellion, revolution, feud, holy war, raids, occupation, standoff, trade war, duel, spirit war, and atrocities (with a care note).
  - Each has sides A and B plus other parties, an era and in-world dates, causes and stakes, theatres and battles, leaders and notable figures, cost, outcome, treaty, and how each side remembers it.
  - Conflicts can sit inside larger conflicts.
  - Eras of conflict appear as spans on the timeline.
  - Continuity flags battles outside their war, leaders who died before it began, factions fighting when they don't exist yet, and people on both sides.
- **Notable figures**: characters gain renown (local to legendary, infamous, mythic, forgotten), an epithet and a legacy. The Notable Figures hall groups them by renown with the wars and factions that made their names, and lists real-world figures by region to research. Character and place pages show their factions, rivalries (including inherited ones) and wars, and how they're involved (directly, as a member, through their people or lineage). Spark dice gain a conflict table (cause, stakes, twist).
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
- **Narrative styles**: 22 traditions from around the world, plus 2 Euro-American forms for comparison only. Each has beats, guidance and sources:
  - East Asia: Kishōtenketsu, Jo-ha-kyū, Zhanghui chapter novel, Pansori, Rakugo, Jianghu ensemble
  - South Asia, Persia and the Arab world: Rasa arc, Nested frame tale, Maqāma, Naqqālī
  - Africa: Griot epic, Anansesem trickster tale, Ifá precedent verse, Ntsomi image weaving
  - African American and the diaspora: Chanted sermon, Blues form (AAB), Signifying & the toast, Freedom narrative
  - Southeast Asia: Wayang kulit night cycle
  - Americas: Popol Vuh cycles of making, Spiral / returning story
  - Pacific: Whakapapa layering
- **Culture atlas**: 21 regional information pools (now including Europe's minority and Indigenous peoples, the Caucasus, the Himalaya, Madagascar and the Indian Ocean, and diasporas), with an index of 694 named peoples. Descendants of the transatlantic slave trade have three pools of their own: **African American & Black North America** (Gullah Geechee, Black Southerners, Great Migration communities, Freedmen and Black Indians, Black Canadians, Louisiana Creoles…), **Caribbean & Afro-Caribbean** (every island nation plus Maroon nations such as the Windward and Leeward Maroons, Ndyuka, Saramaka and Aluku), and **Afro-Latin America** (Afro-Brazilians and quilombolas, Palenqueros, Garifuna, Afro-Peruvians, Afro-Mexicans and more). Diasporas include returnee communities such as the Krio, Americo-Liberians, Agudá and Tabom, and the Windrush generation. That's a starting point, not a census: thousands of peoples exist, so add your own. Each lists storytelling forms, cosmology, power concepts, mythic and historical figures, crafts, further reading and a **cultural-care note**. One tap sends any item to your Research Pool.
- **Faiths library**: 102 real religions and philosophies, 149 prominent branches (Sunni schools and Sufi orders, Theravada, Mahayana and Vajrayana schools, Orthodox and Oriental churches, Candomblé nations, Vodou rites, the Black Church — AME, AME Zion, Black Baptist conventions, COGIC — African American Islam and more). African diaspora faiths include Hoodoo, Louisiana Voodoo, Gullah spirituality, Kongo religion, Palo, Abakuá, Arará, Lucumí, Espiritismo, Jamaican Revival, Spiritual Baptists, Trinidad Orisha, Big Drum, Kélé, Comfa, Dominican Vudú, María Lionza, Winti, Umbanda and other Afro-Brazilian traditions, the Nation of Islam, Moorish Science, the Five-Percent Nation and Black Hebrew Israelites, across Abrahamic, Dharmic, East Asian, Iranian, African and diaspora, Indigenous, historical and modern families. Each has key ideas, where it lives, sources and care notes.
- **Languages library**: 323 real languages in 33 families (including sign languages, creoles, isolates and real constructed or ritual languages), 60 writing systems, and 24 language features to design with (tone, clicks, evidentiality, noun classes, honorifics, whistled and drummed speech…).
- **World coverage & gaps**: which regions, faith families, language families and power concepts your world draws on. It also spots **natural gaps** along 29 real contact zones (Silk Roads, Indian Ocean monsoon world, Trans-Saharan routes, the Atlantic world, Austronesian voyaging, Manila galleons, indenture, the Great Migration, the Underground Railroad, Return to Africa, the Haitian Revolution, Windrush, diasporas and more), each with a story hook.
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
- `lore.json`: real animals, mythic and fictional beings, wars, rivalries, and history & myth

After editing any of them, run:

```sh
node tools/build-data.mjs
```

That regenerates `web/js/reference-data.js` and `ios/WowBrainstorm.swiftpm/ReferenceData.swift`.

## A note on care

The atlas and styles are **starting points, not authorities**. Many stories, designs and ceremonies belong to specific communities and aren't public domain. The care notes say where. Read work by people from those cultures, credit your sources in the Research Pool, and ask permission when in doubt.
