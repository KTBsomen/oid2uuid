String objectIdToUUID(String objectId) {
  if (objectId.length != 24) {
    throw ArgumentError("Invalid ObjectId length. Must be 24 hex characters.");
  }

  // Take first 16 bytes of ObjectId (we can only use 16 bytes for UUID)
  // But we'll store the version and variant bits in the last part to preserve them
  String baseUUID = objectId.substring(0, 24);

  // Get parts for the UUID
  String part1 = baseUUID.substring(0, 8);
  String part2 = baseUUID.substring(8, 12);
  String part3 = baseUUID.substring(12, 16);
  String part4 = baseUUID.substring(16, 20);
  String part5 =
      baseUUID.substring(20, 24) + "00000000"; // Add padding to complete UUID

  // Save the original version bits before modifying
  int originalVersion = int.parse(part3, radix: 16) & 0xF000;

  // Ensure version 4 UUID by setting appropriate bits
  int version = int.parse(part3, radix: 16);
  version = (version & 0x0FFF) | 0x4000; // Set version to 4
  part3 = version.toRadixString(16).padLeft(4, '0');

  // Save the original variant bits before modifying
  int originalVariant = int.parse(part4, radix: 16) & 0xC000;

  // Ensure variant bits are set correctly for UUID
  int variant = int.parse(part4, radix: 16);
  variant = (variant & 0x3FFF) | 0x8000; // Set variant bits
  part4 = variant.toRadixString(16).padLeft(4, '0');

  // Store the original bits in the last segment for recovery
  // First 4 hex digits of part5 is actual ObjectId data
  // Next 2 hex digits store the version bits in positions 4-7
  // Next 2 hex digits store the variant bits in positions 4-7
  String versionBits =
      (originalVersion >> 12).toRadixString(16).padLeft(2, '0');
  String variantBits =
      (originalVariant >> 14).toRadixString(16).padLeft(2, '0');

  part5 =
      part5.substring(0, 4) + versionBits + variantBits + part5.substring(8);

  // Construct UUID string
  return '$part1-$part2-$part3-$part4-$part5';
}

// Convert UUID back to MongoDB ObjectId
String uuidToObjectId(String uuid) {
  // Remove dashes and validate length
  String cleanUUID = uuid.replaceAll('-', '');
  if (cleanUUID.length != 32) {
    throw ArgumentError("Invalid UUID format");
  }

  // Extract parts
  String part1 = cleanUUID.substring(0, 8);
  String part2 = cleanUUID.substring(8, 12);
  String part3Modified = cleanUUID.substring(12, 16);
  String part4Modified = cleanUUID.substring(16, 20);
  String part5 = cleanUUID.substring(20, 32);

  // Extract stored original version and variant bits
  int versionBits = int.parse(part5.substring(4, 6), radix: 16);
  int variantBits = int.parse(part5.substring(6, 8), radix: 16);

  // Reconstruct original version bits
  int originalVersion = int.parse(part3Modified, radix: 16);
  originalVersion = (originalVersion & 0x0FFF) | (versionBits << 12);
  String part3 = originalVersion.toRadixString(16).padLeft(4, '0');

  // Reconstruct original variant bits
  int originalVariant = int.parse(part4Modified, radix: 16);
  originalVariant = (originalVariant & 0x3FFF) | (variantBits << 14);
  String part4 = originalVariant.toRadixString(16).padLeft(4, '0');

  // Get the actual ObjectId data from part5
  String objectIdEnd = part5.substring(0, 4);

  // Reconstruct the original ObjectId
  return part1 + part2 + part3 + part4 + objectIdEnd;
}
