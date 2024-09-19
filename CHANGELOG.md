# Changelog

## 1.8.4 - 2024-09-19

- Use `stream` subdomain for SSE (#203)

## 1.8.3 - 2024-09-16

- Add JavaScript stub & bootstrapping (#200)

## 1.8.2 - 2024-09-03

- Forbid bad semantic_logger version (#198)

## 1.8.1 - 2024-09-03

- Fix SSE reconnection bug (#197)

## 1.8.0 - 2024-08-22

- Load config from belt and failover to suspenders (#195)

## 1.7.2 - 2024-06-24

- Support JSON config values (#194)

## 1.7.1 - 2024-04-11

- Ergonomics (#191)

## 1.7.0 - 2024-04-10

- Add duration support (#187)

## 1.6.2 - 2024-03-29

- Fix context telemetry when JIT and Block contexts are combined (#185)
- Remove logger prefix (#186)

## 1.6.1 - 2024-03-28

- Performance optimizations (#178)
- Global context (#182)

## 1.6.0 - 2024-03-27

- Use semantic_logger for internal logging (#173)
- Remove Prefab::LoggerClient as a logger for end users (#173)
- Provide log_filter for end users (#173)

## 1.5.1 - 2024-02-22

- Fix: Send context shapes by default (#174)

## 1.5.0 - 2024-02-12

- Fix potential inconsistent Context behavior (#172)

## 1.4.5 - 2024-01-31

- Refactor out a `should_log?` method (#170)

## 1.4.4 - 2024-01-26

- Raise when ENV var is missing

## 1.4.3 - 2024-01-17

- Updated proto definition file

## 1.4.2 - 2023-12-14

- Use reportable value even for invalid data (#166)

## 1.4.1 - 2023-12-08

- Include version in `get` request (#165)

## 1.4.0 - 2023-11-28

- ActiveJob tagged logger issue (#164)
- Compact Log Format (#163)
- Tagged Logging (#161)
- ContextKey logging thread safety (#162)

## 1.3.2 - 2023-11-15

- Send back cloud.prefab logging telemetry (#160)

## 1.3.1 - 2023-11-14

- Improve path of rails.controller logging & fix strong param include (#159)

## 1.3.0 - 2023-11-13

- Less logging when wifi is off and we load from cache (#157)
- Alpha: Add Provided & Secret Support (#152)
- Alpha: x_datafile (#156)
- Add single line action-controller output under rails.controller (#158)

## 1.2.1 - 2023-11-01

- Update protobuf definitions (#154)

## 1.2.0 - 2023-10-30

- Add `Prefab.get('key')` style usage after a `Prefab.init()` call (#151)
- Add `add_context_keys` and `with_context_keys` method for LoggerClient (#145)

## 1.1.2 - 2023-10-13

- Add `cloud.prefab.client.criteria_evaluator` `debug` logging of evaluations (#150)
- Add `x_use_local_cache` for local caching (#148)
- Tests run in RubyMine (#147)

## 1.1.1 - 2023-10-11

- Migrate happy-path client-initialization logging to `DEBUG` level rather than `INFO` (#144)
- Add `ConfigClientPresenter` for logging out stats upon successful client initialization (#144)
- Add support for default context (#146)

## 1.1.0 - 2023-09-18

- Add support for structured logging (#143)
  - Ability to pass a hash of key/value context pairs to any of the user-facing log methods

## 1.0.1 - 2023-08-17

- Bug fix for StringList w/ ExampleContextsAggregator (#141)

## 1.0.0 - 2023-08-10

- Removed EvaluatedKeysAggregator (#137)
- Change `collect_evaluation_summaries` default to true (#136)
- Removed some backwards compatibility shims (#133)
- Standardizing options (#132)
  - Note that the default value for `context_upload_mode` is `:periodic_example` which means example contexts will be collected.
    This enables easy variant override assignment in our UI. More at https://prefab.cloud/blog/feature-flag-variant-assignment/

## 0.24.6 - 2023-07-31

- Logger Client compatibility (#129)
- Replace EvaluatedConfigs with ExampleContexts (#128)
- Add ConfigEvaluationSummaries (opt-in for now) (#123)

## 0.24.5 - 2023-07-10

- Report Client Version (#121)

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
