# FIT protocol compatibility roadmap

This roadmap tracks gaps found by comparing SwiftFit with Garmin's FIT protocol,
FIT Profile, and Activity file guidance.

## Wire protocol correctness

- [ ] Model developer field definitions as `(field number, size, developer data index)`
  and resolve their base type through the corresponding `field_description` message
  ([PR #5](https://github.com/zaneenders/swift-fit/pull/5)).
- [ ] Use the FIT invalid sentinel for every base type when encoding and map invalid
  sentinels to `.invalid` when decoding; preserve positions in partially invalid byte
  arrays ([PR #3](https://github.com/zaneenders/swift-fit/pull/3)).
- [ ] Add the `uint64z` base type introduced by the current Garmin profile
  ([PR #7](https://github.com/zaneenders/swift-fit/pull/7)).
- [ ] Decode null-separated string arrays, including leading empty entries and trailing
  terminator handling ([PR #4](https://github.com/zaneenders/swift-fit/pull/4)).
- [ ] Validate writer values against their declared base type and encoded field size so
  a mismatched value cannot corrupt all following records.
- [ ] Require FIT protocol 2.0 whenever developer data fields are written
  ([PR #6](https://github.com/zaneenders/swift-fit/pull/6)).
- [ ] Allow local message numbers to be redefined and reused throughout a file rather
  than limiting a writer to sixteen definitions total.
- [ ] Validate protocol versions, reserved record-header bits, definition reserved
  bytes, field sizes, field counts, and other bounded wire values without trapping.
- [ ] Decode FIT strings through the first null terminator instead of joining bytes
  separated by embedded nulls.

## Profile support

- [ ] Generate the complete message/type profile from Garmin's current `Profile.xlsx`,
  including names, enums, units, scales, offsets, subfields, components, accumulated
  components, and native developer-field overrides.
- [ ] Expand packed high-resolution HR messages and support merging their timestamped
  samples into record messages.

## File-type conformance

- [ ] Emit conforming Activity files: one `file_id`, at least one `session`, one
  `activity`, required summary timestamps and durations, and timer events.
- [ ] Add profile-backed support and conformance fixtures for Course, Workout,
  Monitoring, Health, Device, and other standard FIT file types.

## Interoperability verification

- [ ] Run Garmin's official example corpus and FitCSVTool in CI, including developer
  data, big-endian definitions, compressed timestamps, malformed files, and files
  produced by multiple vendors.
- [ ] Add headerless/data-only and partial-recovery decoder modes for embedded streams
  and damaged activity recovery.

## References

- <https://developer.garmin.com/fit/protocol/>
- <https://developer.garmin.com/fit/cookbook/developer-data/>
- <https://developer.garmin.com/fit/file-types/activity/>
- <https://github.com/garmin/fit-sdk-tools/blob/main/Profile.xlsx>
