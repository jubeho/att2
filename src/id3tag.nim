import std/[tables,logging]

proc readId3Metadata*(fp: string): (OrderedTable[string, tuple[tagname, tagvalue: string, enc: uint8]],
                  seq[tuple[data: seq[uint8]]])
proc writeId3Metadata*(tags: OrderedTable[string, tuple[tagname, tagvalue: string, enc: uint8]],
                       pics: seq[tuple[data: seq[uint8]]], fp: string)

proc readId3Metadata*(fp: string): (OrderedTable[string, tuple[tagname, tagvalue: string, enc: uint8]],
                  seq[tuple[data: seq[uint8]]]) =

  discard
  
proc writeId3Metadata*(tags: OrderedTable[string, tuple[tagname, tagvalue: string, enc: uint8]],
                       pics: seq[tuple[data: seq[uint8]]], fp: string) =
  discard

