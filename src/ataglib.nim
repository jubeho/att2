import std/[logging,tables,os,strformat,strutils,streams]
import config

type
  Enc* = enum
    encIso = 0x00
    encUtf16 = 0x01
    encUtf8 = 0x03
    
  TagType* = enum
    ttUndef, ttID3v22, ttID3v23, ttID3v24, ttVorbisComment

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
    tags*: OrderedTable[string, Tag] # key: ataglib-tagname from 
    pics*: seq[Pic]

include id3tag
include flactag
   
proc readAudiometadata*(fp: string, cfg: AttConfig): AudioMetadata
proc writeAudiomedata*(am: AudioMetadata, fp: string)

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
      result.audioType = atMP3
  elif metadataKind == ['f','L','a']:
    if strm.readChar() != 'C':
      echo fmt("ERROR: found fLa as prefix - expecting 'C' but got not 'C'")
      return nil
    result = readFlacMetadata(strm, cfg.vorbisToAtt)
    if result != nil:
      result.audioType = atFLAC
  else:
    echo fmt("unsupported or no metadata kind (tag-typ3) {metadataKind}")
    return nil

proc writeAudiomedata*(am: AudioMetadata, fp: string) =
  if os.fileExists(fp):
    warn(fmt("file already exists, overwriting it: {fp}"))
  var (_, _, ext) = os.splitFile(fp)
  ext = toLower(ext)
  case ext
  of ".mp3":
    debug "found mp3 file"
    writeId3Metadata(am, fp)
  of ".flac":
    debug "found flac file"
    writeFlacMetadata(am, fp)
  else:
    warn(fmt("unsupport file-type: {ext}"))

when isMainModule:
  let cfg = loadTagmap("tagmap.toml")
  let am = readAudiometadata("sepp.mP3", cfg)
  let am2 = readAudiometadata("sepp.Flac", cfg)
  let am3 = readAudiometadata("sepp.mPd3", cfg)
  writeAudiomedata(am, "att.mp3")
