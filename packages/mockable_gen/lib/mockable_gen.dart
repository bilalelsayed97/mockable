/// `mockable_gen` builder entry point. Consumers wire this in via
/// `build.yaml` (declared in this package) — they do not call into this
/// library directly.
library;

export 'builder.dart' show mockBuilder;
