import std/[tables]

proc readFlacMetadata*(fp: string): (OrderedTable[string, tuple[tagname, tagvalue: string, enc: uint8]],
                  seq[tuple[data: seq[uint8]]])
proc writeFlacMetadata*(tags: OrderedTable[string, tuple[tagname, tagvalue: string, enc: uint8]],
                        pics: seq[tuple[data: seq[uint8]]], fp: string)

proc readFlacMetadata*(fp: string): (OrderedTable[string, tuple[tagname, tagvalue: string, enc: uint8]],
                  seq[tuple[data: seq[uint8]]]) =
  discard

proc writeFlacMetadata*(tags: OrderedTable[string, tuple[tagname, tagvalue: string, enc: uint8]],
                        pics: seq[tuple[data: seq[uint8]]], fp: string) =
  discard
