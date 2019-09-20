import cpu
import interconnect
import memoryzone
import logging

type
  System* = object
    psxCpu: Cpu
    psxBios: MemoryZone
    memoryControl: MemoryZone
    psxInterconnect: Interconnect

proc init*(this: var System) =
  this.psxBios = new(MemoryZone)
  this.psxBios.loadFile("./assets/SCPH1001.BIN", BIOS_SIZE)
  this.psxBios.setStartAddr(BIOS_START_ADDR)
  this.psxBios.setMode(MemoryAccessMode.readOnly)
  info("Bios loaded")

  this.memoryControl = new(MemoryZone)
  this.memoryControl.fromMemory32([LTQ_MC_DDR_BASE_1_VALUE, LTQ_MC_DDR_BASE_2_VALUE])
  this.memoryControl.setStartAddr(LTQ_MC_DDR_BASE_1)
  this.memoryControl.setMode(MemoryAccessMode.noChange)

  this.psxInterconnect = Interconnect()
  this.psxInterconnect.addZone(this.psxBios)
  this.psxInterconnect.addZone(this.memoryControl)
  info("System ready")

  this.psxCpu.init(this.psxInterconnect)

proc run*(this: var System) =
  while true:
    this.psxCpu.runNextInstr()