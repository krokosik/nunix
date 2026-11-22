# Paper summary: Why is AI-generated language so hard to understand?

Thomas Hikaru Clark (NYU), Matias B. Martin and Kyle Mahowald (UT Austin). arXiv 2610.29162v1, 2026. <https://arxiv.org/abs/2610.29162>

## The claim in one paragraph

People widely feel that LLM text has become harder to read. The authors measured seven features that psycholinguistics links to reading difficulty. Frontier models use these features more than human writers do. They also use them more than a meaning-preserving paraphrase of the same text, which shows the model chose the harder form. The authors argue that the cause is post-training on math, code, and reasoning with verifiable rewards. That training rewards correct answers and short outputs, not clear communication. When they fine-tuned a small model with a length penalty, it switched to the shorter grammatical variant every time, unlike humans. The habit also spread to constructions it was never trained on.

## Two hypotheses

- **H1.** Frontier LLMs overuse linguistic features linked to human comprehension difficulty. Supported.
- **H2.** Pressure for information density during post-training makes LLM output less humanlike. Supported as a proof of concept.

## Why human language is easy to read

Human language is shaped by communication. Speakers balance effort to produce against effort to understand. Two well-studied pressures follow from that:

- **Dependency length minimization.** Speakers keep related words close because working memory is limited and lossy.
- **Uniform information density (UID).** Speakers spread information evenly so no stretch overloads the listener. They add optional words like "that" where the next part is hard to predict, and drop them where it is easy.

LLMs do not have human memory limits. They attend to long contexts without loss. If training no longer rewards being understood by people, nothing keeps their output within human limits.

## The seven features

Each feature is harder for people to process and is also shorter or denser than its alternative.

| Feature | Example from model output | Why readers struggle | Why it is denser |
| --- | --- | --- | --- |
| Rare n-grams (unattested bigrams, high trigram perplexity) | "reader-patience budget", "not really a gear trap" | Unpredictable words take longer to read (surprisal theory) | Predictable, redundant words are cut |
| Long dependencies | "All five expression shapes — attribute access, subscript, calls, nested calls, string literals — leave current on NAME" | Holding a word until its partner arrives strains working memory | Packs more into one sentence |
| Object relative clauses | "the house the contractors built" | Non-canonical word order; longer dependencies than subject relatives | Shorter than the passive "the house that was built by the contractors" |
| Reduced relatives (no "that"/"which") | "behaviour the old code never reached" | Removes a cue that a clause is starting | Saves a word |
| Stacked nouns (3+) | "class-time shutdown requirement" | Bracketing is ambiguous ("Squad Helps Dog Bite Victim"); slows reading | Replaces prepositional phrases and clauses |
| Denominal verbs (ad hoc) | "footnote it", "this cushions price spikes" | Part-of-speech shift triggers reanalysis | "bottle the whiskey" vs "put the whiskey in a bottle" |
| Inanimate subject + animate verb | "`is_file()` swallows that", "where this asymmetry bites" | Violates expected subject type; readers use animacy to parse; can trigger reanalysis (P600) | "bites" stands in for "causes a problem" |

The paper's opening sentence shows several at once: *"Your instinct is right; the convoluted sentence you are currently reading is quietly eating its own reader-patience budget — footnote it."* It contains an object relative, a denominal verb ("footnote"), an inanimate subject with "eat", and a noun stack that is a rare n-gram ("reader-patience budget").

## Experiment 1: corpus study

**Models (14).** Claude Sonnet 5, Opus 5, Opus 5.5, Fable 5; GPT-5.6 Luna, Terra, Sol; Kimi K2.5; GLM 5; and smaller open models: Olmo 3 7B (Base, Instruct, Think) and Llama 3.1 8B (Base, Instruct).

**Settings.**
- Chat: 10 casual topics, 12 turns each, against a simulated user.
- Coding: 5 real Python repos; the model hunts and fixes bugs over about 11 turns.
- Essay: single-turn persuasive essays on 7 PERSUADE 2.0 prompts.

**Human baselines.** OpenSubtitles (chat), StackExchange (coding), top-scoring PERSUADE student essays (essays), plus Wikipedia.

**Paraphrase control.** Each sentence was translated English → Japanese → English with NLLB-200. This keeps the meaning but normalizes the wording. If a feature becomes rarer after the round trip, the model picked it over an available plainer form. Russian pivots and a second translator gave consistent results.

**Results.**
- All nine frontier and near-frontier models used more inanimate-subject/animate-verb pairs and more rare n-grams than human writing.
- Most also used longer dependencies, more stacked nouns, and more reduced object relatives in conversation.
- Against the paraphrases, nearly all frontier models overused rare n-grams, denominal verbs, inanimate subjects, and reduced relatives. They underused relatives *with* "that". Together these show a consistent preference for dropping the optional word.
- Effects were largest in multi-turn chat and coding and smaller in single-turn essays. The authors suggest that long exchanges push models toward compression.
- Llama and the Olmo base and instruct models changed least and were closest to human text. Olmo Think, the reasoning-trained variant, looked like the frontier models. Within Olmo, the effect grew from base to instruct to reasoning.
- Claude Opus 5.5 scored lower than Opus 5 on 19 of 21 difficulty measures, eight with non-overlapping intervals. Training can reduce the problem.

## Experiment 2: length penalty

**Setup.** Qwen2.5-1.5B-Instruct was fine-tuned with GRPO. The task was turning a JSON event description into one English sentence. The reward was correctness times format, minus a per-token length penalty λ. A KL term β kept the model close to the base model in some runs.

**Alternations trained.** Each pair has a short form and a long form that are both correct.
- Dative: "gave his wife a gift" / "gave a gift to his wife"
- Object relative: "the book the professor wrote" / "the book that the professor wrote"
- Complement clause: "knew the answer was wrong" / "knew that the answer was wrong"
- Particle order (same length, control): "picked up the book" / "picked the book up"

**Held out.** "sure (that)", "so (that)" (near transfer); genitive, "all (of)", "(in order) to", passive (far transfer).

**Results.**
- Preference for the short form rose with λ. Without KL, every λ > 0 led to an almost fixed choice of the short form (over 98% for both "that" alternations). With λ = 0, preference varied by seed with no stable choice.
- With KL regularization the shift was slower but still present.
- The preference transferred to the untrained "sure (that)" and "so (that)" cases. Far transfer appeared only for the genitive, and only without KL.
- Humans use both forms and choose by context. The trained model used one form regardless of context, which is a clear break from human usage.

## Interpretation

- RLHF tends to reward longer outputs, so it is unlikely to cause this compression. Training with verifiable rewards, with humans out of the loop and long, costly context windows, is the more plausible source.
- The result is a dialect that suits the model's own problem solving but is worse for human readers. Every construction is legal English, but the mix is outside the human distribution.
- Training can reward communication too, as the Opus 5 → Opus 5.5 improvement shows.

## Limitations

English only, a subset of models, few seeds (10 chat topics, 5 repos). The causal claim rests on a small-model proxy, not on the frontier models' actual post-training.

## What this means for editing

- Target the seven features, especially inanimate subjects with animate verbs and rare word pairings, which were overused across all frontier models.
- The fix is usually a slightly longer, more conventional form: an ordinary verb, an unpacked noun stack, a restored "that", a subject placed next to its verb.
- Do not swing to the opposite extreme. People vary by context, adding optional words where the next part is hard to predict (UID). A rewrite that adds "that" to every clause is as unnatural as one that removes it from every clause.
