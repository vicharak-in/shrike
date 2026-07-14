# Example or Project?  Classification Criteria

Shrike has two homes for contributed designs:

- **[`shrike/examples/`](https://github.com/vicharak-in/shrike)**  the curated *teaching set*
- **[`shrike_projects/`](https://github.com/vicharak-in/shrike_projects)**  the *showcase* of things built on Shrike

Both are first-class. Projects are not "worse examples"  they're a different
species, with different rules. This document is how we (and you) decide where
a contribution belongs.

---

## The one-question test

> **If a beginner opened this to learn, would they learn ONE thing  or would
> they mostly be impressed?**

- Learn one thing → **example**
- Be impressed → **project**

An example exists to *transfer a concept*. A project exists to *demonstrate
what the board can do*. The same code can be brilliant at one and useless at
the other.

## The checklist (when the one-question test isn't obvious)

Score each row. Three or more in one column decides it.

| Signal | Example | Project |
|---|---|---|
| **Concept count** | One idea (a protocol, a primitive, a technique) | Several ideas composed into a system |
| **Describable as…** | "how to do X" | "a thing that does X" |
| **Audience** | Someone learning FPGAs | Someone who already knows FPGAs (or just wants the demo) |
| **On the course path?** | Is / could be a course module's material | On no learning path |
| **Concept already covered?** | Teaches something no other example teaches | Its concepts are taught elsewhere in `examples/` |
| **External context needed** | Works with the board (± a jumper or PMOD) | Needs RF setup, host apps, dictionaries, models, external circuits |
| **Host-side software** | None, or a trivial driver script | Real PC-side component (`host/` folder earns its keep) |
| **Completeness** | Minimal  deliberately nothing extra | Polished end-to-end: it's a *product* |

## Hard rules (override the checklist)

1. **Course dependency = example.** If the Shrike FPGA Course roadmap uses it,
   it stays in `examples/`, full stop. (This is why `protocol_translator`,
   `led_reaction_timer`, and `cordic` are examples despite project-ish traits.)
2. **No FPGA content = project.** `examples/` in the *shrike* repo teaches the
   FPGA and FPGA↔MCU interface. Firmware-only designs
   (`wifi_screen_mirror`, `vector_predictor`) are welcome  in shrike_projects.
3. **Hardware validation = neither.** Bring-up and self-test designs
   (`PSRAM_test`) live in `test/`.
4. **Redundant teaching = project.** If the concept is already taught by a
   simpler example, a bigger design built on it is a project
   (`seven_seg_clock` demonstrates display multiplexing  but
   `pmod_dual_7seg` already *teaches* it).

## Worked classifications (precedents)

| Design | Verdict | The deciding factor |
|---|---|---|
| `uart_led` | Example | One concept: UART RX framing |
| `gpio_extender_8pin` | Example | One concept: the FPGA↔MCU bridge |
| `vector4_cpu` | Example | Big, but it's the course capstone (Rule 1)  and it teaches, module by module, how a CPU is structured |
| `spell_autocorrector` | Project | System: RTL + firmware + dictionary + HID host interface |
| `ir_transmitter_receiver` | Project | Complete NEC remote system; 5 RTL modules composed |
| `seven_seg_clock` | Project | Rule 4: multiplexing already taught by `pmod_dual_7seg` |
| `ask_modulator` | Project | Needs external RF context; demo, not lesson |
| `prng_64` | Project | Algorithm showcase; on no learning path |
| `cordic` | Example | Rule 1: course Module 8 material; one classic technique |
| `PSRAM_test` | `test/` | Rule 3: hardware validation |

## What each home demands

**Examples carry obligations.** Canonical folder structure (enforced by CI),
an entry in the difficulty table, minimal code with nothing decorative,
compatibility across board variants stated, and  as the course grows  a
testbench. The review bar is high because beginners copy these verbatim.

**Projects get freedom.** Structure is lighter (README + `project.yaml` +
whatever the project needs), creative scope is unlimited, host-side code and
external hardware are welcome, and review checks that it works and is
documented  not that it's pedagogically minimal.

## For contributors: where do I submit?

1. Apply the one-question test.
2. Ambiguous? Apply the checklist and hard rules.
3. Still unsure? **Default to shrike_projects**  a great project can always
   be *distilled into* an example later (extract the one teachable concept
   into a minimal design), but a bloated example teaches nobody.

Maintainers may ask you to move a PR to the other repo. That's routing, not
rejection.
