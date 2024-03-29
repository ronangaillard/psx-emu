import memoryzone
import strformat

const REGION_MASK: array[8, uint32] = [
  # KUSEG: 2048MB
  0xffffffff.uint32, 0xffffffff.uint32, 0xffffffff.uint32, 0xffffffff.uint32,
  # KUSEG0: 512MB
  0x7fffffff.uint32,
  # KSEG1: 512MB,
  0x1fffffff.uint32,
  # KSEG2: 1024MB
  0xffffffff.uint32, 0xffffffff.uint32
]

type 
  UnallocatedAddress = Exception
  UnalignedMemoryAccess = Exception

type
  Interconnect* = object
    memoryZones: seq[MemoryZone]

proc addZone*(this: var Interconnect, mz: MemoryZone) =
  this.memoryZones.add(mz)

proc maskCpuAddress(address: uint32): uint32 =
  let index = (address shr 29)

  return address and REGION_MASK[index]

proc load32*(this: Interconnect, address: uint32): uint32 =
  if address mod 4 != 0:
    raise newException(UnalignedMemoryAccess, "Unaligned memory access is not allowed")

  let maskedAddress = maskCpuAddress(address)

  for mz in this.memoryZones:
    if mz.provides(maskedAddress):
      return mz.load32(maskedAddress)

  raise newException(UnallocatedAddress, fmt"Address {address:#x} is unallocated")

proc load8*(this: Interconnect, address: uint32): uint8 =
  let maskedAddress = maskCpuAddress(address)

  for mz in this.memoryZones:
    if mz.provides(maskedAddress):
      return mz.load8(maskedAddress)

  raise newException(UnallocatedAddress, fmt"Address {address:#x} is unallocated")

proc store32*(this: Interconnect, address: uint32, value:uint32) =
  if address mod 4 != 0:
    raise newException(UnalignedMemoryAccess, "Unaligned memory access is not allowed")
    
  let maskedAddress = maskCpuAddress(address)

  for mz in this.memoryZones:
    if mz.provides(maskedAddress):
      mz.store32(maskedAddress, value)
      return

  raise newException(UnallocatedAddress, fmt"Address {address:#x} is unallocated") 

proc store16*(this: Interconnect, address:uint32, value:uint16) =
  if address mod 2 != 0:
    raise newException(UnalignedMemoryAccess, "Unaligned memory access is not allowed")
    
  let maskedAddress = maskCpuAddress(address)

  for mz in this.memoryZones:
    if mz.provides(maskedAddress):
      mz.store16(maskedAddress, value)
      return

  raise newException(UnallocatedAddress, fmt"Address {address:#x} is unallocated") 

proc store8*(this: Interconnect, address:uint32, value:uint8) =
  let maskedAddress = maskCpuAddress(address)

  for mz in this.memoryZones:
    if mz.provides(maskedAddress):
      mz.store8(maskedAddress, value)
      return

  raise newException(UnallocatedAddress, fmt"Address {address:#x} is unallocated") 

proc printState*(this: Interconnect) =
  for mz in this.memoryZones:
    mz.printState()
