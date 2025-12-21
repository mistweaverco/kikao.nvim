<div align="center">

![Kikao Logo](logo.svg)

# Kikao.nvim

![Lua](https://img.shields.io/badge/Made%20with%20Lua-blueviolet.svg?style=for-the-badge&logo=lua)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/mistweaverco/kikao.nvim?style=for-the-badge)](https://github.com/mistweaverco/kikao.nvim/releases/latest)

[What](#what) • [Requirements](#requirements) • [Install](#install) • [Configuration](#configuration) • [How](#how)

<p></p>

A minimal session management plugin for your favorite editor.

Kikao is swahili for "session".

</div>

## What

It's a simple plugin that allows you to automatically save and
restore your session when you open and close neovim.

It basically saves the state of your editor when you close it and
restores it when you open it.

So you have your window layout and buffers just as you left them.

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
{
  'mistweaverco/kikao.nvim',
  opts = {
    -- Checks for the existence of the project root by checking for these directories
    -- If none are found, the session won't be loaded or saved
    project_dir_matchers = { ".git", ".svn", ".jj", ".hg" },
    -- The path to the session file
    -- If not provided, the session file will be stored in:
    -- ~/.cache/nvim/kikao.nvim/{{SHA256_PROJECT_DIR}}/session.vim
    --
    -- If you want to store the session file in the project root,
    -- you can set this to "{{PROJECT_DIR}}/.session.vim"
    session_file_path = nil,
    -- The name of the session file
    session_file_name = "session.vim",
    -- Don't start or restore a session if the file is in the deny_on_path list
    -- and you opened that file directly
    deny_on_path = {
      ".git/COMMIT_EDITMSG",
    },
  }
},
```

## How

How does it work?

- When you open neovim, kikao will look for an existing session file for the project.
- If there is a session file, it'll be loaded.
- When you close neovim, kikao will save the session file in the project root.

Sessions are stored in a directory structure based on the SHA256 hash of the
project root path.

For example:

```
~/.cache/nvim/kikao.nvim/3a7bd3c8e5f6f7e8f9e0d1c2b3a4b5c6d7e8f9a0b1c2d3e4f5g6h7i8j9k0l1m2/session.vim
```

Additionally, kikao saves metadata about the session in a separate file called
`metadata.json` in the same directory as the session file.

This metadata includes:
- The project root path as (`project_dir`)

But it can also include many more sets of data from other plugins.

See [here](https://github.com/mistweaverco/bafa.nvim/blob/e051e06dc250baf703c2a9d5327a9e8ace0c9f7f/lua/bafa/utils/state.lua#L300) for an example how other plugins persist data via Kikao.

Reading from persisted data via the Kikao API is [also pretty easy](https://github.com/mistweaverco/bafa.nvim/blob/e051e06dc250baf703c2a9d5327a9e8ace0c9f7f/lua/bafa/utils/state.lua#L313).

## API

- `require("kikao").clear()` - Clears the current project's session file.
  Also closes all buffers.
- `require("kikao").clear_all()` - Clears all session files.
  Also closes all buffers.
- `require("kikao").version()` - Returns the version info.
