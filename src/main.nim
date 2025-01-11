import std/[logging,tables,strformat,os]
import argparse
import ./[att]

var p = newParser:
  help("this is att2 - nice to meet you")
  command("show"):
    help("show's the tags from given file(s)/folder")
    arg("args", help="file(s)/folder to show tags from", nargs = -1)

proc cmdShow(args: seq[string])
    
try:
  let opts = p.parse()
  if opts.command == "show":
    cmdShow(opts.show.get.args)
except ShortCircuit as err:
  if err.flag == "argparse_help":
    echo err.help
    quit(1)
except UsageError:
  stderr.writeLine getCurrentExceptionMsg()
  quit(1)

proc cmdShow(args: seq[string]) =
  var attdata = newAttData(args)
  echo $attdata.audioMetadatas
  echo(fmt("found {len(attdata.files)} and read tags from {len(attdata.audioMetadatas)}"))
  for file in keys(attdata.audioMetadatas):
    echo file
  attdata.audioMetadatas[absolutePath("123.mp3")].tags["YEAR"].value = "2025"
  echo $attdata.audioMetadatas
  for v in values(attdata.audioMetadatas):
    if len(v.pics) > 0:
      echo "got pics..."
  writeAudiometadatas(attdata, @[(absolutePath("123.mp3"), "att2-firstWrite.mp3")])

