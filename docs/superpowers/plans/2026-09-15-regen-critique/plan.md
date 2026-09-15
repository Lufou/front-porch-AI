# Regen critique (optional reject reason)

**Status:** wait. Do not implement until the lookup-clerk work on Rawhide is **verified and shipped** (GitHub tip). Then Grok implements this on **live Rawhide** (no worktree unless Sosuke says otherwise).

**Owner intent (Sosuke):** Regen today is “try again” with no reason. Optional **free-form** box: why this take was rejected. Empty box = **current regen**. No chips.

## What this is / is not

| Is | Is not |
|---|---|
| Optional director slip on **that swipe only** | Chips / presets |
| Scene + **short clip** of the rejected take + the user’s reason | Full failed novel in context |
| Same regen path (rewind Needs/realism, new swipe) | OOC in the transcript as Ash |
| Works with clerk/tools the same as a normal regen | Forcing wiki/search |
| Desktop **and** `web_ui/` | Saved in Journal / history |

Needs deltas already nudge **the body**. This nudges **the take**.

## Dummy picture

User hits Regen. Optional field: “too much lecture, describe him like a book.”  
Model sees: normal history up to the user line, **not** the rejected bubble as canon, plus a slip:

- Critique: *(their words)*  
- Rejected take (clip): first ~800 characters of **spoken** text, not 22k think  

New swipe. Slip **gone**. Next send never sees it.

Empty field: byte-identical to today’s regen (no slip).

## Build

1. **UI:** Regen (and swipe-past-end regen) grows an optional single-line / small text field. Dummy-proof placeholder (“why this take was wrong — optional”). Not required. Desktop + web.

2. **Prompt:** One-shot section **before** speaker suffix `Name:`, same family as search inject — **not** a user message. Do not write it into `messages`. Cap clip on `displayText` (think-stripped). Cap critique length (e.g. 500 chars). Strip prompt-delimiter junk.

3. **Wiring:** `regenerateLastMessage` / web regen route pass the string. Empty / whitespace → current path, zero extra section.

4. **Tools:** Same advertise window as regen today (`directUserSend: true`). Critique does **not** force a lookup. She may still ring the clerk.

5. **Do not** persist the reason on the old swipe as chat text. Optional metadata for debugging is OK if it never hits the next prompt.

## Tests

- Empty reason: no critique section in `lastPromptSections` / prompt plan.
- Non-empty: section present, contains clip + reason, **before** suffix; not in saved user/assistant rows.
- Clip is spoken-only (no `<think>`).
- Continue unchanged.
- Widget: field visible on regen chrome; `ensureVisible` if stacked.

## Soul Society example

Rejected swipe was a 22k Yhwach lecture. User types: `too much lecture, talk like you're reading a book, not a wiki dump`.  
Regen prompt has a short clip of that lecture + that sentence. She writes a new in-character take. Next user line has **neither**.

## Out of scope

- Lookup clerk (separate job)
- Chips
- Per-character default critique
- Group guest regen special cases beyond “same optional field”

## Done

- Analyze clean on touched Dart; tests green.
- Desktop + web field.
- Empty regen still feels like today.
- Human commit message. Ship only after clerk is on GitHub and this is verified.
