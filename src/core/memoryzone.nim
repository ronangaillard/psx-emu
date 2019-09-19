import streams
import logging
import strformat

const BIOS_START_ADDR* = 0xbfc00000.uint32
const BIOS_SIZE* = 512 * 1024

type
  MemoryZone* = ref object
    data: seq[uint8]
    startAddr: uint32

proc loadFile*(this: var MemoryZone, filepath: string, size: int) =
  this.data = newSeq[uint8](size)
  let f = newFileStream(filepath, fmRead)
  if isNil(f):
     raise new(Exception)

  assert f.readData(addr(this.data[0]), size) == size

  info(fmt"Loaded {size} bytes of file {filepath}")

proc setStartAddr*(this: var MemoryZone, startAddr: uint32) =
  this.startAddr = startAddr

proc provides*(this: MemoryZone, address: uint32): bool =
  return address >= this.startAddr and address < this.startAddr + this.data.len.uint32

proc load32*(this: MemoryZone, address: uint32): uint32 =
  let offset = address - this.startAddr

  let b0 = this.data[offset + 0].uint32
  let b1 = this.data[offset + 1].uint32
  let b2 = this.data[offset + 2].uint32
  let b3 = this.data[offset + 3].uint32

  return b0 or ( b1 shl 8 ) or ( b2 shl 16 ) or (b3 shl 24)

proc store32*(this: MemoryZone, address: uint32, value: uint32) =
  let offset = address - this.startAddr

  this.data[offset + 0] = (value and 0xff).uint8
  this.data[offset + 1] = (value shr 8 and 0xff).uint8
  this.data[offset + 2] = (value shr 16 and 0xff).uint8
  this.data[offset + 3] = (value shr 32 and 0xff).uint8
