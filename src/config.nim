import std/[tables]
import parsetoml

type
  AttConfig* = ref object
    id3v23ToAtt*: OrderedTable[string, string]
    attToid3v23*: OrderedTable[string, string]
    vorbisToAtt*: OrderedTable[string, string]
    attToVorbis*: OrderedTable[string, string]
    

proc loadTagmap*(fp: string): AttConfig

proc loadTagmap*(fp: string): AttConfig =
  result = AttConfig()
  result.id3v23ToAtt = initOrderedTable[string, string]()
  result.attToid3v23 = initOrderedTable[string, string]()
  result.vorbisToAtt = initOrderedTable[string, string]()
  result.attToVorbis = initOrderedTable[string, string]()
    
  let toml = parsetoml.parseFile(fp)
  let
    id3v23  = toml["id3v23"].getTable()
    vorbis = toml["vorbis"].getTable()
  for k, v in id3v23:
    result.attToid3v23[k] = v.getStr()
    result.id3v23ToAtt[v.getStr()] = k
  for k, v in vorbis:
    result.attToVorbis[k] = v.getStr()
    result.vorbisToAtt[v.getStr()] = k

when isMainModule:
  discard loadTagmap("tagmap.toml")
