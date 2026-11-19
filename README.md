# Wordsmith ✨

Write in your language, send in English: a rewriter and summarizer for your menu bar.

Menu bar app: select text in your language anywhere (Slack, mail…), tap **⌥ twice** quickly, pick a version, and it replaces the selection.

| Key | Choice |
|-----|--------|
| 1 | Professional |
| 2 | Shorter |
| 3 | Casual / friendly |
| 4 | Keep original |

↑/↓ + Enter or a mouse click also work, Esc cancels. Your clipboard is put back afterwards.

**Summarize: tap ⌃ twice.** Select any text (a Slack thread, an email, a document, Czech or English) and get a short summary: the bottom line plus bullets with the important points (decisions, action items, deadlines, numbers). It comes in English and in your first non-English language from System Settings → General → Language & Region (Czech here); pick one with 1/2, arrows + Enter or a click to copy it. The selection is never changed. Esc closes.

## Requirements
- Claude Code CLI installed and signed in (`claude auth login`). The app runs `claude -p --model sonnet`, so it uses your subscription and needs no API key.
- Accessibility permission (System Settings → Privacy & Security → Accessibility), asked for on first launch. Needed to simulate ⌘C / ⌘V.

## Build and run
```bash
./build.sh          # → build/Wordsmith.app
./build.sh test     # self-test (reply parsing, double-tap detection)
open build/Wordsmith.app
```
To start it at login, add `build/Wordsmith.app` under System Settings → General → Login Items.

### Keep the Accessibility permission across rebuilds (one time)
macOS ties the permission to the app's signature. Without a certificate the app is signed ad hoc, the signature changes on every build, and the permission silently stops working (the shortcut does nothing).

1. Keychain Access → menu Keychain Access → Certificate Assistant → Create a Certificate…
2. Name: `Profesional Local Signing`, Identity Type: Self-Signed Root, Certificate Type: Code Signing → Create.
3. `./build.sh`, then in System Settings → Privacy & Security → Accessibility remove Wordsmith (−), add `build/Wordsmith.app` again (+) and turn it on.

## Notes
- The Claude desktop app also uses double ⌥ by default. Turn that off in Claude → Settings, or both will open.
- Speed: about 4.5 s per rewrite and about 7–8 s per summary (both languages), most of it `claude` CLI overhead. A direct API call with your own key would be about 1.5 s.

## Download page
`./build.sh site` builds `build/site`: the page from `site/index.html`, the zipped app and the demo video from `brag-output/`. The GitHub Action in `.github/workflows/pages.yml` runs the self-test and this build on every push to `main` and publishes it to GitHub Pages (enable Pages with source "GitHub Actions" in the repo settings). The CI build is signed ad hoc and not notarized, so the page tells people how to open it the first time.
