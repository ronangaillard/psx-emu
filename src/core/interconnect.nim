import memoryzone

type
  Interconnect* = object
    memoryZones: seq[MemoryZone]

proc addZone*(this: var Interconnect, mz: MemoryZone) =
  this.memoryZones.add(mz)

proc load32*(this: Interconnect, address: uint32): uint32 =
  for mz in this.memoryZones:
    if mz.provides(address):
      return mz.load32(address)

