# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## What this module does

`simp-tuned` is a small SIMP Puppet module that manages the **`tuned`**
system-tuning daemon (the Linux performance-tuning service, historically paired
with `ktune`) on Enterprise Linux systems. The single `tuned` class installs
the `tuned` package, renders the daemon's two configuration files, ensures the
`ktune` sysctl file exists, and keeps the `tuned` service running and enabled
(`manifests/init.pp`).

The module does **not** select a named `tuned` profile. Instead it manages the
older `tuned.conf` / `sysconfig/ktune` configuration surface directly: it toggles
the individual monitoring/tuning plugins (disk, network, CPU), sets the tuning
interval, and configures the I/O scheduler (`elevator`) and the block devices it
applies to.

### Business logic

The module is a single public class; there are no defines, no other classes, and
no `assert_private()` (consumers `include 'tuned'`).

- **`tuned` (`manifests/init.pp`)** — Public entry class. Parameters and
  their defaults (`init.pp`):
  - `$io_scheduler` (`Tuned::IoSchedule`, default `'deadline'`) — the I/O
    scheduler (`ELEVATOR`) ktune applies. See the data type below for legal
    values. Per the docstring it does **not** override a scheduler set on the
    kernel command line, nor one already changed on a non-default device
    (`init.pp`).
  - `$elevator_tune_devs` (`Array[String]`, default `['hd','sd','cciss']`) — the
    device name prefixes whose queues get the elevator setting; rendered into a
    `/sys/block/{...}*/queue/scheduler` glob (`ktune.erb`).
  - `$use_sysctl` (`Boolean`, default `true`) — when true, `ktune` reads the
    custom `/etc/sysctl.conf` (`ktune.erb`).
  - `$use_sysctl_post` (`Boolean`, default **`false`**) — when true, `ktune`
    applies `/etc/sysctl.ktune` *after* custom settings, overriding them
    (`ktune.erb`). Note the module always ensures `/etc/sysctl.ktune`
    exists (`init.pp`) even though this defaults off.
  - `$tuning_interval` (`Integer`, default `10`) — seconds between `tuned`
    tuning runs (`tuned.conf.erb`).
  - Plugin toggles (all `Boolean`), rendered into `tuned.conf` as
    capitalized `True`/`False` (`tuned.conf.erb`): `$diskmonitor_enable`
    (default `true`), `$disktuning_enable` (`true`), `$disktuning_hdparm`
    (`true`), `$disktuning_alpm` (`true`), `$netmonitor_enable` (`true`),
    `$nettuning_enable` (`true`), `$cpumonitor_enable` (`true`),
    `$cputuning_enable` (`true`).
  - `$package_ensure` (`String`) — the ensure state of the `tuned` package.
    Defaults to
    `simplib::lookup('simp_options::package_ensure', { 'default_value' => 'installed' })`
    (`init.pp`). This is the module's only SIMP `simp_options` seam.

  Resources declared (`init.pp`), all keyed off the local
  `$ktune_name = 'tuned'` (`init.pp`):
  - `file { '/etc/tuned.conf' }` — mode `0640`, content from
    `template('tuned/etc/tuned.conf.erb')`, **notifies `Service['tuned']`**
    (`init.pp`).
  - `file { '/etc/sysconfig/ktune' }` — mode `0640`, content from
    `template('tuned/etc/sysconfig/ktune.erb')`; **does not** notify the service
    directly, but the service `require`s it (`init.pp`).
  - `file { '/etc/sysctl.ktune' }` — `ensure => present`, mode `0640`, empty
    (managed for existence only) (`init.pp`).
  - `package { 'tuned' }` at `$package_ensure` (`init.pp`).
  - `service { 'tuned' }` — `ensure => running`, `enable => true`,
    `hasrestart`/`hasstatus => true`, `require => [Package['tuned'],
    File['/etc/sysconfig/ktune']]` (`init.pp`).

### The `Tuned::IoSchedule` data type

`types/ioschedule.pp` defines the type for `$io_scheduler`:

