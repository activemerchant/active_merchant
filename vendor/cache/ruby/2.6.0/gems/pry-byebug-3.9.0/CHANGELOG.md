# CHANGELOG

## Master (Unreleased)

## 3.9.0 (2020-03-21)

### Fixed

* Dependency on pry being too loose. Now breaking minor releases of pry won't affect pry-byebug users (#289).

### Added

* Support for pry 0.13.0 (#266).

### Removed

* Support for pry older than 0.13.0 (#289).

## 3.8.0 (2020-01-22)

### Fixed

* Use `Binding#source_location` instead of evaluating `__FILE__` to avoid
  warnings on Ruby 2.7 and on Ruby 2.6 in verbose mode (#221).

### Removed

* Support for Ruby 2.3. Pry-byebug no longer installs on this platform.

## 3.7.0 (2019-02-21)

* Byebug 11 compatibility, with ruby 2.6 support.

## 3.6.0 (2018-02-07)

### Added

* Byebug 10 compatibility, with ruby 2.5 support.

## 3.5.1 (2017-11-27)

### Fixed

* Allow other threads like Pry (#142).

## 3.5.0 (2017-08-23)

### Added

* Byebug 9.1 support. As a result, Ruby 2.0 & Ruby 2.1 support has been dropped.
  Pry-byebug no longer installs on these platforms.

## 3.4.3 (2017-08-22)

### Fixed

* Installation on old rubies after byebug dropping support for them.

## 3.4.2 (2016-12-06)

### Fixed

* Byebug doesn't start after `disable-pry` command.

## 3.4.1 (2016-11-22)

### Fixed

* control_d handler not being required properly when `pry-byebug` loaded
  as a `pry` plugin and not through explicit require.

## 3.4.0 (2016-05-15)

### Fixed

* Byebug 9 compatibility.

### Added

* A new `backtrace` command.

## 3.3.0 (2015-11-05)

### Fixed

* Byebug 8 compatibility.
* Fix encoding error in gemspec file (#70).
* Debugger being too slow (#80, thanks @k0kubun).

## 3.2.0 (2015-07-18)

### Added

* `continue` can now receive a line number argument (#56).

### Fixed

* Conflicts with `break` and `next` Ruby keywords inside multiline statements
  (#44).

### Removed

* `breaks` command. It was broken anyways (#47).

## 3.1.0 (2015-04-14)

### Added

* Frame navigation commands `up`, `down` and `frame`.

## 3.0.1 (2015-04-02)

### Fixed

* Several formatting and alignment issues.

## 3.0.0 (2015-02-02)

### Fixed

* `binding.pry` would not stop at the correct place when called at the last
  line of a method/block.

### Removed

* Stepping aliases for `next` (`n`), `step` (`s`), `finish` (`f`) and `continue`
  (`c`). See #34.

## 2.0.0 (2014-01-09)

### Fixed

* Byebug 3 compatibility.
* Pry not starting at the first line after `binding.pry`  but at `binding.pry`.
* `continue` not finishing pry instance (#13).

## 1.3.3 (2014-25-06)

### Fixed

* Pry 0.10 series and further minor version level releases compatibility.

## 1.3.2 (2014-24-02)

### Fixed

* Bug inherited from `byebug`.

## 1.3.1 (2014-08-02)

### Fixed

* Bug #22 (thanks @andreychernih).

## 1.3.0 (2014-05-02)

### Added

* Breakpoints on method names (thanks @andreychernih & @palkan).

### Fixed

* "Undefined method `interface`" error (huge thanks to @andreychernih).

## 1.2.1 (2013-30-12)

### Fixed

* "Uncaught throw :breakout_nav" error (thanks @lukebergen).

## 1.2.0 (2013-24-09)

### Fixed

* Compatibility with byebug's 2.x series

## 1.1.2 (2013-11-07)

### Fixed

* Compatibility with backwards compatible byebug versions.

## 1.1.1 (2013-02-07)

### Fixed

* Bug when doing `step n` or `next n` where n > 1 right after `binding.pry`.

## 1.1.0 (2013-06-06)

### Added

* `s`, `n`, `f` and `c` aliases (thanks @jgakos!).

## 1.0.1 (2013-05-07)

### Fixed

* Unwanted debugging printf.

## 1.0.0 (2013-05-07)

### Added

* Initial release forked from
  [pry-debugger](https://github.com/nixme/pry-debugger) to support byebug.

### Removed

* pry-remote support.

## Older releases

* Check [pry-debugger](https://github.com/nixme/pry-debugger)'s CHANGELOG.
