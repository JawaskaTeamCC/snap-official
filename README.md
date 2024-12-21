# Snap official repo

The (Internal) snap command official repository.

## Description

The official repostiroy for the `snap` command.

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
