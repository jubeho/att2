import std/[logging]
import ./[ataglib]

type
  AttData* = ref object
    audioMetadatas*: OrderedTable[string, AudioMetadata] # key: filepath

