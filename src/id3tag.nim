import std/[encodings]
import bio
import bitseqs
import ./[endians]

proc readId3Metadata*(strm: FileStream, tagmap: OrderedTable[string, string]):AudioMetadata
proc readTextInformationFrame(strm: FileStream): (tuple[flags: uint16, enc: uint8, information: string])
proc readApicFrame(strm: FileStream): Pic

proc writeId3Metadata*(amd: AudioMetadata, srcfp, destfp: string)
proc extractAudiodataFromId3v23(fp: string): string
proc writeTextTags(strm: FileStream, amd: AudioMetadata)
  
proc decodeTagsize(sizeRaw: uint32): uint32
proc encodeTagsize(size: uint32): array[4, byte]
proc toByteArray(num: BitSeq): array[4, uint8]
proc uint8ToEnc(enc: uint8): Enc

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
        result.tags[attTagname] = Tag(name: frameId, value: val, enc: uint8ToEnc(enc))
      continue
    if frameId == "APIC":
      info("found APIC-frame")
      result.pics.add(readApicFrame(strm))
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
  
proc writeId3Metadata*(amd: AudioMetadata, srcfp, destfp: string) =
  if amd.tagtype != ttId3v23:
    warn(fmt("currently only support ID3v2.3 Tags - this is a {amd.tagtype}"))
    return

  let audiodata = extractAudiodataFromId3v23(srcfp)

  var strm = newFileStream(destfp, fmWrite)
  strm.write("ID3")
  const id3v2Version = [byte 0x03, 0x00]
  const tagHeaderFlags = [byte 0x00]
  strm.write(id3v2Version)
  strm.write(tagHeaderFlags)
  # write dummy-Length, because we don not know yet the correct size
  strm.write([byte 0x00, 0x00, 0x00, 0x00])
  
  writeTextTags(strm, amd)
  # writePictureframes(strm, amd.pics)

  let sizeOfTag = strm.getPosition() - 10
  debug(fmt("size of complete tag: {sizeOfTag}"))
  let sizeOfTagBytes = encodeTagsize(uint32(sizeOfTag))
  strm.setPosition(6)
  strm.write(sizeOfTagBytes)

  strm.setPosition(sizeOfTag + 10)
  strm.write(audiodata)

  strm.close
  info(fmt("written {amd.tagtype} to {destfp}"))  
  
proc readTextInformationFrame(strm: FileStream): (tuple[flags: uint16, enc: uint8, information: string])=
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

proc readApicFrame(strm: FileStream): Pic =
  result = Pic()
  let frameStartPos = strm.getPosition()
  let frameSize = strm.readBEUint32()
  let frameFlags = strm.readBEUint16()
  let posTextEncodingStart = strm.getPosition()
  result.enc = uint8ToEnc(strm.readUint8())
  while true:
    let c = strm.readChar()
    if c == '\x00':
      break
    result.mimeType.add(c)
  result.type = strm.readUint8()

  # [[ read description ]]
  var description = ""
  while true:
    let c = strm.readChar()
    if c == '\x00':
      if strm.peekChar() == '\x00':
        discard strm.readChar()
      break
    description.add(c)

  if result.enc == encIso:
    result.description = convert(description, "UTF-8", "ISO-8859-1")
  elif result.enc == encUtf16:
    result.description = convert(description, "UTF-8", "UTF-16")

  let dataLength = int(frameSize) - (strm.getPosition() - posTextEncodingStart)
  debug(fmt("framesize: {int(frameSize)}({frameSize})"))
  debug(fmt("dataLength: {dataLength}"))
  result.data.setLen(dataLength)
  let bytelength = strm.readData(addr(result.data[0]), dataLength)
  debug(fmt("read data bytes: {byteLength}"))
  # writeFile("buidl.jpg", result.data)
  if strm.getPosition() != (frameStartPos + 6 + int(frameSize)):
    error(fmt("APIC End Position {strm.getPosition()} does not match calculation size {(frameStartPos + 6)} :( "))

proc writeTextTags(strm: FileStream, amd: AudioMetadata) =
  for tag in values(amd.tags):
    if tag.name == "TXXX":
      warn(fmt("sorry - no support for TXXX Tags yet :( skip this Tag with value {tag.value}"))
      continue
    let sizeEncoding = 1
    var tagvalue = ""
    var sizeInfoTermination = 0
    case tag.enc
    of encIso:
      tagvalue = convert(tag.value, "ISO-8859-1", "UTF-8")
      sizeInfoTermination = 1
    of encUtf16:
      tagvalue = convert(tag.value, "UTF-16", "UTF-8")
      sizeInfoTermination = 2
    of encUtf8:
      notice(fmt("found UTF-8 Tag: this encoding is not supported by ID3v2 - convert it to UTF-16"))
      tagvalue = convert(tag.value, "UTF-16", "UTF-8")
      tag.enc = encUTF16
      sizeInfoTermination = 2

    let sizeInformation = len(tagvalue) + sizeInfoTermination
    var framesize = toBytesBE(uint32(sizeInformation + sizeEncoding))
    strm.write(tag.name)
    strm.write(framesize)
    strm.write([byte 0x00,0x00])
    var curEnc: uint8 = 0x00'u8
    case tag.enc
    of encIso:
      curEnc = 0x00'u8
    of encUTF16:
      curEnc = 0x01'u8
    else:
      error(fmt("encoding for Tag {tag.name} is not supported: {tag.enc}"))
      strm.close
      system.quit("bye...")
    strm.write(curEnc)
    strm.write(tagvalue)
    if tag.enc == encIso:
      strm.write([byte 0x00])
    elif tag.enc == encUtf16:
      strm.write([byte 0x00,0x00])
    else:
      error(fmt("encoding for Tag {tag.name} is not supported: {tag.enc}"))
    
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

