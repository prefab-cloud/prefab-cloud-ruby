# Changelog

## Unreleased

## [0.24.4] - 2023-07-06

- Support Timed Loggers (#119)
- Added EvaluatedConfigsAggregator (disabled by default) (#118)
- Added EvaluatedKeysAggregator (disabled by default) (#117)
- Dropped Ruby 2.6 support (#116)
- Capture/report context shapes (#115)
- Added bin/console (#114)

## [0.24.3] - 2023-05-15

- Add JSON log formatter (#106)

# [0.24.2] - 2023-05-12

- Fix bug in FF rollout eval consistency (#108)
- Simplify forking (#107)

# [0.24.1] - 2023-04-26

- Fix misleading deprecation warning (#105)

# [0.24.0] - 2023-04-26

- Backwards compatibility for JIT context (#104)
- Remove upsert (#103)
- Add resolver presenter and `on_update` callback (#102)
- Deprecate `lookup_key` and introduce Context (#99)

# [0.23.8] - 2023-04-21

- Update protobuf (#101)

# [0.23.7] - 2023-04-21

- Guard against ActiveJob not being loaded (#100)

# [0.23.6] - 2023-04-17

- Fix bug in FF rollout eval consistency (#98)
- Add tests for block-form of logging (#96)

# [0.23.5] - 2023-04-13

- Cast the value to string when checking presence in string list (#95)

# [0.23.4] - 2023-04-12

- Remove GRPC (#93)

# [0.23.3] - 2023-04-07

- Use exponential backoff for log level uploading (#92)

# [0.23.2] - 2023-04-04

- Move log collection logs from INFO to DEBUG (#91)
- Fix: Handle trailing slash in PREFAB_API_URL (#90)

# [0.23.1] - 2023-03-30

- ActiveStorage not defined in Rails < 5.2 (#87)

# [0.23.0] - 2023-03-28

- Convenience for setting Rails.logger (#85)
- Log evaluation according to rules (#81)

# [0.22.0] - 2023-03-15

- Report log paths and usages (#79)
- Accept hash or keyword args in `initialize` (#78)
