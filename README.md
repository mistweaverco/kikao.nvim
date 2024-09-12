<div align="center">

![Kulala Logo](logo.svg)

# kulala.nvim

![Lua](https://img.shields.io/badge/Made%20with%20Lua-blueviolet.svg?style=for-the-badge&logo=lua)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/mistweaverco/kikao.nvim?style=for-the-badge)](https://github.com/mistweaverco/kikao.nvim/releases/latest)

[Requirements](#requirements) • [Install](#install) • [Configuration](#configuration) • [How](#how)

<p></p>

A minimal session management plugin for your favorite editor.

Kikao is swahili for "session".

It is a simple plugin that allows you to automatically save and
restore your session when you open and close neovim.

<p></p>

</div>

## Requirements

- Neovim 0.10.0+

## Install

Via [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ 'mistweaverco/kikao.nvim', opts = {} },
```

> [!NOTE]
> `opts` needs to be at least an empty table `{}` and can't be completely omitted.

## Configuration

```lua
{ 'mistweaverco/kikao.nvim',
  opts = {
    -- Checks for the existence of the project root by checking for these directories
    project_dir_matchers = { ".git", ".hg", ".bzr", ".svn" },
    -- The path to the session file
    -- If not provided, the session file will be stored in {{PROJECT_DIR}}/.nvim/session.vim
    session_file_path = nil,
  }
},
```

## How

How does it work?

- When you open neovim, kikao will check if there is a session file in the project root.
- If there is a session file, it will be loaded.
- When you close neovim, kikao will save the session file in the project root.
