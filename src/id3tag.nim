import std/[encodings]
import bio
import bitseqs

proc readId3Metadata*(strm: FileStream, tagmap: OrderedTable[string, string]):AudioMetadata
proc writeId3Metadata*(amd: AudioMetadata, fp: string)

proc decodeTagsize(sizeRaw: uint32): uint32
proc readTextInformationFrame(strm: FileStream):(tuple[flags: uint16, enc: uint8, information: string])


proc readId3Metadata*(strm: FileStream, tagmap: OrderedTable[string, string]): AudioMetadata =
  result = AudioMetaData(
    header: Header(),
  )
  let
    metadataVersion = strm.readUint8()
    metadataRevision = strm.readUint8()
  if metadataVersion != 3:
    warn(fmt("got id3v2.{metadataVersion} mp3-tag"))
    warn("currently only id3v2.3 mp3-tags are supported... sorry")
    return nil
  result.tagtype = ttId3v23
  result.header.flags = strm.readUint8()
  if result.header.flags != 0x00:
    warn(fmt("currently only 0x00 header-flags are supported, got flags {result.header.flags} sorry"))
    return nil
  result.header.size = decodeTagsize(strm.readBEUint32())

  var startPaddingBytes = false
  while (strm.getPosition() < int(result.header.size)+10):
    let frameId = strm.readStr(4)
    if frameId == "TXXX":
      debug("found TXXX frame")
      # let (_, enc, desc, val) = readTxxxTif(strm)
      # echo "TXXX frames currently not supported... sorry skip this file"
      # return nil
      # echo "################## TXXX #################"
      # echo fmt("enc: {enc}\nDescription '{desc}': {val}\n")
      continue
    if frameId.startsWith("T"):
      debug(fmt("found text-information-frame {frameId}"))
      let (_ , enc, val) = readTextInformationFrame(strm)
      # result.textInformations.add((kind: frameId, enc: enc, value: val))
      var attTagname = frameId
      if hasKey(tagmap, frameId):
        attTagname = tagmap[frameId]
      if hasKey(result.tags, attTagname):
        warn(fmt("found non-unique (att-)tagname: {attTagname}\nskip this (att-)tagname..."))
      else:
        if enc == 0x02'u8 or (enc notin Enc.low.uint8..Enc.high.uint8):
          error(fmt("unsupported ENCODING {enc} for id3v23-tag {frameid}"))
          system.quit("too hot stuff for me, sorry! Bye...")
        result.tags[attTagname] = Tag(name: frameId, value: val, enc: cast[Enc](enc))
      continue
    if frameId == "APIC":
      debug("found APIC-frame")
      # result.pics.add(readApicFrame(strm))
      continue
    if frameId[0] == '\x00':
      if not startPaddingBytes:
        startPaddingBytes = true
      continue
    else:
      warn(fmt("unsupported frame-id: {frameId}"))
      let frameSize = strm.readBEUint32()
      let frameFlags = strm.readBEUint16()
      strm.setPosition(strm.getPosition() + int(frameSize))
  
proc writeId3Metadata*(amd: AudioMetadata, fp: string) =
  discard

# decodeTagsize calculates the weird id3v2.3 size (7th-bit is always 0)
# to "regular" size
proc decodeTagsize(sizeRaw: uint32): uint32 =
  let sizeRawBs = sizeRaw.toBitSeq()

  var sizeBs = newBitSeq(32)
  var idx = 31
  for i in countdown(31, 0):
    if i in @[0,8,16,24]:
      continue
    sizeBs[idx] = sizeRawBs[i]
    idx -= 1
  
  sizeBs[0] = 0.Bit
  sizeBs[1] = 0.Bit
  sizeBs[2] = 0.Bit
  sizeBs[3] = 0.Bit
  
  result = fromBitSeq[uint32](sizeBs)

proc readTextInformationFrame(strm: FileStream):(tuple[flags: uint16, enc: uint8, information: string])=
  let frameSize = strm.readBEUint32()
  let frameFlags = strm.readBEUint16()
  var frameEncoding = strm.readUint8() # is writeable; if encoding is not 0x00 or 0x01 we repair it
  let frameRawValue = strm.readStr(int(frameSize-1))
  var frameValue = ""
  if frameEncoding == 0x00: # ISO-8859-1
    frameValue = convert(frameRawValue, "UTF-8", "ISO-8859-1")
  elif frameEncoding == 0x01: # UTF16
    frameValue = convert(frameRawValue, "UTF-8", "UTF-16")
  elif frameEncoding == 0x03: # UTF8
    frameValue = frameRawValue
    frameEncoding = 0x01
  else:
    error(fmt("unsupported frame encoding: {frameEncoding}"))
    return (0,0,"")
  if (len(frameValue) > 0) and (int(frameValue[^1]) == 0x00):
    frameValue = frameValue[0..^2]
  else:
    warn(fmt("malformed frame-information: {frameValue} - missing 0x00 termination!"))
  result = (frameFlags, frameEncoding, frameValue)
