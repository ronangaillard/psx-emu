import memoryzone

type
  Interconnect* = object
    memoryZones: seq[MemoryZone]

proc addZone*(this: var Interconnect, mz: MemoryZone) =
  # Following line for debug only
  this.memoryZones = @[]
  this.memoryZones.add(mz)

