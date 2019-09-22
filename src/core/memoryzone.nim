import streams
import logging
import strformat

const BIOS_START_ADDR* = 0x1fc00000.uint32
const BIOS_SIZE* = 512 * 1024

const RAM_SIZE_REG_ADDR* = 0x1f801060.uint32
const CACHE_CONTROL_ADDR* = 0xfffe0130.uint32

const RAM_START_ADDR* = 0x00000000.uint32
const RAM_SIZE* = 2 * 1024 * 1024

const SPU_REGISTER_SIZE* = 640
const SPU_REGISTER_ADDR* = 0x1f801c00.uint32

const LTQ_MC_DDR_BASE_1*: uint32 = 0x1f801000
const LTQ_MC_DDR_BASE_1_VALUE*: uint32 = 0x1f000000
const LTQ_MC_DDR_BASE_2*: uint32 = 0x1f801004
const LTQ_MC_DDR_BASE_2_VALUE*: uint32 = 0x1f802000

const EXPANSION1_ADDRESS* = 0x1f000084
const EXPANSION1_SIZE* = 1

const EXPANSION2_ADDRESS* = 0x1f802000.uint32
const EXPANSION2_SIZE* = 66

const INTERRUPT_REGISTER_ADDRESS* = 0x1f801070
const INTERRUPT_REGISTER_SIZE* = 8

const WORD_SIZE* = 4

type
  MemoryAccessMode* = enum
    readOnly, readWrite, noChange

  MemoryZone* = ref object
    data: seq[uint8]
    startAddr: uint32

    mode: MemoryAccessMode

proc loadFile*(this: var MemoryZone, filepath: string, size: int) =
  this.data = newSeq[uint8](size)
  let f = newFileStream(filepath, fmRead)
  if isNil(f):
     raise new(Exception)

  assert f.readData(addr(this.data[0]), size) == size

  info(fmt"Loaded {size} bytes of file {filepath}")

proc fromMemory32*(this: var MemoryZone, data: openArray[uint32]) =
  for data32 in data:
    this.data.add((data32 and 0xff).uint8)
    this.data.add((data32 shr 8 and 0xff).uint8)
    this.data.add((data32 shr 16 and 0xff).uint8)
    this.data.add((data32 shr 24 and 0xff).uint8)

proc fromMemory8*(this: var MemoryZone, data: openArray[uint8]) =
  for i in data:
    this.data.add(i)

proc initEmpty*(this: var MemoryZone, size: uint32) =
  this.data = newSeq[uint8](size)

proc setMode*(this: var MemoryZone, newMode: MemoryAccessMode) =
  this.mode = newMode
  
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

proc load8*(this: MemoryZone, address: uint32): uint8 =
  let offset = address - this.startAddr

  return this.data[offset]

proc store32*(this: MemoryZone, address: uint32, value: uint32) =
  if this.mode == MemoryAccessMode.readOnly:
    raise newException(Exception, "Trying to write to read only memory")
  if this.mode == MemoryAccessMode.noChange and this.load32(address) != value:
    raise newException(Exception, "Trying to change value to \"no change\" memory")
    
  let offset = address - this.startAddr

  this.data[offset + 0] = (value and 0xff).uint8
  this.data[offset + 1] = (value shr 8 and 0xff).uint8
  this.data[offset + 2] = (value shr 16 and 0xff).uint8
  this.data[offset + 3] = (value shr 24 and 0xff).uint8

proc store16*(this: MemoryZone, address: uint32, value: uint16) =
  if this.mode == MemoryAccessMode.readOnly:
    raise newException(Exception, "Trying to write to read only memory")
  if this.mode == MemoryAccessMode.noChange and this.load32(address) != value:
    raise newException(Exception, "Trying to change value to \"no change\" memory")
    
  # TODO

proc store8*(this: MemoryZone, address: uint32, value: uint8) =
  if this.mode == MemoryAccessMode.readOnly:
    raise newException(Exception, "Trying to write to read only memory")
  if this.mode == MemoryAccessMode.noChange and this.load32(address) != value:
    raise newException(Exception, "Trying to change value to \"no change\" memory")
    
  let offset = address - this.startAddr

  this.data[offset] = value

proc printState*(this: MemoryZone) =
  info(fmt"MemoryZone [{this.startAddr:#x}, {(this.startAddr + this.data.len.uint32):#x}] mode : {this.mode}")
