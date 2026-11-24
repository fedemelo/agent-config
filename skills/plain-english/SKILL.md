---
name: plain-english
description: "The standard for prose meant for another person to read: B2-level English, no jargon or corporate fluff, no reference chains, nothing that reads as AI-written. Other skills reference it when writing review comments, replies, and descriptions. Use when writing or judging text someone else will read."
---

Write the draft you would write anyway, then rewrite it against every rule below. Write for a competent developer who is reading in a second language and was not present for the reasoning behind the text. Whatever they need to act is in the text; everything else is noise that costs them time.

Sentences and words:

1. B2-level English: the common word over the rare one. "wrong" not "erroneous", "use" not "leverage", "same" not "identical", "so" not "hence".
2. Active voice with a concrete subject. "This reads the config twice", not "the configuration ends up being read twice".
3. Verbs over nominalizations. "This duplicates the data", not "this introduces duplication of the data".
4. One idea per sentence, with no clause stacked inside another. A "which", "while", "although", "given that", or an opening "Having ..." is the signal to break the sentence in two. Two short statements may be joined with a single "and", "but", or "so", and that is the whole allowance. A second join in the same sentence, or a comma that drags in a third statement, means you have written three sentences and punctuated two. Count the statements in a sentence before you keep it. You know all of them already, so the cost of holding them at once is invisible to you. The reader is the one paying it. A period costs the reader nothing, while a nested clause makes them hold the first half in mind to parse the second.
5. No dashes. A dash between clauses is doing a period's job, and what follows it is either a sentence of its own or noise, so promote it or cut it. This covers the em dash, the en dash, and the hyphen standing in for either. Hyphens inside a compound are rule 6's business instead.
6. Unroll hyphenated compounds unless the compound is a fixed term. Established ones stay as they are: read-only, off-by-one, type-safe, non-null. Invented ones go back into ordinary word order, so "hard-to-follow logic" becomes "logic that's hard to follow", and "a single-source-of-truth problem" becomes "this value is now stored in two places". A non-native reader who is translating in their head has to undo the hyphens before they can start.
7. Contract wherever English allows it: don't, isn't, it's, can't, won't, there's, that's, I'd. The spelled-out form reads as a formal document, or as stress on the "not", and neither is what a message between colleagues means.
8. Use the short forms developers already write to each other: imo, idk, afaik, iirc, bc. Lowercase, no periods. Use one only where it stands in for the phrase you'd write anyway, so "idk if this runs in a job" replaces "I don't know whether", and "imo" can replace "I think". Ones that carry no meaning stay out, since they're padding in a shorter shape: tbh, fwiw, btw, lol.

No fluff. A word earns its place when it names something with a definition, and knowing that definition changes what the reader should do. Technical terms qualify and should be used plainly: cache, coupling, cohesion, encapsulation, race condition, side effect, idempotent, invariant, off-by-one, N+1 query, memory leak, deadlock. These do not:

1. Metaphors standing in for the mechanism: plumbing, thread through, wire up, surface (as a verb), blast radius, surface area, footgun, reach into, bleeds into, in the wild. A non-native reader cannot decode them. Replace each with what actually happens.
2. Quality words that measure nothing: brittle, fragile, robust, resilient, hardening, clean, elegant, seamless, holistic, first-class, non-trivial, orthogonal, opinionated, canonical, sane defaults, gracefully. "Brittle" becomes "breaks when the list is empty".
3. Labels that replace the argument: code smell, anti-pattern, tech debt, best practice. Say what goes wrong rather than naming a category it belongs to.
4. Padding: utilize, facilitate, ensure that, in order to, it is worth noting, at the end of the day.

Keep the reader's memory free:

1. Name only the symbols the reader must act on. Every extra function, module, or file name is one more thing to hold in mind while reading the rest of the sentence.
2. Give the conclusion and its consequence, not the path taken to reach them. No chain of hops through the codebase.
3. Cut the investigation: what was checked first, what was ruled out, what turned out fine.
4. Once there are more than two ideas, put a blank line between them. The eye needs somewhere to rest, and a wall of text gives it nowhere. This buys readability, never permission to write more.

When the text speaks to a person:

1. Never use the imperative. Not "move this to the service", not "remove the cast", not "extract this into a helper". An order leaves the reader nothing to answer.
2. When something is wrong, open with "I think" or "imo". It says the reasoning is done and the conclusion stands, while leaving the reader room to show you otherwise: "I think this breaks when the list is empty".
3. When offering an alternative rather than correcting an error, use "we could" or "we might": "we could pass the id in instead". When you'd want it changed before merging, "we should probably" says so without an order.
4. A question does the same work and is usually shorter. "Why not pass the id in?" is a complete message. A claim the reader can confirm in a glance can end in ", no?" in place of "I think": "nothing calls this without the flag, no?". Never close a point with "Was that intended?" or "Is that what we want?", which asks the reader to defend the code instead of answering the point.
5. Soften the stance, never the claim. Where a sentence opens with "I think" or "imo", that's the hedge it gets, so nothing else is stacked on top. Never "I think this might possibly break".
6. State the case once, and never argue with the reader. "This is exactly what gets here" and "this will in fact fail" answer an objection nobody has made yet, and the insistence reads as pleading. Drop "exactly", "in fact", "actually", "clearly", "definitely", "notably", and "do note that". The claim is already in the sentence.

Do not read as AI-written:

1. Plain prose. No bold, no headers, no bullet list for a single point.
2. Never restate the reader's own code or words back to them before making the point.
3. No praise, and no empty softener that pads the message without changing it: "great catch", "nice work", "just a thought". The stance markers above are a different thing, since they say who is claiming what.
4. One hedge at most, and only where the uncertainty is real. Never "it might potentially be worth considering".
5. No sign-off, no summary of what was just said, no offer to help further.

What this looks like. Before:

> This introduces a fairly brittle coupling: `resolveTenantConfig` reaches into the `SessionContext` singleton to surface the tenant id, which is then threaded through `buildQueryPlan` and `executePlan`, so any caller that instantiates the planner outside a request lifecycle hits a hard-to-diagnose null deref.

After:

> This only works inside a request. In a background job there's no session, so the tenant id is null and the planner crashes. imo the tenant id should be an argument instead.

Applying this: invoked directly, rewrite the given text against these rules and return it. Referenced from another skill, apply it to every part of the output that a person other than the user will read. It governs prose only, never code, identifiers, quoted text, or command output.

A skill naming this standard in double brackets is telling you to load this file and apply it, not merely that it exists. The name in the brackets is a skill, and nothing expands the reference for you: unless you read it, the rules above are not in front of you and the text you write will not follow them. So load it before writing the output it governs, not after. The same holds for every double-bracket reference in these skills.
