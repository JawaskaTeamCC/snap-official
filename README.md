# Snap official repo

The (Internal) snap command official repository.

## Description

The official software repostiroy for the `snap` command.

Here are stored the programs that you can install with it,
for example to update snap:

```sh
snap install snap
```

## Adding your programs and libraries

Is as easy as opening a PR with your folders. It will get accepted
as long as it respects the mentioned structure, and you don't
modify anything outside of your organization without permission.

Just fork, upload and ask for a merge PR. If your PR gets rejected
it may be because youre lacking an essential `.cfg` file (Like `info.cfg`),
or you didn't add your organization to the public repository list
(Remember to always append your organization at the end, or the PR will
be automatically rejected).

## Structure

Folders represent organization, subfolders projects and or programs/libraries,
and down there versions.

Example:

```
📁 Argochamber (Organization)
├── 📜 info.cfg (Some basic information of your organization)
│
├── 📁 Some Project
│   ├── 📁 Program A
│   │   ├── 📁 1.1.1
│   │   ├── 📁 1.1.2
|   |   └── 📜 project.cfg (Keep this up to date!)
│   └── 📁 Library B
│
└── 📁 Snap
    ├── 📁 2.1
    ├── 📁 2.2
    └── 📜 project.cfg (Contains version mappings and other information, if present)
```

## Usage

The snap command can be used to pull programs, libraries and dependencies
from any repository, as long as it mimicks this structure.
