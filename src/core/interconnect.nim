import memoryzone
import strformat

const LTQ_MC_DDR_BASE_1*: uint32 = 0x1f801000
const LTQ_MC_DDR_BASE_1_VALUE*: uint32 = 0x1f000000
const LTQ_MC_DDR_BASE_2*: uint32 = 0x1f801004
const LTQ_MC_DDR_BASE_2_VALUE*: uint32 = 0x1f802000

type 
  UnallocatedAddress = Exception
  UnalignedMemoryAccess = Exception

type
  Interconnect* = object
    memoryZones: seq[MemoryZone]

proc addZone*(this: var Interconnect, mz: MemoryZone) =
  this.memoryZones.add(mz)

proc load32*(this: Interconnect, address: uint32): uint32 =
  if address mod 4 != 0:
    raise newException(UnalignedMemoryAccess, "Unaligned memory access is not allowed")

  for mz in this.memoryZones:
    if mz.provides(address):
      return mz.load32(address)

  raise newException(UnallocatedAddress, fmt"Address {address:#x} is unallocated")

proc store32*(this: Interconnect, address: uint32, value:uint32) =
  if address mod 4 != 0:
    raise newException(UnalignedMemoryAccess, "Unaligned memory access is not allowed")
    
  for mz in this.memoryZones:
    if mz.provides(address):
      mz.store32(address, value)
      return

  raise newException(UnallocatedAddress, fmt"Address {address:#x} is unallocated") 

proc printState*(this: Interconnect) =
  for mz in this.memoryZones:
    mz.printState()
