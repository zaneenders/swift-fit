# SwiftFit

A Swift 6 library for reading and writing [Garmin FIT](https://developer.garmin.com/fit/protocol/) activity files.

## Packages

| Target | Description |
|--------|-------------|
| `SwiftFit` | Low-level FIT decoder, writer, CRC, and profile constants |
| `SwiftFitActivity` | Higher-level activity parsing and encoding |

## Usage

```swift
import SwiftFit
import SwiftFitActivity

let bytes = try Data(contentsOf: fitURL)
let summary = try FITActivityParser.parse(bytes: Array(bytes))

let encoded = try FITActivityEncoder.encode(summary)
```

### Decode options

```swift
var options = FITDecodeOptions()
options.validateFileCRC = true
options.validateHeaderCRC = true
options.strictDefinitions = true

let fit = try FITFile(bytes: bytes, options: options)
```

By default, file and header CRC mismatches are reported via `fileCRCValid` / `headerCRCValid` but do not fail decoding. Enable the matching `validate*` flags to throw.

## Supported protocol features

- 12- and 14-byte headers with optional header CRC validation
- Definition and data messages
- Compressed timestamp headers (read and write)
- Developer field payloads in definitions
- `developer_data_id` (207) and `developer_data_definition` (206) message parsing
- Little-endian architecture (read and write)
- Big-endian architecture (read)

## Requirements

- macOS 13+
- Swift 6.3+

## Development

```bash
export PATH="$HOME/.swiftly/bin:$PATH"
swift build
swift test
```

The package builds with strict Swift 6 language mode, strict memory safety, and warnings treated as errors.

## Testing

You can use the following commands to view current test coverage.

**macOS**
```bash
export PATH="$HOME/.swiftly/bin:$PATH"
swift test --enable-code-coverage
PROFDATA=$(find .build -name '*.profdata' -print -quit)
BIN=$(find .build -name 'SwiftFitPackageTests' -type f -not -path '*.dSYM*' -print -quit)
xcrun llvm-cov report "$BIN" --instr-profile="$PROFDATA" --ignore-filename-regex='(\.build/|Tests/)'
```

**Linux**
```bash
swift test --enable-code-coverage
PROFDATA=$(find .build -name '*.profdata' -print -quit)
BIN=$(find .build -name 'SwiftFitPackageTests.xctest' -type f -print -quit)
llvm-cov report "$BIN" --instr-profile="$PROFDATA" --ignore-filename-regex='(\.build/|Tests/)'
```

## License

See repository license.
