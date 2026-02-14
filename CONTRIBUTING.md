# Contributing to Ora et Labora

Thank you for your interest in contributing to Ora et Labora! Contributions are warmly welcomed, whether you're fixing a bug, adding a feature, improving documentation, or suggesting ideas.

## Our Promise

I respond to every pull request and issue. Your time and effort are valued, and you'll always hear back from me.

## What We Accept

- **Bug fixes**: Obvious accepts. If something is broken, let's fix it.
- **New features**: Welcome! If you have an idea that would make this project better, I'd love to see it.
- **Documentation improvements**: Always appreciated.
- **Art and theming**: Improvements to the procedural graphics, new monastery decorations, or UI polish.

## Getting Started

### Prerequisites

1. **LOVE2D 11.4+** - Install via your system package manager:
   ```bash
   # macOS
   brew install love

   # Ubuntu/Debian
   sudo apt-get install love

   # Windows
   # Download from https://love2d.org/
   ```

### Development Workflow

```bash
# Clone the repository
git clone https://github.com/JohnVonDrashek/ora-et-labora.git
cd ora-et-labora

# Run the game
love .
```

## Coding Standards

### Lua Style

- Use `local` for all variables and functions where possible
- Use 4-space indentation
- Keep lines under 100 characters when reasonable

### Module Pattern

All modules use the standard Lua return-table pattern:

```lua
local MyModule = {}

function MyModule.doSomething()
    -- ...
end

return MyModule
```

### OOP via Metatables

Classes use the `__index` metatable pattern:

```lua
local MyClass = {}
MyClass.__index = MyClass

function MyClass.new(...)
    local self = setmetatable({}, MyClass)
    -- initialize
    return self
end
```

### Internal vs Display Names

The codebase preserves internal stat field names for backward compatibility while displaying themed names:

| Internal | Display |
|----------|---------|
| `fun` | Devotion |
| `creativity` | Wisdom |
| `graphics` | Beauty |
| `sound` | Harmony |
| `fans` | Renown |
| `money` | Treasury |

## Submitting Changes

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test by running `love .` and playing through a few in-game years
5. Commit your changes with a clear message
6. Push to your fork
7. Open a Pull Request

## Questions or Ideas?

Feel free to open an issue for discussion, or reach out directly:

**Email**: johnvondrashek@gmail.com

## Code of Conduct

This project follows the [Rule of St. Benedict Code of Conduct](https://opensource.saintaardvarkthecarpeted.com/rule-of-st-benedict-code-of-conduct/). In short: be kind, be patient, listen well, and work together in peace.

---

Thank you for contributing!
