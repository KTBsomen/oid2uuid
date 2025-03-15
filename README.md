# oid2uuid
This document explains a bidirectional conversion system between MongoDB ObjectId and UUID formats. The implementation preserves all information during the conversion, allowing perfect roundtrip operations.
# ObjectId to UUID Conversion Library

## Background

### MongoDB ObjectId
- 12 bytes (24 hex characters)
- Structure: timestamp (4 bytes) + machine ID (3 bytes) + process ID (2 bytes) + counter (3 bytes)
- No special version or variant bits

### UUID
- 16 bytes (32 hex characters + 4 hyphens)
- Format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
- Version 4 UUIDs require specific bits at positions 12-15 (stored as the first hex digit of the third group)
- Variant bits are required at positions 64-65 (stored as the first hex digit of the fourth group)

## Function Explanations

### `objectIdToUUID(String objectId)`

```dart
String objectIdToUUID(String objectId) {
  if (objectId.length != 24) {
    throw ArgumentError("Invalid ObjectId length. Must be 24 hex characters.");
  }
```
- This checks that the input is a valid ObjectId string (24 hex characters)
- Throws an exception if the length is invalid

```dart
  // Take first 16 bytes of ObjectId (we can only use 16 bytes for UUID)
  // But we'll store the version and variant bits in the last part to preserve them
  String baseUUID = objectId.substring(0, 24);
```
- Creates a base string containing all 24 hex characters from the ObjectId
- We'll distribute these characters across the UUID format

```dart
  // Get parts for the UUID
  String part1 = baseUUID.substring(0, 8);
  String part2 = baseUUID.substring(8, 12);
  String part3 = baseUUID.substring(12, 16);
  String part4 = baseUUID.substring(16, 20);
  String part5 = baseUUID.substring(20, 24) + "00000000"; // Add padding to complete UUID
```
- Divides the ObjectId into segments matching the UUID format
- `part1`: First 8 characters (4 bytes)
- `part2`: Next 4 characters (2 bytes)
- `part3`: Next 4 characters (2 bytes) - will contain version bits
- `part4`: Next 4 characters (2 bytes) - will contain variant bits
- `part5`: Last 4 characters (2 bytes) + 8 characters of padding to complete the 12-character group

```dart
  // Save the original version bits before modifying
  int originalVersion = int.parse(part3, radix: 16) & 0xF000;
```
- Converts `part3` from a hex string to an integer
- Applies a bitwise AND with `0xF000` (binary: 1111 0000 0000 0000)
- This extracts the top 4 bits that will be overwritten by UUID version bits
- These bits are part of the original ObjectId data we need to preserve

```dart
  // Ensure version 4 UUID by setting appropriate bits
  int version = int.parse(part3, radix: 16);
  version = (version & 0x0FFF) | 0x4000; // Set version to 4
  part3 = version.toRadixString(16).padLeft(4, '0');
```
- Converts `part3` again to an integer
- Masks out the top 4 bits with `0x0FFF` (binary: 0000 1111 1111 1111)
- Sets the version bits to 4 by OR-ing with `0x4000` (binary: 0100 0000 0000 0000)
- Converts back to a hex string, ensuring it's 4 characters long with padding

```dart
  // Save the original variant bits before modifying
  int originalVariant = int.parse(part4, radix: 16) & 0xC000;
```
- Similar to saving version bits, this preserves the top 2 bits from `part4`
- Uses `0xC000` mask (binary: 1100 0000 0000 0000)
- These bits will be overwritten by the UUID variant bits

```dart
  // Ensure variant bits are set correctly for UUID
  int variant = int.parse(part4, radix: 16);
  variant = (variant & 0x3FFF) | 0x8000; // Set variant bits
  part4 = variant.toRadixString(16).padLeft(4, '0');
```
- Converts `part4` to an integer
- Masks out the top 2 bits with `0x3FFF` (binary: 0011 1111 1111 1111)
- Sets the variant bits to `10` (binary format) with `0x8000` (binary: 1000 0000 0000 0000)
- Converts back to a 4-character hex string

```dart
  // Store the original bits in the last segment for recovery
  // First 4 hex digits of part5 is actual ObjectId data
  // Next 2 hex digits store the version bits in positions 4-7
  // Next 2 hex digits store the variant bits in positions 4-7
  String versionBits = (originalVersion >> 12).toRadixString(16).padLeft(2, '0');
  String variantBits = (originalVariant >> 14).toRadixString(16).padLeft(2, '0');
```
- Shifts the saved original bits to create compact representations
- For version bits: Shifts right by 12 positions to get a 4-bit value (1 hex digit)
- For variant bits: Shifts right by 14 positions to get a 2-bit value
- Converts both to 2-character hex strings

