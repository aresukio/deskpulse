# DeskPulse

DeskPulse is a macOS background agent that keeps your session active based on configurable Wi-Fi and working-hours filters.

## Install (First time)

```bash
brew tap aresukio/deskpulse
brew install aresukio/deskpulse/deskpulse

deskpulse up // to trigger permission

// 1) Open System Settings -> Privacy & Security -> Accessibility 
// 2) Enable deskpulse-agent

deskpulse up // again

```

## Accessibility Permission (Required)

1. Open **System Settings -> Privacy & Security -> Accessibility**
2. Enable `deskpulse-agent` in the Accessibility list.

![Accessibility settings](./accessibility.png)

## Update to the latest version

```bash
deskpulse update

// Every new version will require trust to be granted again
// 1) Open System Settings -> Privacy & Security -> Accessibility 
// 2) Enable the newly aded deskpulse-agent

deskpulse up // again
```

## Useful commands

```bash
deskpulse help
deskpulse status
deskpulse logs
```
