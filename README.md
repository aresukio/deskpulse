# DeskPulse

DeskPulse is a macOS background agent that keeps your session active based on configurable Wi-Fi and working-hours filters.

## Install (First time)

```bash
brew tap aresukio/deskpulse
brew install aresukio/deskpulse/deskpulse

deskpulse up

// At this stage the binary will have to be allowed under 
1) Open System Settings -> Privacy & Security -> Accessibility 
2) Enable deskpulse-agent

Run `deskpulse up` again until it doesn't show any error.

```

Trust will have to be granted, follow **Accessibility Permission (Required)**.

## Accessibility Permission (Required)

1. Open **System Settings -> Privacy & Security -> Accessibility**
2. Enable `deskpulse-agent` in the Accessibility list.

![Accessibility settings](./accessibility.png)

## Update to the latest version

```bash
deskpulse update
```

Every new version will require trust to be granted again, follow **Accessibility Permission (Required)**.

## Useful commands

```bash
deskpulse help
deskpulse status
deskpulse logs
deskpulse update
```
