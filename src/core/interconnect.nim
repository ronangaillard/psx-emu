import memoryzone
import strformat

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

  raise newException(UnallocatedAddress, fmt"Address {address} is unallocated")

proc store32*(this: Interconnect, address: uint32, value:uint32) =
  if address mod 4 != 0:
    raise newException(UnalignedMemoryAccess, "Unaligned memory access is not allowed")
    
  for mz in this.memoryZones:
    if mz.provides(address):
      mz.store32(address, value)

  raise newException(UnallocatedAddress, fmt"Address {address} is unallocated") 