proc encodeTagsize(size: uint32): array[4, byte] =
  let sizeBs = size.toBitSeq()

  var ts = newBitSeq(32)
  for i in countdown(31, 25):
    ts[i] = sizeBs[i]
  ts[24] = 0.Bit
  for i in countdown(24, 18):
    ts[i-1] = sizeBs[i]
  ts[16] = 0.Bit
  for i in countdown(17, 11):
    ts[i-2] = sizeBs[i]
  ts[8] = 0.Bit
  for i in countdown(10, 4):
    ts[i-3] = sizeBs[i]
  ts[0] = 0.Bit

  result = ts.toByteArray()
  
proc uint8ToEnc(enc: uint8): Enc =
  if enc == 0x02'u8 or (enc notin Enc.low.uint8..Enc.high.uint8):
    error(fmt("unsupported ENCODING {enc}"))
    system.quit("too hot stuff for me, sorry! Bye...")
  result = cast[Enc](enc)

proc extractAudiodataFromId3v23(fp: string): string =
  let strm = newFileStream(fp, fmRead)
  if strm == nil:
    error(fmt("could not open stream to extract audiodata from file {fp}"))
    return
  
  var buf: array[3, char]
  try:
    discard strm.readData(addr buf, 3)
  except:
    echo IOError
    return
  defer: strm.close()

  if buf != ['I','D','3']:
    warn(fmt("file has not an ID3-Tag..."))
    return
  let metadataVersion = strm.readUint8()
  if metadataVersion != 3:
      warn(fmt("got id3v2.{metadataVersion}-Tag...currently only id3v2.3 audio-tags are supported... sorry"))
      return
  discard strm.readUint8() # we don not need metadataRevision, but have to go ahead in stream

  const id3v23MetadataSizePos = 6
  strm.setPosition(id3v23MetadataSizePos)
  let orgTagSize = int(decodeTagsize(strm.readBEUint32()))
  strm.setPosition(orgTagSize + 10)
  result = strm.readAll()

proc toByteArray(num: BitSeq): array[4, uint8] =

  var byte4BitSeq = newBitSeq(8)
  byte4BitSeq[7] = num[31]
  byte4BitSeq[6] = num[30]
  byte4BitSeq[5] = num[29]
  byte4BitSeq[4] = num[28]
  byte4BitSeq[3] = num[27]
  byte4BitSeq[2] = num[26]
  byte4BitSeq[1] = num[25]
  byte4BitSeq[0] = num[24]

  var byte3BitSeq = newBitSeq(8)
  byte3BitSeq[7] = num[23]
  byte3BitSeq[6] = num[22]
  byte3BitSeq[5] = num[21]
  byte3BitSeq[4] = num[20]
  byte3BitSeq[3] = num[19]
  byte3BitSeq[2] = num[18]
  byte3BitSeq[1] = num[17]
  byte3BitSeq[0] = num[16]

  var byte2BitSeq = newBitSeq(8)
  byte2BitSeq[7] = num[15]
  byte2BitSeq[6] = num[14]
  byte2BitSeq[5] = num[13]
  byte2BitSeq[4] = num[12]
  byte2BitSeq[3] = num[11]
  byte2BitSeq[2] = num[10]
  byte2BitSeq[1] = num[9]
  byte2BitSeq[0] = num[8]

  var byte1BitSeq = newBitSeq(8)
  byte1BitSeq[7] = num[7]
  byte1BitSeq[6] = num[6]
  byte1BitSeq[5] = num[5]
  byte1BitSeq[4] = num[4]
  byte1BitSeq[3] = num[3]
  byte1BitSeq[2] = num[2]
  byte1BitSeq[1] = num[1]
  byte1BitSeq[0] = num[0]

  #result: array[4, uint8]
  result[0] = fromBitSeq[uint8](byte1BitSeq)
  result[1] = fromBitSeq[uint8](byte2BitSeq)
  result[2] = fromBitSeq[uint8](byte3BitSeq)
  result[3] = fromBitSeq[uint8](byte4BitSeq)
