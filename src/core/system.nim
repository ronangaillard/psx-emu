import cpu
import interconnect
import memoryzone
import logging

type
  System* = object
    psxCpu: Cpu
    psxBios: MemoryZone
    memoryControl1: MemoryZone
    memoryControl2: MemoryZone
    psxInterconnect: Interconnect

proc init*(this: var System) =
  this.psxBios = new(MemoryZone)
  this.psxBios.loadFile("./assets/SCPH1001.BIN", BIOS_SIZE)
  this.psxBios.setStartAddr(BIOS_START_ADDR)
  this.psxBios.setMode(MemoryAccessMode.readOnly)
  info("Bios loaded")

  this.memoryControl1 = new(MemoryZone)
  this.memoryControl1.fromMemory32([LTQ_MC_DDR_BASE_1_VALUE, LTQ_MC_DDR_BASE_2_VALUE])
  this.memoryControl1.setStartAddr(LTQ_MC_DDR_BASE_1)
  this.memoryControl1.setMode(MemoryAccessMode.noChange)

  this.memoryControl2 = new(MemoryZone)
  this.memoryControl2.initEmpty(28)
  this.memoryControl2.setStartAddr(LTQ_MC_DDR_BASE_2 + 4)
  this.memoryControl2.setMode(MemoryAccessMode.readWrite)

  this.psxInterconnect = Interconnect()
  this.psxInterconnect.addZone(this.psxBios)
  this.psxInterconnect.addZone(this.memoryControl1)
  this.psxInterconnect.addZone(this.memoryControl2)
  info("System ready")

  this.psxCpu.init(this.psxInterconnect)

proc run*(this: var System) =
  try:
    while true:
      this.psxCpu.runNextInstr()
  except:
    this.psxCpu.printState()
    this.psxInterconnect.printState()
    raise