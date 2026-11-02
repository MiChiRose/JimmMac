<div align="center">
  <img src="Resources/ICQFlower.png" alt="JimmMac ICQ flower" width="112" />
  <h1>JimmMac</h1>
  <p><b>A familiar flower. An older Mac. A new conversation.</b></p>
  <p>
    <img src="https://img.shields.io/badge/version-0.12.0-5a9638" alt="Version 0.12.0" />
    <img src="https://img.shields.io/badge/status-public%20testing-d59b35" alt="Public testing" />
    <img src="https://img.shields.io/badge/OS%20X-10.8%E2%80%9310.13-silver" alt="Target: OS X 10.8 through macOS 10.13" />
    <img src="https://img.shields.io/badge/architecture-Intel%20x86__64-687b8c" alt="Intel x86_64" />
  </p>
  <p>
    <a href="https://github.com/MiChiRose/JimmMac/releases/latest"><b>Download JimmMac</b></a>
    · <a href="https://github.com/MiChiRose/JimmMac/issues">Report a problem</a>
    · <a href="docs/GUIDE.ru.md">Подробная инструкция на русском</a>
  </p>
</div>

## ICQ conversations, at home on a classic Mac

JimmMac is an independent client for [Jimm.online](https://jimm.online), a service
reviving ICQ-style messaging. It brings UIN sign-in, contacts and everyday text
conversations to older Intel Macs, with native AppKit controls, silver panels,
the green ICQ flower and familiar message sounds.

The interface is currently in Russian. The application is written in Objective-C
and uses one Intel build targeting **OS X 10.8 Mountain Lion through macOS 10.13
High Sierra**. It is an independent project, not an official ICQ application.

<p align="center">
  <img src="screenshots/UI-chat-polished.png" alt="JimmMac conversation on OS X Mavericks, using fictional contacts and messages" width="900" />
</p>
<p align="center"><em>Native AppKit on Mavericks. Screenshot uses fictional conversations.</em></p>

## Download and install

| Download | What to choose |
| --- | --- |
| [0.12.0 DMG installer](https://github.com/MiChiRose/JimmMac/releases/download/v0.12.0/JimmMac-0.12.0-macos10.8-10.13-x86_64.dmg) | Open the image and drag JimmMac into Applications. |
| [0.12.0 application ZIP](https://github.com/MiChiRose/JimmMac/releases/download/v0.12.0/JimmMac-0.12.0-macos10.8-10.13-x86_64.zip) | The same application in a ZIP archive. |
| [Release notes and SHA-256 checksums](https://github.com/MiChiRose/JimmMac/releases/tag/v0.12.0) | Read about this version and verify your download. |

Launch JimmMac from **Applications in Finder**. When updating, quit JimmMac before
replacing it; keep your existing application data and settings. The application
is not Developer ID signed or notarized. If Gatekeeper blocks the first launch,
Control-click JimmMac and choose **Open**.

Use a **Jimm.online UIN and password** to sign in. If you need an account, start at
[Jimm.online](https://jimm.online). Enable **«Запомнить меня»** to restore your login
after restarting the application.

## What you can do

- Keep **Contacts** and **Conversations** separate, find people by UIN, add contacts
  and organize them into groups.
- Send and receive text messages automatically, including offline messages, with
  unread counts, typing indicators and reconnection after a network interruption.
- Browse local history, search older messages, follow clickable links and reply
  with a quote.
- Leave a draft and return to it after restarting, with separate drafts for each
  conversation and account.
- View profiles and avatars, edit your own profile and photo, and change your
  online status with server confirmation.
- Adjust message fonts, sounds, notification previews and Enter-to-send behavior.
- Use native keyboard shortcuts, including Command shortcuts with a Russian
  keyboard layout. Open **«Справка → Сочетания клавиш…»** for the full reference.

<details>
<summary><b>A closer look: contacts, profile and sign-in</b></summary>

<p align="center">
  <img src="screenshots/UI-contacts.png" alt="JimmMac contacts and group filter with fictional data" width="850" />
  <img src="screenshots/UI-own-profile.png" alt="JimmMac profile editor with fictional account details" width="520" />
  <img src="screenshots/UI-login.png" alt="JimmMac UIN sign-in window" width="520" />
</p>

</details>

## New in 0.12.0

This release improves keyboard navigation, Escape and Enter behavior, undo/redo
isolation and clipboard shortcuts. Incoming messages preserve selected history
text so you can continue copying it. Account identity and connection status now
have separate places in the window.

The classic green-and-silver appearance includes new About and keyboard-help
windows. A decorated DMG provides drag-to-Applications installation. The network
layer now selects an OS X 10.8 fallback at runtime, keeping one application for
the full target range.

[Read the 0.12.0 release notes](https://github.com/MiChiRose/JimmMac/releases/tag/v0.12.0).

## Compatibility and testing

| System | Current verification |
| --- | --- |
| OS X 10.8 Mountain Lion | Build targets 10.8; fallback network path tested on Mavericks. A real 10.8 test is still needed. |
| OS X 10.9 Mavericks | Tested on **10.9.5**, including installation, saved login, sending and automatic message reception. |
| OS X 10.10–macOS 10.13 | Within the target range; tests on these systems are still needed. |

Version 0.12.0 is a **public testing build**. It passed 566 automated checks on
Mavericks, covering both network paths, storage and the interface. The final
application was built with Xcode 5.1.1 / SDK 10.9, with a minimum system of 10.8.
Build compatibility does not replace testing on each actual system; differences
in system TLS, certificates and rendering may still matter.

If you test it, please [open an issue](https://github.com/MiChiRose/JimmMac/issues)
with your OS version, JimmMac version, what you did and what happened. Installation,
sign-in, automatic incoming messages and restarting with a saved login are useful
first checks. Remove private conversation details from screenshots, and never
include passwords or session tokens.

## Your data

JimmMac does not save your password. Optional saved sign-in uses an expiring token
in the system Keychain. **Cmd+Q** keeps that login; **«Выйти из аккаунта»** removes it.

Message history and drafts are stored locally under
`~/Library/Application Support/JimmMac/`, separately for each account. These JSON
files are **not encrypted**. Search runs against local history. Notification
previews can be adjusted in Settings.

[Detailed behavior and storage notes, in Russian](docs/GUIDE.ru.md#данные-и-сетевое-поведение).

## Build and explore

The repository includes the application source, resources and tests. The verified
build environments are Xcode 5.1.1 / SDK 10.9 and Xcode 6.2 / SDK 10.10 on Mavericks.
Current Xcode versions do not include the legacy ARC support needed for this
deployment target.

```sh
git clone https://github.com/MiChiRose/JimmMac.git
cd JimmMac
bash scripts/test.sh
bash scripts/build.sh
```

Open `build/JimmMac.app` from Finder. UI checks are available through
`bash scripts/ui-smoke.sh` and use fictional data.

[Build, packaging and architecture guide](docs/GUIDE.ru.md)
· [Verification record](VALIDATION.md)
· [Jimm.online API documentation](https://jimm.online/developers)

## More life for older Macs

If you also use Telegram, take a look at
[Telegraphica for Mac](https://github.com/MiChiRose/telegraphica), our separate
client for older Intel Macs. The same link is available inside JimmMac under
**«Справка → Telegraphica для Mac…»** and in **«О JimmMac»**.

JimmMac is developed by **Yura Menschikov**. Thanks to the author of Jimm.online
for the service and API that make these conversations possible.

<sub>ICQ branding, graphics and sounds belong to their respective owners.
See <a href="Resources/ASSET-SOURCES.md">asset sources and attribution</a>.</sub>
