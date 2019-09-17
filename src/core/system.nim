import cpu
import interconnect
import memoryzone

type
  System* = object
    psxCpu: Cpu
    psxBios: MemoryZone
    psxInterconnect: Interconnect

proc init*(this: var System) =
  this.psxBios = new(MemoryZone)
  this.psxBios.loadFile("./assets/SCPH1001.BIN", BIOS_SIZE)
  echo("Bios loaded")

  this.psxInterconnect = Interconnect()
  this.psxInterconnect.addZone(this.psxBios)

  echo("System ready")

