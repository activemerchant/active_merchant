# pry-byebug

[![Version][VersionBadge]][VersionURL]
[![Build][CIBadge]][CIURL]
[![Inline docs][InchCIBadge]][InchCIURL]
[![Coverage][CoverageBadge]][CoverageURL]

Adds step-by-step debugging and stack navigation capabilities to [pry] using
[byebug].

To use, invoke pry normally. No need to start your script or app differently.
Execution will stop in the first statement after your `binding.pry`.

```ruby
def some_method
  puts 'Hello World' # Run 'step' in the console to move here
end

binding.pry
some_method          # Execution will stop here.
puts 'Goodbye World' # Run 'next' in the console to move here.
```

## Requirements

MRI 2.4.0 or higher.

## Installation

Add

```ruby
gem 'pry-byebug'
```

to your Gemfile and run

```console
bundle install
```

Make sure you include the gem globally or inside the `:test` group if you plan
to use it to debug your tests!

## Commands

### Step-by-step debugging

**break:** Manage breakpoints.

**step:** Step execution into the next line or method. Takes an optional numeric
argument to step multiple times.

**next:** Step over to the next line within the same frame. Also takes an
optional numeric argument to step multiple lines.

**finish:** Execute until current stack frame returns.

**continue:** Continue program execution and end the Pry session.

### Callstack navigation

**backtrace:** Shows the current stack. You can use the numbers on the left
side with the `frame` command to navigate the stack.

**up:** Moves the stack frame up. Takes an optional numeric argument to move
multiple frames.

**down:** Moves the stack frame down. Takes an optional numeric argument to move
multiple frames.

**frame:** Moves to a specific frame. Called without arguments will show the
current frame.

## Matching Byebug Behaviour

If you're coming from Byebug or from Pry-Byebug versions previous to 3.0, you
may be lacking the 'n', 's', 'c' and 'f' aliases for the stepping commands.
These aliases were removed by default because they usually conflict with
scratch variable names. But it's very easy to reenable them if you still want
them, just add the following shortcuts to your `~/.pryrc` file:

```ruby
if defined?(PryByebug)
  Pry.commands.alias_command 'c', 'continue'
  Pry.commands.alias_command 's', 'step'
  Pry.commands.alias_command 'n', 'next'
  Pry.commands.alias_command 'f', 'finish'
end
```

Also, you might find useful as well the repeat the last command by just hitting
the `Enter` key (e.g., with `step` or `next`). To achieve that, add this to
your `~/.pryrc` file:

```ruby
# Hit Enter to repeat last command
Pry::Commands.command /^$/, "repeat last command" do
  _pry_.run_command Pry.history.to_a.last
end
```

## Breakpoints

You can set and adjust breakpoints directly from a Pry session using the
`break` command:

**break:** Set a new breakpoint from a line number in the current file, a file
and line number, or a method. Pass an optional expression to create a
conditional breakpoint. Edit existing breakpoints via various flags.

Examples:

```ruby
break SomeClass#run            # Break at the start of `SomeClass#run`.
break Foo#bar if baz?          # Break at `Foo#bar` only if `baz?`.
break app/models/user.rb:15    # Break at line 15 in user.rb.
break 14                       # Break at line 14 in the current file.

break --condition 4 x > 2      # Change condition on breakpoint #4 to 'x > 2'.
break --condition 3            # Remove the condition on breakpoint #3.

break --delete 5               # Delete breakpoint #5.
break --disable-all            # Disable all breakpoints.

break                          # List all breakpoints.
break --show 2                 # Show details about breakpoint #2.
```

Type `break --help` from a Pry session to see all available options.

## Alternatives

Note that all of the alternatives here are incompatible with pry-byebug. If
your platform is supported by pry-byebug, you should remove any of the gems
mentioned here if they are present in your Gemfile.

* [pry-debugger]: Provides step-by-step debugging for MRI 1.9.3 or older
  rubies. If you're still using those and need a step-by-step debugger to help
  with the upgrade, pry-debugger can be handy.

* [pry-stack_explorer]: Provides stack navigation capabilities for MRI 1.9.3 or
  older rubies. If you're still using those and need to navigate your stack to
  help with the upgrade, pry-stack_explorer can be handy.

* [pry-nav]: Provides step-by-step debugging for JRuby.

## Contribute

See [Getting Started with Development](CONTRIBUTING.md).

## Funding

Subscribe to [Tidelift] to ensure pry-byebug stays actively maintained, and at
the same time get licensing assurances and timely security notifications for
your open source dependencies.

You can also help `pry-byebug` by leaving a small (or big) tip through [Liberapay].

[Tidelift]: https://tidelift.com/subscription/pkg/rubygems-pry-byebug?utm_source=rubygems-pry-byebug&utm_medium=referral&utm_campaign=readme
[Liberapay]: https://liberapay.com/pry-byebug/donate

## Security contact information

Please use the Tidelift security contact to [report a security vulnerability].
Tidelift will coordinate the fix and disclosure.

[report a security vulnerability]: https://tidelift.com/security

## Credits

* Gopal Patel (@nixme), creator of [pry-debugger], and everybody who contributed
  to it. pry-byebug is a fork of pry-debugger so it wouldn't exist as it is
  without those contributions.
* John Mair (@banister), creator of [pry].

Patches and bug reports are welcome.

[pry]: http://pry.github.com
[byebug]: https://github.com/deivid-rodriguez/byebug
[pry-debugger]: https://github.com/nixme/pry-debugger
[pry-nav]: https://github.com/nixme/pry-nav
[pry-stack_explorer]: https://github.com/pry/pry-stack_explorer

[VersionBadge]: https://badge.fury.io/rb/pry-byebug.svg
[VersionURL]: http://badge.fury.io/rb/pry-byebug
[CIBadge]: https://github.com/deivid-rodriguez/pry-byebug/workflows/ubuntu/badge.svg?branch=master
[CIURL]: https://github.com/deivid-rodriguez/pry-byebug/actions?query=workflow%3Aubuntu
[InchCIBadge]: http://inch-ci.org/github/deivid-rodriguez/pry-byebug.svg?branch=master
[InchCIURL]: http://inch-ci.org/github/deivid-rodriguez/pry-byebug
[CoverageBadge]: https://api.codeclimate.com/v1/badges/a88e27809329c03af017/test_coverage
[CoverageURL]: https://codeclimate.com/github/deivid-rodriguez/pry-byebug/test_coverage
