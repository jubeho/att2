import std/[logging,tables,strformat]
import ./[ataglib,config,fileutils]

var consoleLog = newConsoleLogger(levelThreshold=lvlInfo, fmtStr="[$levelname] ")
if len(getHandlers()) == 0:
  echo "att: added handler"
  addHandler(consoleLog)

type
  AttData* = ref object
    files*: seq[string]
    cfg*: AttConfig
    audioMetadatas*: OrderedTable[string, AudioMetadata] # key: filepath

proc newAttData*(args: seq[string], cfgfile: string = "tagmap.toml"): AttData

proc `$`*(audiometadatas: OrderedTable[string, AudioMetadata]): string

proc newAttData*(args: seq[string], cfgfile: string = "tagmap.toml"): AttData =
  result = AttData(
    cfg: loadConfig(cfgfile),
    audioMetadatas: initOrderedTable[string, AudioMetadata](),
  )
  for file in getFiles(args, @[".mp3"]):
    result.files.add(file)
    let amd = readAudiometadata(file, result.cfg)
    if amd != nil:
      result.audioMetadatas[file] = amd

proc `$`*(audiometadatas: OrderedTable[string, AudioMetadata]): string =
  result = ""
  for file, audiometadata in pairs(audiometadatas):
    result.add(fmt("FILE=={file}\n"))
    result.add($audiometadata.tags)

