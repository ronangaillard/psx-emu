import cpu
import interconnect
import memoryzone
import logging

type
  System* = object
    psxCpu: Cpu
    psxBios: MemoryZone
    psxInterconnect: Interconnect

proc init*(this: var System) =
  this.psxBios = new(MemoryZone)
  this.psxBios.loadFile("./assets/SCPH1001.BIN", BIOS_SIZE)
  this.psxBios.setStartAddr(BIOS_START_ADDR)
  info("Bios loaded")

  this.psxInterconnect = Interconnect()
  this.psxInterconnect.addZone(this.psxBios)
  info("System ready")

  this.psxCpu.init(this.psxInterconnect)

proc run*(this: var System) =
  while true:
    this.psxCpu.runNextInstr()