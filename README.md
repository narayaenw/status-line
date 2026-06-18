# Claude Code statusline

Jednoduchá, ale informačně hutná **status line pro [Claude Code](https://claude.com/claude-code)** — jeden bash skript, žádné závislosti navíc kromě `jq`. Ukazuje model, zaplnění kontextu, cenu session, čas a git větev v jednom řádku.

```
[Opus 4.8 (1M context) ·xhigh] 📁 youtubedb | 🌿 main± | ████░░░░░░ 47% | $1.23 | 🕐 1h 2m
```

> Náhled v reálu (přidej si vlastní screenshot do `assets/`):
>
> ![Náhled statusline](assets/screenshot.png)

## Co to ukazuje

| Část | Význam |
|---|---|
| `[Opus 4.8 (1M context) ·xhigh]` | model + reasoning effort (`·xhigh` se skryje, když ho prostředí nehlásí — třeba při API klíči) |
| `📁 youtubedb` | aktuální složka |
| `🌿 main±` | git větev; `±` značí necommitnuté změny (dirty working tree) |
| `████░░░░░░ 47%` | **zaplnění kontextového okna** — desetidílný bar, který mění barvu podle naplnění |
| `$1.23` | odhad ceny session v USD (kolik by vyšla přes API — i na předplatném je to hezká reflexe, co session „stojí") |
| `🕐 1h 2m` | délka session |

Barvy zaplnění kontextu:

- 🟢 zelená < 50 %
- 🟡 žlutá ≥ 50 %
- 🟠 oranžová ≥ 70 %
- 🔴 červená ≥ 90 %

## Požadavky

- **bash**
- **[`jq`](https://jqlang.github.io/jq/)** — parsování JSON, který Claude Code posílá na stdin (`brew install jq`)
- **git** — volitelně; bez gitu nebo mimo repozitář se zobrazí `no-git`

> Skript je defenzivní: když `jq` chybí nebo přijde nevalidní vstup, nespadne — jen zobrazí prázdné/nulové hodnoty.

## Instalace

1. Stáhni `statusline.sh` (klidně do `~/.claude/statusline.sh`) a nastav mu práva ke spuštění:

   ```bash
   curl -o ~/.claude/statusline.sh https://raw.githubusercontent.com/<tvuj-github>/claude-code-statusline/main/statusline.sh
   chmod +x ~/.claude/statusline.sh
   ```

2. Zapni ho v Claude Code přes `~/.claude/settings.json` (globálně) nebo `.claude/settings.json` (per projekt):

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "/Users/<ty>/.claude/statusline.sh"
     }
   }
   ```

3. Otevři novou session — status line se objeví dole.

## Přizpůsobení

Celé je to jeden krátký skript, takže úpravy jsou triviální:

- **Prahy barev kontextu** — hodnoty `50 / 70 / 90` v sekci *„Context % color threshold"*.
- **Layout / pořadí polí** — finální `printf` na konci souboru.
- **Délka baru** — desetidílný bar v sekci *„10-segment progress bar"*.
- **Emoji** — `📁 🌿 🕐` v `printf` (standardní emoji, nepotřebuješ Nerd Font).

## Jak se počítá kontext

Skript bere primárně `context_window.used_percentage` z payloadu Claude Code (přesné — započítá i cache). Když pole chybí, spadne na ruční výpočet `total_input_tokens / context_window_size`. Celý JSON se parsuje **jedním** průchodem `jq`.

## Atribuce / Credit

Vychází ze statusline ukázané v tutoriálu **Leonarda Grigoria** — *„My actual Claude Code workflow"* ([YouTube](https://www.youtube.com/watch?v=Hhiwq1aHK7o), kanál [Build & Ship with AI](https://www.youtube.com/@leonardogrig)).

Tahle verze je **podstatně upravená**: jeden `jq` průchod místo pěti, primárně přesné `used_percentage` s fallbackem, vlastní prahy barev a desetidílný bar, ošetření chyb. Díky Leonardovi za původní nápad. 🙏

## Licence

[MIT](LICENSE) © 2026 Jindřich Fáborský — vztahuje se na úpravy v tomto repozitáři.
