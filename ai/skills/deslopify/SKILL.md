---
name: deslopify
description: 'Rewrite AI-sounding prose so people can read it easily. Targets the patterns that research links to harder reading in LLM text: inanimate subjects with "animate" verbs ("the test bites", "the docstring promises"), nouns used as verbs ("calendar it"), stacks of three or more nouns, dropped "that" in relative and complement clauses, long gaps between related words, and rare, made-up word pairings. Use when the user asks to deslopify, de-AI, humanize, plain-English, or make text clearer, or when reviewing a draft, README, commit message, PR description, or reply for readability.'
license: MIT
metadata:
  tags: "Writing, Editing, Readability, Plain Language"
  category: "writing"
---

# deslopify

Frontier LLMs write in a dense, compressed dialect. Each sentence is grammatical, but it is harder for people to read than the way a person would say the same thing. This skill turns that dialect back into plain English.

The basis is Clark, Martin & Mahowald (2026), *Why is AI-generated language so hard to understand?* See [references/paper-summary.md](references/paper-summary.md) for the findings and why each pattern costs the reader effort. Read it when you need to justify an edit or decide a borderline case.

## When to use it

- The user hands you text and asks you to deslopify, de-AI, humanize, simplify, or make it readable.
- The user asks you to review a draft for clarity.
- You are writing prose a person must read (docs, PR text, explanations), and the user has asked for this style.

Leave code, identifiers, quotes, and technical terms alone. Only the prose around them changes.

## The core idea

People pay for every word they read, but they pay more for words that are hard to predict or hard to connect. A sentence that is a few words longer but easy to parse beats a short one the reader must decode. Trade length for clarity, but only where it buys clarity. Do not pad.

## The patterns, and what to do with each

Work through the text sentence by sentence. For each sentence, check these seven patterns. The first two are the strongest signal: every frontier model in the study overused them compared with human writing.

### 1. Inanimate subjects doing things only people or animals do

Code, documents, ideas, and problems "swallow", "promise", "bite", "forget", "hope", "ask", "eat", "misunderstand", or "quietly" do anything. The reader has to stop and reinterpret the verb.

- "`is_file()` swallows that and returns False" → "`is_file()` catches that error and returns False"
- "Puzzle patterns where this asymmetry bites" → "Puzzle patterns where this asymmetry causes problems"
- "The docstring promises they're skipped" → "The docstring says they're skipped"
- "the check covered str but forgot its sibling type bytes" → "the check handled str but not bytes"

Keep conventional uses that people really say: "the function returns", "the test fails", "the server crashes", "the script runs".

### 2. Rare or invented word pairings

Phrases a person would not have written before: "reader-patience budget", "papercut people feel day-to-day", "gear trap", "the part most advice glosses over". Each one forces the reader to work out a new meaning. Replace it with the ordinary phrase for the idea. If no ordinary phrase exists, say the idea in a short clause.

- "eating its own reader-patience budget" → "wearing out the reader's patience"
- "That's not 'trip to Vegas' money" → "That's more money than a holiday costs"

Metaphors are fine when they are common ones. One fresh image in a page can work. A fresh image in every sentence cannot.

### 3. Nouns turned into verbs on the spot

"footnote it", "calendar it", "this cushions price spikes", "the logic mirrors real-world challenges", "pooling judgments filters out errors". Established verbs (email, text, google, bottle) are fine. If the verb would sound odd said aloud to a colleague, use the longer phrase.

- "footnote it" → "move it to a footnote"
- "calendar it" → "put it on the calendar"

### 4. Noun stacks

Three or more nouns in a row, each modifying the next: "class-time shutdown requirement", "absolute dotfile backup path handling", "community service honor cord". The reader cannot tell how the words group. Unpack the stack with prepositions, a possessive, or a clause.

- "Fixed absolute dotfile backup path handling" → "Fixed how absolute paths are handled when backing up dotfiles"
- "Policy 1's class-time shutdown requirement" → "Policy 1's rule that phones are off during class"

Two-noun compounds (coffee shop, test suite, error message) are fine. Established technical terms (pull request, garbage collector) count as one unit.

### 5. Missing "that"

LLMs drop the optional "that" far more than people do. Put it back when the sentence is long, the clause is far from what it modifies, or the next words could be misread as the main clause.

- "the behaviour the old code never reached" → "the behaviour that the old code never reached"
- "Some students may feel required service takes time away" → "Some students may feel that required service takes time away"
- "I knew the answer was wrong" (short, clear) → leave as is

Also restore other optional words when they help: "so that", "all of", "in order to" before a long clause, "the roof of the house" instead of "the house's roof" when the owner phrase is long.

People choose between these forms by context. Do not add "that" everywhere. Add it where the reader would otherwise stumble.

### 6. Object relative clauses

"The house the contractors built" makes the reader hold "the house" until the verb arrives. It is fine when short. When the clause is long or nested, rewrite it:

- Use a subject relative: "the contractors who built the house".
- Use a passive: "the house that was built by the contractors".
- Split it into two sentences.

### 7. Long gaps between words that belong together

A subject far from its verb, or a verb far from its object, strains working memory. Common forms:

- A long list or parenthetical between subject and verb: "All five expression shapes — attribute access, subscript, calls, nested calls, string literals — leave current on NAME" → "The fix works for all five expression shapes: attribute access, subscripts, calls, nested calls, and string literals."
- A long modifier before the noun: "The guitar sitting in the corner because you're still 'deciding' teaches you zero chords" → "If the guitar sits in the corner while you're still 'deciding', you won't learn any chords."
- Several clauses before the main verb.

Fix by moving the long part to the end, turning it into its own sentence, or putting the subject and verb first.

## Other quick checks

- **Em-dash chains.** One aside per sentence at most. Turn the rest into commas, colons, or new sentences.
- **Semicolon chains.** Often hide two or three sentences. Split them.
- **Fragments as sentences** ("No new branch, no change in control flow — just closing the gap"). Fine in casual chat; in docs, write the full sentence.
- **Ellipsis of shared material.** "Three fail on the old code; the others check behaviour the old code never reached." Say what fails and what the others are.

## How to rewrite

1. Keep the meaning, facts, and register. Casual stays casual; technical stays technical.
2. Change only what one of the patterns above explains. Do not rewrite for taste.
3. Prefer the version a careful human writer would produce: concrete subject, ordinary verb, words in the expected order.
4. Expect the result to be somewhat longer. If it grows by more than about a third, you are probably padding. Cut filler instead ("it's worth noting that", "honestly", "genuinely", "actually").
5. Read each rewritten sentence once, left to right. If you had to go back, it still needs work.

## Output

When rewriting text the user supplied:

1. Give the rewritten text first, in full, ready to paste.
2. Then, unless the user asked for the text only, list the main changes briefly, grouped by pattern (e.g. "Inanimate subjects: 4. Noun stacks: 2."). Quote one or two before/after pairs. Do not annotate every edit.

When reviewing without rewriting, quote each problem sentence, name the pattern, and suggest a fix.

## Writing this way yourself

If the user wants your own output in this style, apply the same checks before you send each reply. The most common slips are inanimate subjects with lively verbs, invented compound phrases, and dropped "that".
