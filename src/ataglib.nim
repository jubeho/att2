import std/[logging,tables,os,strformat,strutils,streams]
import config

var consoleLog = newConsoleLogger(levelThreshold=lvlInfo, fmtStr="[$levelname] ")
if len(getHandlers()) == 0:
  echo "ataglib: added handler"
  addHandler(consoleLog)

type
  Enc* = enum
    encIso = 0x00'u8,
    encUtf16 = 0x01'u8,
    encUtf8 = 0x03'u8
    
  TagType* = enum
    ttUndef, ttId3v22, ttId3v23, ttId3v24, ttVorbisComment

  AudioType* = enum
    atMP3,atFLAC

  Pic* = ref object
    enc*: Enc
    description*: string
    mimeType*: string
    `type`*: uint8
    data*: seq[byte]

  Header* = ref object
    flags*: byte
    size*: uint32

  Tag* = ref object
    name*: string
    value*: string
    enc*: Enc
  
  AudioMetadata* = ref object
    audiotype*: AudioType
    tagtype*: TagType
    header*: Header
    tags*: OrderedTable[string, Tag] # key: ataglib-tagname 
    pics*: seq[Pic]

include id3tag
include flactag
   
proc readAudiometadata*(fp: string, cfg: AttConfig): AudioMetadata
proc writeAudiomedata*(am: AudioMetadata, srcfp, destfp: string)

proc `$`*(tags: OrderedTable[string, Tag]): string

proc readAudiometadata*(fp: string, cfg: AttConfig): AudioMetadata =
  let strm = newFileStream(fp, fmRead)
  if strm == nil:
    error(fmt("could not open stream for file {fp}"))
    return nil
  defer: strm.close()

  result = new(AudioMetaData)

  var metadataKind: array[3, char]
  try:
    discard strm.readData(addr metadataKind, 3)
  except:
    echo IOError
    return

  if metadataKind == ['I','D','3']:
    result = readId3Metadata(strm, cfg.id3v23ToAtt)
    if result != nil:
      info(fmt("read in id3-tag from {fp}"))
      result.audioType = atMP3
    else:
      info(fmt("could not read id3Tag for {fp}"))
      return nil
  elif metadataKind == ['f','L','a']:
    if strm.readChar() != 'C':
      error("found fLa as prefix - expecting 'C' but got not 'C'")
      return nil
    result = readFlacMetadata(strm, cfg.vorbisToAtt)
    if result != nil:
      info(fmt("read in vorbis-coomment from {fp}"))
      result.audioType = atFLAC
  else:
    warn(fmt("unsupported or no metadata kind (tag-typ3) {metadataKind}"))
    return nil

proc writeAudiomedata*(am: AudioMetadata, srcfp, destfp: string) =
  if os.fileExists(destfp):
    warn(fmt("file already exists, overwriting it: {destfp}"))
  var (_, _, ext) = os.splitFile(destfp)
  ext = toLower(ext)
  case ext
  of ".mp3":
    debug "found mp3 file"
    writeId3Metadata(am, srcfp, destfp)
  of ".flac":
    debug "found flac file"
    writeFlacMetadata(am, destfp)
  else:
    warn(fmt("unsupport file-type: {ext}"))

proc `$`*(tags: OrderedTable[string, Tag]): string =
  result = ""
  for tagname, tagval in pairs(tags):
    result.add(fmt("{tagname}=={tagval.value}\n"))
    
when isMainModule:
  let cfg = loadConfig("tagmap.toml")
  let am = readAudiometadata("123.mp3", cfg)
  
