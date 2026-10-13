# SoundAnalysis classifier evaluation

**Goal:** measure how well the on-device classifier (`SNClassifySoundRequest`, version 1) separates *singing* from other sound, because only singing is scored.

**Method (done at the lab with the Tuner tab on an iPhone):** for each situation make the sound for about 5 seconds, 4 times, and note whether the chip showed *Singing detected* at the end. Test with and without headphones where relevant. Record the top label the classifier reported if visible (Xcode console prints failures only; the chip shows the label for non-singing).

| Situation | Tries | Chip said "Singing detected" | Correct? (singing → yes, others → no) |
|---|---|---|---|
| Singing "aah" | 4 | | |
| Humming | 4 | | |
| Talking | 4 | | |
| Silence / room noise | 4 | | |
| Music from a speaker | 4 | | |

**Confusion summary** (fill after the lab):

| | Predicted singing | Predicted not singing |
|---|---|---|
| Actually singing/humming (8) | TP = | FN = |
| Actually other (12) | FP = | TN = |

Accuracy = (TP + TN) / 20 = 

**Threshold:** `SingingClassifier.threshold` = 0.35 (final value after tuning: ). **Observed labels** from `knownClassifications` for singing: *(paste from the console: add `print(request.knownClassifications.filter{...})` temporarily or note from the chip)*.

**Limitations to discuss:** latency (~1 s), noisy rooms, speaker bleed, one phone only, small sample size.
