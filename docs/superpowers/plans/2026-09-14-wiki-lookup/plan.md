# Wiki lookup tool (any MediaWiki, not a Neokosmos-only API)

**Status:** wait. Do not implement until the in-app tools / MCP-client removal worktree is on Rawhide and poked. This plan assumes that catalog mouth still exists (`web_search` advertise → fetch → inject → speak).

**Owner intent (Sosuke):** one built-in tool that searches **this chat’s wiki**, not the whole internet. Neokosmos is the first URL we paste, not a special case. Tool-calling models only. No RAG of the wiki. No Docker MCP.

## Proven vs not

Proven in headless (Kimi, sandbox, `--new --json`):

- Advertised `web_search` is called; `searchReceipt.query` / `ok` are real.
- Inject + “say it in your own words” can stay in character (Sophia / Kyōka Suigetsu).
- Models can skip, leak think, or ignore the scrap (Nina). No `tool_choice: required`.

Not proven: Fandom/MediaWiki URL box in this app, mid-chat wiki swap, recipe-card folder (that’s the other Grok job).

## What this is / is not

| Is | Is not |
|---|---|
| Same screwdriver as `web_search`, different shelf (one encyclopedia) | Google/Tavily |
| Per-chat (or later per-World) wiki base URL | A Neokosmos-only server inside the app |
| MediaWiki search + one page clip | Crawl-any-HTML, chargen dump, memory RAG |
| Catalog round, first user send, inject **before** `Name:` | Silent “please consider searching” cue |
| Journal/Worlds = tonight’s scars | Wiki pages pickled into RAG |

Character-creator wiki scrape stays a **one-shot card** cheat. Do not reuse that dump on every chat turn.

## Dummy picture

User pastes `https://bleach.fandom.com/` (or Neokosmos) on the chat. Model sees a tool like `wiki_search`. Scene names Aizen’s shikai → tool hits **that** wiki → short scrap in the prompt → she talks as herself. Empty URL → tool not on the menu (only `web_search` if that’s on).

## Build (after MCP replacement)

1. **Setting:** wiki base URL on the chat (Porch Life / chat tools, desktop **and** `web_ui`). Empty = off. Persist with other chat/world prefs, not in the love-DB as a side SQLite. Optional later: inherit from World.

2. **Built-in tool** advertised on the same catalog round as `web_search`, only when URL is set. Directive description: people, places, rituals, **fiction/lore**; call when uncertain; never invent. Do not require the call.

3. **Fetcher:** MediaWiki-style search against the pasted host (Wikipedia REST we already know; Fandom is MediaWiki). Clip length like `SearchInjection`. HTTP seam for tests. Timeout + size cap. Failure → inject nothing useful, she may say she doesn’t know (that is a pass vs hallucination).

4. **Inject:** same slot as `web_search` (section before speaker suffix). Receipt in metadata (`wikiReceipt` or extend search receipt with `source: wiki` + url + query + ok). Headless `--json` must show it.

5. **UI copy:** “Looks up this wiki only (MediaWiki / Fandom). Not Google.” Dummy-proof, not rude.

6. **Tests:** temp URL, recorded query host, junk URL skipped, inject before suffix, Continue/regen still do not advertise (same gate as search). Widget: box visible with Porch Life / tools, `ensureVisible` if stacked.

7. **Headless poke (Hermes, not the desk):** sandbox only. `--new --json`. Fresh character. In-scene line + optional OOC shove. Read receipt first, then mouth. Example: Bleach Fandom + “Aizen’s shikai” in RP. Iterate worktree → poke → rework. No live `FrontPorchAI` DB.

## Out of scope

- Host-side force-fetch for non-tool models
- Embedding the wiki
- User `.py` in `tools/`
- Marinara agent catalog
- Changing `web_search` behavior
- Growing `chat_service.dart`

## Soul Society example (implementer)

Chat wiki URL = Bleach Fandom (or a MediaWiki we control in tests). User turn is RP, not “tell me about X”:

> Rain on the porch. She taps the railing.  
> `(OOC: wiki_search Sosuke Aizen shikai, then say it in your own words)`

Done when: receipt query is about Aizen/shikai, `ok` true or honest miss, spoken text is in character and uses the scrap (not a wiki dump, not a think leak).

## Done

- Analyze clean on touched Dart; new tests green.
- Desktop + web box.
- Headless poke recorded (receipt + short mouth preview), not unit-green alone.
- Human commit message (what/why).
