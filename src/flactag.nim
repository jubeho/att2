import std/[streams]

proc readFlacMetadata*(strm: FileStream, tagmap: OrderedTable[string, string]): AudioMetadata
proc writeFlacMetadata*(am: AudioMetadata, fp: string)

proc readFlacMetadata*(strm: FileStream, tagmap: OrderedTable[string, string]):AudioMetadata =
  discard

proc writeFlacMetadata*(am: AudioMetadata, fp: string) =
  discard
