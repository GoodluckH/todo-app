# todo-app

A minimal SwiftUI todo app for iOS with Liquid Glass and natural-language deadlines.

## Features

- **Natural-language deadlines.** Type “Call mom tomorrow at 5pm” and the app detects the date on-device, shows it as a chip above the input field, and saves the task as “Call mom” due tomorrow at 5:00 PM. Tap the chip to adjust the date, or × to keep the words as part of the title.
- **Grouped home screen.** Open tasks are sorted into Overdue, Today, Tomorrow, Upcoming, and No Date.
- **Quick actions.** Swipe right to complete, swipe left to delete, long-press to set a due date. Completing a task shows a short Undo toast.
- **Completed tasks** are hidden by default; show or clear them from the toolbar menu.
- Persisted locally with SwiftData.

## Requirements

- Xcode 27.1 or later
- iOS 27.0 or later

## Getting started

1. Clone the repo and open `Untitled Project.xcodeproj`.
2. Select the **MyApp** target, open **Signing & Capabilities**, and choose your team. The committed project has no development team set.
3. Build and run.

## Keeping your Team ID out of commits

Xcode writes your Apple Developer Team ID into `project.pbxproj` when you pick a team. This repo uses a git filter (declared in `.gitattributes`) to blank that value in every commit while leaving your local file untouched, so Xcode keeps signing normally.

Git doesn't share filter definitions through the repo, so run this once in each clone:

```sh
git config filter.strip-team.clean "sed -E 's/DEVELOPMENT_TEAM = [A-Z0-9]+;/DEVELOPMENT_TEAM = \"\";/'"
git config filter.strip-team.smudge cat
```

To check it's working, the staged copy should show `DEVELOPMENT_TEAM = "";`:

```sh
git add "Untitled Project.xcodeproj/project.pbxproj"
git show :"Untitled Project.xcodeproj/project.pbxproj" | grep DEVELOPMENT_TEAM
```