```puppet
type Tuned::IoSchedule = Enum['deadline','as','cfq','noop']
```

It is a simple `Enum` of the four legal elevator values (`types/ioschedule.pp`).
Note the manifest parameter uses the type as `Tuned::IoSchedule` while the file is
`ioschedule.pp` — Puppet's autoloader treats the type name case-insensitively for
the filename, so the `IoSchedule` alias resolves to `ioschedule.pp`.

## Gotchas / non-obvious details

- **No profile selection.** Unlike modern `tuned` usage, this module never runs
  `tuned-adm profile ...` or sets an `active_profile`. It manages the legacy
  `tuned.conf` / `sysconfig/ktune` plugin configuration directly
  (`templates/`). If you need named-profile behavior, that is not what this
  module does today.
- **Only `/etc/tuned.conf` notifies the service.** A change to
  `/etc/sysconfig/ktune` will *not* restart `tuned` on its own — the ktune file
  is a `require` of the service, not a `notify` (`init.pp`). Editing
  ktune-only parameters (e.g. `$io_scheduler`, `$use_sysctl`) will not trigger a
  service restart in the same run.
- **`/etc/sysctl.ktune` is always created empty**, regardless of
  `$use_sysctl_post` (`init.pp`). The `$use_sysctl_post` flag only controls
  whether `ktune` is told to *read* it (`ktune.erb`).
- **Boolean rendering differs between the two templates.** `tuned.conf.erb`
  renders the plugin booleans as capitalized words (`True`/`False`, via
  `.to_s.capitalize`), while `ktune.erb` uses `<% if ... %>` blocks to
  comment/uncomment lines. Match the existing style when adding options.
- **`$elevator_tune_devs` is interpolated into a shell glob** —
  `/sys/block/{hd,sd,cciss}*/queue/scheduler` (`ktune.erb`). Values are joined
  with commas and are not shell-escaped; keep them simple device-name prefixes.
- **`simp/simp_options` is NOT a declared dependency** in `metadata.json`, yet
  the manifest consumes the `simp_options::package_ensure` seam via
  `simplib::lookup` (a function provided by `simp/simplib`). The lookup has an
  explicit `default_value`, so it resolves correctly without `simp_options`
  present; `simp_options` is not even a test fixture (`.fixtures.yml` lists only
  `stdlib` and `simplib`).
- **The `tuned`/`ktune` split is historical.** On EL7-era systems `tuned` and
  `ktune` were distinct; here the package, service, and local `$ktune_name` are
  all just `'tuned'` (`init.pp`). The `ktune` naming survives only in the
  config-file paths and the sysconfig template.

## Dependencies

Module dependencies (from `metadata.json`):

- `simp/simplib` `>= 4.9.0 < 5.0.0` (provides the `simplib::lookup` function used
  for the `simp_options::package_ensure` seam) (`metadata.json`).
- `puppetlabs/stdlib` `>= 8.0.0 < 10.0.0` (`metadata.json`).

There are **no** optional dependencies (`metadata.json` has no
`simp.optional_dependencies` block) and the manifest makes **no**
`simplib::assert_optional_dependency` calls.

Runtime requirement (from `metadata.json` `requirements`, `metadata.json`):
`puppet >= 7.0.0 < 9.0.0`. This is an older SIMP baseline — the module is still
on Puppet and has **not** migrated to OpenVox. The `Gemfile` default Puppet range
matches: `['>= 7', '< 9']` (`Gemfile`), and the Puppet gem is pulled in only
via `gem 'puppet', puppet_version` (`Gemfile`).

Supported OS matrix (from `metadata.json`, `metadata.json`): CentOS 7/8/9;
RedHat 7/8/9; OracleLinux 7/8/9; Rocky 8/9; AlmaLinux 8/9.

## Repository layout

- `manifests/init.pp` — the **sole** manifest; the `tuned` class (all logic).
- `types/ioschedule.pp` — the `Tuned::IoSchedule` enum data type.
- `templates/etc/tuned.conf.erb` — renders `/etc/tuned.conf` (the `tuned`
  daemon plugin config).
