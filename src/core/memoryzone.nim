import streams

const BIOS_SIZE* = 512 * 1024

type
  MemoryZone* = ref object
    data: seq[uint8]

proc loadFile*(this: var MemoryZone, filepath: string, size: int) =
  this.data = newSeq[uint8](size)
  let f = newFileStream(filepath, fmRead)
  if isNil(f):
     raise new(Exception)

  assert f.readData(addr(this.data[0]), size) == size

proc load32(this: MemoryZone, offset: uint32): uint32 =
  let b0 = this.data[offset + 0].uint32
  let b1 = this.data[offset + 1].uint32
  let b2 = this.data[offset + 2].uint32
  let b3 = this.data[offset + 3].uint32

  return b0 or ( b1 shl 8 ) or ( b2 shl 16 ) or (b3 shl 24)
