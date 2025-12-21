<div align="center">

![Kikao Logo](logo.svg)

# Kikao.nvim

[![Made with love][badge-made-with-love]][contributors]
[[![Made with love][badge-latest-release]][latest-release]][latest-release]

[What](#what) •
[Requirements](#requirements) •
[Install](#install) •
[Configuration](#configuration) •
[How](#how) •
[API](#api)

<p></p>

A minimal session management plugin for your favorite editor.

Kikao is swahili for "session."

</div>

## What

It's a uncomplicated plugin that allows you to automatically save and
restore your session when you open and close neovim.

It basically saves the state of your editor when you close it and
restores it when you open it.

So you have your window layout and buffers just as you left them.

## Requirements

- Neovim 0.11.5+
  (tested on 0.11.5, may work on earlier versions but not guaranteed)

## Install

Please use release tags when installing the plugin to ensure
compatibility and stability.

The `main` branch may contain breaking changes
and isn't guaranteed to be stable.

### Lazy.nvim

See: [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'mistweaverco/kikao.nvim',
  version = 'v3.3.0',
  opts = {}
},
```

> [!IMPORTANT]
> `opts` needs to be at least an empty table `{}` and
> can't be completely omitted.

### Packer.nvim

See: [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'mistweaverco/kikao.nvim',
  tag = 'v3.3.0',
  config = function()
    require('snap').setup({})
  end
})
```

> [!IMPORTANT]
> `setup` call needs to have at least an empty table `{}` and
> can't be completely omitted.

### Neovim built-in package manager

```lua
vim.pack.add({
  src = 'https://github.com/mistweaverco/kikao.nvim.git',
  version = 'v3.3.0',
})
require('snap').setup({})
```

> [!IMPORTANT]
> `setup` call needs to have at least an empty table `{}` and
> can't be completely omitted.

## Configuration options

```lua
return {
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
    -- checkign via str:match on bufname
    deny_on_path = {
        ".git/COMMIT_EDITMSG",
    }
}
```

## How

How does it work?

### Starting a session

1. You open neovim in a project directory
    (a directory that contains one of the `project_dir_matchers`).


2. Kikao checks if a git mergetool is active via the
   `GIT_MERGE_AUTOEDIT` environment variable.
    - If a git mergetool is active, kikao won't load or save a session.
    - else, it continues to step 3.

3. Kikao determines the project root path.

4. Kikao checks if there is a session file for that project.
    - If there is a session file, kikao loads it.
    - else, it continues to step 5.

5. You work on your project.

### Saving a session

1. You exit neovim in a project directory
    (a directory that contains one of the `project_dir_matchers`).

2. If Kikao has been loaded
   (if git mergetool isn't active and
    the opened file isn't in the `deny_on_path` list),
  - Kikao determines the project root path.
  - Kikao saves the session file for that project.
    - Kikao saves metadata about the session in a separate file.

3. Neovim closes.


### Session file location

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

It can also include many more sets of data from other plugins.

See [here][api-other-plugins-set] for an example how
other plugins persist data via
the exposed `kikao.api.set_value` function.

Reading from persisted data via
the exposed `kikao.api.get_value` function is
[also pretty easy][api-other-plugins-get].

## API

- `require("kikao.api")` - The API module.
  Contains functions to interact with kikao programmatically.
    - `require("kikao.api").get_value(key: string): any` - Gets a
      value from the session metadata.
      Key supports dot notation for nested values.
      It should be considered good practice to
      prefix your keys with your plugin name like so:
      Returns `nil` if the key doesn't exist.
      `my_plugin_name.my.nested.key`
    - `require("kikao.api").set_value(key: string, value: any): void` - Sets a
      value in the session metadata.
      Key supports dot notation for nested values.
      It should be considered good practice to
      prefix your keys with your plugin name like so:
      `my_plugin_name.my.nested.key`
      Values are serialized to JSON.
- `require("kikao").clear()` - Clears the current project's session file.
  Also closes all buffers.
- `require("kikao").clear_all()` - Clears all session files.
  Also closes all buffers.
- `require("kikao").version()` - Returns the version info.



[badge-made-with-love]: assets/badge-made-with-love.svg
[contributors]: https://github.com/mistweaverco/kikao.nvim/graphs/contributors
[logo]: assets/logo.svg
[badge-latest-release]: https://img.shields.io/github/v/release/mistweaverco/kikao.nvim?style=for-the-badge
[latest-release]: https://github.com/mistweaverco/kikao.nvim/releases/latest
[api-other-plugins-set]: https://github.com/mistweaverco/bafa.nvim/blob/e051e06dc250baf703c2a9d5327a9e8ace0c9f7f/lua/bafa/utils/state.lua#L300
[api-other-plugins-get]: https://github.com/mistweaverco/bafa.nvim/blob/e051e06dc250baf703c2a9d5327a9e8ace0c9f7f/lua/bafa/utils/state.lua#L313
