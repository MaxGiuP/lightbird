<p align="center"><img width="240" src="lightbird/assets/logo.svg" alt="Lightbird logo"></p>

<p align="center">An elegant Thunderbird theme with frosted-glass UI, system accent colours, and a custom wallpaper background.</p>

<p align="center"><img src="images/lightbird.webp" alt="Lightbird preview"></p>


## Installation

### Quick install (Linux / macOS / Windows Git Bash)

```bash
git clone https://github.com/reizumii/lightbird
cd lightbird
bash install.sh
```

The script auto-detects your OS, finds the default Thunderbird profile, copies the theme files into `chrome/`, and merges the required preferences into `user.js`.

Restart Thunderbird after running the script.

### Manual install

1. In Thunderbird, open **Menu → Help → Troubleshooting Information**.
2. Click **Open Folder** next to *Profile Folder*.
3. Inside the profile folder, create a `chrome/` directory if it does not exist.
4. Copy these items from this repo into `chrome/`:
   - `userChrome.css`
   - `userContent.css`
   - `lightbird/` (whole directory)
   - `images/` (whole directory)
5. Copy `user.js` from this repo into the **profile root** (the folder containing `chrome/`, not inside it).
6. Restart Thunderbird.

### Uninstall

```bash
bash install.sh --uninstall
```

Or delete `chrome/userChrome.css`, `chrome/userContent.css`, `chrome/lightbird/`, and `chrome/images/` manually.

---

## Recommended add-ons

- [Thunderbird Conversations](https://addons.thunderbird.net/thunderbird/addon/gmail-conversation-view/) — threaded conversation view
- [Auto Profile Picture](https://addons.thunderbird.net/thunderbird/addon/auto-profile-picture/) — avatar images in message list
- [uBlock Origin](https://addons.thunderbird.net/thunderbird/addon/ublock-origin/) — optional ad blocking

## Windows — Mica / Acrylic transparency

Thunderbird 140+ supports native Mica/Acrylic transparency on Windows 11.
Open **Advanced Preferences** and set:

| Preference | Value |
|---|---|
| `widget.windows.mica` | `true` |
| `widget.windows.mica.toplevel-backdrop` | `1` = Mica, `2` = Acrylic |

Also set Thunderbird's colour theme to **System theme — auto**.

## Customization

### CSS variables

All sizing and colour tokens live in `lightbird/components/variables.css`.
Create a `lightbird/custom.css` to override them without touching the base files:

```css
/* lightbird/custom.css — example: red accent */
:root {
  --selected-item-color: rgba(255, 0, 0, 0.1) !important;
  --lb-text-color: rgba(255, 0, 0) !important;
  --lb-panel-bgcolor: rgba(255, 0, 0, 0.05) !important;
}
```

Then add one line to `userChrome.css`:

```css
@import "lightbird/custom.css";
```

### Wallpaper

Replace `images/winmail.png` with any image you prefer and re-run `install.sh`.

### Hide the Lightbird logo

In Thunderbird **Advanced Preferences**, create a Boolean preference:

```
lightbird.logo.hide = true
```

---

## Acknowledgements

Icons: [Microsoft Fluent UI System Icons](https://github.com/microsoft/fluentui-system-icons)
Bird + mail icon: derivative of [Microsoft Fluent Emoji](https://github.com/microsoft/fluentui-emoji)
Font: [Junicode](https://github.com/psb1558/Junicode-font)
Cloud photo: [engin akyurt](https://unsplash.com/@enginakyurt) on Unsplash
