import std/[streams]
import config

proc readId3Metadata*(strm: FileStream):AudioMetadata
proc writeId3Metadata*(amd: AudioMetadata, fp: string)

proc readId3Metadata*(strm: FileStream):AudioMetadata =

  discard
  
proc writeId3Metadata*(amd: AudioMetadata, fp: string) =
  discard

