import std/[os]

proc getFiles*(args: seq[string], pattern: seq[string] = @[".txt", ".jpg"]): seq[string]
proc getFilesHandleFiles(fp: string, pattern: seq[string]): seq[string]
proc getFilesHandleDirs(dir: string, pattern: seq[string]): seq[string]

proc getFiles*(args: seq[string], pattern: seq[string] = @[".txt", ".jpg"]): seq[string] =
  result = @[]
  for arg in args:
    try:
      let fi = getFileInfo(arg)
      if fi.kind == pcFile:
        result.add(getFilesHandleFiles(arg, pattern))
      elif fi.kind == pcDir:
        result.add(getFilesHandleDirs(arg, pattern))
      else:
        discard
    except:
      echo getCurrentExceptionMsg()

proc getFilesHandleFiles(fp: string, pattern: seq[string]): seq[string] =
  result = @[]
  let (_, _, ext) = splitFile(fp)
  if ext in pattern:
    result.add(absolutePath(fp))

proc getFilesHandleDirs(dir: string, pattern: seq[string]): seq[string] =
  result = @[]
  for path in os.walkDirRec(dir):
    let (_, _, ext) = splitFile(path)
    if ext in pattern:
      result.add(absolutePath(path))