- `templates/etc/sysconfig/ktune.erb` — renders `/etc/sysconfig/ktune` (the
  legacy ktune service config).
- `metadata.json` — deps, OS matrix, Puppet requirement.
- `spec/classes/init_spec.rb` — the rspec-puppet unit tests (compile + expected
  file content, driven by `on_supported_os`).
- `spec/expected/default_tuned.conf`, `spec/expected/default_sysconfig_ktune` —
  golden files the unit spec compares rendered output against.
- `spec/spec_helper.rb` — unit test bootstrap (`spec_helper.rb` requires
  `puppetlabs_spec_helper/module_spec_helper`).
- `spec/spec_helper_acceptance.rb` — present, but see the CI note below.
- `REFERENCE.md` — generated Puppet Strings reference; `README.md`, `CHANGELOG`.
- No `data/` directory and no `hiera.yaml` — this module ships **no module
  data** (all defaults are literal parameter defaults in `init.pp`). No `lib/`
  — it has no Ruby types/providers/functions/facts.

### CI

- `.github/workflows/pr_tests.yml` runs the **six standard jobs only**:
  `puppet-syntax`, `puppet-style`, `ruby-style`, `file-checks`,
  `releng-checks`, and `spec-tests` (unit tests on Puppet 7.x and 8.x)
  (`pr_tests.yml`). It uses the older-style global
  `env: PUPPET_VERSION: '~> 7'` (`pr_tests.yml`).
- **There is no acceptance job and no acceptance testing at all.**
  `spec/acceptance/nodesets/` contains **0 files** (there is no beaker nodeset
  and no acceptance suite; only `spec/spec_helper_acceptance.rb` exists as a
  leftover bootstrap). This module is **unit-tests-only**.

## Common commands

```sh
# Install dependencies
bundle install

# Run all unit tests
bundle exec rake spec

# Run the single class spec
bundle exec rspec spec/classes/init_spec.rb

# Puppet lint
bundle exec rake lint

# Ruby lint
bundle exec rake rubocop

# Regenerate REFERENCE.md from puppet-strings docstrings
puppet strings generate --format markdown --out REFERENCE.md
```

There is no `beaker:suites` target to run — the module has no acceptance suite.

Relevant gem pins (from `Gemfile`): `puppetlabs_spec_helper ~> 8.0.0`
(`Gemfile`), `simp-rake-helpers ~> 5.24.0` (`Gemfile`),
`simp-rspec-puppet-facts ~> 4.0.0` (`Gemfile`), `simp-beaker-helpers
~> 2.0.0` (`Gemfile`). Rubocop is pinned to `~> 1.88.0` (`Gemfile`). The
tested Puppet range is `>= 7 < 9` (`Gemfile`).

## Conventions

- Preserve the `@summary`-style header and `@param` puppet-strings docstrings on
  the class (`init.pp`) — they drive `REFERENCE.md`. Regenerate
  `REFERENCE.md` after changing docs or parameters.
- Keep parameter defaults as literals in `init.pp` — this module intentionally
  has no `data/` / `hiera.yaml`. Don't introduce module data for a single value.
- Route SIMP feature toggles through
  `simplib::lookup('simp_options::*', { 'default_value' => ... })` with an
  explicit default rather than assuming `simp_options` is included, as
  `$package_ensure` does (`init.pp`).
- Extend `Tuned::IoSchedule` (`types/ioschedule.pp`) rather than widening
  `$io_scheduler` to a bare `String` if new elevator values are needed.
- `Gemfile`, `spec/spec_helper.rb`, and `.github/workflows/pr_tests.yml` carry a
  **puppetsync** notice — they are baseline-managed and the next sync overwrites
  local edits. Push changes to those files upstream to the baseline, not here.
- Match the existing 2-space Puppet indentation and aligned-arrow parameter
  style used in `manifests/init.pp`.
