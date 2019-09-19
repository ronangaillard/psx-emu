import memoryzone
import strformat

type UnallocatedAddress = Exception

type
  Interconnect* = object
    memoryZones: seq[MemoryZone]

proc addZone*(this: var Interconnect, mz: MemoryZone) =
  this.memoryZones.add(mz)

proc load32*(this: Interconnect, address: uint32): uint32 =
  for mz in this.memoryZones:
    if mz.provides(address):
      return mz.load32(address)

  raise newException(UnallocatedAddress, fmt"Address {address} is unallocated")

