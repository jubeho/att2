import std/[logging,tables,os,strformat,strutils]
import ./[id3tag,flactag]


type

  AudioMetadata* = ref object
    tags*: OrderedTable[string, tuple[tagname, tagvalue: string, enc: uint8]] # key: tagname
    pics*: seq[tuple[textEncoding: uint8, description: string, mimeType: string, picType: uint8, data: seq[byte]]]

proc readAudiometadata*(fp: string): AudioMetadata
proc writeAudiomedata*(am: AudioMetadata, fp: string)

proc readAudiometadata*(fp: string): AudioMetadata =

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
    result = readId3v23(strm)
    if result != nil:
      result.filepath = fp
      result.audioType = atMP3
  elif metadataKind == ['f','L','a']:
    if strm.readChar() != 'C':
      echo fmt("ERROR: found fLa as prefix - expecting 'C' but got not 'C'")
      return nil
    result = parseFlacStream(strm)
    if result != nil:
      result.filepath = fp
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
    writeId3Metadata(am.tags, am.pics, fp)
  of ".flac":
    debug "found flac file"
    writeFlacMetadata(am.tags, am.pics, fp)
  else:
    warn(fmt("unsupport file-type: {ext}"))

when isMainModule:
  let am = readAudiometadata("sepp.mP3")
  let am2 = readAudiometadata("sepp.Flac")
  let am3 = readAudiometadata("sepp.mPd3")
  writeAudiomedata(am, "att.mp3")