```dart
  part5 = part5.substring(0, 4) + versionBits + variantBits + part5.substring(8);
```
- Modifies `part5` to store our preserved bits
- First 4 characters: Original ObjectId data
- Next 2 characters: Original version bits
- Next 2 characters: Original variant bits
- Rest: Keeping the original padding

```dart
  // Construct UUID string
  return '$part1-$part2-$part3-$part4-$part5';
}
```
- Combines all parts with hyphens to create a standard UUID format

### `uuidToObjectId(String uuid)`

```dart
String uuidToObjectId(String uuid) {
  // Remove dashes and validate length
  String cleanUUID = uuid.replaceAll('-', '');
  if (cleanUUID.length != 32) {
    throw ArgumentError("Invalid UUID format");
  }
```
- Removes all hyphens from the UUID string
- Validates that the resulting string is exactly 32 characters (16 bytes)

```dart
  // Extract parts
  String part1 = cleanUUID.substring(0, 8);
  String part2 = cleanUUID.substring(8, 12);
  String part3Modified = cleanUUID.substring(12, 16);
  String part4Modified = cleanUUID.substring(16, 20);
  String part5 = cleanUUID.substring(20, 32);
```
- Splits the UUID into its component parts
- Note that `part3Modified` and `part4Modified` contain the UUID-specific version and variant bits

```dart
  // Extract stored original version and variant bits
  int versionBits = int.parse(part5.substring(4, 6), radix: 16);
  int variantBits = int.parse(part5.substring(6, 8), radix: 16);
```
- Retrieves the original version and variant bits we stored in `part5`
- These are in positions 4-5 (version) and 6-7 (variant) of `part5`

```dart
  // Reconstruct original version bits
  int originalVersion = int.parse(part3Modified, radix: 16);
  originalVersion = (originalVersion & 0x0FFF) | (versionBits << 12);
  String part3 = originalVersion.toRadixString(16).padLeft(4, '0');
```
- Converts the modified `part3` to an integer
- Clears the top 4 bits (version bits) with the mask `0x0FFF`
- Shifts our saved version bits left by 12 positions
- OR combines with the cleared number to restore the original bits
- Converts back to a 4-character hex string

```dart
  // Reconstruct original variant bits
  int originalVariant = int.parse(part4Modified, radix: 16);
  originalVariant = (originalVariant & 0x3FFF) | (variantBits << 14);
  String part4 = originalVariant.toRadixString(16).padLeft(4, '0');
```
- Similar to version bit restoration:
- Converts `part4Modified` to an integer
- Clears the top 2 bits (variant bits) with the mask `0x3FFF`
- Shifts saved variant bits left by 14 positions
- OR combines to restore the original bits
- Converts back to a 4-character hex string

```dart
  // Get the actual ObjectId data from part5
  String objectIdEnd = part5.substring(0, 4);
```
- Extracts the first 4 characters from `part5`, which contain original ObjectId data

```dart
  // Reconstruct the original ObjectId
  return part1 + part2 + part3 + part4 + objectIdEnd;
}
```
- Concatenates all parts to rebuild the original 24-character ObjectId

## Bit Manipulation Details

### Version Bits
- In UUID: Bits 12-15 must be set to `0100` (hex: 4) for version 4 UUID
- Operation to set: `(value & 0x0FFF) | 0x4000`
  - `0x0FFF` = `0000 1111 1111 1111` (clears top 4 bits)
  - `0x4000` = `0100 0000 0000 0000` (sets version to 4)

### Variant Bits
- In UUID: Bits 64-65 must be set to `10` for RFC 4122 variant
- Operation to set: `(value & 0x3FFF) | 0x8000`
  - `0x3FFF` = `0011 1111 1111 1111` (clears top 2 bits)
  - `0x8000` = `1000 0000 0000 0000` (sets variant bits to `10`)

### Storage of Original Bits
- Version bits are stored in positions 4-5 of `part5` after being shifted right by 12
- Variant bits are stored in positions 6-7 of `part5` after being shifted right by 14
- This compact representation allows perfect reconstruction

## Usage Examples

```dart
// Convert from ObjectId to UUID
String objectId = "507f1f77bcf86cd799439011";
String uuid = objectIdToUUID(objectId);
// Result: "507f1f77-bcf8-4cd7-9943-90114fc00008"

// Convert back to ObjectId
String recoveredId = uuidToObjectId(uuid);
// Result: "507f1f77bcf86cd799439011" (exactly matches original)
```

## Limitations and Considerations

1. The implementation is focused on preserving all bits during conversion, not on generating truly random UUIDs.
2. The resulting UUIDs comply with version 4 and variant specifications, but their distribution is not random.
3. This is specifically designed for MongoDB ObjectId conversion and might not be suitable for general UUID generation.
