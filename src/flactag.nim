import std/[streams]

proc readFlacMetadata*(strm: FileStream): AudioMetadata
proc writeFlacMetadata*(am: AudioMetadata, fp: string)

proc readFlacMetadata*(strm: FileStream):AudioMetadata =
  discard

proc writeFlacMetadata*(am: AudioMetadata, fp: string) =
  discard
